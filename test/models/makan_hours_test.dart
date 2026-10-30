import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/makan/makan_hours.dart';
import 'package:duitkita/models/makan_spot.dart';

/// 5 Jan 2026 is a Monday; `at(1, 8, 30)` is Monday 8:30 AM.
DateTime at(int weekday, int hour, [int minute = 0]) =>
    DateTime(2026, 1, 4 + weekday, hour, minute);

int hm(int h, [int m = 0]) => h * 60 + m;

WeeklyHours everyDay(List<OpenSlot> slots) => {
  for (var d = 1; d <= 7; d++) d: slots,
};

void main() {
  test('helper lands on the right weekdays', () {
    expect(at(1, 0).weekday, DateTime.monday);
    expect(at(7, 0).weekday, DateTime.sunday);
  });

  group('OpenSlot', () {
    test('duration handles same-day, overnight and all-day', () {
      expect(OpenSlot(hm(7), hm(11)).duration, 240);
      expect(OpenSlot(hm(18), hm(2)).duration, 480);
      expect(OpenSlot(hm(18), 0).duration, 360);
      expect(OpenSlot.allDay.duration, 1440);
    });
  });

  group('isOpenAt', () {
    final breakfast = everyDay([OpenSlot(hm(6, 30), hm(11))]);

    test('inside, at the edges, and outside a same-day slot', () {
      expect(isOpenAt(breakfast, at(3, 6, 29)), isFalse);
      expect(isOpenAt(breakfast, at(3, 6, 30)), isTrue);
      expect(isOpenAt(breakfast, at(3, 10, 59)), isTrue);
      expect(isOpenAt(breakfast, at(3, 11)), isFalse);
    });

    test('a split day is closed between sessions', () {
      final split = everyDay([
        OpenSlot(hm(7), hm(14)),
        OpenSlot(hm(17), hm(23)),
      ]);
      expect(isOpenAt(split, at(2, 12)), isTrue);
      expect(isOpenAt(split, at(2, 15)), isFalse);
      expect(isOpenAt(split, at(2, 20)), isTrue);
    });

    test('an overnight slot carries into the next morning', () {
      final supper = {
        5: [OpenSlot(hm(18), hm(3))],
      }; // Friday night only
      expect(isOpenAt(supper, at(5, 23)), isTrue);
      expect(isOpenAt(supper, at(6, 2, 30)), isTrue); // Saturday 2:30 AM
      expect(isOpenAt(supper, at(6, 3)), isFalse);
      expect(isOpenAt(supper, at(4, 2)), isFalse); // Thursday morning
    });

    test('Sunday night wraps into Monday morning', () {
      final sunday = {
        7: [OpenSlot(hm(20), hm(2))],
      };
      expect(isOpenAt(sunday, at(1, 1)), isTrue);
      expect(isOpenAt(sunday, at(1, 2)), isFalse);
    });

    test('closed days', () {
      final closedMonday = {
        for (var d = 2; d <= 7; d++) d: [OpenSlot(hm(7), hm(22))],
      };
      expect(isOpenAt(closedMonday, at(1, 12)), isFalse);
      expect(isOpenAt(closedMonday, at(2, 12)), isTrue);
    });

    test('no hours is never open', () {
      expect(isOpenAt(const {}, at(1, 12)), isFalse);
    });
  });

  group('statusAt', () {
    test('unknown without hours', () {
      expect(statusAt(const {}, at(1, 9)), isA<HoursUnknown>());
    });

    test('24 hours every day', () {
      expect(
        statusAt(everyDay(const [OpenSlot.allDay]), at(3, 3)),
        isA<OpenAllDay>(),
      );
    });

    test('open until the slot closes', () {
      final s = statusAt(everyDay([OpenSlot(hm(7), hm(22))]), at(2, 9));
      expect(s, isA<OpenUntil>());
      expect((s as OpenUntil).closesAt, at(2, 22));
    });

    test('overnight closing time is on the next day', () {
      final s = statusAt(everyDay([OpenSlot(hm(18), hm(2))]), at(2, 23));
      expect((s as OpenUntil).closesAt, at(3, 2));
    });

    test('a slot ending at midnight chains into one starting at midnight', () {
      final hours = {
        2: [OpenSlot(hm(18), 0)],
        3: [OpenSlot(0, hm(3))],
      };
      final s = statusAt(hours, at(2, 20));
      expect((s as OpenUntil).closesAt, at(3, 3));
    });

    test('closed reports the next opening, skipping closed days', () {
      final hours = {
        for (var d = 2; d <= 7; d++) d: [OpenSlot(hm(7), hm(22))],
      };
      // Sunday 11 PM → closed Monday → opens Tuesday 7 AM.
      final s = statusAt(hours, at(7, 23));
      expect(s, isA<ClosedUntil>());
      expect((s as ClosedUntil).opensAt, DateTime(2026, 1, 13, 7));
    });

    test('closed before opening today', () {
      final s = statusAt(everyDay([OpenSlot(hm(17), hm(23))]), at(4, 9));
      expect((s as ClosedUntil).opensAt, at(4, 17));
    });
  });

  group('meal periods', () {
    test('mealPeriodFor', () {
      expect(mealPeriodFor(at(1, 7)), MealPeriod.breakfast);
      expect(mealPeriodFor(at(1, 12, 30)), MealPeriod.lunch);
      expect(mealPeriodFor(at(1, 16)), MealPeriod.teaTime);
      expect(mealPeriodFor(at(1, 19)), MealPeriod.dinner);
      expect(mealPeriodFor(at(1, 23)), MealPeriod.supper);
      expect(mealPeriodFor(at(1, 2)), MealPeriod.supper);
      expect(mealPeriodFor(at(1, 5)), MealPeriod.breakfast);
    });

    test('isOpenDuring needs a real overlap', () {
      final lateOpener = everyDay([OpenSlot(hm(10, 50), hm(15))]);
      expect(isOpenDuring(lateOpener, MealPeriod.breakfast, at(1, 0)), isFalse);
      expect(isOpenDuring(lateOpener, MealPeriod.lunch, at(1, 0)), isTrue);

      final early = everyDay([OpenSlot(hm(10), hm(15))]);
      expect(isOpenDuring(early, MealPeriod.breakfast, at(1, 0)), isTrue);
    });

    test('supper counts a stall that opens late on that evening', () {
      final mamak = {
        5: [OpenSlot(hm(21), hm(4))],
      };
      expect(isOpenDuring(mamak, MealPeriod.supper, at(5, 0)), isTrue);
      expect(isOpenDuring(mamak, MealPeriod.supper, at(6, 0)), isFalse);
    });

    test('supper on Sunday reaches Monday morning hours', () {
      final mondayEarly = {
        1: [OpenSlot(0, hm(4))],
      };
      expect(isOpenDuring(mondayEarly, MealPeriod.supper, at(7, 0)), isTrue);
    });

    test('closed day is not open for any meal', () {
      final hours = {
        2: [OpenSlot(hm(7), hm(22))],
      };
      expect(isOpenDuring(hours, MealPeriod.lunch, at(1, 0)), isFalse);
      expect(isOpenDuring(hours, MealPeriod.lunch, at(2, 0)), isTrue);
    });
  });

  group('formatting', () {
    test('formatMinutes', () {
      expect(formatMinutes(0), '12:00 AM');
      expect(formatMinutes(hm(6, 30)), '6:30 AM');
      expect(formatMinutes(hm(12)), '12:00 PM');
      expect(formatMinutes(hm(23, 5)), '11:05 PM');
    });

    test('formatSlot and formatSlots', () {
      expect(formatSlot(OpenSlot.allDay), '24 hours');
      expect(formatSlot(OpenSlot(hm(7), hm(14))), '7:00 AM – 2:00 PM');
      expect(formatSlots(const []), 'Closed');
    });

    test('statusLabel relative days', () {
      final now = at(2, 23);
      expect(
        statusLabel(OpenUntil(at(2, 23, 30)), now),
        'Open · closes 11:30 PM',
      );
      expect(
        statusLabel(ClosedUntil(at(3, 7)), now),
        'Closed · opens 7:00 AM tomorrow',
      );
      expect(
        statusLabel(ClosedUntil(at(5, 7)), now),
        'Closed · opens Fri 7:00 AM',
      );
    });

    test('uniformSlots', () {
      final same = {
        1: [OpenSlot(hm(7), hm(14))],
        3: [OpenSlot(hm(7), hm(14))],
      };
      expect(uniformSlots(same), [OpenSlot(hm(7), hm(14))]);
      expect(uniformSlots(const {}), isNull);
      final differ = {
        1: [OpenSlot(hm(7), hm(14))],
        2: [OpenSlot(hm(8), hm(14))],
      };
      expect(uniformSlots(differ), isNull);
    });
  });
}
