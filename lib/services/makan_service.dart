import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/makan_spot.dart';

/// Makan spots live in one top-level `makan_spots` collection that every
/// signed-in user reads — the app is used by one family, so the list is
/// shared. Anyone may add or edit a spot; only whoever added it removes it.
class MakanService {
  final FirebaseFirestore _firestore;

  MakanService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('makan_spots');

  /// Every spot. Sorted in the UI — no index needed.
  Stream<List<MakanSpot>> streamAll() => _col.snapshots().map(
    (s) => s.docs.map((d) => MakanSpot.fromMap(d.data(), d.id)).toList(),
  );

  Stream<MakanSpot?> streamSpot(String spotId) =>
      _col.doc(spotId).snapshots().map((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        return MakanSpot.fromMap(data, snap.id);
      });

  Future<String> addSpot(MakanSpot spot) async {
    _validate(spot);
    final now = DateTime.now();
    final doc = _col.doc();
    await doc.set({
      ...spot.toMap(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return doc.id;
  }

  Future<void> updateSpot(MakanSpot spot) async {
    _validate(spot);
    await _col.doc(spot.id).update({
      ...spot.toMap(),
      // Who added it never changes — the rules check this too.
      'addedBy': spot.addedBy,
      'createdAt': Timestamp.fromDate(spot.createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteSpot(MakanSpot spot) => _col.doc(spot.id).delete();

  void _validate(MakanSpot spot) {
    if (spot.name.trim().isEmpty) throw Exception('Name cannot be empty');
    if (spot.area.trim().isEmpty) throw Exception('Area cannot be empty');
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final makanServiceProvider = Provider<MakanService>((ref) => MakanService());

/// The family's whole list, live.
final makanSpotsProvider = StreamProvider<List<MakanSpot>>((ref) {
  return ref.watch(makanServiceProvider).streamAll();
});

/// One spot, live.
final makanSpotProvider = StreamProvider.family<MakanSpot?, String>((
  ref,
  spotId,
) {
  return ref.watch(makanServiceProvider).streamSpot(spotId);
});
