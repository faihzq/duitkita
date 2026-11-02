import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/services/makan_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/features/makan/makan_hours.dart';
import 'package:duitkita/features/makan/makan_spot_form_screen.dart';
import 'package:duitkita/features/makan/makan_style.dart';
import 'package:duitkita/features/makan/makan_widgets.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

class MakanSpotDetailScreen extends ConsumerWidget {
  final String spotId;

  const MakanSpotDetailScreen({super.key, required this.spotId});

  Future<void> _launch(BuildContext context, Uri url, String app) async {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showSnackBar(context, 'Could not open $app', isError: true);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MakanSpot spot,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: DT.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius),
            ),
            title: Text(
              'Remove this spot?',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DT.text,
              ),
            ),
            content: Text(
              '“${spot.name}” will be removed for everyone.',
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                color: DT.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: DT.danger),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(makanServiceProvider).deleteSpot(spot);
      if (context.mounted) {
        Navigator.of(context).pop();
        showSnackBar(context, 'Spot removed');
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Could not remove: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final spotAsync = ref.watch(makanSpotProvider(spotId));
    final spot = spotAsync.valueOrNull;

    if (spot == null) {
      return Scaffold(
        backgroundColor: DT.bg,
        body: SafeArea(
          child: Column(
            children: [
              TripBackHeader(
                title: 'Spot',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Center(
                  child:
                      spotAsync.isLoading
                          ? const CircularProgressIndicator(
                            color: DT.accent,
                            strokeWidth: 2,
                          )
                          : Text(
                            'This spot is no longer available.',
                            style: GoogleFonts.manrope(color: DT.textSecondary),
                          ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // The list is shared work: anyone edits, but only the person who added a
    // spot removes it. Mirrors the rules.
    final mine = spot.addedBy == userId;

    final now = DateTime.now();
    final status = statusAt(spot.hours, now);

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TripBackHeader(
              title: spot.name,
              sub: spot.area,
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TripIconButton(
                    icon: Icons.edit_outlined,
                    onTap:
                        () => Navigator.of(context).push(
                          AppTheme.slideRoute(MakanSpotFormScreen(spot: spot)),
                        ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 8),
                    TripIconButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: () => _confirmDelete(context, ref, spot),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(DS.xl, 0, DS.xl, 24),
                children: [
                  // ── Summary ─────────────────────────────────────
                  _Card(
                    child: Row(
                      children: [
                        MakanEmojiTile(spot: spot, size: 54),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MakanStatusLine(
                                status: status,
                                now: now,
                                fontSize: 13.5,
                              ),
                              if (spot.categories.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  spot.categories.join(' · '),
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: DT.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                mine
                                    ? 'Added by you'
                                    : 'Added by ${spot.addedByName.isEmpty ? 'family' : spot.addedByName}',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: DT.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Directions ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TripPrimaryButton(
                          label: 'Google Maps',
                          icon: Icons.directions_outlined,
                          height: 48,
                          onTap:
                              () => _launch(
                                context,
                                MakanMaps.google(spot),
                                'Google Maps',
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TripPrimaryButton(
                          label: 'Waze',
                          icon: Icons.navigation_outlined,
                          height: 48,
                          onTap:
                              () => _launch(
                                context,
                                MakanMaps.waze(spot),
                                'Waze',
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Menu ────────────────────────────────────────
                  if (spot.menu.isNotEmpty) ...[
                    const _Heading('Menu'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in spot.menu)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: DT.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: DT.border),
                            ),
                            child: Text(
                              m,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: DT.text,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Hours ───────────────────────────────────────
                  const _Heading('Opening hours'),
                  _Card(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child:
                        !spot.hours.values.any((s) => s.isNotEmpty)
                            ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Not set yet. Edit the spot to add them.',
                                style: GoogleFonts.manrope(
                                  fontSize: 13.5,
                                  color: DT.textSecondary,
                                ),
                              ),
                            )
                            : Column(
                              children: [
                                for (var d = 1; d <= 7; d++)
                                  _HoursRow(
                                    day: weekdayLong[d - 1],
                                    slots: spot.hours[d] ?? const [],
                                    today: d == now.weekday,
                                  ),
                              ],
                            ),
                  ),

                  // ── Notes ───────────────────────────────────────
                  if (spot.notes?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 20),
                    const _Heading('Notes'),
                    _Card(
                      child: Text(
                        spot.notes!.trim(),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: DT.text,
                          height: 1.5,
                        ),
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

class _HoursRow extends StatelessWidget {
  final String day;
  final List<OpenSlot> slots;
  final bool today;

  const _HoursRow({
    required this.day,
    required this.slots,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.manrope(
      fontSize: 13.5,
      fontWeight: today ? FontWeight.w800 : FontWeight.w600,
      color: slots.isEmpty ? DT.danger : (today ? DT.text : DT.textSecondary),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              day,
              style: style.copyWith(color: today ? DT.text : DT.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              formatSlots(slots),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: DT.text,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DT.border),
      ),
      child: child,
    );
  }
}
