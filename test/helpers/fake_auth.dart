import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/auth_service.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockAuthService extends Mock implements AuthService {}

class MockUser extends Mock implements User {}

// ── Factory ───────────────────────────────────────────────────────────────────

/// Creates an [AuthController] backed by a [MockAuthService].
///
/// [signInCompleter]: if provided, signIn waits on it — useful for testing
/// loading state. Complete it with `AuthResponse(user: null, error: ...)`.
///
/// [forgotPasswordSucceeds]: controls whether sendPasswordResetEmail returns
/// a response with no error.
/// [signedInUid]: when given, currentUser reports a user with that uid, for
/// screens that vary by who is looking at them.
AuthController fakeAuthController({
  Completer<AuthResponse>? signInCompleter,
  bool forgotPasswordSucceeds = true,
  String? signedInUid,
}) {
  final svc = MockAuthService();

  // Auth stream — emits null (unauthenticated) and stays open
  final streamController = StreamController<User?>();
  when(() => svc.authStateChanges).thenAnswer((_) => streamController.stream);

  if (signedInUid == null) {
    when(() => svc.currentUser).thenReturn(null);
  } else {
    final user = MockUser();
    when(() => user.uid).thenReturn(signedInUid);
    when(() => svc.currentUser).thenReturn(user);
  }

  // signIn
  if (signInCompleter != null) {
    when(
      () => svc.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => signInCompleter.future);
  } else {
    when(
      () => svc.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => AuthResponse(user: null, error: AuthError.invalidCredential),
    );
  }

  // signUp — always returns failure (no real User in tests)
  when(
    () => svc.signUpWithEmailAndPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
      name: any(named: 'name'),
      phoneNumber: any(named: 'phoneNumber'),
    ),
  ).thenAnswer(
    (_) async => AuthResponse(user: null, error: AuthError.invalidCredential),
  );

  // forgotPassword
  when(() => svc.sendPasswordResetEmail(email: any(named: 'email'))).thenAnswer(
    (_) async =>
        forgotPasswordSucceeds
            ? AuthResponse(user: null) // no error → success
            : AuthResponse(user: null, error: AuthError.userNotFound),
  );

  return AuthController(svc);
}

// ── Widget wrapper ────────────────────────────────────────────────────────────

/// Wraps [child] in a [ProviderScope] + [MaterialApp] suitable for tests.
/// Disables Google Fonts network fetching to avoid flake.
Widget testApp(
  Widget child, {
  AuthController? controller,
  List<Override> extraOverrides = const [],
}) {
  GoogleFonts.config.allowRuntimeFetching = false;
  final ctrl = controller ?? fakeAuthController();
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => ctrl),
      ...extraOverrides,
    ],
    child: MaterialApp(home: child),
  );
}
