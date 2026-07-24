import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _Slide(
      title: 'Track money\nwith your people',
      body:
          'Split bills with family, settle group expenses, and stop chasing cousins for that RM50.',
      art: _ArtKind.people,
    ),
    _Slide(
      title: 'Never miss\na monthly payment',
      body:
          "See every loan, bill and group contribution in one place. We'll nudge you before due dates.",
      art: _ArtKind.calendar,
    ),
    _Slide(
      title: 'Pay & verify\nin two taps',
      body:
          'Generate a DuitNow QR, snap a receipt, and the admin gets a clean approve / reject card.',
      art: _ArtKind.qr,
    ),
    _Slide(
      title: 'Stay in control,\ntogether',
      body:
          'Members see what they owe. Admins see who paid. No spreadsheets, no awkward chats.',
      art: _ArtKind.shield,
    ),
  ];

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.xl, 12, DS.xl, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icon/play_store_512.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'DuitKita',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: DT.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  if (!isLast)
                    TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: DT.textSecondary,
                        padding: const EdgeInsets.all(8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
              ),
            ),

            // Page dots
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 24 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: isActive ? DT.text : DT.borderStrong,
                    ),
                  );
                }),
              ),
            ),

            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.xl, 0, DS.xl, DS.xxl),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLast ? 'Get started' : 'Continue',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slide page ──────────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  final _Slide slide;

  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _OnboardArt(kind: slide.art),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: DT.text,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: DT.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide data ───────────────────────────────────────────────────────────────

enum _ArtKind { people, calendar, qr, shield }

class _Slide {
  final String title;
  final String body;
  final _ArtKind art;

  const _Slide({required this.title, required this.body, required this.art});
}

// ─── Illustration art ─────────────────────────────────────────────────────────

class _OnboardArt extends StatelessWidget {
  final _ArtKind kind;

  const _OnboardArt({required this.kind});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 200,
      child: switch (kind) {
        _ArtKind.people => const _PeopleArt(),
        _ArtKind.calendar => const _CalendarArt(),
        _ArtKind.qr => const _QrArt(),
        _ArtKind.shield => const _ShieldArt(),
      },
    );
  }
}

// Art 1: Two overlapping member cards with family label pill
class _PeopleArt extends StatelessWidget {
  const _PeopleArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: DT.catGroupsSoft,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // Left card — Mum
        Positioned(
          left: 30,
          top: 20,
          child: _MemberCard(
            initials: 'MU',
            avatarColor: DT.catGroups,
            amountText: 'RM 240',
            amountColor: DT.catGroups,
          ),
        ),
        // Right card — Adik Aliya (rotated)
        Positioned(
          right: 14,
          top: 10,
          child: Transform.rotate(
            angle: 0.07,
            child: _MemberCard(
              initials: 'AA',
              avatarColor: DT.accent,
              amountText: 'RM 80',
              amountColor: DT.accent,
            ),
          ),
        ),
        // Bottom pill
        Positioned(
          bottom: -10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: DT.text,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: DT.text.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Family · 4 members',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String initials;
  final Color avatarColor;
  final String amountText;
  final Color amountColor;

  const _MemberCard({
    required this.initials,
    required this.avatarColor,
    required this.amountText,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DT.border),
        boxShadow: [
          BoxShadow(
            color: DT.text.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Skeleton lines
          Container(height: 6, decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 6),
          Container(width: 60, height: 6, decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(3))),
          const Spacer(),
          // Amount
          Text(
            amountText,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: amountColor,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            'this month',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: DT.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// Art 2: Calendar with highlighted due dates
class _CalendarArt extends StatelessWidget {
  const _CalendarArt();

  static const _dueDays = {4, 9, 17}; // 0-indexed
  static const _today = 12;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: DT.accentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // Calendar card
        Positioned(
          left: 24,
          right: 24,
          top: 28,
          bottom: 28,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DT.border),
              boxShadow: [
                BoxShadow(
                  color: DT.text.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'May 2026',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DT.text,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: DT.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '3 due',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: DT.accentDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Grid
                GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: 21,
                  itemBuilder: (_, i) {
                    final isToday = i == _today;
                    final isDue = _dueDays.contains(i);
                    Color bg;
                    Color fg;
                    if (isToday) {
                      bg = DT.text;
                      fg = Colors.white;
                    } else if (isDue) {
                      bg = DT.accent;
                      fg = Colors.white;
                    } else {
                      bg = DT.surfaceAlt;
                      fg = DT.textTertiary;
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Art 3: DuitNow QR card
class _QrArt extends StatelessWidget {
  const _QrArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: DT.catBillsSoft,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // QR card centered
        Center(
          child: Container(
            width: 130,
            height: 160,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DT.border),
              boxShadow: [
                BoxShadow(
                  color: DT.text.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // QR pattern
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: DT.text,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: CustomPaint(
                      painter: _QrPatternPainter(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'RM 120.00',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DT.text,
                  ),
                ),
                Text(
                  'DuitNow QR',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: DT.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const cell = 5.0;
    const gap = 2.0;
    // Draw a simple QR-like grid pattern
    for (double x = 0; x < size.width; x += cell + gap) {
      for (double y = 0; y < size.height; y += cell + gap) {
        // Simple pseudo-random pattern based on position
        final hash = (x * 3 + y * 7).toInt() % 3;
        if (hash != 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, cell, cell),
              const Radius.circular(1),
            ),
            paint,
          );
        }
      }
    }

    // Corner squares (QR finder patterns)
    _drawFinderPattern(canvas, 0, 0, size, paint);
    _drawFinderPattern(canvas, size.width - 21, 0, size, paint);
    _drawFinderPattern(canvas, 0, size.height - 21, size, paint);
  }

  void _drawFinderPattern(Canvas canvas, double x, double y, Size size, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 21, 21), const Radius.circular(3)),
      paint,
    );
    final inner = Paint()
      ..color = const Color(0xFF0B1F3A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 3, y + 3, 15, 15), const Radius.circular(2)),
      inner,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 6, y + 6, 9, 9), const Radius.circular(1)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Art 4: Check circle on blue background
class _ShieldArt extends StatelessWidget {
  const _ShieldArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: DT.catDebtsSoft,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // Center check card
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: DT.border),
              boxShadow: [
                BoxShadow(
                  color: DT.text.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: DT.catDebts,
            ),
          ),
        ),
      ],
    );
  }
}
