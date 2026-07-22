import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/utils/utils.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

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
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Back button row ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.sm, DS.sm, DS.sm, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: DT.text),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _emailSent ? _SentView(
                email: _emailController.text.trim(),
                onResend: () {
                  setState(() => _emailSent = false);
                },
                onBack: () => Navigator.of(context).pop(),
              ) : _FormView(
                emailController: _emailController,
                emailError: _emailError,
                isLoading: _isLoading,
                onEmailChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
                onSubmit: _resetPassword,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Form view ────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final TextEditingController emailController;
  final String? emailError;
  final bool isLoading;
  final ValueChanged<String> onEmailChanged;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _FormView({
    required this.emailController,
    required this.emailError,
    required this.isLoading,
    required this.onEmailChanged,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: DS.screenPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DS.xl),

          // Icon
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [DT.headerGradientStart, DT.headerGradientEnd],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: DS.xl),

          // Heading
          Text('Reset password', style: GoogleFonts.manrope(
            fontSize: 24, fontWeight: FontWeight.w800, color: DT.text,
          ), textAlign: TextAlign.center),
          const SizedBox(height: DS.sm),
          Text(
            'Enter your email and we\'ll send you a link to get back into your account.',
            style: GoogleFonts.manrope(fontSize: 14, color: DT.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DS.xxl),

          // Email field
          Text('Email address', style: GoogleFonts.manrope(
            fontSize: 13, fontWeight: FontWeight.w600, color: DT.text,
          )),
          const SizedBox(height: 6),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: onEmailChanged,
            autofocus: true,
            style: GoogleFonts.manrope(fontSize: 15, color: DT.text),
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: GoogleFonts.manrope(fontSize: 14, color: DT.textTertiary),
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18, color: DT.textTertiary),
              filled: true,
              fillColor: emailError != null ? DT.dangerSoft : DT.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: DS.lg, vertical: DS.lg),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DS.cardRadius),
                borderSide: BorderSide(color: emailError != null ? DT.danger : DT.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DS.cardRadius),
                borderSide: BorderSide(color: emailError != null ? DT.danger : DT.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DS.cardRadius),
                borderSide: BorderSide(color: emailError != null ? DT.danger : DT.text, width: 1.5),
              ),
            ),
          ),
          if (emailError != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 13, color: DT.danger),
                const SizedBox(width: 4),
                Text(emailError!, style: GoogleFonts.manrope(
                  fontSize: 12, color: DT.danger, fontWeight: FontWeight.w500,
                )),
              ],
            ),
          ],
          const SizedBox(height: DS.xl),

          // Send button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: DT.text,
                foregroundColor: Colors.white,
                disabledBackgroundColor: DT.border,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
              ),
              child: isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text('Send reset link', style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
            ),
          ),
          const SizedBox(height: DS.lg),

          // Back to login
          Center(
            child: TextButton(
              onPressed: onBack,
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
                    fontSize: 14, fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sent confirmation view ───────────────────────────────────────────────────

class _SentView extends StatelessWidget {
  final String email;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _SentView({
    required this.email,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.screenPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success icon
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(color: DT.successSoft, shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read_outlined, color: DT.success, size: 44),
            ),
          ),
          const SizedBox(height: DS.xl),

          Text('Check your inbox', style: GoogleFonts.manrope(
            fontSize: 24, fontWeight: FontWeight.w800, color: DT.text,
          ), textAlign: TextAlign.center),
          const SizedBox(height: DS.sm),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.manrope(fontSize: 14, color: DT.textSecondary, height: 1.5),
              children: [
                const TextSpan(text: 'We sent a password reset link to\n'),
                TextSpan(
                  text: email,
                  style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: DT.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DS.xxxl),

          // Info card
          Container(
            padding: const EdgeInsets.all(DS.lg),
            decoration: BoxDecoration(
              color: DT.infoSoft,
              borderRadius: BorderRadius.circular(DS.cardRadius),
              border: Border.all(color: DT.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: DT.info),
                const SizedBox(width: DS.sm),
                Expanded(
                  child: Text(
                    'Didn\'t get it? Check your spam folder or wait a few minutes before trying again.',
                    style: GoogleFonts.manrope(fontSize: 13, color: DT.info, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DS.xl),

          // Back to login (primary)
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: DT.text,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
              ),
              child: Text('Back to sign in', style: GoogleFonts.manrope(
                fontSize: 16, fontWeight: FontWeight.w700,
              )),
            ),
          ),
          const SizedBox(height: DS.md),

          // Resend
          Center(
            child: TextButton(
              onPressed: onResend,
              style: TextButton.styleFrom(
                foregroundColor: DT.textSecondary,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Resend email', style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w600,
              )),
            ),
          ),
        ],
      ),
    );
  }
}
