import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/services/auth_service.dart';
import 'package:duitkita/config/app_theme.dart';
import '../screens/login_screen.dart';
import '../screens/main_navigation.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the Firebase auth stream directly for reliable session tracking
    final authStream = ref.watch(authStateProvider);

    return authStream.when(
      data: (user) {
        return KeyedSubtree(
          key: ValueKey(user?.uid ?? 'logged_out'),
          child: user != null ? const MainNavigation() : const LoginScreen(),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      ),
      error: (_, __) => const LoginScreen(),
    );
  }
}
