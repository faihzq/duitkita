import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/makan/makan_geo.dart';
import 'package:duitkita/features/makan/makan_style.dart';
import 'package:duitkita/models/makan_spot.dart';

MakanSpot spot(
  String id, {
  double? lat,
  double? lng,
  String? mapQuery,
  String? mapLink,
}) => MakanSpot(
  id: id,
  name: 'Spot $id',
  area: 'Bangi',
  lat: lat,
  lng: lng,
  mapQuery: mapQuery,
  mapLink: mapLink,
  addedBy: 'uid-1',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  const klcc = (lat: 3.1579, lng: 101.7116);
  const bangi = (lat: 2.9264, lng: 101.7820);

  group('parseLatLng', () {
    test('reads coordinate pairs', () {
      expect(parseLatLng('3.1579,101.7116'), klcc);
      expect(parseLatLng(' -6.2, 106.8 '), (lat: -6.2, lng: 106.8));
    });

    test('rejects names and out-of-range values', () {
      expect(parseLatLng('Warung Mak Teh, Bangi'), isNull);
      expect(parseLatLng('95.0,101.0'), isNull);
      expect(parseLatLng(null), isNull);
    });
  });

  group('MakanSpot.coords', () {
    test('prefers stored lat/lng', () {
      final s = spot('a', lat: 1.5, lng: 103.7, mapQuery: '3.1579,101.7116');
      expect(s.coords, (lat: 1.5, lng: 103.7));
    });

    test('falls back to a coordinate mapQuery', () {
      expect(spot('a', mapQuery: '3.1579,101.7116').coords, klcc);
    });

    test('null for a name-only spot', () {
      expect(spot('a', mapQuery: 'Bangi Gateway').coords, isNull);
    });

    test('lat/lng survive toMap/fromMap', () {
      final back = MakanSpot.fromMap(
        spot('a', lat: 2.9, lng: 101.7).toMap(),
        'a',
      );
      expect(back.coords, (lat: 2.9, lng: 101.7));
    });
  });

  test('distanceKm is about right for KLCC to Bangi', () {
    expect(distanceKm(klcc, bangi), closeTo(26.8, 1.0));
    expect(distanceKm(klcc, klcc), 0);
  });

  test('formatDistance', () {
    expect(formatDistance(0.347), '350 m');
    expect(formatDistance(1.23), '1.2 km');
    expect(formatDistance(14.6), '15 km');
  });

  test('sortByDistance puts unknown locations last, in their order', () {
    final spots = [
      spot('far', lat: bangi.lat, lng: bangi.lng),
      spot('none1'),
      spot('near', lat: 3.158, lng: 101.712),
      spot('none2'),
    ];
    final d = distancesFrom(klcc, spots);
    expect(d.keys, unorderedEquals(['far', 'near']));
    expect(sortByDistance(spots, d).map((s) => s.id), [
      'near',
      'far',
      'none1',
      'none2',
    ]);
  });

  group('MakanMaps', () {
    test('coordinates win for Google Maps and Waze', () {
      final s = spot('a', lat: 2.9, lng: 101.7, mapQuery: 'Bangi Gateway');
      expect(MakanMaps.google(s).queryParameters['destination'], '2.9,101.7');
      expect(MakanMaps.waze(s).queryParameters['ll'], '2.9,101.7');
    });

    test('an unresolved share link opens as-is', () {
      final s = spot('a', mapLink: 'https://maps.app.goo.gl/abc');
      expect(MakanMaps.google(s).toString(), 'https://maps.app.goo.gl/abc');
    });

    test('nothing at all searches by name and area', () {
      expect(MakanMaps.waze(spot('a')).queryParameters['q'], 'Spot a, Bangi');
    });
  });
}
