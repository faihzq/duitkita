import 'package:flutter/material.dart';
import 'package:duitkita/config/design_tokens.dart';

/// Circular progress ring for the redesigned Home hero ("Focus" direction).
///
/// Drop this file into `lib/features/home/` and use `HeroRing` inside the hero
/// card. It draws a rounded-cap accent arc over a faint white track, sized to
/// fill its box. Pass [pct] as 0.0–1.0.
///
/// Usage:
///   SizedBox(
///     width: 128, height: 128,
///     child: HeroRing(pct: progressPct, center: /* your % + label column */),
///   )
class HeroRing extends StatelessWidget {
  final double pct; // 0.0 – 1.0
  final Widget center; // typically the "43% / CLEARED" column
  final double stroke;
  const HeroRing({
    super.key,
    required this.pct,
    required this.center,
    this.stroke = 12,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(pct.clamp(0.0, 1.0), stroke),
      child: Center(child: center),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final double stroke;
  _RingPainter(this.pct, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.width - stroke) / 2;

    final track =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = Colors.white.withValues(alpha: 0.15);

    final prog =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = DT.accent;

    canvas.drawCircle(c, r, track);
    // Start at top (-90°), sweep clockwise by pct of a full turn.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5707963, // -pi/2
      6.2831853 * pct, // 2*pi * pct
      false,
      prog,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.stroke != stroke;
}

/// Animated variant — sweeps from 0 to [pct] on first build. Use this if you
/// want the ring to fill in when the Home screen appears.
class AnimatedHeroRing extends StatelessWidget {
  final double pct;
  final Widget center;
  final double stroke;
  final Duration duration;
  const AnimatedHeroRing({
    super.key,
    required this.pct,
    required this.center,
    this.stroke = 12,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder:
          (_, value, __) => CustomPaint(
            painter: _RingPainter(value, stroke),
            child: Center(child: center),
          ),
    );
  }
}
