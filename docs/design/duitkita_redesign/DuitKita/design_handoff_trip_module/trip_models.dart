import 'package:cloud_firestore/cloud_firestore.dart';

/// Starter models for the Trips feature.
/// Align fromMap/toMap with the conventions in lib/models/group_model.dart.

enum TripStatus { tentative, confirmed, settled }

TripStatus _statusFrom(String? s) => TripStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TripStatus.tentative,
    );

class TripModel {
  final String id;
  final String name;
  final List<String> destinations;
  final DateTime startDate;
  final DateTime endDate;
  final TripStatus status;
  final String? emoji;
  final String? bandGradient; // preset key for the card colour band
  final String createdBy;
  final List<String> travellerIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripModel({
    required this.id,
    required this.name,
    this.destinations = const [],
    required this.startDate,
    required this.endDate,
    this.status = TripStatus.tentative,
    this.emoji,
    this.bandGradient,
    required this.createdBy,
    this.travellerIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripModel.fromMap(Map<String, dynamic> data, String id) {
    return TripModel(
      id: id,
      name: data['name'] ?? '',
      destinations: List<String>.from(data['destinations'] ?? const []),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _statusFrom(data['status']),
      emoji: data['emoji'],
      bandGradient: data['bandGradient'],
      createdBy: data['createdBy'] ?? '',
      travellerIds: List<String>.from(data['travellerIds'] ?? const []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'destinations': destinations,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': status.name,
        'emoji': emoji,
        'bandGradient': bandGradient,
        'createdBy': createdBy,
        'travellerIds': travellerIds,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

/// travel | food | sight | stay | prayer  (UI labels: Travel/Food/Activity/Stay/Break)
enum StopType { travel, food, sight, stay, prayer }

StopType _stopTypeFrom(String? s) => StopType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => StopType.travel,
    );

class ItineraryStop {
  final String id;
  final int day; // 1..N
  final int order; // sort within the day
  final String time; // "10:00 AM"
  final String title;
  final String? note;
  final StopType type;
  final String icon; // glyph key
  final String? placeQuery; // Google Maps query
  final String? about;
  final int? legMinutes; // drive from previous stop
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

  factory ItineraryStop.fromMap(Map<String, dynamic> data, String id) {
    return ItineraryStop(
      id: id,
      day: (data['day'] ?? 1) as int,
      order: (data['order'] ?? 0) as int,
      time: data['time'] ?? '',
      title: data['title'] ?? '',
      note: data['note'],
      type: _stopTypeFrom(data['type']),
      icon: data['icon'] ?? 'pin',
      placeQuery: data['placeQuery'],
      about: data['about'],
      legMinutes: data['legMinutes'],
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
}

/// Google Maps deep-link helpers (open with url_launcher, mode externalApplication).
class TripMaps {
  static Uri search(String query) => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');

  static Uri directions(String destination) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&travelmode=driving&destination=${Uri.encodeComponent(destination)}');

  /// Chain a day's mappable stops into one driving route.
  static Uri? dayRoute(List<ItineraryStop> stops) {
    final pts = stops
        .where((s) => s.type != StopType.prayer && (s.placeQuery ?? s.title).isNotEmpty)
        .map((s) => s.placeQuery ?? s.title)
        .toList();
    if (pts.length < 2) return pts.isEmpty ? null : directions(pts.first);
    final origin = pts.first, destination = pts.last;
    final waypoints = pts.sublist(1, pts.length - 1);
    var url =
        'https://www.google.com/maps/dir/?api=1&travelmode=driving&origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destination)}';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=${waypoints.map(Uri.encodeComponent).join('%7C')}';
    }
    return Uri.parse(url);
  }
}
