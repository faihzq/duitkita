import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/features/makan/makan_geo.dart';
import 'package:duitkita/features/makan/makan_hours.dart';
import 'package:duitkita/features/makan/makan_style.dart';

/// "Open · closes 11:00 PM" as a coloured dot + text.
class MakanStatusLine extends StatelessWidget {
  final OpenStatus status;
  final DateTime now;
  final double fontSize;

  const MakanStatusLine({
    super.key,
    required this.status,
    required this.now,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OpenAllDay() || OpenUntil() => DT.success,
      ClosedUntil() => DT.danger,
      HoursUnknown() => DT.textTertiary,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            statusLabel(status, now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: status is HoursUnknown ? DT.textTertiary : color,
            ),
          ),
        ),
      ],
    );
  }
}

class MakanEmojiTile extends StatelessWidget {
  final MakanSpot spot;
  final double size;
  const MakanEmojiTile({super.key, required this.spot, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: DT.catMakanSoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: Text(makanEmoji(spot), style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}

class MakanSpotCard extends StatelessWidget {
  final MakanSpot spot;
  final DateTime now;
  final VoidCallback onTap;

  /// Menu items to call out, e.g. the ones matching a search.
  final List<String> highlight;

  /// Straight-line distance from the user, when "Near me" is on.
  final double? distanceKm;

  const MakanSpotCard({
    super.key,
    required this.spot,
    required this.now,
    required this.onTap,
    this.highlight = const [],
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final status = statusAt(spot.hours, now);
    final menu = [
      ...highlight,
      ...spot.menu.where((m) => !highlight.contains(m)),
    ];
    final subtitle = [
      if (distanceKm != null) formatDistance(distanceKm!),
      spot.area,
      if (spot.categories.isNotEmpty) spot.categories.first,
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DT.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0B1F3A),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MakanEmojiTile(spot: spot),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: DT.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: DT.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MakanStatusLine(status: status, now: now),
                  if (menu.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      menu.take(5).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DT.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped filter chip.
class MakanChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  const MakanChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? DT.text : DT.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? DT.text : DT.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : DT.text,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(
                trailingIcon,
                size: 16,
                color: selected ? Colors.white : DT.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
