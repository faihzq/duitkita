import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/services/auth_service.dart';

// Authentication state
enum AuthState { initial, loading, authenticated, unauthenticated, error }

// Authentication state notifier
class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService) : super(AuthState.initial) {
    // Check initial auth state
    if (_authService.currentUser != null) {
      state = AuthState.authenticated;
    } else {
      state = AuthState.unauthenticated;
    }
  }

  // Get current user
  User? get currentUser => _authService.currentUser;

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    state = AuthState.loading;

    final response = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    state = response.isSuccess ? AuthState.authenticated : AuthState.error;

    return response;
  }

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    state = AuthState.loading;

    final response = await _authService.signUpWithEmailAndPassword(
      email: email,
      password: password,
    );

    state = response.isSuccess ? AuthState.authenticated : AuthState.error;

    return response;
  }

  // Sign out
  Future<void> signOut() async {
    state = AuthState.loading;
    await _authService.signOut();
    state = AuthState.unauthenticated;
  }

  // Forgot password
  Future<AuthResponse> forgotPassword({required String email}) async {
    state = AuthState.loading;

    final response = await _authService.sendPasswordResetEmail(email: email);

    state = AuthState.unauthenticated;

    return response;
  }
}

// Auth controller provider
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final authService = ref.watch(authServiceProvider);
    return AuthController(authService);
  },
);
