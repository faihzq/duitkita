import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/makan/makan_filter.dart';
import 'package:duitkita/features/makan/makan_hours.dart';
import 'package:duitkita/models/makan_spot.dart';

/// 5 Jan 2026 is a Monday.
DateTime at(int weekday, int hour, [int minute = 0]) =>
    DateTime(2026, 1, 4 + weekday, hour, minute);

MakanSpot spot(
  String id,
  String name, {
  String area = 'Bangi',
  List<String> menu = const [],
  List<String> categories = const [],
  List<OpenSlot> slots = const [],
}) => MakanSpot(
  id: id,
  name: name,
  area: area,
  menu: menu,
  categories: categories,
  hours: {
    if (slots.isNotEmpty)
      for (var d = 1; d <= 7; d++) d: slots,
  },
  addedBy: 'uid-1',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  final spots = [
    spot(
      'a',
      'Warung Pagi',
      menu: const ['Nasi Lemak', 'Roti Canai'],
      slots: const [OpenSlot(6 * 60, 11 * 60)],
    ),
    spot(
      'b',
      'Mamak 24',
      area: 'kajang',
      categories: const ['Mamak'],
      menu: const ['Roti Telur'],
      slots: const [OpenSlot.allDay],
    ),
    spot(
      'c',
      'Gerai Malam',
      area: 'Kajang',
      slots: const [OpenSlot(18 * 60, 2 * 60)],
    ),
    spot('d', 'No Hours Cafe'),
  ];

  test('now: open spots first, the rest unavailable', () {
    final r = filterSpots(spots, const MakanQuery(), at(1, 8));
    expect(r.available.map((s) => s.id), ['b', 'a']);
    expect(r.unavailable.map((s) => s.id), ['c', 'd']);
  });

  test('meal filter plans ahead', () {
    final r = filterSpots(
      spots,
      const MakanQuery(meal: MealPeriod.dinner),
      at(1, 8),
    );
    expect(r.available.map((s) => s.id), ['c', 'b']);
  });

  test('any time ignores hours', () {
    final r = filterSpots(spots, const MakanQuery(anyTime: true), at(1, 8));
    expect(r.available, hasLength(4));
    expect(r.unavailable, isEmpty);
  });

  test('area matches case-insensitively', () {
    final r = filterSpots(
      spots,
      const MakanQuery(anyTime: true, area: 'KAJANG'),
      at(1, 8),
    );
    expect(r.available.map((s) => s.id), ['c', 'b']);
  });

  test('text search hits menu, name and category, and reports menu hits', () {
    final r = filterSpots(
      spots,
      const MakanQuery(anyTime: true, text: 'roti'),
      at(1, 8),
    );
    expect(r.available.map((s) => s.id), ['b', 'a']);
    expect(r.menuHits['a'], ['Roti Canai']);
    expect(r.menuHits['b'], ['Roti Telur']);

    final byCategory = filterSpots(
      spots,
      const MakanQuery(anyTime: true, text: 'mamak'),
      at(1, 8),
    );
    expect(byCategory.available.map((s) => s.id), ['b']);
  });

  group('mealDay', () {
    test('a meal still ahead today is today', () {
      expect(mealDay(MealPeriod.lunch, at(1, 8)), DateTime(2026, 1, 5));
    });

    test('a meal already past is tomorrow', () {
      expect(mealDay(MealPeriod.breakfast, at(1, 21)), DateTime(2026, 1, 6));
    });

    test('supper in the small hours is last night', () {
      expect(mealDay(MealPeriod.supper, at(2, 1)), DateTime(2026, 1, 5));
      expect(mealDay(MealPeriod.supper, at(2, 23)), DateTime(2026, 1, 6));
    });
  });

  test('makanMenuItems: distinct dishes, most common first', () {
    final items = makanMenuItems([
      spot('x', 'X', menu: const ['Roti Canai', 'Teh Tarik']),
      spot('y', 'Y', menu: const ['roti canai', ' ', 'Nasi Lemak']),
      spot('z', 'Z', menu: const ['Nasi Lemak', 'ROTI CANAI']),
    ]);
    expect(items, ['Roti Canai', 'Nasi Lemak', 'Teh Tarik']);
  });

  test('makanAreas dedupes case-insensitively and sorts', () {
    expect(makanAreas(spots), ['Bangi', 'kajang']);
  });

  group('MakanSpot map round trip', () {
    test('hours survive toMap/fromMap with string keys', () {
      final original = spots[2];
      final map = original.toMap();
      expect((map['hours'] as Map).keys, everyElement(isA<String>()));
      final back = MakanSpot.fromMap(map, 'c');
      expect(back.hours[3], const [OpenSlot(18 * 60, 2 * 60)]);
      expect(back.createdAt, isA<DateTime>());
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('garbage hours are ignored', () {
      final back = MakanSpot.fromMap({
        'name': 'X',
        'area': 'Y',
        'hours': {'9': [], 'abc': [], '2': 'nope'},
      }, 'x');
      expect(back.hours, isEmpty);
    });
  });
}
