/// Wire values are `travel | food | sight | stay | prayer`.
/// UI labels are Travel / Food / Activity / Stay / Break.
enum StopType { travel, food, sight, stay, prayer }

StopType stopTypeFrom(String? s) => StopType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => StopType.travel,
    );

String stopTypeLabel(StopType t) => switch (t) {
      StopType.travel => 'Travel',
      StopType.food => 'Food',
      StopType.sight => 'Activity',
      StopType.stay => 'Stay',
      StopType.prayer => 'Break',
    };

/// Default glyph key for a type — used when a stop is created without one.
String defaultGlyphFor(StopType t) => switch (t) {
      StopType.travel => 'car',
      StopType.food => 'food',
      StopType.sight => 'camera',
      StopType.stay => 'home',
      StopType.prayer => 'mosque',
    };

class ItineraryStop {
  final String id;

  /// 1-based day within the trip.
  final int day;

  /// Sort key within the day. Written as minutes-from-midnight so stops stay
  /// in chronological order without parsing [time] on every read.
  final int order;

  /// Display time, e.g. "10:00 AM".
  final String time;
  final String title;
  final String? note;
  final StopType type;

  /// Glyph key — see `TripGlyphs.icon` in `features/trips/trip_style.dart`.
  final String icon;

  /// Free-text place used to build Google Maps links.
  final String? placeQuery;
  final String? about;

  /// Approximate drive from the previous stop.
  final int? legMinutes;
  final double? legKm;

  ItineraryStop({
    required this.id,
    required this.day,
    this.order = 0,
    required this.time,
    required this.title,
    this.note,
    this.type = StopType.travel,
    this.icon = 'pin',
    this.placeQuery,
    this.about,
    this.legMinutes,
    this.legKm,
  });

  /// Text handed to Google Maps — the explicit place if set, otherwise the
  /// title (plus the note, which is usually the area/branch).
  String get mapQuery {
    final q = placeQuery?.trim();
    if (q != null && q.isNotEmpty) return q;
    final n = note?.trim();
    return (n != null && n.isNotEmpty) ? '$title $n' : title;
  }

  /// Human location line on the stop detail screen.
  String get placeLabel {
    final q = placeQuery?.trim();
    if (q != null && q.isNotEmpty) return q;
    final n = note?.trim();
    return (n != null && n.isNotEmpty) ? n : title;
  }

  bool get hasLeg => (legMinutes ?? 0) > 0 || (legKm ?? 0) > 0;

  /// "~1 h 40 · 155 km"
  String get legLabel {
    final parts = <String>[];
    if ((legMinutes ?? 0) > 0) parts.add(formatDuration(legMinutes!));
    if ((legKm ?? 0) > 0) parts.add('${legKm!.round()} km');
    return parts.isEmpty ? '' : '~${parts.join(' · ')}';
  }

  factory ItineraryStop.fromMap(Map<String, dynamic> data, String id) {
    return ItineraryStop(
      id: id,
      day: (data['day'] as num?)?.toInt() ?? 1,
      order: (data['order'] as num?)?.toInt() ?? 0,
      time: data['time'] ?? '',
      title: data['title'] ?? '',
      note: data['note'],
      type: stopTypeFrom(data['type']),
      icon: data['icon'] ?? 'pin',
      placeQuery: data['placeQuery'],
      about: data['about'],
      legMinutes: (data['legMinutes'] as num?)?.toInt(),
      legKm: (data['legKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'day': day,
        'order': order,
        'time': time,
        'title': title,
        'note': note,
        'type': type.name,
        'icon': icon,
        'placeQuery': placeQuery,
        'about': about,
        'legMinutes': legMinutes,
        'legKm': legKm,
      };

  ItineraryStop copyWith({
    int? day,
    int? order,
    String? time,
    String? title,
    String? note,
    StopType? type,
    String? icon,
    String? placeQuery,
    String? about,
    int? legMinutes,
    double? legKm,
  }) {
    return ItineraryStop(
      id: id,
      day: day ?? this.day,
      order: order ?? this.order,
      time: time ?? this.time,
      title: title ?? this.title,
      note: note ?? this.note,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      placeQuery: placeQuery ?? this.placeQuery,
      about: about ?? this.about,
      legMinutes: legMinutes ?? this.legMinutes,
      legKm: legKm ?? this.legKm,
    );
  }
}

/// "2 h 30" / "45 min"
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m';
}

/// Minutes from midnight for a "10:00 AM" / "22:15" string. Returns 0 when the
/// string can't be parsed, which sorts the stop to the top of its day.
int minutesFromTimeLabel(String time) {
  final m = RegExp(r'^\s*(\d{1,2})[:.](\d{2})\s*([AaPp][Mm])?')
      .firstMatch(time.trim());
  if (m == null) return 0;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  final suffix = m.group(3)?.toUpperCase();
  if (suffix == 'PM' && hour != 12) hour += 12;
  if (suffix == 'AM' && hour == 12) hour = 0;
  return hour * 60 + minute;
}

/// Totals for a day's legs: drive minutes + kilometres.
({int minutes, double km}) dayTotals(List<ItineraryStop> stops) {
  var minutes = 0;
  var km = 0.0;
  for (final s in stops) {
    minutes += s.legMinutes ?? 0;
    km += s.legKm ?? 0;
  }
  return (minutes: minutes, km: km);
}

/// Google Maps deep links — open with `url_launcher`, mode externalApplication.
class TripMaps {
  static Uri search(String query) => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');

  static Uri directions(String destination) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&travelmode=driving&destination=${Uri.encodeComponent(destination)}');

  /// Chain a day's mappable stops into one driving route. Break/prayer stops are
  /// excluded — they're rest points, not places you navigate to.
  /// Returns null when nothing on the day is mappable.
  static Uri? dayRoute(List<ItineraryStop> stops) {
    final pts = stops
        .where((s) => s.type != StopType.prayer && s.mapQuery.trim().isNotEmpty)
        .map((s) => s.mapQuery)
        .toList();
    if (pts.isEmpty) return null;
    if (pts.length < 2) return directions(pts.first);

    final origin = pts.first;
    final destination = pts.last;
    final waypoints = pts.sublist(1, pts.length - 1);
    var url = 'https://www.google.com/maps/dir/?api=1&travelmode=driving'
        '&origin=${Uri.encodeComponent(origin)}'
        '&destination=${Uri.encodeComponent(destination)}';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=${waypoints.map(Uri.encodeComponent).join('%7C')}';
    }
    return Uri.parse(url);
  }
}
