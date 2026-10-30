import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/services/makan_service.dart';
import 'package:duitkita/features/makan/makan_filter.dart';
import 'package:duitkita/features/makan/makan_hours.dart';
import 'package:duitkita/features/makan/makan_list_screen.dart';
import 'package:duitkita/features/makan/makan_spot_detail_screen.dart';
import 'package:duitkita/features/makan/makan_widgets.dart';

/// Home's "Where to eat?" card — what is open right now, and the way into
/// the Makan module.
///
/// Home lives in an `IndexedStack` and is rarely rebuilt, so the card keeps
/// its own clock; otherwise a card built at breakfast still says "nothing
/// open" at lunch.
class MakanHomeCard extends ConsumerStatefulWidget {
  final String userId;
  const MakanHomeCard({super.key, required this.userId});

  @override
  ConsumerState<MakanHomeCard> createState() => _MakanHomeCardState();
}

class _MakanHomeCardState extends ConsumerState<MakanHomeCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _openList(BuildContext context) =>
      Navigator.of(context).push(AppTheme.slideRoute(const MakanListScreen()));

  @override
  Widget build(BuildContext context) {
    final spots =
        ref.watch(allMakanSpotsProvider(widget.userId)).valueOrNull ??
        const <MakanSpot>[];
    final now = DateTime.now();
    final meal = mealPeriodFor(now);
    final open = filterSpots(spots, const MakanQuery(), now).available;

    final subtitle =
        spots.isEmpty
            ? 'Save your go-to places with their hours and menu'
            : open.isEmpty
            ? 'Nothing on your list is open right now'
            : '${open.length} open now for ${meal.label.toLowerCase()}';

    return GestureDetector(
      onTap: () => _openList(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DT.catMakanSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      meal.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where to eat?',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: DT.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: open.isEmpty ? DT.textSecondary : DT.catMakan,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: DT.textTertiary),
              ],
            ),
            for (final s in open.take(3)) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1, color: DT.border),
              const SizedBox(height: 10),
              _Row(
                spot: s,
                now: now,
                onTap:
                    () => Navigator.of(context).push(
                      AppTheme.slideRoute(
                        MakanSpotDetailScreen(spotId: s.id, groupId: s.groupId),
                      ),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final MakanSpot spot;
  final DateTime now;
  final VoidCallback onTap;
  const _Row({required this.spot, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          MakanEmojiTile(spot: spot, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DT.text,
                  ),
                ),
                Text(
                  [spot.area, ...spot.menu.take(3)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: DT.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // The status line flexes its text, so it needs a bounded width
          // inside this row.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: MakanStatusLine(
              status: statusAt(spot.hours, now),
              now: now,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
