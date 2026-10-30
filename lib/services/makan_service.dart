import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/services/group_service.dart';

/// Makan spots live in two places:
///   `makan_spots/{id}`                 — personal, readable by [addedBy] only
///   `groups/{groupId}/makan_spots/{id}` — shared, every member can read/edit
///
/// They are split by path rather than by a `sharedGroupIds` field because
/// Firestore rules cannot prove "member of one of these groups" for a list
/// query; a path-scoped group check is what the rules can enforce.
class MakanService {
  final FirebaseFirestore _firestore;

  MakanService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String? groupId) =>
      groupId == null
          ? _firestore.collection('makan_spots')
          : _firestore
              .collection('groups')
              .doc(groupId)
              .collection('makan_spots');

  List<MakanSpot> _read(
    QuerySnapshot<Map<String, dynamic>> snap,
    String? gid,
  ) =>
      snap.docs
          .map((d) => MakanSpot.fromMap(d.data(), d.id, groupId: gid))
          .toList();

  /// Spots the user saved for themselves. Sorted in the UI — no index needed.
  Stream<List<MakanSpot>> streamPersonal(String userId) => _col(
    null,
  ).where('addedBy', isEqualTo: userId).snapshots().map((s) => _read(s, null));

  Stream<List<MakanSpot>> streamGroup(String groupId) =>
      _col(groupId).snapshots().map((s) => _read(s, groupId));

  Stream<MakanSpot?> streamSpot(String spotId, {String? groupId}) =>
      _col(groupId).doc(spotId).snapshots().map((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        return MakanSpot.fromMap(data, snap.id, groupId: groupId);
      });

  /// Saves into the group's list when [groupId] is given, else personal.
  Future<String> addSpot(MakanSpot spot, {String? groupId}) async {
    _validate(spot);
    final now = DateTime.now();
    final doc = await _col(groupId).add({
      ...spot.toMap(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return doc.id;
  }

  Future<void> updateSpot(MakanSpot spot) async {
    _validate(spot);
    await _col(spot.groupId).doc(spot.id).update({
      ...spot.toMap(),
      // Who added it never changes — the rules check this too.
      'addedBy': spot.addedBy,
      'createdAt': Timestamp.fromDate(spot.createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Puts a copy of [spot] in another list — personal when [toGroupId] is
  /// null. The copy belongs to whoever made it; the original is untouched, so
  /// later edits to one do not reach the other.
  Future<String> copySpot(
    MakanSpot spot, {
    String? toGroupId,
    required String byUserId,
    required String byName,
  }) {
    final now = DateTime.now();
    return addSpot(
      MakanSpot(
        id: '',
        name: spot.name,
        area: spot.area,
        categories: spot.categories,
        menu: spot.menu,
        hours: spot.hours,
        mapLink: spot.mapLink,
        mapQuery: spot.mapQuery,
        lat: spot.lat,
        lng: spot.lng,
        notes: spot.notes,
        addedBy: byUserId,
        addedByName: byName,
        createdAt: now,
        updatedAt: now,
      ),
      groupId: toGroupId,
    );
  }

  /// Whether a list already has a spot with exactly this name — a guard
  /// against sharing the same warung twice. The personal query must filter on
  /// `addedBy`, or the rules reject it.
  Future<bool> hasSpotNamed(
    String name, {
    String? groupId,
    required String userId,
  }) async {
    Query<Map<String, dynamic>> q = _col(
      groupId,
    ).where('name', isEqualTo: name.trim());
    if (groupId == null) q = q.where('addedBy', isEqualTo: userId);
    final snap = await q.limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> deleteSpot(MakanSpot spot) =>
      _col(spot.groupId).doc(spot.id).delete();

  void _validate(MakanSpot spot) {
    if (spot.name.trim().isEmpty) throw Exception('Name cannot be empty');
    if (spot.area.trim().isEmpty) throw Exception('Area cannot be empty');
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final makanServiceProvider = Provider<MakanService>((ref) => MakanService());

final personalMakanSpotsProvider =
    StreamProvider.family<List<MakanSpot>, String>((ref, userId) {
      return ref.watch(makanServiceProvider).streamPersonal(userId);
    });

final groupMakanSpotsProvider = StreamProvider.family<List<MakanSpot>, String>((
  ref,
  groupId,
) {
  return ref.watch(makanServiceProvider).streamGroup(groupId);
});

/// One spot, live. Keyed by `(spotId, groupId)` since the path depends on both.
final makanSpotProvider =
    StreamProvider.family<MakanSpot?, ({String spotId, String? groupId})>((
      ref,
      key,
    ) {
      return ref
          .watch(makanServiceProvider)
          .streamSpot(key.spotId, groupId: key.groupId);
    });

/// Everything the user can see: their own spots plus every group's list.
///
/// Loading only while the personal list has not arrived — a slow or failing
/// group stream should not hide the rest.
final allMakanSpotsProvider =
    Provider.family<AsyncValue<List<MakanSpot>>, String>((ref, userId) {
      final personal = ref.watch(personalMakanSpotsProvider(userId));
      final groups =
          ref.watch(userGroupsStreamProvider(userId)).valueOrNull ??
          const <GroupModel>[];

      final all = <MakanSpot>[...?personal.valueOrNull];
      for (final g in groups) {
        all.addAll(
          ref.watch(groupMakanSpotsProvider(g.id)).valueOrNull ?? const [],
        );
      }

      if (personal.isLoading && !personal.hasValue) return const AsyncLoading();
      if (personal.hasError && !personal.hasValue) {
        return AsyncError(personal.error!, personal.stackTrace!);
      }
      return AsyncData(all);
    });
