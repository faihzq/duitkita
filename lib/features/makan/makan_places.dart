/// "Fill from Google Maps": look a place up with the Places API (New) and turn
/// what comes back into form values — name, area, location, hours, category.
///
/// The key is passed at build time and never committed:
///   flutter run --dart-define-from-file=secrets.json
/// with `secrets.json` (git-ignored) holding `{"PLACES_API_KEY": "..."}`.
/// Without it [placesConfigured] is false and the form hides the button.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/features/trips/map_link.dart';

const _apiKey = String.fromEnvironment('PLACES_API_KEY');

bool get placesConfigured => _apiKey.isNotEmpty;

/// The headers Google checks on a key restricted to this Android app: the
/// package name and the SHA-1 of the certificate it is signed with. Read once
/// from the platform (Play re-signs the app, so it cannot be hard-coded).
/// Empty off Android or if the lookup fails — an unrestricted key ignores them.
Future<Map<String, String>> _appHeaders() =>
    _appHeadersOnce ??= () async {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        return const <String, String>{};
      }
      try {
        final identity = await const MethodChannel(
          'duitkita/app_identity',
        ).invokeMapMethod<String, String?>('identity');
        final package = identity?['package'];
        final sha1 = identity?['sha1'];
        if (package == null || sha1 == null) return const <String, String>{};
        return {'X-Android-Package': package, 'X-Android-Cert': sha1};
      } catch (_) {
        return const <String, String>{};
      }
    }();
Future<Map<String, String>>? _appHeadersOnce;

/// One search result, already in the shape the form wants.
class MakanPlace {
  final String name;
  final String address;
  final String? area;
  final double? lat;
  final double? lng;
  final WeeklyHours hours;
  final List<String> categories;
  final String? mapsUri;

  const MakanPlace({
    required this.name,
    required this.address,
    this.area,
    this.lat,
    this.lng,
    this.hours = const {},
    this.categories = const [],
    this.mapsUri,
  });

  /// `lat,lng` — the directions destination, exact where a name is not.
  String? get query => lat == null || lng == null ? null : '$lat,$lng';

  factory MakanPlace.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    return MakanPlace(
      name: (json['displayName'] as Map?)?['text'] as String? ?? '',
      address: json['formattedAddress'] as String? ?? '',
      area: areaFromComponents(json['addressComponents'] as List?),
      lat: (location?['latitude'] as num?)?.toDouble(),
      lng: (location?['longitude'] as num?)?.toDouble(),
      hours: hoursFromPeriods(
        (json['regularOpeningHours'] as Map?)?['periods'] as List?,
      ),
      categories: categoriesFromTypes([
        if (json['primaryType'] is String) json['primaryType'] as String,
        ...?(json['types'] as List?)?.whereType<String>(),
      ]),
      mapsUri: json['googleMapsUri'] as String?,
    );
  }
}

/// The town people would call the area: locality first, then the finer or
/// coarser names Google sometimes gives instead.
String? areaFromComponents(List? components) {
  if (components == null) return null;
  for (final type in const [
    'locality',
    'sublocality_level_1',
    'sublocality',
    'administrative_area_level_2',
  ]) {
    for (final c in components.whereType<Map>()) {
      final types = (c['types'] as List?) ?? const [];
      if (types.contains(type)) {
        final name = c['longText'] as String? ?? c['shortText'] as String?;
        if (name != null && name.trim().isNotEmpty) return name.trim();
      }
    }
  }
  return null;
}

