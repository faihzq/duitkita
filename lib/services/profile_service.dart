// lib/services/profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/user_profile.dart';
import 'package:duitkita/utils/username.dart';

/// Raised when a handle is already claimed by another account.
class UsernameTakenException implements Exception {
  const UsernameTakenException();
  @override
  String toString() => 'That username is already taken';
}

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

  CollectionReference get _usernames => _firestore.collection('usernames');

  /// Resolve a handle to a user. One document read, versus the indexed query
  /// [getUserIdByEmail] needs.
  Future<String?> getUserIdByUsername(String username) async {
    final handle = normaliseUsername(username);
    if (handle.isEmpty) return null;
    try {
      final snap = await _usernames.doc(handle).get();
      if (!snap.exists) return null;
      return (snap.data() as Map<String, dynamic>?)?['uid'] as String?;
    } catch (e) {
      debugPrint('Error getting user ID by username: $e');
      return null;
    }
  }

  /// Looks someone up by whatever was typed — `@handle`, `handle`, or an email
  /// address. Keeps the older email flow working for accounts that predate
  /// usernames.
  Future<String?> findUserId(String input) {
    final value = input.trim();
    if (value.contains('@') && value.contains('.')) {
      return getUserIdByEmail(value);
    }
    return getUserIdByUsername(value);
  }

  /// Claims [username] for [uid], releasing any handle they already held.
  ///
  /// Firestore has no unique constraint, so `usernames/{handle}` is the index:
  /// creating that document *is* the claim, and the transaction makes the
  /// check-then-claim atomic against two people racing for the same handle.
  ///
  /// Throws [UsernameTakenException] when someone else holds it.
  Future<void> setUsername({
    required String uid,
    required String username,
  }) async {
    final handle = normaliseUsername(username);
    final problem = usernameError(handle);
    if (problem != null) throw ArgumentError(problem);

    await _firestore.runTransaction((tx) async {
      final claimRef = _usernames.doc(handle);

      // Every read must precede every write inside a transaction.
      final claim = await tx.get(claimRef);
      final profile = await tx.get(_users.doc(uid));

      if (claim.exists) {
        final owner = (claim.data() as Map<String, dynamic>?)?['uid'];
        if (owner != uid) throw const UsernameTakenException();
      }

      final previous =
          (profile.data() as Map<String, dynamic>?)?['username'] as String?;
      if (previous != null && previous.isNotEmpty && previous != handle) {
        tx.delete(_usernames.doc(previous));
      }

      tx.set(claimRef, {'uid': uid});
      tx.update(_users.doc(uid), {
        'username': handle,
        'updatedAt': DateTime.now(),
      });
    });
  }

  /// Gives an account a username if it has none, deriving one from the name or
  /// email and adding a number until it is free.
  ///
  /// Existing accounts predate the field, and adding people by username is
  /// useless while most of them are unfindable.
  Future<String?> ensureUsername(String uid) async {
    try {
      final profile = await getUserProfile(uid);
      final existing = profile?.username;
      if (existing != null && existing.isNotEmpty) return existing;

      final base = suggestUsername(
        name: profile?.name,
        email: profile?.email,
        uid: uid,
      );

      for (var attempt = 1; attempt <= 10; attempt++) {
        final candidate = usernameAttempt(base, attempt);
        try {
          await setUsername(uid: uid, username: candidate);
          return candidate;
        } on UsernameTakenException {
          continue; // Someone has it; try the next number.
        }
      }
    } catch (e) {
      // Never block sign-in over a handle — it can be set later in Profile.
      debugPrint('Could not assign a username: $e');
    }
    return null;
  }

  // Get user ID by email
  Future<String?> getUserIdByEmail(String email) async {
    try {
      final querySnapshot =
          await _users.where('email', isEqualTo: email).limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user ID by email: $e');
      return null;
    }
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
    try {
      await _users.doc(profile.uid).update(profile.toMap());
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Set the profile image URL. Uses merge-set so it succeeds even if the
  // user document does not exist yet (avoids a silent no-op on update).
  Future<void> setProfileImageUrl(String uid, String url) async {
    try {
      await _users.doc(uid).set({
        'profileImageUrl': url,
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update profile image: $e');
    }
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
