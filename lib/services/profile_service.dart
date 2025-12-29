// lib/services/profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/user_profile.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _users => _firestore.collection('users');

  // Get user profile stream
  Stream<UserProfile?> getUserProfileStream(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserProfile.fromMap(
          snapshot.data() as Map<String, dynamic>,
          uid,
        );
      }
      return null;
    });
  }

  // Get user profile future
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromMap(doc.data() as Map<String, dynamic>, uid);
    }
    return null;
  }

  // Create a new user profile
  Future<void> createUserProfile(UserProfile profile) async {
    try {
      await _users.doc(profile.uid).set(profile.toMap());
    } catch (e) {
      // Add error handling
      throw Exception('Failed to create profile: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).update(profile.toMap());
  }
}

// Provider for profile service
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// Stream provider for user profile
final userProfileStreamProvider = StreamProvider.family<UserProfile?, String>((
  ref,
  uid,
) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getUserProfileStream(uid);
});
