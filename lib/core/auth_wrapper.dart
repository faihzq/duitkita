import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/services/auth_service.dart';
import 'package:duitkita/config/app_theme.dart';
import '../screens/login_screen.dart';
import '../screens/main_navigation.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStream = ref.watch(authStateProvider);

    return authStream.when(
      data: (user) {
        // Cross-check with currentUser to guard against the stream-before-restore
        // race: authStateChanges() can briefly emit null on cold start before the
        // cached session is fully restored. currentUser is the authoritative sync
        // source — it's already settled by the time we reach this point because
        // main() awaited authStateChanges().first before calling runApp().
        // When the user explicitly signs out, both are null simultaneously.
        final effectiveUser = user ?? FirebaseAuth.instance.currentUser;
        return KeyedSubtree(
          key: ValueKey(effectiveUser?.uid ?? 'logged_out'),
          child: effectiveUser != null ? const MainNavigation() : const LoginScreen(),
        );
      },
      loading: () {
        // While stream connects, trust Firebase's cached session
        // This is how Shopee/WhatsApp/Telegram stay logged in instantly
        final cachedUser = FirebaseAuth.instance.currentUser;
        if (cachedUser != null) {
          return KeyedSubtree(
            key: ValueKey(cachedUser.uid),
            child: const MainNavigation(),
          );
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );
      },
      error: (_, __) {
        // On error, still check cached session before showing login
        final cachedUser = FirebaseAuth.instance.currentUser;
        if (cachedUser != null) {
          return KeyedSubtree(
            key: ValueKey(cachedUser.uid),
            child: const MainNavigation(),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
