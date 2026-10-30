import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/itinerary_stop.dart';

void main() {
  ItineraryStop makeStop({
    String id = 'stop-1',
    int day = 1,
    String time = '10:00 AM',
    String title = 'Ferry to Langkawi',
    String? note,
    StopType type = StopType.travel,
    String? placeQuery,
    int? legMinutes,
    double? legKm,
  }) =>
      ItineraryStop(
        id: id,
        day: day,
        time: time,
        title: title,
        note: note,
        type: type,
        placeQuery: placeQuery,
        legMinutes: legMinutes,
        legKm: legKm,
      );

  group('minutesFromTimeLabel', () {
    test('parses 12-hour labels', () {
      expect(minutesFromTimeLabel('10:00 AM'), 600);
      expect(minutesFromTimeLabel('1:30 PM'), 13 * 60 + 30);
      expect(minutesFromTimeLabel('12:00 AM'), 0);
      expect(minutesFromTimeLabel('12:15 PM'), 12 * 60 + 15);
    });

    test('parses 24-hour labels', () {
      expect(minutesFromTimeLabel('22:15'), 22 * 60 + 15);
      expect(minutesFromTimeLabel('06:01'), 361);
    });

    test('returns 0 for unparseable input', () {
      expect(minutesFromTimeLabel(''), 0);
      expect(minutesFromTimeLabel('morning'), 0);
    });
  });

  group('formatDuration', () {
    test('formats minutes, hours, and combinations', () {
      expect(formatDuration(45), '45 min');
      expect(formatDuration(60), '1 h');
      expect(formatDuration(100), '1 h 40');
      expect(formatDuration(0), '0 min');
    });
  });

  group('ItineraryStop', () {
    test('legLabel combines time and distance', () {
      expect(makeStop(legMinutes: 100, legKm: 155).legLabel, '~1 h 40 · 155 km');
      expect(makeStop(legMinutes: 75).legLabel, '~1 h 15');
      expect(makeStop(legKm: 6).legLabel, '~6 km');
      expect(makeStop().legLabel, '');
    });

    test('openUri prefers a saved share link over searching by name', () {
      final withLink = ItineraryStop(
        id: 'x',
        day: 1,
        time: '9:00 AM',
        title: 'Home',
        placeQuery: '2.0453,102.5689',
        mapUrl: 'https://maps.app.goo.gl/AbCdEf',
      );
      expect(withLink.openUri.toString(), 'https://maps.app.goo.gl/AbCdEf');
    });

    test('openUri falls back to a search when there is no link', () {
      expect(
        makeStop(placeQuery: 'Penang Hill').openUri.toString(),
        contains('maps/search/?api=1&query=Penang%20Hill'),
      );
    });

    test('openUri ignores a malformed link rather than launching junk', () {
      final bad = ItineraryStop(
        id: 'x',
        day: 1,
        time: '9:00 AM',
        title: 'Home',
        placeQuery: 'Kajang',
        mapUrl: 'not a url',
      );
      expect(bad.openUri.toString(), contains('maps/search'));
    });

    test('hasLeg is false when neither value is set', () {
      expect(makeStop().hasLeg, isFalse);
      expect(makeStop(legKm: 3).hasLeg, isTrue);
    });

    test('mapQuery prefers placeQuery, then title + note', () {
      expect(
        makeStop(placeQuery: 'Kuala Perlis Ferry Terminal').mapQuery,
        'Kuala Perlis Ferry Terminal',
      );
      expect(
        makeStop(title: 'TS Duty Free', note: 'Kuah').mapQuery,
        'TS Duty Free Kuah',
      );
      expect(makeStop(title: 'Penang Hill').mapQuery, 'Penang Hill');
    });

    test('placeLabel prefers placeQuery, then note, then title', () {
      expect(makeStop(placeQuery: 'Tambun, Ipoh').placeLabel, 'Tambun, Ipoh');
      expect(makeStop(note: 'Check in').placeLabel, 'Check in');
      expect(makeStop(title: 'Penang Hill').placeLabel, 'Penang Hill');
    });

    test('round-trips through toMap/fromMap', () {
      final stop = makeStop(
        day: 3,
        type: StopType.stay,
        placeQuery: 'Ulu Melaka, Langkawi',
        legMinutes: 10,
        legKm: 4,
      );
      final restored = ItineraryStop.fromMap(stop.toMap(), 'stop-1');

      expect(restored.day, 3);
      expect(restored.type, StopType.stay);
      expect(restored.placeQuery, 'Ulu Melaka, Langkawi');
      expect(restored.legMinutes, 10);
      expect(restored.legKm, 4.0);
    });

    test('round-trips the map link', () {
      final stop = ItineraryStop(
        id: 'x',
        day: 1,
        time: '9:00 AM',
        title: 'Home',
        mapUrl: 'https://maps.app.goo.gl/AbCdEf',
      );
      final restored = ItineraryStop.fromMap(stop.toMap(), 'x');

      expect(restored.mapUrl, 'https://maps.app.goo.gl/AbCdEf');
    });

    test('fromMap leaves mapUrl null for stops saved before the field existed',
        () {
      final restored = ItineraryStop.fromMap(
        {'day': 1, 'time': '9:00 AM', 'title': 'Old stop'},
        'legacy',
      );
      expect(restored.mapUrl, isNull);
      expect(restored.openUri.toString(), contains('maps/search'));
    });

    test('fromMap falls back to travel for an unknown type', () {
      final restored = ItineraryStop.fromMap(
        {'day': 1, 'time': '9:00 AM', 'title': 'X', 'type': 'nonsense'},
        'stop-x',
      );
      expect(restored.type, StopType.travel);
    });
  });

  group('dayTotals', () {
    test('sums legs and ignores unset ones', () {
      final totals = dayTotals([
        makeStop(id: 'a'),
        makeStop(id: 'b', legMinutes: 150, legKm: 175),
        makeStop(id: 'c', legMinutes: 45, legKm: 30),
      ]);
      expect(totals.minutes, 195);
      expect(totals.km, 205);
    });

    test('is zero for an empty day', () {
      final totals = dayTotals([]);
      expect(totals.minutes, 0);
      expect(totals.km, 0);
    });
  });

  group('TripMaps', () {
    test('search encodes the query', () {
      expect(
        TripMaps.search('Penang Hill, Air Itam').toString(),
        'https://www.google.com/maps/search/?api=1&query=Penang%20Hill%2C%20Air%20Itam',
      );
    });

    test('directions requests driving mode', () {
      final url = TripMaps.directions('Kuala Perlis Ferry Terminal').toString();
      expect(url, contains('travelmode=driving'));
      expect(url, contains('destination=Kuala%20Perlis%20Ferry%20Terminal'));
    });

    test('accepts coordinates as a place, for pin-only locations', () {
      final url = TripMaps.leg('2.0453, 102.5689', 'Jeti Kuala Perlis').toString();
      // Maps resolves an encoded lat,lng origin the same as a named place.
      expect(url, contains('origin=2.0453%2C%20102.5689'));

      expect(
        TripMaps.search('6.4414,99.7772').toString(),
        contains('query=6.4414%2C99.7772'),
      );
    });

    test('leg links a single origin to a destination', () {
      final url = TripMaps.leg('Kajang', 'Jeti Kuala Perlis').toString();
      expect(url, contains('origin=Kajang'));
      expect(url, contains('destination=Jeti%20Kuala%20Perlis'));
      expect(url, contains('travelmode=driving'));
      expect(url, isNot(contains('waypoints')));
    });

    test('dayRoute chains origin, waypoints and destination', () {
      final url = TripMaps.dayRoute([
        makeStop(id: 'a', placeQuery: 'Alor Setar'),
        makeStop(id: 'b', placeQuery: 'Kuala Perlis'),
        makeStop(id: 'c', placeQuery: 'Langkawi'),
      ])!;
      expect(url.toString(), contains('origin=Alor%20Setar'));
      expect(url.toString(), contains('destination=Langkawi'));
      expect(url.toString(), contains('waypoints=Kuala%20Perlis'));
    });

    test('dayRoute excludes break stops', () {
      final url = TripMaps.dayRoute([
        makeStop(id: 'a', placeQuery: 'Alor Setar'),
        makeStop(id: 'b', placeQuery: 'R&R Tapah', type: StopType.prayer),
        makeStop(id: 'c', placeQuery: 'Langkawi'),
      ])!;
      expect(url.toString(), isNot(contains('waypoints')));
      expect(url.toString(), contains('origin=Alor%20Setar'));
      expect(url.toString(), contains('destination=Langkawi'));
    });

    test('dayRoute falls back to plain directions for a single stop', () {
      final url = TripMaps.dayRoute([makeStop(placeQuery: 'Penang Hill')])!;
      expect(url.toString(), contains('destination=Penang%20Hill'));
      expect(url.toString(), isNot(contains('origin=')));
    });

    test('dayRoute returns null when nothing is mappable', () {
      expect(TripMaps.dayRoute([]), isNull);
      expect(
        TripMaps.dayRoute([makeStop(type: StopType.prayer, title: 'Subuh')]),
        isNull,
      );
    });
  });
}
