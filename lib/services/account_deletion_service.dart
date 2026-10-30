import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Deletes an account and the data belonging to it.
///
/// Google Play requires any app that lets people create an account to offer an
/// in-app way to delete it, so this has to actually remove the data rather than
/// just sign out.
///
/// What it does NOT remove, deliberately:
///   • Payments already recorded against a group — the group's balance and
///     other members' history depend on them. This is disclosed in the privacy
///     policy, and the record keeps only the name already visible to members.
class AccountDeletionService {
  AccountDeletionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  /// How this account signs in, so the UI knows which re-authentication to ask
  /// for. Null when there is nobody signed in.
  String? get signInMethod {
    final providers = _auth.currentUser?.providerData.map((p) => p.providerId);
    if (providers == null || providers.isEmpty) return null;
    if (providers.contains('google.com')) return 'google.com';
    return providers.first; // 'password' for email accounts.
  }

  /// Proves the session is fresh so Firebase will allow the delete.
  ///
  /// [password] is required for email accounts; Google accounts re-run the
  /// Google prompt instead.
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionFailure('You are not signed in.');
    }

    try {
      if (signInMethod == 'google.com') {
        await GoogleSignIn.instance.initialize();
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw const AccountDeletionFailure(
            'Google did not confirm your identity.',
          );
        }
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
        return;
      }

      final email = user.email;
      if (email == null || password == null || password.isEmpty) {
        throw const AccountDeletionFailure('Enter your password to confirm.');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionFailure(switch (e.code) {
        'wrong-password' ||
        'invalid-credential' => 'That password is not correct.',
        'too-many-requests' => 'Too many attempts. Try again shortly.',
        _ => e.message ?? 'Could not confirm your identity.',
      });
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AccountDeletionFailure('Confirmation cancelled.');
      }
      throw AccountDeletionFailure(e.description ?? 'Google sign-in failed.');
    }
  }

  /// Removes the account's data, then the account itself.
  ///
  /// Firestore first, auth last: the security rules need the user still signed
  /// in, so deleting the credential first would strand the data forever.
  ///
  /// Throws [ReauthRequired] when Firebase wants a fresh sign-in before it will
  /// delete the credential — the caller should re-authenticate and call again.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionFailure('You are not signed in.');
    }
    final uid = user.uid;

    await _leaveGroups(uid);
    await _handOverOrDeleteTrips(uid);
    await _deletePersonalDebts(uid);
    await _deletePersonalMakanSpots(uid);
    await _deleteProfileAndHandle(uid);
    await _deleteProfileImage(uid);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') throw const ReauthRequired();
      throw AccountDeletionFailure(
        e.message ?? 'Could not delete the account.',
      );
    }

    // Clear the cached Google session so the next sign-in asks properly.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      /* Not signed in with Google, or already cleared. */
    }
  }

  // ── Groups ────────────────────────────────────────────────────────────────

  /// Leaves every group. When the departing member is the creator, ownership
  /// moves to someone else rather than leaving a group nobody can administer.
  Future<void> _leaveGroups(String uid) async {
    final groups =
        await _db
            .collection('groups')
            .where('memberIds', arrayContains: uid)
            .get();

    for (final doc in groups.docs) {
      try {
        final data = doc.data();
        final memberIds = List<String>.from(data['memberIds'] ?? const []);
        final others = memberIds.where((id) => id != uid).toList();

        if (others.isEmpty) {
          // Nobody left to keep it — remove the group and its subcollections.
          await _deleteSubcollection(doc.reference.collection('members'));
          await _deleteSubcollection(doc.reference.collection('payments'));
          await _deleteSubcollection(doc.reference.collection('makan_spots'));
          await doc.reference.delete();
          continue;
        }

        final update = <String, dynamic>{
          'memberIds': FieldValue.arrayRemove([uid]),
          'memberCount': others.length,
          'updatedAt': DateTime.now(),
        };

        if (data['createdBy'] == uid) {
          update['createdBy'] = await _nextOwner(doc.reference, others);
        }

        await doc.reference.update(update);
        await doc.reference.collection('members').doc(uid).delete();
      } catch (e) {
        debugPrint('Could not leave group ${doc.id}: $e');
      }
    }
  }

  /// Prefers an existing admin, otherwise the longest-standing member, so the
  /// group keeps someone who can approve payments.
  Future<String> _nextOwner(
    DocumentReference<Map<String, dynamic>> group,
    List<String> candidates,
  ) async {
    try {
      final members = await group.collection('members').get();
      final rows =
          members.docs.where((d) => candidates.contains(d.id)).toList();

      rows.sort((a, b) {
        final aAdmin = a.data()['isAdmin'] == true;
        final bAdmin = b.data()['isAdmin'] == true;
        if (aAdmin != bAdmin) return aAdmin ? -1 : 1;
        final aJoined = (a.data()['joinedAt'] as Timestamp?)?.toDate();
        final bJoined = (b.data()['joinedAt'] as Timestamp?)?.toDate();
        if (aJoined == null || bJoined == null) return 0;
        return aJoined.compareTo(bJoined);
      });

      if (rows.isNotEmpty) {
        // The new owner needs admin rights to actually run the group.
        await group.collection('members').doc(rows.first.id).update({
          'isAdmin': true,
        });
        return rows.first.id;
      }
    } catch (e) {
      debugPrint('Could not pick a new group owner: $e');
    }
    return candidates.first;
  }

  // ── Trips ─────────────────────────────────────────────────────────────────

  /// Leaves trips. An organiser hands over to another traveller; a trip with
  /// nobody else on it is deleted along with its stops and tickets.
  Future<void> _handOverOrDeleteTrips(String uid) async {
    final trips =
        await _db
            .collection('trips')
            .where('travellerIds', arrayContains: uid)
            .get();

    for (final doc in trips.docs) {
      try {
        final data = doc.data();
        final travellerIds = List<String>.from(
          data['travellerIds'] ?? const [],
        );
        final others = travellerIds.where((id) => id != uid).toList();
        final travellers =
            (data['travellers'] as List? ?? const [])
                .map((t) => Map<String, dynamic>.from(t))
                .where((t) => t['userId'] != uid)
                .toList();

        if (others.isEmpty) {
          await _deleteSubcollection(doc.reference.collection('stops'));
          await _deleteTripTickets(doc.id);
          await doc.reference.delete();
          continue;
        }

        await doc.reference.update({
          'travellerIds': others,
          'travellers': travellers,
          // Hand the plan over, otherwise nobody could edit it again.
          if (data['createdBy'] == uid) 'createdBy': others.first,
          'updatedAt': DateTime.now(),
        });
      } catch (e) {
        debugPrint('Could not leave trip ${doc.id}: $e');
      }
    }
  }

  Future<void> _deleteTripTickets(String tripId) async {
    try {
      final dir = _storage.ref().child('trip_tickets/$tripId');
      final listing = await dir.listAll();
      for (final stop in listing.prefixes) {
        final files = await stop.listAll();
        for (final f in files.items) {
          await f.delete();
        }
      }
      for (final f in listing.items) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('Could not remove tickets for trip $tripId: $e');
    }
  }

  // ── Personal records ──────────────────────────────────────────────────────

  Future<void> _deletePersonalDebts(String uid) async {
    try {
      final debts =
          await _db.collection('debts').where('userId', isEqualTo: uid).get();
      for (final doc in debts.docs) {
        await _deleteSubcollection(doc.reference.collection('payments'));
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Could not delete debts: $e');
    }
  }

  Future<void> _deletePersonalMakanSpots(String uid) async {
    try {
      final spots =
          await _db
              .collection('makan_spots')
              .where('addedBy', isEqualTo: uid)
              .get();
      for (final doc in spots.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Could not delete makan spots: $e');
    }
  }

  Future<void> _deleteProfileAndHandle(String uid) async {
    try {
      final profile = await _db.collection('users').doc(uid).get();
      final handle = profile.data()?['username'] as String?;
      if (handle != null && handle.isNotEmpty) {
        // Release the username so it becomes available again.
        await _db.collection('usernames').doc(handle).delete();
      }
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('Could not delete profile: $e');
    }
  }

  Future<void> _deleteProfileImage(String uid) async {
    try {
      final dir = _storage.ref().child('profile_images/$uid');
      final listing = await dir.listAll();
      for (final f in listing.items) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('Could not delete profile image: $e');
    }
  }

  /// Firestore does not cascade, so subcollections go one batch at a time.
  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    while (true) {
      final page = await ref.limit(300).get();
      if (page.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in page.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (page.docs.length < 300) return;
    }
  }
}

/// Firebase will not delete a credential that has not signed in recently.
class ReauthRequired implements Exception {
  const ReauthRequired();
  @override
  String toString() => 'Please sign in again to confirm.';
}

class AccountDeletionFailure implements Exception {
  final String message;
  const AccountDeletionFailure(this.message);
  @override
  String toString() => message;
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(),
);
