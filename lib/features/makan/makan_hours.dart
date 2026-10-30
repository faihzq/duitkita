/// Opening-hours arithmetic for makan spots.
///
/// Everything is done on a single week-long timeline of minutes (Monday 00:00
/// = 0, Sunday 23:59 = 10079). A slot becomes an interval on that line, which
/// may run past the end of Sunday and wrap to Monday — so "open past midnight"
/// and "Sunday night into Monday" need no special cases beyond the wrap.
///
/// Pure functions only; the UI passes in `DateTime.now()`.
library;

import 'package:duitkita/models/makan_spot.dart';

const _day = 1440;
const _week = _day * 7;

/// Minutes since Monday 00:00 for [t].
int weekMinute(DateTime t) => (t.weekday - 1) * _day + t.hour * 60 + t.minute;

typedef _Span = ({int start, int end});

List<_Span> _spans(WeeklyHours hours) => [
  for (final e in hours.entries)
    if (e.key >= 1 && e.key <= 7)
      for (final s in e.value)
        (
          start: (e.key - 1) * _day + s.open,
          end: (e.key - 1) * _day + s.open + s.duration,
        ),
];

/// [m] inside [span], allowing for a span that wraps past Sunday.
bool _contains(_Span span, int m) =>
    (m >= span.start && m < span.end) ||
    (m + _week >= span.start && m + _week < span.end);

int _overlap(_Span a, _Span b) {
  var total = 0;
  for (final shift in const [-_week, 0, _week]) {
    final start = a.start > b.start + shift ? a.start : b.start + shift;
    final end = a.end < b.end + shift ? a.end : b.end + shift;
    if (end > start) total += end - start;
  }
  return total;
}

bool isOpenAt(WeeklyHours hours, DateTime t) {
  final m = weekMinute(t);
  return _spans(hours).any((s) => _contains(s, m));
}

/// Every day of the week is a single 24-hour slot.
bool isAlwaysOpen(WeeklyHours hours) {
  for (var d = 1; d <= 7; d++) {
    final slots = hours[d] ?? const [];
    if (!slots.any((s) => s.isAllDay)) return false;
  }
  return true;
}

/// Where a spot stands at a given moment.
sealed class OpenStatus {
  const OpenStatus();
}

/// No hours entered — the spot is listed but we can't say.
class HoursUnknown extends OpenStatus {
  const HoursUnknown();
}

class OpenAllDay extends OpenStatus {
  const OpenAllDay();
}

class OpenUntil extends OpenStatus {
  final DateTime closesAt;
  const OpenUntil(this.closesAt);
}

class ClosedUntil extends OpenStatus {
  /// Null when the spot has no opening at all in the week.
  final DateTime? opensAt;
  const ClosedUntil(this.opensAt);
}

OpenStatus statusAt(WeeklyHours hours, DateTime t) {
  final spans = _spans(hours);
  if (spans.isEmpty) return const HoursUnknown();
  if (isAlwaysOpen(hours)) return const OpenAllDay();

  final m = weekMinute(t);
  final now = DateTime(t.year, t.month, t.day, t.hour, t.minute);

  // Open: the latest closing among the slots covering now, chained through any
  // slot that starts exactly as the previous one ends (a day split at midnight).
  final covering = spans.where((s) => _contains(s, m)).toList();
  if (covering.isNotEmpty) {
    var until = 0;
    for (final s in covering) {
      final left = (s.end - m) % _week;
      final mins = left == 0 ? _week : left;
      if (mins > until) until = mins;
    }
    var extended = true;
    while (extended && until < _week) {
      extended = false;
      final edge = (m + until) % _week;
      for (final s in spans) {
        if (s.start % _week == edge) {
          until += s.end - s.start;
          extended = true;
          break;
        }
      }
    }
    if (until >= _week) return const OpenAllDay();
    return OpenUntil(now.add(Duration(minutes: until)));
  }

  var soonest = _week;
  for (final s in spans) {
    final wait = (s.start - m) % _week;
    if (wait > 0 && wait < soonest) soonest = wait;
  }
  return ClosedUntil(now.add(Duration(minutes: soonest)));
}

