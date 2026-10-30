import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/map_link.dart';

void main() {
  group('latLngFromMapUrl', () {
    test('prefers the place coordinates over the camera centre', () {
      // @ is where the camera sits; !3d/!4d is the place itself. They differ.
      const url =
          'https://www.google.com/maps/place/Jeti+Kuala+Perlis/@6.4000,100.1300,17z'
          '/data=!3m1!4b1!4m6!3m5!1s0x304be0!8m2!3d6.4014!4d100.1372';

      expect(latLngFromMapUrl(url), '6.4014,100.1372');
    });

    test('falls back to the camera centre when there is no data blob', () {
      const url =
          'https://www.google.com/maps/place/Penang+Hill/@5.4239,100.2685,15z';

      expect(latLngFromMapUrl(url), '5.4239,100.2685');
    });

    test('reads an explicit query point', () {
      expect(
        latLngFromMapUrl('https://www.google.com/maps?q=2.0453,102.5689'),
        '2.0453,102.5689',
      );
      expect(
        latLngFromMapUrl('https://maps.google.com/?ll=5.4239,100.2685&z=17'),
        '5.4239,100.2685',
      );
    });

    test('reads an encoded query point', () {
      expect(
        latLngFromMapUrl(
            'https://www.google.com/maps/search/?api=1&query=2.0453%2C102.5689'),
        '2.0453,102.5689',
      );
    });

    test('handles negative coordinates', () {
      expect(
        latLngFromMapUrl('https://www.google.com/maps/@-6.1751,106.8650,17z'),
        '-6.1751,106.8650',
      );
    });

    test('returns null for a short link, which carries no coordinates', () {
      expect(latLngFromMapUrl('https://maps.app.goo.gl/AbCdEf123'), isNull);
    });

    test('returns null for a name-only place URL', () {
      expect(
        latLngFromMapUrl('https://www.google.com/maps/place/Penang+Hill'),
        isNull,
      );
    });

    test('is not fooled by a zoom level that looks like a pair', () {
      // "17z" must not be read as part of the coordinates.
      final result = latLngFromMapUrl(
          'https://www.google.com/maps/place/X/@5.4239,100.2685,17z');
      expect(result, '5.4239,100.2685');
    });
  });

  group('looksLikeMapUrl', () {
    test('accepts Google Maps links', () {
      expect(looksLikeMapUrl('https://maps.app.goo.gl/AbCdEf'), isTrue);
      expect(looksLikeMapUrl('https://www.google.com/maps/place/X'), isTrue);
      expect(looksLikeMapUrl('  https://goo.gl/maps/X  '), isTrue);
    });

    test('rejects anything else', () {
      expect(looksLikeMapUrl(''), isFalse);
      expect(looksLikeMapUrl('Jeti Kuala Perlis'), isFalse);
      expect(looksLikeMapUrl('2.0453, 102.5689'), isFalse);
      expect(looksLikeMapUrl('https://waze.com/ul/abc'), isFalse);
    });
  });

  group('placeNameFromMapUrl', () {
    // Many share links carry no coordinates at all — only the name.
    test('reads the name and address out of a place URL', () {
      const url =
          'https://www.google.com/maps/place/Lily+Penang+Hill+Ice+Kacang,+Bukit+Bendera,'
          '+11500+Bukit+Bendera,+Penang/data=!4m2!3m1!1s0x304ac398ec5e62c1:0x79c7a9ab811c328';

      expect(
        placeNameFromMapUrl(url),
        'Lily Penang Hill Ice Kacang, Bukit Bendera, 11500 Bukit Bendera, Penang',
      );
    });

    test('decodes percent-encoded characters', () {
      expect(
        placeNameFromMapUrl('https://www.google.com/maps/place/R%26R+Tapah'),
        'R&R Tapah',
      );
    });

    test('reads a search URL too', () {
      expect(
        placeNameFromMapUrl('https://www.google.com/maps/search/Penang+Hill'),
        'Penang Hill',
      );
    });

    test('does not mistake a coordinate path for a name', () {
      expect(
        placeNameFromMapUrl('https://www.google.com/maps/place/5.4239,100.2685'),
        isNull,
      );
    });

    test('is null when there is no place segment', () {
      expect(placeNameFromMapUrl('https://maps.app.goo.gl/AbCdEf'), isNull);
    });
  });

  group('resolveMapLink', () {
    test('returns coordinates directly when the URL already has them',
        () async {
      // No client passed: a full URL must not need the network at all.
      final r =
          await resolveMapLink('https://www.google.com/maps?q=2.0453,102.5689');
      expect(r?.query, '2.0453,102.5689');
      expect(r?.isCoordinates, isTrue);
    });

    test('falls back to the place name when there are no coordinates',
        () async {
      final r =
          await resolveMapLink('https://www.google.com/maps/place/Penang+Hill');
      expect(r?.query, 'Penang Hill');
      expect(r?.isCoordinates, isFalse);
    });

    test('prefers coordinates over the name when both are present', () async {
      final r = await resolveMapLink(
        'https://www.google.com/maps/place/Penang+Hill/@5.4239,100.2685,15z',
      );
      expect(r?.query, '5.4239,100.2685');
      expect(r?.isCoordinates, isTrue);
    });

    test('returns null for a link with nothing to extract', () async {
      expect(await resolveMapLink('https://www.google.com/maps'), isNull);
    });
  });
}
