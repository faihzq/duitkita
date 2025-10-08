import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/user_profile.dart';
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

  AuthResponse({this.user, this.error, this.errorMessage});

  bool get isSuccess => user != null && error == null;
  // bool get isSuccess => error == null;
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
      // If we have a user, create a profile
      if (userCredential.user != null) {
        final profileService = ProfileService();
        final userProfile = UserProfile(
          uid: userCredential.user!.uid,
          name: name,
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await profileService.createUserProfile(userProfile);
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

  // Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Send password reset email
  Future<AuthResponse> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return AuthResponse(error: null, errorMessage: null);
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return AuthResponse(error: _getAuthError(e), errorMessage: e.message);
    } catch (e) {
      print('Unexpected error: $e');
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
