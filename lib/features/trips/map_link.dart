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

/// Expands a short link if needed, then extracts coordinates.
///
/// Only follows redirects — no API key, no quota. Returns null when the link
/// can't be resolved, in which case the caller should keep the URL as-is: it
/// still opens correctly, it just can't be used as a directions destination.
Future<String?> resolveMapLink(String url, {http.Client? client}) async {
  final trimmed = url.trim();
  final direct = latLngFromMapUrl(trimmed);
  if (direct != null) return direct;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !_isShortLink(uri)) return null;

  final owned = client == null;
  final http.Client c = client ?? http.Client();
  try {
    var target = uri;
    // Short links can bounce more than once before landing on the real URL.
    for (var hop = 0; hop < 5; hop++) {
      final request = http.Request('GET', target)..followRedirects = false;
      final response = await c.send(request);
      final location = response.headers['location'];
      if (location == null || location.isEmpty) break;

      target = Uri.parse(location.startsWith('http')
          ? location
          : target.resolve(location).toString());

      final found = latLngFromMapUrl(target.toString());
      if (found != null) return found;
    }
  } catch (_) {
    // Offline or blocked — the raw link still works for opening.
  } finally {
    if (owned) c.close();
  }
  return null;
}
