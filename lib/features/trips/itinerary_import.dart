/// Parses a pasted itinerary into stops.
///
/// The input is whatever people already keep in Notes or WhatsApp, so the
/// parser is deliberately forgiving: it looks for a leading time and takes the
/// rest of the line as the title, with optional extras.
///
/// Recognised shapes:
///
///     Day 1                         → everything after this belongs to day 1
///     12:30 PM Ibu departs Muar
///     - 3:00 PM Arrive Kajang - Pick up Angah      (note after " - ")
///     10:00 AM Ferry to Langkawi @ Jeti Kuala Perlis   (place after " @ ")
///     8.45am Breakfast              (dots and no space both fine)
library;

import 'package:duitkita/models/itinerary_stop.dart';

/// One line of the paste, resolved.
class ParsedStop {
  final int day;
  final String time;
  final String title;
  final String? note;
  final String? place;
  final StopType type;

  /// The original line, shown in the preview so a bad parse is recognisable.
  final String source;

  const ParsedStop({
    required this.day,
    required this.time,
    required this.title,
    required this.source,
    this.note,
    this.place,
    this.type = StopType.travel,
  });

  ItineraryStop toStop() => ItineraryStop(
    id: '',
    day: day,
    order: minutesFromTimeLabel(time),
    time: time,
    title: title,
    note: note,
    placeQuery: place,
    type: type,
    icon: defaultGlyphFor(type),
  );
}

/// A line that carried no recognisable time.
class SkippedLine {
  final int lineNumber;
  final String text;
  const SkippedLine(this.lineNumber, this.text);
}

class ImportResult {
  final List<ParsedStop> stops;
  final List<SkippedLine> skipped;
  const ImportResult({required this.stops, required this.skipped});

  bool get isEmpty => stops.isEmpty;
  int get dayCount =>
      stops.isEmpty
          ? 0
          : stops.map((s) => s.day).reduce((a, b) => a > b ? a : b);
}

final _dayHeader = RegExp(
  r'^\s*day\s*(\d+)\s*[:.\-–—]?\s*$',
  caseSensitive: false,
);

/// Leading time: `9:00 AM`, `09:00`, `8.45am`, `8am`. Bullets and dashes ahead
/// of it are stripped first.
/// `\s*` rather than `\s+` before the title: with `\s+` a line that is only a
/// time ("10:00 AM") backtracks, leaving the meridiem itself as the title.
final _leadingTime = RegExp(
  r'^\s*(\d{1,2})(?:[:.](\d{2}))?\s*([AaPp][Mm])?\s*(.*)$',
);

/// Bullets, dashes and numbering people paste from lists.
final _bullet = RegExp(r'^\s*(?:[-*•·]|\d+[.)])\s+');

ImportResult parseItinerary(String text, {int startDay = 1}) {
  final stops = <ParsedStop>[];
  final skipped = <SkippedLine>[];
  var day = startDay;

  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;

    final header = _dayHeader.firstMatch(trimmed);
    if (header != null) {
      day = int.parse(header.group(1)!);
      continue;
    }

    final body = trimmed.replaceFirst(_bullet, '');
    final match = _leadingTime.firstMatch(body);
    if (match == null) {
      skipped.add(SkippedLine(i + 1, trimmed));
      continue;
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '0');
    final suffix = match.group(3)?.toUpperCase();
    var rest = match.group(4)!.trim();

    // A bare hour with no am/pm and no minutes is far more likely to be part of
    // the text ("2 hours at the beach") than a time.
    if (suffix == null && match.group(2) == null) {
      skipped.add(SkippedLine(i + 1, trimmed));
      continue;
    }
    if (hour > 23 || minute > 59) {
      skipped.add(SkippedLine(i + 1, trimmed));
      continue;
    }

    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    // No am/pm on a plausible daytime hour: assume the 24-hour clock as typed.

    String? place;
    final at = rest.indexOf(' @ ');
    if (at != -1) {
      place = rest.substring(at + 3).trim();
      rest = rest.substring(0, at).trim();
    }

    String? note;
    final sep = RegExp(r'\s+[-–—]\s+').firstMatch(rest);
    if (sep != null) {
      note = rest.substring(sep.end).trim();
      rest = rest.substring(0, sep.start).trim();
    }

    if (rest.isEmpty) {
      skipped.add(SkippedLine(i + 1, trimmed));
      continue;
    }

    stops.add(
      ParsedStop(
        day: day,
        time: _formatTime(hour, minute),
        title: rest,
        note: (note?.isEmpty ?? true) ? null : note,
        place: (place?.isEmpty ?? true) ? null : place,
        type: inferType('$rest ${note ?? ''}'),
        source: trimmed,
      ),
    );
  }

  return ImportResult(stops: stops, skipped: skipped);
}

String _formatTime(int hour24, int minute) {
  final period = hour24 >= 12 ? 'PM' : 'AM';
  var h = hour24 % 12;
  if (h == 0) h = 12;
  return '$h:${minute.toString().padLeft(2, '0')} $period';
}

/// Guesses the stop type from the wording, so an imported itinerary doesn't
/// arrive as 40 identical "Travel" stops. English and Malay, since that is what
/// these itineraries are actually written in.
StopType inferType(String text) {
  final t = text.toLowerCase();

  // Whole words only. A substring match makes "Breakfast" contain "break" and
  // land every meal under the prayer/rest type.
  bool has(List<String> words) =>
      words.any((w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(t));

  if (has([
    'solat',
    'prayer',
    'subuh',
    'zohor',
    'asar',
    'maghrib',
    'isyak',
    'masjid',
    'mosque',
    'surau',
    'rehat',
    'rest stop',
    'break',
  ])) {
    return StopType.prayer;
  }
  if (has([
    'breakfast',
    'lunch',
    'dinner',
    'supper',
    'makan',
    'sarapan',
    'brunch',
    'cafe',
    'kopi',
    'coffee',
    'nasi',
    'mee',
    'restoran',
    'restaurant',
    'food',
    'eat',
    'snack',
    'ais',
    'dessert',
  ])) {
    return StopType.food;
  }
  if (has([
    'check in',
    'check-in',
    'checkin',
    'homestay',
    'hotel',
    'resort',
    'airbnb',
    'chalet',
    'penginapan',
    'stay',
    'lodge',
  ])) {
    return StopType.stay;
  }
  if (has([
    'drive',
    'depart',
    'bertolak',
    'gerak',
    'ferry',
    'feri',
    'flight',
    'terbang',
    'jeti',
    'jetty',
    'airport',
    'lapangan',
    'arrive',
    'sampai',
    'tiba',
    'pick up',
    'transit',
    'balik',
    'head home',
    'perjalanan',
    'menuju',
  ])) {
    return StopType.travel;
  }
  return StopType.sight;
}
