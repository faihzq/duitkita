import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duitkita/firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/core/auth_wrapper.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/widgets/dk_toast.dart';
import 'package:duitkita/services/notification_service.dart';
import 'package:duitkita/features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Block until Firebase Auth has restored the persisted session from local
  // storage. This guarantees that FirebaseAuth.instance.currentUser is correct
  // before the UI renders, eliminating the race condition that causes the app
  // to redirect to LoginScreen on cold start even when a valid session exists.
  await FirebaseAuth.instance.authStateChanges().first;

  await NotificationService.init();

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_seen') ?? false);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(ProviderScope(child: MyApp(showOnboarding: showOnboarding)));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;

  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuitKita',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // Lets DkToast reach the root overlay when the calling screen has already
      // been popped — the case the old `final messenger = ...` captures existed
      // to handle.
      navigatorKey: DkToast.navigatorKey,
      home: showOnboarding ? const _OnboardingEntry() : const AuthWrapper(),
    );
  }
}

class _OnboardingEntry extends StatelessWidget {
  const _OnboardingEntry();

  Future<void> _markSeen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(onDone: () => _markSeen(context));
  }
}
