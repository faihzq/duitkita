import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/trip_model.dart';

// ─── Date formatting ──────────────────────────────────────────────────────────

const tripMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const tripWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "8 Aug 2026"
String formatTripDate(DateTime d) =>
    '${d.day} ${tripMonths[d.month - 1]} ${d.year}';

/// "8 – 14 Aug 2026", collapsing the shared month/year where possible.
String formatTripRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${start.day} – ${end.day} ${tripMonths[start.month - 1]} ${start.year}';
  }
  if (start.year == end.year) {
    return '${start.day} ${tripMonths[start.month - 1]} – ${formatTripDate(end)}';
  }
  return '${formatTripDate(start)} – ${formatTripDate(end)}';
}

/// "Sat, 8 Aug"
String formatDayLabel(DateTime d) =>
    '${tripWeekdays[d.weekday - 1]}, ${d.day} ${tripMonths[d.month - 1]}';

/// "10:00 AM"
String formatTimeOfDay(TimeOfDay t) {
  final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

// ─── Avatars ──────────────────────────────────────────────────────────────────

/// Initials circle with a colour derived from the name — same palette as the
/// home screen avatar so the same person looks the same everywhere.
class TripAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const TripAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    required this.size,
  });

  static const _palette = [
    [Color(0xFF5B6FFF), Color(0xFFECEFFF)],
    [Color(0xFF00C2A8), Color(0xFFE0F7F2)],
    [Color(0xFFF59E0B), Color(0xFFFEF3DC)],
    [Color(0xFFEF4444), Color(0xFFFDECEC)],
    [Color(0xFF3B82F6), Color(0xFFE8F0FE)],
    [Color(0xFF8B5CF6), Color(0xFFF1EBFE)],
    [Color(0xFF10B981), Color(0xFFE5F7EF)],
    [Color(0xFFEC4899), Color(0xFFFCE7F3)],
  ];

  @override
  Widget build(BuildContext context) {
    final initials = (name.trim().isEmpty ? '?' : name.trim())
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isNotEmpty ? s[0] : '')
        .join()
        .toUpperCase();

    int h = 0;
    for (final ch in name.codeUnits) {
      h = (h * 31 + ch) & 0xFFFFFFFF;
    }
    final pair = _palette[h % _palette.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pair[1],
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                initials,
                style: GoogleFonts.manrope(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w700,
                  color: pair[0],
                  letterSpacing: -0.3,
                ),
              ),
            )
          : null,
    );
  }
}

/// Overlapping avatar stack with a ring in the surrounding surface colour.
class TravellerAvatarStack extends StatelessWidget {
  final List<TripTraveller> travellers;
  final double size;
  final bool onDark;
  final int max;

  const TravellerAvatarStack({
    super.key,
    required this.travellers,
    this.size = 30,
    this.onDark = false,
    this.max = 5,
  });

  /// Design overlap between adjacent avatars.
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    if (travellers.isEmpty) return const SizedBox.shrink();
    final shown = travellers.take(max).toList();
    final extra = travellers.length - shown.length;
    final ring = onDark ? DT.headerGradientEnd : DT.surface;

    // Avatar plus its 2px ring on each side.
    final outer = size + 4;
    final advance = outer - _overlap;
    final count = shown.length + (extra > 0 ? 1 : 0);

    // Laid out with a Stack, not negative margins — Container asserts that
    // margin is non-negative, which crashed as soon as a second avatar existed.
    final items = <Widget>[
      for (var i = 0; i < shown.length; i++)
        Positioned(
          left: i * advance,
          top: 0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 2),
            ),
            child: TripAvatar(
              name: shown[i].name,
              imageUrl: shown[i].photoUrl,
              size: size,
            ),
          ),
        ),
      if (extra > 0)
        Positioned(
          left: shown.length * advance,
          top: 0,
          child: Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onDark ? Colors.white24 : DT.primarySoft,
              border: Border.all(color: ring, width: 2),
            ),
            child: Center(
              child: Text(
                '+$extra',
                style: GoogleFonts.manrope(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w800,
                  color: onDark ? Colors.white : DT.textSecondary,
                ),
              ),
            ),
          ),
        ),
    ];

    return SizedBox(
      width: outer + (count - 1) * advance,
      height: outer,
      // Reversed so the leftmost avatar paints on top, matching the design's
      // descending z-index.
      child: Stack(children: items.reversed.toList()),
    );
  }
}

// ─── Chrome ───────────────────────────────────────────────────────────────────

/// Back arrow + title/subtitle + optional trailing action. [onDark] switches it
/// for the navy gradient headers.
class TripBackHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;
  final bool onDark;
  final VoidCallback onBack;

  const TripBackHeader({
    super.key,
    required this.title,
    this.sub,
    this.trailing,
    this.onDark = false,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: [
          TripIconButton(
            icon: Icons.chevron_left_rounded,
            onTap: onBack,
            onDark: onDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: onDark ? Colors.white : DT.text,
                    letterSpacing: -0.4,
                  ),
                ),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: onDark ? Colors.white70 : DT.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class TripIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool onDark;

  const TripIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.12) : DT.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
          border: onDark ? null : Border.all(color: DT.border),
        ),
        child: Icon(icon, size: 20, color: onDark ? Colors.white : DT.text),
      ),
    );
  }
}

