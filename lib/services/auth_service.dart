import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:duitkita/models/user_profile.dart';
import 'package:duitkita/services/notification_service.dart';
import 'package:duitkita/services/profile_service.dart';

// Authentication service errors
enum AuthError {
  invalidEmail,
  userDisabled,
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  invalidCredential,
  operationNotAllowed,
  weakPassword,
  undefined,
}

// Authentication service response
class AuthResponse {
  final User? user;
  final AuthError? error;
  final String? errorMessage;

  /// True when the user backed out of a provider flow (e.g. dismissed the
  /// Google account picker). Not a failure — callers should stay silent.
  final bool cancelled;

  AuthResponse({
    this.user,
    this.error,
    this.errorMessage,
    this.cancelled = false,
  });

  bool get isSuccess => user != null && error == null;
}

// Authentication service
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get error from firebase exception
  AuthError _getAuthError(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-email':
        return AuthError.invalidEmail;
      case 'user-disabled':
        return AuthError.userDisabled;
      case 'user-not-found':
        return AuthError.userNotFound;
      case 'wrong-password':
        return AuthError.wrongPassword;
      case 'email-already-in-use':
        return AuthError.emailAlreadyInUse;
      case 'invalid-credential':
        return AuthError.invalidCredential;
      case 'operation-not-allowed':
        return AuthError.operationNotAllowed;
      case 'weak-password':
        return AuthError.weakPassword;
      default:
        return AuthError.undefined;
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResponse(user: userCredential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(error: _getAuthError(e), errorMessage: e.message);
    } catch (e) {
      return AuthResponse(
        error: AuthError.undefined,
        errorMessage: e.toString(),
      );
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? name,
    String? phoneNumber,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // If we have a user, create a profile.
      //
      // Deliberately NOT awaited. A Firestore write settles only once the
      // server acknowledges it, and the client sits in backoff for a while
      // after an auth change — every listener opened under the old token has
      // just failed with permission-denied. Signing out and immediately
      // signing up reliably lands in that window, and awaiting here left the
      // sign-up button spinning forever on an account that already existed.
      //
      // The write is durable regardless: Firestore persists it locally and
      // retries until it lands, so the profile appears as soon as the client
      // recovers. ProfileService.ensureProfile covers the case where the app
      // dies first.
      if (userCredential.user != null) {
        final profileService = ProfileService();
        final userProfile = UserProfile(
          uid: userCredential.user!.uid,
          name: name,
          email: email, // Store email in profile
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        unawaited(
          profileService.createUserProfile(userProfile).catchError((Object e) {
            debugPrint('Signed up but could not write the profile: $e');
          }),
        );
      }
      return AuthResponse(user: userCredential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(error: _getAuthError(e), errorMessage: e.message);
    } catch (e) {
      return AuthResponse(
        error: AuthError.undefined,
        errorMessage: e.toString(),
      );
    }
  }

  // ─── Google sign-in ─────────────────────────────────────────────────────────

  /// Web OAuth client ID. Android needs this to return an ID token in some
  /// project configurations; when null the plugin falls back to the value in
  /// google-services.json / GoogleService-Info.plist. If sign-in succeeds but
  /// [GoogleSignInAuthentication.idToken] comes back null, set this to the
  /// "Web client" ID from Firebase Console → Project settings → Your apps.
  static const String? _googleServerClientId = null;

  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
    _googleInitialized = true;
  }

  /// Signs in with Google and exchanges the ID token for a Firebase session.
  /// On first sign-in a user profile document is created from the Google
  /// account; existing profiles are left untouched so local edits survive.
  Future<AuthResponse> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return AuthResponse(
          error: AuthError.operationNotAllowed,
          errorMessage: 'Google sign-in is not supported on this platform.',
        );
      }

      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();
      final String? idToken = account.authentication.idToken;

      if (idToken == null) {
        return AuthResponse(
          error: AuthError.invalidCredential,
          errorMessage:
              'Google did not return an ID token. Check that the OAuth web '
              'client ID is configured for this project.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        // Not awaited, for the same reason as signUpWithEmailAndPassword: a
        // first-time Google sign-in would otherwise block the UI on a Firestore
        // read *and* a write while the client is still in backoff from the auth
        // change.
        unawaited(
          _bootstrapGoogleProfile(user, account).catchError((Object e) {
            debugPrint('Signed in but could not write the profile: $e');
          }),
        );
      }

      return AuthResponse(user: user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return AuthResponse(cancelled: true);
      }
      return AuthResponse(
        error: AuthError.undefined,
        errorMessage:
            e.description ?? 'Google sign-in failed (${e.code.name}).',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResponse(error: _getAuthError(e), errorMessage: e.message);
    } catch (e) {
      return AuthResponse(
        error: AuthError.undefined,
        errorMessage: e.toString(),
      );
    }
  }

  /// Creates the profile document for a first-time Google account.
  ///
  /// Runs in the background; the caller must not wait on it.
  Future<void> _bootstrapGoogleProfile(
    User user,
    GoogleSignInAccount account,
  ) async {
    final profileService = ProfileService();
    if (await profileService.getUserProfile(user.uid) != null) return;
    await profileService.createUserProfile(
      UserProfile(
        uid: user.uid,
        name: user.displayName ?? account.displayName,
        email: user.email ?? account.email,
        profileImageUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  // Sign out
  Future<void> signOut() async {
    // Detach this device first, while the credential still satisfies the
    // users/{uid} rule. Afterwards the write would be denied and this account
    // would keep receiving notifications on a device it no longer owns.
    await NotificationService.clearFcmToken();

    // Also clear the Google session so the account picker reappears next time.
    // Best-effort: fails harmlessly if Google sign-in was never initialized.
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      /* not signed in with Google, or plugin unavailable */
    }
    await _firebaseAuth.signOut();
  }

  // Send password reset email
  Future<AuthResponse> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return AuthResponse(error: null, errorMessage: null);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(error: _getAuthError(e), errorMessage: e.message);
    } catch (e) {
      return AuthResponse(
        error: AuthError.undefined,
        errorMessage: e.toString(),
      );
    }
  }
}

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});