bool isOpenStatus(OpenStatus s) => s is OpenAllDay || s is OpenUntil;

// ── Meal periods ──────────────────────────────────────────────────────────────

enum MealPeriod {
  breakfast('Breakfast', '🍳', 5 * 60, 11 * 60),
  lunch('Lunch', '🍛', 11 * 60, 15 * 60),
  teaTime('Tea time', '☕', 15 * 60, 18 * 60),
  dinner('Dinner', '🍽️', 18 * 60, 22 * 60),
  supper('Supper', '🌙', 22 * 60, 5 * 60);

  final String label;
  final String emoji;

  /// Window in minutes from midnight; [end] before [start] wraps to the next
  /// day (supper runs 22:00 → 05:00).
  final int start;
  final int end;

  const MealPeriod(this.label, this.emoji, this.start, this.end);

  int get length => (end - start + _day) % _day;
}

/// The meal it is time for at [t]. Small hours count as last night's supper.
MealPeriod mealPeriodFor(DateTime t) {
  final m = t.hour * 60 + t.minute;
  for (final p in MealPeriod.values) {
    final inside =
        p.end > p.start ? m >= p.start && m < p.end : m >= p.start || m < p.end;
    if (inside) return p;
  }
  return MealPeriod.supper;
}

/// A spot counts for a meal when it is open for at least this long inside the
/// meal window — a place opening at 10:55 is not a breakfast option.
const minMealOverlap = 30;

/// Open during [period] on the day of [day]. Supper belongs to the evening it
/// starts on, so "supper on Friday" is Friday 22:00 → Saturday 05:00.
bool isOpenDuring(WeeklyHours hours, MealPeriod period, DateTime day) {
  final start = (day.weekday - 1) * _day + period.start;
  final window = (start: start, end: start + period.length);
  final need = period.length < minMealOverlap ? period.length : minMealOverlap;
  return _spans(hours).any((s) => _overlap(s, window) >= need);
}

// ── Formatting ────────────────────────────────────────────────────────────────

/// "6:30 AM", "12:00 PM", "12:00 AM" (midnight).
String formatMinutes(int minutes) {
  final m = minutes % _day;
  final h24 = m ~/ 60;
  final min = m % 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final suffix = h24 < 12 ? 'AM' : 'PM';
  return '$h12:${min.toString().padLeft(2, '0')} $suffix';
}

String formatSlot(OpenSlot s) =>
    s.isAllDay
        ? '24 hours'
        : '${formatMinutes(s.open)} – ${formatMinutes(s.close)}';

String formatSlots(List<OpenSlot> slots) =>
    slots.isEmpty ? 'Closed' : slots.map(formatSlot).join(', ');

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Open · closes 11:00 PM", "Closed · opens 6:30 AM tomorrow" …
String statusLabel(OpenStatus s, DateTime now) {
  String when(DateTime at) {
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(at.year, at.month, at.day);
    final days = that.difference(today).inDays;
    final time = formatMinutes(at.hour * 60 + at.minute);
    if (days == 0) return time;
    if (days == 1) return '$time tomorrow';
    return '${weekdayShort[at.weekday - 1]} $time';
  }

  return switch (s) {
    HoursUnknown() => 'Hours not set',
    OpenAllDay() => 'Open 24 hours',
    OpenUntil(:final closesAt) => 'Open · closes ${when(closesAt)}',
    ClosedUntil(:final opensAt) =>
      opensAt == null ? 'Closed' : 'Closed · opens ${when(opensAt)}',
  };
}

/// Days that share identical slots, for a compact summary. Returns null when
/// the open days differ — the caller then shows the full week.
List<OpenSlot>? uniformSlots(WeeklyHours hours) {
  List<OpenSlot>? shared;
  for (var d = 1; d <= 7; d++) {
    final slots = hours[d] ?? const <OpenSlot>[];
    if (slots.isEmpty) continue;
    if (shared == null) {
      shared = slots;
    } else if (!_sameSlots(shared, slots)) {
      return null;
    }
  }
  return shared;
}

bool _sameSlots(List<OpenSlot> a, List<OpenSlot> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
