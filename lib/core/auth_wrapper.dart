import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/services/auth_service.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/fund_loan_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/match_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/config/app_theme.dart';
import '../screens/login_screen.dart';
import '../screens/main_navigation.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  /// Every Firestore rule in this app requires `isSignedIn()`. The moment the
  /// auth token changes, listeners opened under the old token terminate with
  /// `permission-denied` — and because none of our StreamProviders are
  /// autoDispose, Riverpod caches that terminal error for the life of the app.
  /// Signing back in would keep showing the stale error (or silently empty
  /// data, wherever `.valueOrNull ?? []` swallows it) until a full restart.
  ///
  /// Every data StreamProvider is built from `ref.watch(<x>ServiceProvider)`,
  /// so rebuilding the service providers cascades to all of them, replacing
  /// the dead listeners with fresh ones under the new token.
  void _resetDataProviders(WidgetRef ref) {
    ref.invalidate(profileServiceProvider);
    ref.invalidate(groupServiceProvider);
    ref.invalidate(paymentServiceProvider);
    ref.invalidate(expenseServiceProvider);
    ref.invalidate(debtServiceProvider);
    ref.invalidate(fundLoanServiceProvider);
    ref.invalidate(matchServiceProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reset cached Firestore streams whenever the signed-in identity changes
    // (sign-in, sign-out, or switching accounts).
    ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      if (prev?.valueOrNull?.uid == next.valueOrNull?.uid) return;
      _resetDataProviders(ref);
    });

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
          child:
              effectiveUser != null
                  ? const MainNavigation()
                  : const LoginScreen(),
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
