import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/itinerary_import.dart';
import 'package:duitkita/models/itinerary_stop.dart';

void main() {
  group('times', () {
    test('reads 12-hour times with and without a space', () {
      final r = parseItinerary('12:30 PM Ibu departs Muar\n8.45am Breakfast');

      expect(r.stops, hasLength(2));
      expect(r.stops[0].time, '12:30 PM');
      expect(r.stops[1].time, '8:45 AM');
    });

    test('reads 24-hour times', () {
      final r = parseItinerary('18:30 Homestay Alor Setar\n06:01 Subuh');

      expect(r.stops[0].time, '6:30 PM');
      expect(r.stops[1].time, '6:01 AM');
    });

    test('handles noon and midnight without flipping them', () {
      final r = parseItinerary('12:00 AM Midnight snack\n12:00 PM Lunch');

      expect(r.stops[0].time, '12:00 AM');
      expect(r.stops[1].time, '12:00 PM');
    });

    test('sets order from the time so stops sort chronologically', () {
      final r = parseItinerary('6:00 PM Dinner\n8:00 AM Breakfast');

      expect(r.stops[0].toStop().order, 18 * 60);
      expect(r.stops[1].toStop().order, 8 * 60);
    });
  });

  group('days', () {
    test('a "Day N" line switches the day for what follows', () {
      final r = parseItinerary('''
Day 1
12:30 PM Ibu departs Muar
Day 2
6:30 AM Drive to Penang
''');

      expect(r.stops[0].day, 1);
      expect(r.stops[1].day, 2);
      expect(r.dayCount, 2);
    });

    test('accepts punctuation after the day header', () {
      final r = parseItinerary('Day 3:\n10:00 AM Ferry to Langkawi');
      expect(r.stops.single.day, 3);
    });

    test('everything lands on startDay when there are no headers', () {
      final r = parseItinerary('10:00 AM Ferry', startDay: 4);
      expect(r.stops.single.day, 4);
    });
  });

  group('extras', () {
    test('splits a note after a dash', () {
      final r = parseItinerary('3:00 PM Arrive Kajang - Pick up Angah');

      expect(r.stops.single.title, 'Arrive Kajang');
      expect(r.stops.single.note, 'Pick up Angah');
    });

    test('splits a place after @', () {
      final r = parseItinerary('10:00 AM Ferry to Langkawi @ Jeti Kuala Perlis');

      expect(r.stops.single.title, 'Ferry to Langkawi');
      expect(r.stops.single.place, 'Jeti Kuala Perlis');
    });

    test('takes both a place and a note', () {
      final r = parseItinerary(
          '4:30 PM TS Duty Free - Padang Mat Sirat @ 6.3520,99.7280');

      expect(r.stops.single.title, 'TS Duty Free');
      expect(r.stops.single.note, 'Padang Mat Sirat');
      expect(r.stops.single.place, '6.3520,99.7280');
    });

    test('strips bullets and numbering', () {
      final r = parseItinerary('- 9:00 AM Penang Hill\n2) 11:00 AM Ais kacang');

      expect(r.stops[0].title, 'Penang Hill');
      expect(r.stops[1].title, 'Ais kacang');
    });

    test('does not treat a hyphenated name as a note', () {
      // No spaces around the dash, so it is part of the title.
      final r = parseItinerary('7:00 PM Homestay Sungai-Petani');
      expect(r.stops.single.title, 'Homestay Sungai-Petani');
      expect(r.stops.single.note, isNull);
    });
  });

  group('type inference', () {
    test('spots food, prayer, stay, travel and activity', () {
      expect(inferType('Breakfast — Fizzy Cafe'), StopType.food);
      expect(inferType('Nasi kandar Penang'), StopType.food);
      expect(inferType('Maghrib at R&R Tapah'), StopType.prayer);
      expect(inferType('Homestay Alfa Langkawi - Check in'), StopType.stay);
      expect(inferType('Ferry to Langkawi'), StopType.travel);
      expect(inferType('Drive to Penang'), StopType.travel);
      expect(inferType('Langkawi Cable Car'), StopType.sight);
    });

    test('understands Malay wording', () {
      expect(inferType('Solat Subuh'), StopType.prayer);
      expect(inferType('Makan tengahari'), StopType.food);
      expect(inferType('Bertolak ke Ipoh'), StopType.travel);
      expect(inferType('Sampai Jeti Kuala Perlis'), StopType.travel);
    });

    test('carries the inferred type onto the stop', () {
      final r = parseItinerary('8:45 AM Breakfast — Fizzy Cafe');
      final stop = r.stops.single.toStop();

      expect(stop.type, StopType.food);
      expect(stop.icon, 'food');
    });
  });

  group('lines it cannot use', () {
    test('reports them instead of dropping them silently', () {
      final r = parseItinerary('Langkawi trip\n10:00 AM Ferry\nremember sunscreen');

      expect(r.stops, hasLength(1));
      expect(r.skipped.map((s) => s.text),
          containsAll(['Langkawi trip', 'remember sunscreen']));
      expect(r.skipped.first.lineNumber, 1);
    });

    test('ignores blank lines', () {
      final r = parseItinerary('\n\n10:00 AM Ferry\n\n');
      expect(r.skipped, isEmpty);
      expect(r.stops, hasLength(1));
    });

    test('does not read a bare number as a time', () {
      final r = parseItinerary('3 hours at the beach');
      expect(r.stops, isEmpty);
      expect(r.skipped, hasLength(1));
    });

    test('rejects an impossible time', () {
      final r = parseItinerary('99:99 Nonsense');
      expect(r.stops, isEmpty);
    });

    test('skips a time with no title after it', () {
      final r = parseItinerary('10:00 AM   ');
      expect(r.stops, isEmpty);
      expect(r.skipped, hasLength(1));
    });
  });

  test('parses a realistic pasted day', () {
    final r = parseItinerary('''
Day 3
6:01 AM Subuh - Prayer time in
6:20 AM Drive to Jeti Kuala Perlis
7:30 AM Breakfast — Aminah Pulut Ayam - Grab & go
10:00 AM Ferry to Langkawi @ Kuala Perlis Ferry Terminal
1:00 PM Langkawi Cable Car
6:30 PM Homestay Alfa Langkawi - Check in
''');

    expect(r.stops, hasLength(6));
    expect(r.skipped, isEmpty);
    expect(r.stops.every((s) => s.day == 3), isTrue);
    expect(r.stops.first.type, StopType.prayer);
    expect(r.stops[3].place, 'Kuala Perlis Ferry Terminal');
    expect(r.stops.last.type, StopType.stay);
  });
}
