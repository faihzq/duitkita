import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/screens/signup_screen.dart';
import 'package:duitkita/screens/forgot_password_screen.dart';
import 'package:duitkita/screens/auth_widgets.dart';
import 'package:duitkita/widgets/floating_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    bool ok = true;
    if (!isValidEmail(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      ok = false;
    } else {
      setState(() => _emailError = null);
    }
    if (!isValidPassword(_passwordController.text)) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      ok = false;
    } else {
      setState(() => _passwordError = null);
    }
    return ok;
  }

  Future<void> _login() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);
    final response = await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!response.isSuccess) {
      showSnackBar(
        context,
        response.errorMessage ?? getAuthErrorMessage(response.error),
        isError: true,
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    final response =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    // Dismissing the account picker isn't an error — stay quiet.
    if (!response.isSuccess && !response.cancelled) {
      showSnackBar(
        context,
        response.errorMessage ?? getAuthErrorMessage(response.error),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          const AuthHero(
            title: 'Welcome back',
            subtitle:
                'Sign in to track payments, settle groups, and stay on top of your monthly commitments.',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                DS.screenPad,
                DS.xxl,
                DS.screenPad,
                DS.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FloatingField(
                    controller: _emailController,
                    gap: 0,
                    label: 'Email',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    error: _emailError,
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                  ),
                  const SizedBox(height: DS.md),
                  FloatingField(
                    controller: _passwordController,
                    gap: 0,
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    error: _passwordError,
                    onChanged: (_) {
                      if (_passwordError != null) {
                        setState(() => _passwordError = null);
                      }
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                      style: TextButton.styleFrom(
                        foregroundColor: DT.text,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: DS.sm,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DS.md),
                  PrimaryButton(
                    label: 'Sign in',
                    loading: _isLoading,
                    enabled: !_isGoogleLoading,
                    onPressed: _login,
                  ),
                  const SizedBox(height: DS.lg),
                  const AuthDivider(),
                  const SizedBox(height: DS.lg),
                  GoogleButton(
                    loading: _isGoogleLoading,
                    enabled: !_isLoading,
                    onPressed: _loginWithGoogle,
                  ),
                  const SizedBox(height: DS.xl),
                  const TrustCard(),
                  const SizedBox(height: DS.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New to DuitKita?',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: DT.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            ),
                        style: TextButton.styleFrom(
                          foregroundColor: DT.text,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Create account',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
