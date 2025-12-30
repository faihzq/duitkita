import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/models/user_profile.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _groups => _firestore.collection('groups');

  // Create a new group
  Future<String> createGroup({
    required String name,
    required String description,
    required String createdBy,
    required String creatorName,
    required String? creatorEmail,
    double monthlyAmount = 30.0,
  }) async {
    try {
      final now = DateTime.now();
      final groupData = {
        'name': name,
        'description': description,
        'createdBy': createdBy,
        'monthlyAmount': monthlyAmount,
        'createdAt': now,
        'updatedAt': now,
        'memberIds': [createdBy],
        'memberCount': 1,
      };

      final groupDoc = await _groups.add(groupData);

      // Add creator as admin member
      await groupDoc.collection('members').doc(createdBy).set({
        'userId': createdBy,
        'userName': creatorName,
        'userEmail': creatorEmail,
        'isAdmin': true,
        'joinedAt': now,
        'totalPaid': 0.0,
        'paymentCount': 0,
      });

      return groupDoc.id;
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  // Get user's groups stream
  Stream<List<GroupModel>> getUserGroupsStream(String userId) {
    return _groups
        .where('memberIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => GroupModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  // Get single group stream
  Stream<GroupModel?> getGroupStream(String groupId) {
    return _groups.doc(groupId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return GroupModel.fromMap(
          snapshot.data() as Map<String, dynamic>,
          snapshot.id,
        );
      }
      return null;
    });
  }

  // Get group members stream
  Stream<List<GroupMember>> getGroupMembersStream(String groupId) {
    return _groups
        .doc(groupId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) =>
                        GroupMember.fromMap(doc.data() as Map<String, dynamic>),
                  )
                  .toList(),
        );
  }

  // Add member to group
  Future<void> addMemberToGroup({
    required String groupId,
    required String userId,
    required String userName,
    required String? userEmail,
  }) async {
    try {
      final groupDoc = _groups.doc(groupId);
      final memberDoc = groupDoc.collection('members').doc(userId);

      // Check if member already exists
      final memberSnapshot = await memberDoc.get();
      if (memberSnapshot.exists) {
        throw Exception('User is already a member of this group');
      }

      // Add member
      await memberDoc.set({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'isAdmin': false,
        'joinedAt': DateTime.now(),
        'totalPaid': 0.0,
        'paymentCount': 0,
      });

      // Update group member count and IDs
      await groupDoc.update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to add member: $e');
    }
  }

  // Remove member from group
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      final groupDoc = _groups.doc(groupId);

      // Delete member document
      await groupDoc.collection('members').doc(userId).delete();

      // Update group member count and IDs
      await groupDoc.update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'memberCount': FieldValue.increment(-1),
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to remove member: $e');
    }
  }

  // Update group settings
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    double? monthlyAmount,
  }) async {
    try {
      final updateData = <String, dynamic>{'updatedAt': DateTime.now()};

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (monthlyAmount != null) updateData['monthlyAmount'] = monthlyAmount;

      await _groups.doc(groupId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  // Delete group
  Future<void> deleteGroup(String groupId) async {
    try {
      // Delete all members
      final membersSnapshot =
          await _groups.doc(groupId).collection('members').get();
      for (var doc in membersSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete group
      await _groups.doc(groupId).delete();
    } catch (e) {
      throw Exception('Failed to delete group: $e');
    }
  }

  // Check if user is admin
  Future<bool> isUserAdmin(String groupId, String userId) async {
    try {
      final memberDoc =
          await _groups.doc(groupId).collection('members').doc(userId).get();
      if (memberDoc.exists) {
        final data = memberDoc.data() as Map<String, dynamic>;
        return data['isAdmin'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Update member stats after payment
  Future<void> updateMemberStats({
    required String groupId,
    required String userId,
    required double amount,
  }) async {
    try {
      await _groups.doc(groupId).collection('members').doc(userId).update({
        'totalPaid': FieldValue.increment(amount),
        'paymentCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to update member stats: $e');
    }
  }
}

// Provider for group service
final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService();
});

// Stream provider for user groups
final userGroupsStreamProvider =
    StreamProvider.family<List<GroupModel>, String>((ref, userId) {
      final groupService = ref.watch(groupServiceProvider);
      return groupService.getUserGroupsStream(userId);
    });

// Stream provider for single group
final groupStreamProvider = StreamProvider.family<GroupModel?, String>((
  ref,
  groupId,
) {
  final groupService = ref.watch(groupServiceProvider);
  return groupService.getGroupStream(groupId);
});

// Stream provider for group members
final groupMembersStreamProvider =
    StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
      final groupService = ref.watch(groupServiceProvider);
      return groupService.getGroupMembersStream(groupId);
    });
