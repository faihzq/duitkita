import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/screens/auth_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  int _step = 1; // 1 = about you · 2 = security (KYC handled elsewhere = step 3)

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  bool _agreed = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Password strength 0–4
  int get _strength {
    final p = _passwordController.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  bool _validateStep1() {
    bool ok = true;
    if (_nameController.text.trim().length < 2) {
      setState(() => _nameError = _nameController.text.trim().isEmpty
          ? 'Full name is required'
          : 'Name must be at least 2 characters');
      ok = false;
    } else {
      setState(() => _nameError = null);
    }
    if (!isValidEmail(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      ok = false;
    } else {
      setState(() => _emailError = null);
    }
    if (_phoneController.text.trim().length < 9) {
      setState(() => _phoneError = _phoneController.text.trim().isEmpty
          ? 'Phone number is required'
          : 'Please enter a valid phone number');
      ok = false;
    } else {
      setState(() => _phoneError = null);
    }
    return ok;
  }

  bool _validateStep2() {
    bool ok = true;
    if (!isValidPassword(_passwordController.text) || _strength < 2) {
      setState(() => _passwordError = 'Choose a stronger password (min 8 chars)');
      ok = false;
    } else {
      setState(() => _passwordError = null);
    }
    return ok;
  }

  void _continue() {
    if (_validateStep1()) setState(() => _step = 2);
  }

  Future<void> _signupWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final response =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (response.isSuccess) {
      nav.pop(); // AuthWrapper routes to home
    } else if (!response.cancelled) {
      // Dismissing the account picker isn't an error — stay quiet.
      messenger.showSnackBar(errorSnack(
        response.errorMessage ?? getAuthErrorMessage(response.error),
      ));
    }
  }

  Future<void> _signup() async {
    if (!_validateStep2()) return;
    if (!_agreed) return;
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final response = await ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          phoneNumber: '+60${_phoneController.text.trim()}',
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!response.isSuccess) {
      messenger.showSnackBar(errorSnack(
        response.errorMessage ?? getAuthErrorMessage(response.error),
      ));
    } else {
      nav.pop(); // AuthWrapper routes to KYC / home
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _step == 1 ? true : _agreed;
    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          AuthHero(
            title: _step == 1 ? "Let's get you set up" : 'Almost there',
            subtitle: _step == 1
                ? "Takes 30 seconds. You'll need an email and a Malaysian phone number."
                : "Pick a strong password. We'll verify your identity right after.",
            leading: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              onPressed: () => _step == 2
                  ? setState(() => _step = 1)
                  : Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.xl, DS.screenPad, DS.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stepper
                  Row(
                    children: List.generate(3, (i) {
                      final on = (i + 1) <= _step;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: on ? DT.accent : DT.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: DS.md),
                  Text(
                    'STEP $_step OF 3 · ${_step == 1 ? 'ABOUT YOU' : 'SECURITY'}',
                    style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: DT.textSecondary, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: DS.lg),

                  if (_step == 1) ..._step1() else ..._step2(),

                  const SizedBox(height: DS.lg),
                  PrimaryButton(
                    label: _step == 1 ? 'Continue' : 'Create account',
                    loading: _isLoading,
                    enabled: canSubmit && !_isGoogleLoading,
                    onPressed: _step == 1 ? _continue : _signup,
                  ),

                  // Google is an alternative to the whole form, so it only
                  // belongs on step 1 — by step 2 they're choosing a password.
                  if (_step == 1) ...[
                    const SizedBox(height: DS.lg),
                    const AuthDivider(),
                    const SizedBox(height: DS.lg),
                    GoogleButton(
                      label: 'Sign up with Google',
                      loading: _isGoogleLoading,
                      enabled: !_isLoading,
                      onPressed: _signupWithGoogle,
                    ),
                  ],
                  const SizedBox(height: DS.lg),

                  if (_step == 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?', style: GoogleFonts.manrope(
                          fontSize: 14, color: DT.textSecondary)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: DT.text,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Sign in', style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w800)),
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

  List<Widget> _step1() => [
        FloatingField(
          controller: _nameController,
          label: 'Full name',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          helper: 'As shown on your IC / passport',
          error: _nameError,
          onChanged: (_) { if (_nameError != null) setState(() => _nameError = null); },
        ),
        const SizedBox(height: DS.md),
        FloatingField(
          controller: _emailController,
          label: 'Email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          error: _emailError,
          onChanged: (_) { if (_emailError != null) setState(() => _emailError = null); },
        ),
        const SizedBox(height: DS.md),
        FloatingField(
          controller: _phoneController,
          label: 'Mobile number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          error: _phoneError,
          leadingOverride: Text('🇲🇾 +60', style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
          onChanged: (_) { if (_phoneError != null) setState(() => _phoneError = null); },
        ),
      ];

  List<Widget> _step2() {
    final p = _passwordController.text;
    const labels = ['Too short', 'Weak', 'Okay', 'Good', 'Strong'];
    const colors = [DT.textTertiary, DT.danger, DT.warning, DT.accent, DT.success];
    final reqs = [
      ('At least 8 characters', p.length >= 8),
      ('One uppercase letter', RegExp(r'[A-Z]').hasMatch(p)),
      ('One number', RegExp(r'[0-9]').hasMatch(p)),
      ('One symbol (recommended)', RegExp(r'[^A-Za-z0-9]').hasMatch(p)),
    ];
    return [
      FloatingField(
        controller: _passwordController,
        label: 'Password',
        prefixIcon: Icons.lock_outline_rounded,
        isPassword: true,
        error: _passwordError,
        onChanged: (_) => setState(() {
          if (_passwordError != null) _passwordError = null;
        }),
      ),
      if (p.isNotEmpty) ...[
        const SizedBox(height: DS.md),
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i < _strength ? colors[_strength] : DT.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(labels[_strength], style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700, color: colors[_strength])),
      ],
      const SizedBox(height: DS.lg),
      // Requirements checklist
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PASSWORD MUST HAVE', style: GoogleFonts.manrope(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: DT.textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            ...reqs.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: r.$2 ? DT.successSoft : DT.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: r.$2
                            ? const Icon(Icons.check, size: 10, color: DT.success)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(r.$1, style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: r.$2 ? FontWeight.w600 : FontWeight.w500,
                        color: r.$2 ? DT.text : DT.textSecondary)),
                    ],
                  ),
                )),
          ],
        ),
      ),
      const SizedBox(height: DS.lg),
      // Terms agreement
      GestureDetector(
        onTap: () => setState(() => _agreed = !_agreed),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _agreed ? DT.accent : DT.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20, height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: _agreed ? DT.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: _agreed ? null : Border.all(color: DT.borderStrong, width: 1.5),
                ),
                child: _agreed
                    ? const Icon(Icons.check, size: 12, color: DT.primary)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.manrope(fontSize: 12, height: 1.45, color: DT.text),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(text: 'Terms of Service', style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                      const TextSpan(text: ' and '),
                      TextSpan(text: 'Privacy Policy', style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