// ─── Forms ────────────────────────────────────────────────────────────────────

/// Label + control + optional hint. The Trips forms are pickers rather than
/// plain text fields, so they don't use `FloatingField`.
class TripField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? hint;
  final double gap;

  const TripField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: DT.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 7),
          child,
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: GoogleFonts.manrope(fontSize: 11.5, color: DT.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The bordered white input shell. Wraps a [TextField] or, with [onTap], acts
/// as a read-only picker showing [value] (or [placeholder] when empty).
class TripInput extends StatelessWidget {
  final IconData? icon;
  final bool big;
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;
  final Widget? child;

  const TripInput({
    super.key,
    this.icon,
    this.big = false,
    this.value,
    this.placeholder,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final filled = (value ?? '').isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: big ? 15 : 14,
          vertical: child != null ? 2 : (big ? 15 : 13),
        ),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: DT.border),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: DT.textTertiary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: child ??
                  Text(
                    filled ? value! : (placeholder ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: big ? 16 : 14.5,
                      fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                      color: filled ? DT.text : DT.textTertiary,
                      letterSpacing: -0.2,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Capitalises the first letter of each word as it is typed.
///
/// `TextCapitalization` alone is only a hint to the soft keyboard: Flutter does
/// not transform the text, many IMEs apply it only once a word is committed
/// with a space, and it is ignored outright when the user has auto-capitalise
/// switched off. This enforces it regardless of keyboard.
///
/// Only lowercase letters at a word start are touched, so deliberate casing
/// like "TS Duty Free" or "McDonald" survives. When nothing needs changing the
/// incoming value is returned untouched, which keeps the IME's composing region
/// — and therefore autocorrect and swipe typing — intact for most keystrokes.
class TitleCaseFormatter extends TextInputFormatter {
  const TitleCaseFormatter();

  static final _lower = RegExp(r'[a-z]');
  static const _breaks = {' ', '\n', '\t', '-', '/', '(', ',', '.'};

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    var atWordStart = true;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      buffer.write(atWordStart && _lower.hasMatch(ch) ? ch.toUpperCase() : ch);
      atWordStart = _breaks.contains(ch);
    }

    final result = buffer.toString();
    if (result == text) return newValue;

    // Same length, so the incoming selection stays valid.
    return TextEditingValue(text: result, selection: newValue.selection);
  }
}

/// Borderless text field sized to sit inside a [TripInput].
class TripTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool big;
  final int maxLines;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const TripTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.big = false,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      cursorColor: DT.accent,
      style: GoogleFonts.manrope(
        fontSize: big ? 16 : 14.5,
        fontWeight: FontWeight.w700,
        color: DT.text,
        letterSpacing: -0.2,
        height: maxLines > 1 ? 1.4 : null,
      ),
      decoration: InputDecoration(
        isDense: true,
        // All three must be cleared, not just `border`: InputDecoration pulls
        // any null field from the global InputDecorationTheme, which supplies
        // an outlined enabled/focused border and a fill — that would draw a
        // second border inside the surrounding [TripInput].
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: big ? 13 : 11),
        hintText: placeholder,
        hintStyle: GoogleFonts.manrope(
          fontSize: big ? 16 : 14.5,
          fontWeight: FontWeight.w500,
          color: DT.textTertiary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Sticky footer bar with a top border, sitting above the home indicator.
class TripFooter extends StatelessWidget {
  final Widget child;
  const TripFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DS.xl, 12, DS.xl, 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: DT.surface,
        border: Border(top: BorderSide(color: DT.border)),
      ),
      child: child,
    );
  }
}

/// Full-width navy CTA. Shows a spinner while [busy].
class TripPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool trailingIcon;
  final VoidCallback? onTap;
  final bool busy;
  final double height;

  const TripPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon = false,
    this.onTap,
    this.busy = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: enabled ? DT.text : DT.borderStrong,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null && !trailingIcon) ...[
                      Icon(icon, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (icon != null && trailingIcon) ...[
                      const SizedBox(width: 8),
                      Icon(icon, size: 18, color: Colors.white),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Rounded dashed outline — Flutter has no dashed `BoxBorder`, so anything that
/// needs one (the "Add" destination chip, the "Add a stop" row) paints it.
class DashedBorderPainter extends CustomPainter {
  final double radius;

  /// 1 for the "Add" destination chip, 1.5 for the "Add a stop" row.
  final double strokeWidth;

  const DashedBorderPainter({required this.radius, this.strokeWidth = 1});

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DT.borderStrong
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        // A pill radius must not exceed half the height.
        Radius.circular(radius.clamp(0, size.height / 2)),
      ));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.radius != radius || old.strokeWidth != strokeWidth;
}

/// The `car/ferry · time · km` pill used above a stop card and on stop detail.
class LegPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool large;

  const LegPill({
    super.key,
    required this.label,
    this.icon = Icons.directions_car_outlined,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 9, vertical: large ? 5 : 3),
      decoration: BoxDecoration(
        color: DT.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: DT.textTertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: large ? 11.5 : 11,
              fontWeight: FontWeight.w700,
              color: DT.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
