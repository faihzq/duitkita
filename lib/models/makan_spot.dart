import 'package:cloud_firestore/cloud_firestore.dart';

/// One opening window, in minutes from midnight.
///
/// A slot whose [close] is at or before its [open] runs past midnight into the
/// next day — `18:00 → 02:00` is a supper stall, `18:00 → 00:00` closes at
/// midnight. `open == close` is the whole day (24 hours).
class OpenSlot {
  final int open;
  final int close;

  const OpenSlot(this.open, this.close)
    : assert(open >= 0 && open < 1440),
      assert(close >= 0 && close < 1440);

  static const allDay = OpenSlot(0, 0);

  bool get isAllDay => open == close;
  bool get isOvernight => close <= open;

  /// Length in minutes, 1..1440.
  int get duration => isAllDay ? 1440 : (close - open + 1440) % 1440;

  factory OpenSlot.fromMap(Map<String, dynamic> data) => OpenSlot(
    ((data['open'] as num?)?.toInt() ?? 0) % 1440,
    ((data['close'] as num?)?.toInt() ?? 0) % 1440,
  );

  Map<String, dynamic> toMap() => {'open': open, 'close': close};

  @override
  bool operator ==(Object other) =>
      other is OpenSlot && other.open == open && other.close == close;

  @override
  int get hashCode => Object.hash(open, close);
}

/// Weekly opening hours keyed by `DateTime.weekday` (1 = Monday … 7 = Sunday).
/// A day that is missing or empty is closed.
typedef WeeklyHours = Map<int, List<OpenSlot>>;

/// A place to eat — a warung, mamak, kopitiam, restaurant.
///
/// Lives in the top-level `makan_spots` collection, one list shared by every
/// signed-in user (the app is used by one family).
class MakanSpot {
  final String id;
  final String name;
  final String area;
  final List<String> categories;
  final List<String> menu;
  final WeeklyHours hours;

  /// What the user pasted: a Google Maps share link or a plain place name.
  final String? mapLink;

  /// [mapLink] reduced to `lat,lng` or a place name, usable as a directions
  /// destination. Null when the link could not be resolved.
  final String? mapQuery;

  /// Where the spot is, when known — from GPS ("I'm here now") or read off a
  /// coordinate [mapQuery]. Used for distance only; directions use [mapQuery].
  final double? lat;
  final double? lng;
  final String? notes;
  final String addedBy;
  final String addedByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MakanSpot({
    required this.id,
    required this.name,
    required this.area,
    this.categories = const [],
    this.menu = const [],
    this.hours = const {},
    this.mapLink,
    this.mapQuery,
    this.lat,
    this.lng,
    this.notes,
    required this.addedBy,
    this.addedByName = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasHours => hours.values.any((s) => s.isNotEmpty);

  /// [lat]/[lng] if stored, else coordinates parsed from [mapQuery] — spots
  /// saved before lat/lng existed still get a distance.
  ({double lat, double lng})? get coords {
    if (lat != null && lng != null) return (lat: lat!, lng: lng!);
    return parseLatLng(mapQuery);
  }

  factory MakanSpot.fromMap(Map<String, dynamic> data, String id) {
    final hours = <int, List<OpenSlot>>{};
    final rawHours = data['hours'];
    if (rawHours is Map) {
      rawHours.forEach((key, value) {
        final day = int.tryParse('$key');
        if (day == null || day < 1 || day > 7 || value is! List) return;
        hours[day] =
            value
                .whereType<Map>()
                .map((s) => OpenSlot.fromMap(Map<String, dynamic>.from(s)))
                .toList();
      });
    }

    return MakanSpot(
      id: id,
      name: data['name'] ?? '',
      area: data['area'] ?? '',
      categories: List<String>.from(data['categories'] ?? const []),
      menu: List<String>.from(data['menu'] ?? const []),
      hours: hours,
      mapLink: data['mapLink'],
      mapQuery: data['mapQuery'],
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      notes: data['notes'],
      addedBy: data['addedBy'] ?? '',
      addedByName: data['addedByName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'area': area,
    'categories': categories,
    'menu': menu,
    // Firestore map keys must be strings.
    'hours': {
      for (final e in hours.entries)
        if (e.value.isNotEmpty)
          '${e.key}': e.value.map((s) => s.toMap()).toList(),
    },
    'mapLink': mapLink,
    'mapQuery': mapQuery,
    'lat': lat,
    'lng': lng,
    'notes': notes,
    'addedBy': addedBy,
    'addedByName': addedByName,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  MakanSpot copyWith({
    String? name,
    String? area,
    List<String>? categories,
    List<String>? menu,
    WeeklyHours? hours,
    String? mapLink,
    String? mapQuery,
    double? lat,
    double? lng,
    String? notes,
  }) {
    return MakanSpot(
      id: id,
      name: name ?? this.name,
      area: area ?? this.area,
      categories: categories ?? this.categories,
      menu: menu ?? this.menu,
      hours: hours ?? this.hours,
      mapLink: mapLink ?? this.mapLink,
      mapQuery: mapQuery ?? this.mapQuery,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      notes: notes ?? this.notes,
      addedBy: addedBy,
      addedByName: addedByName,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// `"3.1390,101.6869"` → coordinates; null for a place name or junk.
({double lat, double lng})? parseLatLng(String? value) {
  final m = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
  ).firstMatch(value ?? '');
  if (m == null) return null;
  final lat = double.parse(m.group(1)!);
  final lng = double.parse(m.group(2)!);
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat: lat, lng: lng);
}
