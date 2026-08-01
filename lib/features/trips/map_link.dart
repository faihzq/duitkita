/// Turning a pasted Google Maps share link into coordinates.
///
/// A name search ("Kajang") can land on the wrong side of town; a share link is
/// the exact pin. But Maps deep links only accept a place name, `lat,lng` or a
/// place ID as a `destination` — a share URL cannot be embedded — so to get
/// directions to the pin the link has to be reduced to coordinates first.
library;

import 'package:http/http.dart' as http;

/// Hosts that hand out shortened links, which must be expanded before the
/// coordinates are visible.
const _shortHosts = {
  'maps.app.goo.gl',
  'goo.gl',
  'g.co',
  'maps.google.com', // sometimes issues a redirect too
};

bool looksLikeMapUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) return false;
  if (!uri.scheme.startsWith('http')) return false;
  final host = uri.host.toLowerCase();
  return host.contains('google') || _shortHosts.contains(host);
}

bool _isShortLink(Uri uri) {
  final host = uri.host.toLowerCase();
  return _shortHosts.contains(host) && !uri.path.startsWith('/maps/place');
}

/// Pulls `lat,lng` out of an already-expanded Maps URL.
///
/// Ordered by trustworthiness:
///   `!3d<lat>!4d<lng>` — the place's own coordinates, embedded in the data blob
///   `q=` / `ll=` / `destination=` / `center=` — an explicit point
///   `@<lat>,<lng>` — the *camera* centre, which is only near the place
///
/// Returns null when the URL carries no coordinates (a short link, or a bare
/// `/maps/place/Name` with no data blob).
String? latLngFromMapUrl(String url) {
  final raw = url.trim();
  String text;
  try {
    // Decode first so %2C separators become plain commas.
    text = Uri.decodeFull(raw);
  } on FormatException {
    text = raw; // Stray '%' — match against the original.
  }
  const num = r'(-?\d+\.\d+)';

  final place = RegExp('!3d$num!4d$num').firstMatch(text);
  if (place != null) return '${place.group(1)},${place.group(2)}';

  // `query` before `q` so the shorter name can't shadow it.
  final param = RegExp(
    '[?&](?:query|q|ll|destination|center|daddr|saddr)=$num,\\s*$num',
  ).firstMatch(text);
  if (param != null) return '${param.group(1)},${param.group(2)}';

  final camera = RegExp('@$num,$num').firstMatch(text);
  if (camera != null) return '${camera.group(1)},${camera.group(2)}';

  return null;
}

/// The place name written into a `/maps/place/<name>/…` URL.
///
/// Many share links carry no coordinates at all — Google identifies the place
/// with a hex id in the `data=` blob instead — but the path still holds the
/// full name and address, e.g. "Lily Penang Hill Ice Kacang, Bukit Bendera,
/// 11500 Bukit Bendera, Penang". That is specific enough to be a reliable
/// directions destination.
String? placeNameFromMapUrl(String url) {
  final match = RegExp(
    r'/maps/(?:place|search)/([^/@?]+)',
  ).firstMatch(url.trim());
  if (match == null) return null;

  var name = match.group(1)!.replaceAll('+', ' ');
  try {
    name = Uri.decodeComponent(name);
  } on FormatException {
    // Leave it as-is; the '+' swap alone is usually enough.
  }
  name = name.trim();
  // A coordinate pair in the path is not a name.
  if (name.isEmpty || RegExp(r'^-?\d+\.\d+,-?\d+\.\d+$').hasMatch(name)) {
    return null;
  }
  return name;
}

/// What a share link resolved to.
class ResolvedPlace {
  final String query;

  /// True for `lat,lng`, false when this is a place name. Coordinates are
  /// exact; a name still has to be geocoded by Google.
  final bool isCoordinates;

  const ResolvedPlace(this.query, {required this.isCoordinates});
}

/// Expands a short link if needed, then pulls out the most precise location it
/// can: coordinates when present, otherwise the place name from the URL.
///
/// Only follows redirects — no API key, no quota. Returns null when nothing can
/// be read, in which case the caller should keep the URL as-is: it still opens
/// correctly, it just can't be used as a directions destination.
Future<ResolvedPlace?> resolveMapLink(String url, {http.Client? client}) async {
  final trimmed = url.trim();

  final direct = latLngFromMapUrl(trimmed);
  if (direct != null) return ResolvedPlace(direct, isCoordinates: true);

  final directName = placeNameFromMapUrl(trimmed);
  if (directName != null) {
    return ResolvedPlace(directName, isCoordinates: false);
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !_isShortLink(uri)) return null;

  final owned = client == null;
  final http.Client c = client ?? http.Client();
  try {
    var target = uri;
    String? name;
    // Short links can bounce more than once before landing on the real URL.
    for (var hop = 0; hop < 5; hop++) {
      final request = http.Request('GET', target)..followRedirects = false;
      final response = await c.send(request);
      final location = response.headers['location'];
      if (location == null || location.isEmpty) break;

      target = Uri.parse(
        location.startsWith('http')
            ? location
            : target.resolve(location).toString(),
      );
      final expanded = target.toString();

      // Coordinates win outright; a name is held in case none turn up.
      final found = latLngFromMapUrl(expanded);
      if (found != null) return ResolvedPlace(found, isCoordinates: true);
      name ??= placeNameFromMapUrl(expanded);
    }
    if (name != null) return ResolvedPlace(name, isCoordinates: false);
  } catch (_) {
    // Offline or blocked — the raw link still works for opening.
  } finally {
    if (owned) c.close();
  }
  return null;
}
