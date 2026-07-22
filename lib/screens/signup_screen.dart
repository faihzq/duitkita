import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/utils/utils.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    bool isValid = true;

    if (_nameController.text.trim().length < 2) {
      setState(() => _nameError = _nameController.text.trim().isEmpty
          ? 'Full name is required'
          : 'Name must be at least 2 characters');
      isValid = false;
    } else {
      setState(() => _nameError = null);
    }

    if (!isValidEmail(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      isValid = false;
    } else {
      setState(() => _emailError = null);
    }

    if (_phoneController.text.trim().length < 10) {
      setState(() => _phoneError = _phoneController.text.trim().isEmpty
          ? 'Phone number is required'
          : 'Please enter a valid phone number');
      isValid = false;
    } else {
      setState(() => _phoneError = null);
    }

    if (!isValidPassword(_passwordController.text)) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      isValid = false;
    } else {
      setState(() => _passwordError = null);
    }

    if (_confirmPasswordController.text != _passwordController.text) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      isValid = false;
    } else {
      setState(() => _confirmPasswordError = null);
    }

    return isValid;
  }

  Future<void> _signup() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final response = await ref.read(authControllerProvider.notifier).signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
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
    } else {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          // ── Compact nav header ──────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [DT.headerGradientStart, DT.headerGradientEnd],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DS.sm, DS.sm, DS.screenPad, DS.xl),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: DS.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create account', style: GoogleFonts.manrope(
                          fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
                        )),
                        Text('Join DuitKita today', style: GoogleFonts.manrope(
                          fontSize: 13, color: Colors.white.withValues(alpha: 0.6),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form ───────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: DT.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.xxl, DS.screenPad, DS.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Personal info section ──────────────────
                    _SectionLabel(label: 'Personal info'),
                    const SizedBox(height: DS.md),

                    _SignupField(
                      controller: _nameController,
                      label: 'Full name',
                      hint: 'Ahmad bin Ali',
                      prefixIcon: Icons.person_outline_rounded,
                      error: _nameError,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) { if (_nameError != null) setState(() => _nameError = null); },
                    ),
                    const SizedBox(height: DS.md),

                    _SignupField(
                      controller: _emailController,
                      label: 'Email address',
                      hint: 'you@example.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      error: _emailError,
                      onChanged: (_) { if (_emailError != null) setState(() => _emailError = null); },
                    ),
                    const SizedBox(height: DS.md),

                    _SignupField(
                      controller: _phoneController,
                      label: 'Phone number',
                      hint: '01X-XXXXXXXX',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      error: _phoneError,
                      onChanged: (_) { if (_phoneError != null) setState(() => _phoneError = null); },
                    ),
                    const SizedBox(height: DS.xl),

                    // ── Security section ───────────────────────
                    _SectionLabel(label: 'Security'),
                    const SizedBox(height: DS.md),

                    _SignupField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'At least 6 characters',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: !_isPasswordVisible,
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
                    const SizedBox(height: DS.md),

                    _SignupField(
                      controller: _confirmPasswordController,
                      label: 'Confirm password',
                      hint: 'Re-enter your password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: !_isConfirmPasswordVisible,
                      error: _confirmPasswordError,
                      onChanged: (_) { if (_confirmPasswordError != null) setState(() => _confirmPasswordError = null); },
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: DT.textTertiary, size: 20,
                        ),
                        onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                      ),
                    ),
                    const SizedBox(height: DS.xxl),

                    // ── Create account button ──────────────────
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DT.text,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: DT.border,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DS.cardRadius),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text('Create account', style: GoogleFonts.manrope(
                                fontSize: 16, fontWeight: FontWeight.w700,
                              )),
                      ),
                    ),
                    const SizedBox(height: DS.lg),

                    // ── Sign in link ───────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?', style: GoogleFonts.manrope(
                          fontSize: 14, color: DT.textSecondary,
                        )),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: DT.text,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Sign in', style: GoogleFonts.manrope(
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

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: DT.textTertiary, letterSpacing: 0.8,
        )),
        const SizedBox(width: DS.sm),
        const Expanded(child: Divider(color: DT.border, height: 1)),
      ],
    );
  }
}

// ─── Signup field ─────────────────────────────────────────────────────────────

class _SignupField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final String? error;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const _SignupField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.error,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
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
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          onChanged: onChanged,
          style: GoogleFonts.manrope(fontSize: 15, color: DT.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(fontSize: 14, color: DT.textTertiary),
            prefixIcon: Icon(prefixIcon, size: 18, color: DT.textTertiary),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: hasError ? DT.dangerSoft : DT.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DS.lg, vertical: DS.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius),
              borderSide: BorderSide(color: hasError ? DT.danger : DT.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius),
              borderSide: BorderSide(color: hasError ? DT.danger : DT.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius),
              borderSide: BorderSide(
                color: hasError ? DT.danger : DT.text, width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError) ...[
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