/// Google's weekly periods → [WeeklyHours]. Google counts days from Sunday
/// (0); [WeeklyHours] uses `DateTime.weekday` (Monday 1 … Sunday 7). A period
/// with no close is open around the clock.
WeeklyHours hoursFromPeriods(List? periods) {
  if (periods == null || periods.isEmpty) return const {};
  int minutes(Map p) =>
      ((p['hour'] as num?)?.toInt() ?? 0) * 60 +
      ((p['minute'] as num?)?.toInt() ?? 0);
  int weekday(Map p) {
    final day = (p['day'] as num?)?.toInt() ?? 0;
    return day == 0 ? 7 : day;
  }

  final hours = <int, List<OpenSlot>>{};
  for (final period in periods.whereType<Map>()) {
    final open = period['open'] as Map?;
    if (open == null) continue;
    final close = period['close'] as Map?;
    if (close == null) {
      return {
        for (var d = 1; d <= 7; d++) d: const [OpenSlot.allDay],
      };
    }
    final slot = OpenSlot(minutes(open) % 1440, minutes(close) % 1440);
    (hours[weekday(open)] ??= []).add(slot);
  }
  for (final slots in hours.values) {
    slots.sort((a, b) => a.open.compareTo(b.open));
  }
  return hours;
}

/// Google place types → this app's categories. Only clear matches; anything
/// else is left for the user to pick.
List<String> categoriesFromTypes(List<String> types) {
  const map = {
    'cafe': 'Kafe',
    'coffee_shop': 'Kafe',
    'bakery': 'Bakeri',
    'fast_food_restaurant': 'Fast food',
    'hamburger_restaurant': 'Western',
    'american_restaurant': 'Western',
    'steak_house': 'Western',
    'pizza_restaurant': 'Western',
    'chinese_restaurant': 'Chinese',
    'thai_restaurant': 'Thai',
    'seafood_restaurant': 'Seafood',
    'dessert_shop': 'Dessert',
    'dessert_restaurant': 'Dessert',
    'ice_cream_shop': 'Dessert',
  };
  final out = <String>[];
  for (final t in types) {
    final c = map[t];
    if (c != null && !out.contains(c)) out.add(c);
  }
  return out;
}

const _fields = [
  'places.displayName',
  'places.formattedAddress',
  'places.addressComponents',
  'places.location',
  'places.regularOpeningHours.periods',
  'places.primaryType',
  'places.types',
  'places.googleMapsUri',
];

/// What to ask Google for, given a full Maps URL: the place name written in
/// it, kept near the coordinates it carries. A link with coordinates but no
/// name asks for food right at that point. Null when the URL holds neither.
({String query, ({double lat, double lng})? near})? searchFromMapUrl(
  String url,
) {
  final name = placeNameFromMapUrl(url);
  final near = parseLatLng(latLngFromMapUrl(url));
  if (name != null) return (query: name, near: near);
  if (near != null) return (query: 'food', near: near);
  return null;
}

/// Searches Google for [text] — a place name, or a Maps link, which is first
/// expanded so its place name can be searched near its coordinates. (Searching
/// the bare coordinates would find the street address, not the shop.)
Future<List<MakanPlace>> searchPlaces(
  String text, {
  http.Client? client,
}) async {
  var query = text.trim();
  ({double lat, double lng})? near;
  if (looksLikeMapUrl(query)) {
    final url = await expandMapLink(query, client: client);
    final search = url == null ? null : searchFromMapUrl(url);
    if (search == null) {
      throw Exception('Could not read that link. Try the place name instead.');
    }
    query = search.query;
    near = search.near;
  }

  final owned = client == null;
  final c = client ?? http.Client();
  try {
    final response = await c
        .post(
          Uri.parse('https://places.googleapis.com/v1/places:searchText'),
          headers: {
            ...await _appHeaders(),
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': _fields.join(','),
          },
          body: jsonEncode({
            'textQuery': query,
            'maxResultCount': 8,
            'regionCode': 'MY',
            'languageCode': 'en',
            if (near != null)
              'locationBias': {
                'circle': {
                  'center': {'latitude': near.lat, 'longitude': near.lng},
                  'radius': 500.0,
                },
              },
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 429) {
      throw Exception(
        'Today\'s Google search limit is used up. Try again tomorrow, '
        'or fill the spot in by hand.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('Google search failed (${response.statusCode})');
    }
    final places =
        (jsonDecode(response.body) as Map<String, dynamic>)['places']
            as List? ??
        const [];
    return places
        .whereType<Map<String, dynamic>>()
        .map(MakanPlace.fromJson)
        .where((p) => p.name.isNotEmpty)
        .toList();
  } finally {
    if (owned) c.close();
  }
}
