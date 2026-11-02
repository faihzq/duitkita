import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:duitkita/features/trips/map_link.dart';
import 'package:duitkita/features/makan/makan_places.dart';
import 'package:duitkita/models/makan_spot.dart';

void main() {
  group('hoursFromPeriods', () {
    test('maps Google days (Sunday 0) to weekdays (Sunday 7)', () {
      final hours = hoursFromPeriods([
        {
          'open': {'day': 0, 'hour': 7, 'minute': 0},
          'close': {'day': 0, 'hour': 11, 'minute': 30},
        },
        {
          'open': {'day': 1, 'hour': 7, 'minute': 0},
          'close': {'day': 1, 'hour': 11, 'minute': 0},
        },
      ]);
      expect(hours[7], const [OpenSlot(7 * 60, 11 * 60 + 30)]);
      expect(hours[1], const [OpenSlot(7 * 60, 11 * 60)]);
      expect(hours[2], isNull);
    });

    test('a supper stall closing after midnight stays one slot', () {
      final hours = hoursFromPeriods([
        {
          'open': {'day': 5, 'hour': 18, 'minute': 0},
          'close': {'day': 6, 'hour': 2, 'minute': 0},
        },
      ]);
      expect(hours[5], const [OpenSlot(18 * 60, 2 * 60)]);
    });

    test('two sessions in a day are kept in order', () {
      final hours = hoursFromPeriods([
        {
          'open': {'day': 2, 'hour': 17, 'minute': 0},
          'close': {'day': 2, 'hour': 22, 'minute': 0},
        },
        {
          'open': {'day': 2, 'hour': 7, 'minute': 0},
          'close': {'day': 2, 'hour': 12, 'minute': 0},
        },
      ]);
      expect(hours[2], const [
        OpenSlot(7 * 60, 12 * 60),
        OpenSlot(17 * 60, 22 * 60),
      ]);
    });

    test('no close means open around the clock', () {
      final hours = hoursFromPeriods([
        {
          'open': {'day': 0, 'hour': 0, 'minute': 0},
        },
      ]);
      expect(hours.length, 7);
      expect(hours[3], const [OpenSlot.allDay]);
    });

    test('nothing in, nothing out', () {
      expect(hoursFromPeriods(null), isEmpty);
      expect(hoursFromPeriods(const []), isEmpty);
    });
  });

  test('areaFromComponents prefers the locality', () {
    expect(
      areaFromComponents([
        {
          'longText': 'Johor',
          'types': ['administrative_area_level_1'],
        },
        {
          'longText': 'Muar',
          'types': ['locality', 'political'],
        },
      ]),
      'Muar',
    );
    expect(areaFromComponents(null), isNull);
  });

  test('categoriesFromTypes keeps clear matches only, once each', () {
    expect(
      categoriesFromTypes([
        'cafe',
        'coffee_shop',
        'restaurant',
        'food',
        'bakery',
      ]),
      ['Kafe', 'Bakeri'],
    );
  });

  test('MakanPlace.fromJson reads a Places API result', () {
    final place = MakanPlace.fromJson({
      'displayName': {'text': 'Roti Canai Mustaqim'},
      'formattedAddress': 'Jalan Abdullah, 84000 Muar, Johor',
      'addressComponents': [
        {
          'longText': 'Muar',
          'types': ['locality'],
        },
      ],
      'location': {'latitude': 2.0442, 'longitude': 102.5689},
      'primaryType': 'cafe',
      'googleMapsUri': 'https://maps.google.com/?cid=1',
      'regularOpeningHours': {
        'periods': [
          {
            'open': {'day': 1, 'hour': 7, 'minute': 0},
            'close': {'day': 1, 'hour': 11, 'minute': 0},
          },
        ],
      },
    });
    expect(place.name, 'Roti Canai Mustaqim');
    expect(place.area, 'Muar');
    expect(place.query, '2.0442,102.5689');
    expect(place.categories, ['Kafe']);
    expect(place.hours[1], const [OpenSlot(7 * 60, 11 * 60)]);
    expect(place.mapsUri, 'https://maps.google.com/?cid=1');
  });

  group('searchFromMapUrl', () {
    test('searches the name, kept near the place coordinates', () {
      final search = searchFromMapUrl(
        'https://www.google.com/maps/place/Warung+Paktam+Roti+Canai/'
        '@2.04,102.56,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x1!8m2'
        '!3d2.0442!4d102.5689',
      );
      expect(search?.query, 'Warung Paktam Roti Canai');
      expect(search?.near, (lat: 2.0442, lng: 102.5689));
    });

    test('a bare pin asks for food at that point', () {
      final search = searchFromMapUrl(
        'https://maps.google.com/?q=2.0442,102.5689',
      );
      expect(search?.query, 'food');
      expect(search?.near, (lat: 2.0442, lng: 102.5689));
    });

    test('nothing usable gives null', () {
      expect(searchFromMapUrl('https://maps.google.com/'), isNull);
    });
  });

  group('expandMapLink', () {
    test('follows a short link to the full URL', () async {
      const full =
          'https://www.google.com/maps/place/Warung+Paktam/@2.04,102.56,17z';
      // Second hop has no location header, so the loop stops at [full].
      var calls = 0;
      final twoHop = MockClient((request) async {
        calls++;
        return calls == 1
            ? http.Response('', 302, headers: {'location': full})
            : http.Response('', 200);
      });
      expect(
        await expandMapLink('https://maps.app.goo.gl/abc', client: twoHop),
        full,
      );
    });

    test('a full URL comes back untouched', () async {
      const url = 'https://www.google.com/maps/place/X/@1.0,2.0,17z';
      expect(await expandMapLink(url), url);
    });

    test('a short link that goes nowhere gives null', () async {
      final client = MockClient((request) async => http.Response('', 404));
      expect(
        await expandMapLink('https://maps.app.goo.gl/abc', client: client),
        isNull,
      );
    });
  });
}
