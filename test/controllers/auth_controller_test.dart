import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/auth_service.dart';

import '../helpers/fake_auth.dart';

void main() {
  // ── signIn ────────────────────────────────────────────────────────────────

  group('AuthController.signIn', () {
    test('transitions to loading then error on failure', () async {
      final ctrl = fakeAuthController();
      final states = <AuthState>[];
      ctrl.addListener(states.add, fireImmediately: false);

      await ctrl.signIn(email: 'u@e.com', password: 'pass123');

      expect(states, [AuthState.loading, AuthState.error]);
    });

    test('returns response with error on failure', () async {
      final ctrl = fakeAuthController();
      final res = await ctrl.signIn(email: 'u@e.com', password: 'pass123');
      expect(res.isSuccess, isFalse);
      expect(res.error, AuthError.invalidCredential);
    });

    test('sets loading state while awaiting', () async {
      final completer = Completer<AuthResponse>();
      final ctrl = fakeAuthController(signInCompleter: completer);

      final future = ctrl.signIn(email: 'u@e.com', password: 'pass123');
      expect(ctrl.state, AuthState.loading);

      completer.complete(
          AuthResponse(user: null, error: AuthError.invalidCredential));
      await future;
    });

    test('state becomes error after sign-in failure', () async {
      final ctrl = fakeAuthController();
      await ctrl.signIn(email: 'u@e.com', password: 'pass123');
      expect(ctrl.state, AuthState.error);
    });
  });

  // ── signUp ────────────────────────────────────────────────────────────────

  group('AuthController.signUp', () {
    test('transitions to loading then error on failure', () async {
      final ctrl = fakeAuthController();
      final states = <AuthState>[];
      ctrl.addListener(states.add, fireImmediately: false);

      await ctrl.signUp(
          email: 'u@e.com', password: 'pass123',
          name: 'Ali', phoneNumber: '0123456789');

      expect(states, [AuthState.loading, AuthState.error]);
    });

    test('returns error response when sign-up fails', () async {
      final ctrl = fakeAuthController();
      final res = await ctrl.signUp(
          email: 'u@e.com', password: 'pass123');
      expect(res.isSuccess, isFalse);
    });
  });

  // ── signOut ───────────────────────────────────────────────────────────────

  group('AuthController.signOut', () {
    test('sets state to unauthenticated', () async {
      final svc = MockAuthService();
      final sc = StreamController<User?>();
      when(() => svc.authStateChanges).thenAnswer((_) => sc.stream);
      when(() => svc.currentUser).thenReturn(null);
      when(() => svc.signOut()).thenAnswer((_) async {});

      final ctrl = AuthController(svc);
      await ctrl.signOut();

      expect(ctrl.state, AuthState.unauthenticated);
    });
  });

  // ── forgotPassword ────────────────────────────────────────────────────────

  group('AuthController.forgotPassword', () {
    test('returns success response when service succeeds', () async {
      final ctrl = fakeAuthController(forgotPasswordSucceeds: true);
      final res = await ctrl.forgotPassword(email: 'u@e.com');
      expect(res.error, isNull);
    });

    test('returns error response when service fails', () async {
      final ctrl = fakeAuthController(forgotPasswordSucceeds: false);
      final res = await ctrl.forgotPassword(email: 'u@e.com');
      expect(res.error, AuthError.userNotFound);
    });

    test('state is unauthenticated after forgotPassword completes', () async {
      final ctrl = fakeAuthController(forgotPasswordSucceeds: true);
      await ctrl.forgotPassword(email: 'u@e.com');
      expect(ctrl.state, AuthState.unauthenticated);
    });

    test('transitions through loading during forgotPassword', () async {
      final ctrl = fakeAuthController(forgotPasswordSucceeds: true);
      final states = <AuthState>[];
      ctrl.addListener(states.add, fireImmediately: false);

      await ctrl.forgotPassword(email: 'u@e.com');

      expect(states.first, AuthState.loading);
      expect(states.last, AuthState.unauthenticated);
    });
  });

  // ── auth stream listener ──────────────────────────────────────────────────

  group('AuthController auth stream', () {
    test('sets unauthenticated when stream emits null', () async {
      final svc = MockAuthService();
      final sc = StreamController<User?>.broadcast();
      when(() => svc.authStateChanges).thenAnswer((_) => sc.stream);
      when(() => svc.currentUser).thenReturn(null);

      final ctrl = AuthController(svc);
      sc.add(null);
      await Future.microtask(() {});

      expect(ctrl.state, AuthState.unauthenticated);
    });

    test('does not override loading state when stream fires', () async {
      final completer = Completer<AuthResponse>();
      final ctrl = fakeAuthController(signInCompleter: completer);

      final future = ctrl.signIn(email: 'u@e.com', password: 'p123456');
      expect(ctrl.state, AuthState.loading);

      // auth stream emits null while loading — should be ignored
      await Future.microtask(() {});
      expect(ctrl.state, AuthState.loading);

      completer.complete(
          AuthResponse(user: null, error: AuthError.invalidCredential));
      await future;
    });
  });
}
