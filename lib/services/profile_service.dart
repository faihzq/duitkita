// lib/services/profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  ProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
  ///
  /// With [onlyIfUnset] an account that already has a handle keeps it, checked
  /// inside the transaction: automatic assignment decides from a read that can
  /// be stale (cached, or another device just picked one), and must never
  /// replace a real handle. Returns the handle the account ends up with.
  Future<String> setUsername({
    required String uid,
    required String username,
    bool onlyIfUnset = false,
  }) async {
    final handle = normaliseUsername(username);
    final problem = usernameError(handle);
    if (problem != null) throw ArgumentError(problem);

    return _firestore.runTransaction<String>((tx) async {
      final claimRef = _usernames.doc(handle);

      // Every read must precede every write inside a transaction.
      final claim = await tx.get(claimRef);
      final profile = await tx.get(_users.doc(uid));

      final current =
          (profile.data() as Map<String, dynamic>?)?['username'] as String?;
      if (onlyIfUnset && current != null && current.isNotEmpty) return current;

      if (claim.exists) {
        final owner = (claim.data() as Map<String, dynamic>?)?['uid'];
        if (owner != uid) throw const UsernameTakenException();
      }

      final previous = current;

      // Read the old reservation before deciding to release it. Issuing a
      // delete blind fails the rules when the document is missing: `resource`
      // is null there, so `resource.data.uid` cannot be evaluated and the whole
      // write is denied — which reads as "permission denied" for the rename.
      if (previous != null && previous.isNotEmpty && previous != handle) {
        final old = await tx.get(_usernames.doc(previous));
        final ownedByUs =
            old.exists && (old.data() as Map<String, dynamic>?)?['uid'] == uid;
        if (ownedByUs) tx.delete(_usernames.doc(previous));
      }

      tx.set(claimRef, {'uid': uid});
      tx.update(_users.doc(uid), {
        'username': handle,
        'updatedAt': DateTime.now(),
      });
      return handle;
    });
  }

  /// Recreates the profile document when it is missing.
  ///
  /// Sign-up writes it, but that write can fail — offline, or a rules hiccup —
  /// after the credential has already been created. Rather than strand the new
  /// account, sign-up carries on and this repairs the gap on next launch.
  /// A no-op when the document is already there.
  Future<void> ensureProfile(User user) async {
    try {
      final doc = await _users.doc(user.uid).get();
      if (doc.exists) return;

      // Null fields are omitted, never written. Sign-up queues its own profile
      // write and Firestore flushes in order, so this can land *after* it —
      // and an email sign-up has no displayName or phoneNumber on the auth
      // user, which would otherwise blank out the real ones.
      await _users.doc(user.uid).set({
        if (user.displayName != null) 'name': user.displayName,
        if (user.email != null) 'email': user.email,
        if (user.phoneNumber != null) 'phoneNumber': user.phoneNumber,
        if (user.photoURL != null) 'profileImageUrl': user.photoURL,
        'showJdtMatches': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not restore the profile document: $e');
    }
  }

  /// Gives an account a username if it has none, deriving one from the name or
  /// email and adding a number until it is free.
  ///
  /// Existing accounts predate the field, and adding people by username is
  /// useless while most of them are unfindable.
  Future<String?> ensureUsername(String uid) async {
    try {
      final profile = await getUserProfile(uid);
      if (profile == null) return null; // Nothing to put a handle on yet.
      final existing = profile.username;
      if (existing != null && existing.isNotEmpty) return existing;

      final base = suggestUsername(
        name: profile.name,
        email: profile.email,
        uid: uid,
      );

      for (var attempt = 1; attempt <= 10; attempt++) {
        final candidate = usernameAttempt(base, attempt);
        try {
          return await setUsername(
            uid: uid,
            username: candidate,
            onlyIfUnset: true,
          );
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

  // Create a new user profile. Merged, with empty fields left out, because it
  // runs in the background after sign-in and can land after the username and
  // device tokens were written. A plain set() would erase them.
  Future<void> createUserProfile(UserProfile profile) async {
    try {
      await _users
          .doc(profile.uid)
          .set(
            profile.toMap()..removeWhere((_, value) => value == null),
            SetOptions(merge: true),
          );
    } catch (e) {
      // Add error handling
      throw Exception('Failed to create profile: $e');
    }
  }

  // Update user profile. Never writes the username: only [setUsername] may,
  // alongside its reservation. Callers hold a snapshot that can be out of date,
  // and writing its handle back would revert or blank the real one.
  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      await _users.doc(profile.uid).update(profile.toMap()..remove('username'));
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
