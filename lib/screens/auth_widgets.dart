// ============================================================================
// auth_widgets.dart — shared UI for login, signup & forgot password.
// AuthHero, PrimaryButton, TrustCard, errorSnack.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';

// Floating snackbar for auth errors.
SnackBar errorSnack(String msg) => SnackBar(
      content: Text(msg, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
      backgroundColor: DT.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

// Compact navy gradient hero with brand mark + decorative glow circles.
class AuthHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading; // e.g. a back button on signup
  const AuthHero({super.key, required this.title, required this.subtitle, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DT.headerGradientStart, DT.headerGradientEnd],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(top: -40, right: -50, child: _glowCircle(200, 0.16)),
          Positioned(bottom: -60, left: -30, child: _glowCircle(160, 0.10)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.lg, DS.screenPad, DS.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: DS.xs)],
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icon/play_store_512.png',
                          width: 34, height: 34, fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('DuitKita', style: GoogleFonts.manrope(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                        letterSpacing: -0.4)),
                    ],
                  ),
                  const SizedBox(height: DS.xxl),
                  Text(title, style: GoogleFonts.manrope(
                    fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white,
                    letterSpacing: -0.6, height: 1.15)),
                  const SizedBox(height: DS.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(subtitle, style: GoogleFonts.manrope(
                      fontSize: 14, height: 1.45,
                      color: Colors.white.withValues(alpha: 0.75))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, double opacity) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            DT.accent.withValues(alpha: opacity),
            DT.accent.withValues(alpha: 0),
          ]),
        ),
      );
}

// Dark pill primary button with trailing arrow + loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: (loading || !enabled) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: DT.text,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DT.border,
          disabledForegroundColor: DT.textTertiary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: GoogleFonts.manrope(
                    fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

// "or" separator between the primary action and the provider buttons.
class AuthDivider extends StatelessWidget {
  final String label;
  const AuthDivider({super.key, this.label = 'or'});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider(color: DT.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: DT.textTertiary)),
          ),
          const Expanded(child: Divider(color: DT.border, height: 1)),
        ],
      );
}

// Outlined "Continue with Google" button.
class GoogleButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.label = 'Continue with Google',
    this.loading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: (loading || !enabled) ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: DT.surface,
          foregroundColor: DT.text,
          side: const BorderSide(color: DT.borderStrong),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: DT.textSecondary))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleMark(),
                  const SizedBox(width: 10),
                  Text(label, style: GoogleFonts.manrope(
                    fontSize: 15, fontWeight: FontWeight.w700, color: DT.text)),
                ],
              ),
      ),
    );
  }
}

// Google's "G" wordmark. Replace with the official multi-colour asset if you
// want to follow Google's branding guidelines to the letter.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 20, height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('G', style: GoogleFonts.manrope(
          fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF4285F4))),
      );
}

// "Your data is encrypted..." reassurance card.
class TrustCard extends StatelessWidget {
  const TrustCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: DT.accentDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your data is encrypted and stored in Malaysia. We never share it with third parties.',
              style: GoogleFonts.manrope(
                fontSize: 11.5, height: 1.4,
                fontWeight: FontWeight.w500, color: DT.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
