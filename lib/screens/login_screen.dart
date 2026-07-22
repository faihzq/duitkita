import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/screens/signup_screen.dart';
import 'package:duitkita/screens/forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    bool isValid = true;
    if (!isValidEmail(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      isValid = false;
    } else {
      setState(() => _emailError = null);
    }
    if (!isValidPassword(_passwordController.text)) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      isValid = false;
    } else {
      setState(() => _passwordError = null);
    }
    return isValid;
  }

  Future<void> _login() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final response = await ref.read(authControllerProvider.notifier).signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!response.isSuccess) {
      messenger.showSnackBar(SnackBar(
        content: Text(
          response.errorMessage ?? getAuthErrorMessage(response.error),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        backgroundColor: DT.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          // ── Branding header ─────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [DT.headerGradientStart, DT.headerGradientEnd],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/icon/play_store_512.png',
                        width: 68, height: 68,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('DuitKita', style: GoogleFonts.manrope(
                      fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white,
                      letterSpacing: -0.5,
                    )),
                    const SizedBox(height: 6),
                    Text('Manage money together', style: GoogleFonts.manrope(
                      fontSize: 14, color: Colors.white.withValues(alpha: 0.6),
                    )),
                  ],
                ),
              ),
            ),
          ),

          // ── Form card ────────────────────────────────────────────
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: DT.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.xxl, DS.screenPad, DS.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sign in', style: GoogleFonts.manrope(
                      fontSize: 22, fontWeight: FontWeight.w800, color: DT.text,
                    )),
                    const SizedBox(height: 6),
                    Text('Welcome back — enter your details below', style: GoogleFonts.manrope(
                      fontSize: 14, color: DT.textSecondary,
                    )),
                    const SizedBox(height: DS.xxl),

                    // Email
                    _AuthField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                      error: _emailError,
                      onChanged: (_) { if (_emailError != null) setState(() => _emailError = null); },
                    ),
                    const SizedBox(height: DS.md),

                    // Password
                    _AuthField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: '••••••••',
                      obscureText: !_isPasswordVisible,
                      prefixIcon: Icons.lock_outline_rounded,
                      error: _passwordError,
                      onChanged: (_) { if (_passwordError != null) setState(() => _passwordError = null); },
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: DT.textTertiary, size: 20,
                        ),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: DT.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: DS.sm),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Forgot password?', style: GoogleFonts.manrope(
                          fontSize: 13, fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                    const SizedBox(height: DS.lg),

                    // Sign in button
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DT.text,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: DT.border,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text('Sign in', style: GoogleFonts.manrope(
                                fontSize: 16, fontWeight: FontWeight.w700,
                              )),
                      ),
                    ),
                    const SizedBox(height: DS.xl),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?", style: GoogleFonts.manrope(
                          fontSize: 14, color: DT.textSecondary,
                        )),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignupScreen()),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: DT.text,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Sign up', style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700,
                          )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared auth field ────────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final IconData prefixIcon;
  final String? error;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.error,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(
          fontSize: 13, fontWeight: FontWeight.w600, color: DT.text,
        )),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          style: GoogleFonts.manrope(fontSize: 15, color: DT.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(fontSize: 14, color: DT.textTertiary),
            prefixIcon: Icon(prefixIcon, size: 18, color: DT.textTertiary),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: error != null ? DT.dangerSoft : DT.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: DS.lg, vertical: DS.lg),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius),
              borderSide: BorderSide(color: error != null ? DT.danger : DT.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius),
              borderSide: BorderSide(color: error != null ? DT.danger : DT.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius),
              borderSide: BorderSide(color: error != null ? DT.danger : DT.text, width: 1.5),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 13, color: DT.danger),
              const SizedBox(width: 4),
              Text(error!, style: GoogleFonts.manrope(
                fontSize: 12, color: DT.danger, fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ],
      ],
    );
  }
}
