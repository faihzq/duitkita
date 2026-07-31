import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/trip_service.dart';
import 'package:duitkita/features/trips/itinerary_screen.dart';
import 'package:duitkita/features/trips/trip_form_screen.dart';
import 'package:duitkita/features/trips/trip_style.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

/// Entry point for the Trips module — upcoming and past trips, plus New.
class TripsListScreen extends ConsumerWidget {
  const TripsListScreen({super.key});

  void _openTrip(BuildContext context, String tripId) {
    Navigator.of(context).push(
      AppTheme.slideRoute(ItineraryScreen(tripId: tripId)),
    );
  }

  void _newTrip(BuildContext context) {
    Navigator.of(context).push(AppTheme.slideRoute(const TripFormScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final tripsAsync = ref.watch(tripsStreamProvider(userId));
    final trips = tripsAsync.valueOrNull ?? const <TripModel>[];

    final upcoming = trips.where((t) => !t.isPast).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = trips.where((t) => t.isPast).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.xl, 6, DS.xl, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trips',
                          style: GoogleFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: DT.text,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Plan, split & remember every getaway',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DT.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _newTrip(context),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: DT.text,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 17, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'New',
                            style: GoogleFonts.manrope(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── List ────────────────────────────────────────────
            Expanded(
              child: tripsAsync.isLoading && trips.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: DT.accent, strokeWidth: 2),
                    )
                  : trips.isEmpty
                      ? _EmptyState(onCreate: () => _newTrip(context))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(DS.xl, 4, DS.xl, 24),
                          children: [
                            if (upcoming.isNotEmpty) ...[
                              const _SectionHead('Upcoming', topGap: 8),
                              for (final t in upcoming)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TripCard(
                                    trip: t,
                                    onTap: () => _openTrip(context, t.id),
                                  ),
                                ),
                            ],
                            if (past.isNotEmpty) ...[
                              const _SectionHead('Past trips', topGap: 22),
                              Opacity(
                                opacity: 0.85,
                                child: Column(
                                  children: [
                                    for (final t in past)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: TripCard(
                                          trip: t,
                                          onTap: () => _openTrip(context, t.id),
                                        ),
                                      ),
                                  ],
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

// ─── Trip card ────────────────────────────────────────────────────────────────

class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;

  const TripCard({super.key, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (pillFg, pillBg) = switch (trip.status) {
      TripStatus.confirmed => (DT.accentDeep, DT.accentSoft),
      TripStatus.settled => (DT.textSecondary, DT.surfaceAlt),
      TripStatus.tentative => (DT.warning, DT.warningSoft),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Coloured band
            Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: TripBands.gradient(trip.bandGradient),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        trip.emoji ?? '🗺️',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          trip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (trip.destinations.isNotEmpty)
                          Text(
                            trip.where,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Meta row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 15, color: DT.textTertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      formatTripRange(trip.startDate, trip.endDate),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DT.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tripStatusLabel(trip.status),
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: pillFg,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, thickness: 1, color: DT.border),
            ),

            // People row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  TravellerAvatarStack(travellers: trip.travellers, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${trip.travellers.length} traveller'
                      '${trip.travellers.length == 1 ? '' : 's'}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DT.textSecondary,
                      ),
                    ),
                  ),
                  const Icon(Icons.route_outlined,
                      size: 15, color: DT.textTertiary),
                  const SizedBox(width: 5),
                  Text(
                    '${trip.stopCount} stops',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DT.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section head ─────────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  final String title;
  final double topGap;
  const _SectionHead(this.title, {this.topGap = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 10),
      child: Text(
        title,
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

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: DT.border),
            ),
            child: const Icon(Icons.map_outlined,
                size: 38, color: DT.textTertiary),
          ),
          const SizedBox(height: 20),
          Text(
            'No trips yet',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: DT.text,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Plan a road trip day by day — stops, drive times and one-tap '
            'navigation for the whole squad.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: DT.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onCreate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: DT.text,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Plan your first trip',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
}
