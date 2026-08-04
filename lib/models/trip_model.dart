import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus { tentative, confirmed, settled }

TripStatus tripStatusFrom(String? s) => TripStatus.values.firstWhere(
  (e) => e.name == s,
  orElse: () => TripStatus.tentative,
);

String tripStatusLabel(TripStatus s) => switch (s) {
  TripStatus.tentative => 'Tentative',
  TripStatus.confirmed => 'Confirmed',
  TripStatus.settled => 'Settled',
};

/// A traveller is embedded on the trip doc (name + photo denormalised) so the
/// list screen can draw avatar stacks from a single read. [TripModel.travellerIds]
/// is kept in parallel purely so `arrayContains` queries work.
class TripTraveller {
  final String userId;
  final String name;
  final String? photoUrl;

  const TripTraveller({
    required this.userId,
    required this.name,
    this.photoUrl,
  });

  factory TripTraveller.fromMap(Map<String, dynamic> data) => TripTraveller(
    userId: data['userId'] ?? '',
    name: data['name'] ?? 'Traveller',
    photoUrl: data['photoUrl'],
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'name': name,
    'photoUrl': photoUrl,
  };
}

class TripModel {
  final String id;
  final String name;
  final List<String> destinations;
  final DateTime startDate;
  final DateTime endDate;
  final TripStatus status;
  final String? emoji;

  /// Preset key into [TripBands.gradients] for the card colour band.
  final String? bandGradient;
  final String createdBy;
  final List<String> travellerIds;
  final List<TripTraveller> travellers;

  /// Denormalised count of docs in `trips/{id}/stops`, kept current by
  /// `TripService.addStop`/`deleteStop` so the list screen needs one read.
  final int stopCount;
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
    this.travellers = const [],
    this.stopCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Inclusive day count — a trip that starts and ends the same day is 1 day.
  int get dayCount {
    final a = DateTime(startDate.year, startDate.month, startDate.day);
    final b = DateTime(endDate.year, endDate.month, endDate.day);
    return b.difference(a).inDays + 1;
  }

  /// Calendar date for day [n] (1-based).
  DateTime dateForDay(int n) =>
      DateTime(startDate.year, startDate.month, startDate.day + (n - 1));

  /// "Perlis · Kedah · Penang"
  String get where => destinations.join(' · ');

  /// The organiser owns the plan: only they may change the trip or its stops.
  /// Everyone else on [travellerIds] can see it. Mirrored in firestore.rules —
  /// this getter only decides what to show, the rules are what enforce it.
  bool isOrganiser(String? userId) =>
      userId != null && userId.isNotEmpty && userId == createdBy;

  bool get isPast =>
      endDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  factory TripModel.fromMap(Map<String, dynamic> data, String id) {
    return TripModel(
      id: id,
      name: data['name'] ?? '',
      destinations: List<String>.from(data['destinations'] ?? const []),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: tripStatusFrom(data['status']),
      emoji: data['emoji'],
      bandGradient: data['bandGradient'],
      createdBy: data['createdBy'] ?? '',
      travellerIds: List<String>.from(data['travellerIds'] ?? const []),
      travellers:
          (data['travellers'] as List?)
              ?.map((t) => TripTraveller.fromMap(Map<String, dynamic>.from(t)))
              .toList() ??
          const [],
      stopCount: (data['stopCount'] as num?)?.toInt() ?? 0,
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
    'travellers': travellers.map((t) => t.toMap()).toList(),
    // stopCount is deliberately omitted — it is only ever moved by
    // FieldValue.increment, so writing a read-back value could lose a
    // concurrent stop added from another device.
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  TripModel copyWith({
    String? name,
    List<String>? destinations,
    DateTime? startDate,
    DateTime? endDate,
    TripStatus? status,
    String? emoji,
    String? bandGradient,
    List<String>? travellerIds,
    List<TripTraveller>? travellers,
  }) {
    return TripModel(
      id: id,
      name: name ?? this.name,
      destinations: destinations ?? this.destinations,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      emoji: emoji ?? this.emoji,
      bandGradient: bandGradient ?? this.bandGradient,
      createdBy: createdBy,
      travellerIds: travellerIds ?? this.travellerIds,
      travellers: travellers ?? this.travellers,
      stopCount: stopCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
