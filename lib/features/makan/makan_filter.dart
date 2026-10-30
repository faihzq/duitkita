/// Filtering for the Makan list, kept out of the widget so it can be tested.
library;

import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/features/makan/makan_hours.dart';

/// Which list a spot comes from: `mine` for personal, otherwise a group id.
const makanSourceMine = '__mine__';

class MakanQuery {
  /// A meal to plan for. Null means "open right now", unless [anyTime].
  final MealPeriod? meal;

  /// Ignore opening hours entirely.
  final bool anyTime;
  final String? area;
  final String? source;
  final String text;

  const MakanQuery({
    this.meal,
    this.anyTime = false,
    this.area,
    this.source,
    this.text = '',
  });

  bool get isNow => meal == null && !anyTime;
}

/// The day whose [meal] is meant at [now]: the one still under way, else the
/// next one. Supper at 1 AM is last night's; breakfast at 9 PM is tomorrow's.
DateTime mealDay(MealPeriod meal, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final m = now.hour * 60 + now.minute;
  if (meal.end < meal.start && m < meal.end) {
    return today.subtract(const Duration(days: 1));
  }
  final endsToday = meal.end < meal.start ? meal.end + 1440 : meal.end;
  return m >= endsToday ? today.add(const Duration(days: 1)) : today;
}

class MakanResult {
  /// Matches the search and is open for the chosen time (or every match when
  /// hours are ignored).
  final List<MakanSpot> available;

  /// Matches the search but is closed then, or has no hours to judge by.
  final List<MakanSpot> unavailable;

  /// Spot id → menu items matching the search text.
  final Map<String, List<String>> menuHits;

  const MakanResult(this.available, this.unavailable, this.menuHits);
}

MakanResult filterSpots(List<MakanSpot> spots, MakanQuery q, DateTime now) {
  final text = q.text.trim().toLowerCase();
  final area = q.area?.trim().toLowerCase();
  final available = <MakanSpot>[];
  final unavailable = <MakanSpot>[];
  final hits = <String, List<String>>{};

  final day = q.meal == null ? null : mealDay(q.meal!, now);

  for (final s in spots) {
    if (area != null && s.area.trim().toLowerCase() != area) continue;
    if (q.source != null) {
      final from = s.groupId ?? makanSourceMine;
      if (from != q.source) continue;
    }

    if (text.isNotEmpty) {
      final menu = s.menu.where((m) => m.toLowerCase().contains(text)).toList();
      final matches =
          menu.isNotEmpty ||
          s.name.toLowerCase().contains(text) ||
          s.area.toLowerCase().contains(text) ||
          s.categories.any((c) => c.toLowerCase().contains(text));
      if (!matches) continue;
      if (menu.isNotEmpty) hits[s.id] = menu;
    }

    final ok =
        q.anyTime ||
        (day != null
            ? isOpenDuring(s.hours, q.meal!, day)
            : isOpenAt(s.hours, now));
    (ok ? available : unavailable).add(s);
  }

  int byName(MakanSpot a, MakanSpot b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  available.sort(byName);
  unavailable.sort(byName);
  return MakanResult(available, unavailable, hits);
}

/// Distinct areas, case-insensitively, keeping the first spelling seen.
List<String> makanAreas(List<MakanSpot> spots) {
  final seen = <String, String>{};
  for (final s in spots) {
    final a = s.area.trim();
    if (a.isEmpty) continue;
    seen.putIfAbsent(a.toLowerCase(), () => a);
  }
  return seen.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
