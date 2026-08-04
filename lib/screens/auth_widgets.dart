// ============================================================================
// auth_widgets.dart — shared UI for login, signup & forgot password.
// AuthHero, PrimaryButton, GoogleButton, TrustCard.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';

// Compact navy gradient hero with brand mark + decorative glow circles.
class AuthHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading; // e.g. a back button on signup
  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
  });

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
              padding: const EdgeInsets.fromLTRB(
                DS.screenPad,
                DS.lg,
                DS.screenPad,
                DS.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: DS.xs),
                      ],
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icon/play_store_512.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'DuitKita',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DS.xxl),
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: DS.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
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
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          DT.accent.withValues(alpha: opacity),
          DT.accent.withValues(alpha: 0),
        ],
      ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.cardRadius),
          ),
        ),
        child:
            loading
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DT.textTertiary,
          ),
        ),
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
            borderRadius: BorderRadius.circular(DS.cardRadius),
          ),
        ),
        child:
            loading
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: DT.textSecondary,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GoogleMark(),
                    const SizedBox(width: 10),
                    // Flexible so a longer label ("Sign up with Google") or a
                    // large text scale shrinks rather than overflowing.
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DT.text,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

/// Google's four-colour "G".
///
/// Drawn rather than shipped as an asset: the geometry is transcribed from
/// Google's official 48×48 mark, so it needs neither an image file nor an SVG
/// package, and stays crisp at any size.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: CustomPaint(painter: _GoogleMarkPainter()),
  );
}

class _GoogleMarkPainter extends CustomPainter {
  // Brand colours, in the order the arcs are drawn.
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    // Authored against a 48×48 box.
    final s = size.width / 48;
    canvas.save();
    canvas.scale(s, s);

    void fill(Path path, Color color) => canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );

    // Right arm and the crossbar.
    fill(
      Path()
        ..moveTo(45.12, 24.5)
        ..cubicTo(45.12, 22.94, 44.98, 21.44, 44.72, 20.0)
        ..lineTo(24, 20.0)
        ..lineTo(24, 28.51)
        ..lineTo(35.84, 28.51)
        ..cubicTo(35.33, 31.26, 33.78, 33.59, 31.45, 35.15)
        ..lineTo(31.45, 40.67)
        ..lineTo(38.56, 40.67)
        ..cubicTo(42.72, 36.84, 45.12, 31.20, 45.12, 24.5)
        ..close(),
      _blue,
    );

    // Bottom sweep.
    fill(
      Path()
        ..moveTo(24, 46)
        ..cubicTo(29.94, 46, 34.92, 44.03, 38.56, 40.67)
        ..lineTo(31.45, 35.15)
        ..cubicTo(29.48, 36.47, 26.96, 37.25, 24.0, 37.25)
        ..cubicTo(18.27, 37.25, 13.42, 33.38, 11.69, 28.18)
        ..lineTo(4.34, 28.18)
        ..lineTo(4.34, 33.88)
        ..cubicTo(7.96, 41.07, 15.4, 46, 24, 46)
        ..close(),
      _green,
    );

    // Left edge.
    fill(
      Path()
        ..moveTo(11.69, 28.18)
        ..cubicTo(11.25, 26.86, 11, 25.45, 11, 24)
        // 's' in the source: the control point mirrors the previous one.
        ..cubicTo(11, 22.55, 11.25, 21.14, 11.69, 19.82)
        ..lineTo(11.69, 14.12)
        ..lineTo(4.34, 14.12)
        ..cubicTo(2.85, 17.09, 2, 20.45, 2, 24)
        ..cubicTo(2, 27.55, 2.85, 30.91, 4.34, 33.88)
        ..lineTo(11.69, 28.18)
        ..close(),
      _yellow,
    );

    // Top sweep.
    fill(
      Path()
        ..moveTo(24, 10.75)
        ..cubicTo(27.23, 10.75, 30.13, 11.86, 32.41, 14.04)
        ..lineTo(38.72, 7.73)
        ..cubicTo(34.91, 4.18, 29.93, 2, 24, 2)
        ..cubicTo(15.4, 2, 7.96, 6.93, 4.34, 14.12)
        ..lineTo(11.69, 19.82)
        ..cubicTo(13.42, 14.62, 18.27, 10.75, 24.0, 10.75)
        ..close(),
      _red,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
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
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: DT.accentDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your data is encrypted and stored in Malaysia. We never share it with third parties.',
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: DT.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
