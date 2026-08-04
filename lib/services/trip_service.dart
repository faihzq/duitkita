import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/models/itinerary_stop.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _trips => _firestore.collection('trips');

  CollectionReference<Map<String, dynamic>> _stops(String tripId) =>
      _trips.doc(tripId).collection('stops');

  // ── Trips ────────────────────────────────────────────────────────────────

  /// Every trip the user travels on, newest start date first.
  Stream<List<TripModel>> streamTrips(String userId) {
    return _trips
        .where('travellerIds', arrayContains: userId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map(
                    (d) => TripModel.fromMap(
                      d.data() as Map<String, dynamic>,
                      d.id,
                    ),
                  )
                  .toList(),
        );
  }

  Stream<TripModel?> streamTrip(String tripId) {
    return _trips.doc(tripId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return TripModel.fromMap(snap.data() as Map<String, dynamic>, snap.id);
    });
  }

  Future<TripModel?> getTrip(String tripId) async {
    final snap = await _trips.doc(tripId).get();
    if (!snap.exists || snap.data() == null) return null;
    return TripModel.fromMap(snap.data() as Map<String, dynamic>, snap.id);
  }

  Future<String> createTrip({
    required String name,
    required String createdBy,
    required DateTime startDate,
    required DateTime endDate,
    List<String> destinations = const [],
    TripStatus status = TripStatus.tentative,
    String? emoji,
    String? bandGradient,
    List<TripTraveller> travellers = const [],
  }) async {
    if (name.trim().isEmpty) throw Exception('Trip name cannot be empty');
    if (endDate.isBefore(startDate)) {
      throw Exception('End date cannot be before the start date');
    }

    // The creator always travels — guard against a caller omitting them.
    final people = [...travellers];
    if (!people.any((t) => t.userId == createdBy)) {
      throw Exception('The trip creator must be in the traveller list');
    }

    try {
      final now = DateTime.now();
      final trip = TripModel(
        id: '',
        name: name.trim(),
        destinations: destinations,
        startDate: startDate,
        endDate: endDate,
        status: status,
        emoji: emoji,
        bandGradient: bandGradient,
        createdBy: createdBy,
        travellerIds: people.map((t) => t.userId).toList(),
        travellers: people,
        createdAt: now,
        updatedAt: now,
      );
      final doc = await _trips.add(trip.toMap());
      return doc.id;
    } catch (e) {
      throw Exception('Failed to create trip: $e');
    }
  }

  Future<void> updateTrip(TripModel trip) async {
    await _trips.doc(trip.id).update({
      ...trip.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> setStatus(String tripId, TripStatus status) async {
    await _trips.doc(tripId).update({
      'status': status.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> addTraveller(String tripId, TripTraveller traveller) async {
    await _trips.doc(tripId).update({
      'travellerIds': FieldValue.arrayUnion([traveller.userId]),
      'travellers': FieldValue.arrayUnion([traveller.toMap()]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Deletes the trip and every stop under it. Firestore does not cascade, so
  /// the subcollection is cleared first.
  Future<void> deleteTrip(String tripId) async {
    final stops = await _stops(tripId).get();
    final batch = _firestore.batch();
    for (final doc in stops.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_trips.doc(tripId));
    await batch.commit();
  }

  // ── Stops ────────────────────────────────────────────────────────────────

  /// All stops for a trip, ordered by day then time-of-day.
  Stream<List<ItineraryStop>> streamStops(String tripId) {
    return _stops(tripId)
        .orderBy('day')
        .orderBy('order')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => ItineraryStop.fromMap(d.data(), d.id))
                  .toList(),
        );
  }

  Future<String> addStop(String tripId, ItineraryStop stop) async {
    if (stop.title.trim().isEmpty) throw Exception('Stop needs a title');
    final doc = await _stops(tripId).add({
      ...stop.toMap(),
      // Keep the sort key in sync with the displayed time.
      'order': minutesFromTimeLabel(stop.time),
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    await _touch(tripId, stopDelta: 1);
    return doc.id;
  }

  /// Writes many stops at once, for a pasted itinerary. One batch, so an
  /// import either lands whole or not at all.
  Future<int> addStops(String tripId, List<ItineraryStop> stops) async {
    if (stops.isEmpty) return 0;

    final batch = _firestore.batch();
    final now = Timestamp.fromDate(DateTime.now());
    for (final stop in stops) {
      batch.set(_stops(tripId).doc(), {
        ...stop.toMap(),
        'order': minutesFromTimeLabel(stop.time),
        'createdAt': now,
      });
    }
    batch.update(_trips.doc(tripId), {
      'updatedAt': now,
      'stopCount': FieldValue.increment(stops.length),
    });
    await batch.commit();
    return stops.length;
  }

  Future<void> updateStop(String tripId, ItineraryStop stop) async {
    await _stops(tripId).doc(stop.id).update({
      ...stop.toMap(),
      'order': minutesFromTimeLabel(stop.time),
    });
    await _touch(tripId);
  }

  Future<void> deleteStop(String tripId, String stopId) async {
    await _stops(tripId).doc(stopId).delete();
    await _touch(tripId, stopDelta: -1);
  }

  Future<void> _touch(String tripId, {int stopDelta = 0}) async {
    try {
      await _trips.doc(tripId).update({
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        if (stopDelta != 0) 'stopCount': FieldValue.increment(stopDelta),
      });
    } catch (_) {
      // A stale updatedAt/stopCount is not worth failing the write the user
      // asked for — the stop itself is already saved.
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final tripServiceProvider = Provider<TripService>((ref) => TripService());

/// All trips for a user.
final tripsStreamProvider = StreamProvider.family<List<TripModel>, String>((
  ref,
  userId,
) {
  return ref.watch(tripServiceProvider).streamTrips(userId);
});

/// A single trip, live.
final tripStreamProvider = StreamProvider.family<TripModel?, String>((
  ref,
  tripId,
) {
  return ref.watch(tripServiceProvider).streamTrip(tripId);
});

/// Every stop on a trip, ordered by day then time. Group by `day` in the UI —
/// switching day tabs must not refetch.
final tripStopsStreamProvider =
    StreamProvider.family<List<ItineraryStop>, String>((ref, tripId) {
      return ref.watch(tripServiceProvider).streamStops(tripId);
    });
