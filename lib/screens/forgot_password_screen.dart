import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/screens/auth_widgets.dart';
import 'package:duitkita/widgets/floating_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  String? _emailError;
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    if (!isValidEmail(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      return false;
    }
    setState(() => _emailError = null);
    return true;
  }

  Future<void> _resetPassword() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final response = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(email: _emailController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.error != null) {
      messenger.showSnackBar(errorSnack(
        response.errorMessage ?? getAuthErrorMessage(response.error),
      ));
    } else {
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          AuthHero(
            title: _emailSent ? 'Check your inbox' : 'Reset password',
            subtitle: _emailSent
                ? 'Follow the link we just emailed to set a new password.'
                : 'Enter the email linked to your DuitKita account.',
            leading: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.xxl, DS.screenPad, DS.xl),
              child: _emailSent ? _sentView() : _formView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FloatingField(
          controller: _emailController, gap: 0,
          label: 'Email',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          error: _emailError,
          onChanged: (_) { if (_emailError != null) setState(() => _emailError = null); },
        ),
        const SizedBox(height: DS.md),
        PrimaryButton(
          label: 'Send reset link',
          loading: _isLoading,
          onPressed: _resetPassword,
        ),
        const SizedBox(height: DS.lg),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: DT.textSecondary,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded, size: 14),
                const SizedBox(width: 4),
                Text('Back to sign in', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sentView() {
    final email = _emailController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DS.sm),
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: DT.successSoft, shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_read_outlined, color: DT.success, size: 36),
          ),
        ),
        const SizedBox(height: DS.xl),
        // Confirmation card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DT.successSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_rounded, size: 20, color: DT.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email sent', style: GoogleFonts.manrope(
                      fontSize: 13, fontWeight: FontWeight.w700, color: DT.text)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.manrope(
                          fontSize: 12, height: 1.45, color: DT.textSecondary),
                        children: [
                          const TextSpan(text: 'We sent a reset link to '),
                          TextSpan(text: email, style: GoogleFonts.manrope(
                            fontSize: 12, fontWeight: FontWeight.w700, color: DT.text)),
                          const TextSpan(text: '. Check spam if it doesn\'t arrive in 1–2 minutes.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DS.xl),
        PrimaryButton(
          label: 'Back to sign in',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: DS.md),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _emailSent = false),
            style: TextButton.styleFrom(
              foregroundColor: DT.textSecondary,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Resend email', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
