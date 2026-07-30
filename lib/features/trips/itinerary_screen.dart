import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/itinerary_stop.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/trip_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/features/trips/add_stop_screen.dart';
import 'package:duitkita/features/trips/stop_detail_screen.dart';
import 'package:duitkita/features/trips/trip_style.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

/// The core Trips view — a typed, day-by-day timeline for one trip.
class ItineraryScreen extends ConsumerStatefulWidget {
  final String tripId;
  const ItineraryScreen({super.key, required this.tripId});

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  /// Null until the trip loads, then pinned to today when the trip is running.
  int? _activeDay;

  int _defaultDay(TripModel trip) {
    final today = DateTime.now();
    final start = DateTime(
        trip.startDate.year, trip.startDate.month, trip.startDate.day);
    final n = DateTime(today.year, today.month, today.day)
            .difference(start)
            .inDays +
        1;
    return n.clamp(1, trip.dayCount);
  }

  Future<void> _openUrl(Uri url) async {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showSnackBar(context, 'Could not open Google Maps', isError: true);
    }
  }

  void _navigateDay(List<ItineraryStop> dayStops) {
    final url = TripMaps.dayRoute(dayStops);
    if (url == null) {
      showSnackBar(context, 'Add a place to a stop first so we can map it');
      return;
    }
    _openUrl(url);
  }

  void _share(TripModel trip, List<ItineraryStop> stops) {
    final b = StringBuffer()
      ..writeln(trip.name)
      ..writeln(formatTripRange(trip.startDate, trip.endDate));
    if (trip.destinations.isNotEmpty) b.writeln(trip.where);

    for (var d = 1; d <= trip.dayCount; d++) {
      final dayStops = stops.where((s) => s.day == d).toList();
      if (dayStops.isEmpty) continue;
      b
        ..writeln()
        ..writeln('Day $d — ${formatDayLabel(trip.dateForDay(d))}');
      for (final s in dayStops) {
        b.write('  ${s.time}  ${s.title}');
        if ((s.note ?? '').isNotEmpty) b.write(' (${s.note})');
        b.writeln();
      }
    }
    b
      ..writeln()
      ..write('Planned with DuitKita');
    SharePlus.instance.share(
      ShareParams(text: b.toString(), subject: trip.name),
    );
  }

  void _addStop(TripModel trip, int day) {
    Navigator.of(context).push(
      AppTheme.slideRoute(AddStopScreen(trip: trip, initialDay: day)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripStreamProvider(widget.tripId));
    final trip = tripAsync.valueOrNull;

    if (trip == null) {
      return Scaffold(
        backgroundColor: DT.bg,
        body: SafeArea(
          child: tripAsync.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: DT.accent, strokeWidth: 2))
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Trip not found',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: DT.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go back'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final stops =
        ref.watch(tripStopsStreamProvider(widget.tripId)).valueOrNull ??
            const <ItineraryStop>[];

    final activeDay = (_activeDay ?? _defaultDay(trip)).clamp(1, trip.dayCount);
    final dayStops = stops.where((s) => s.day == activeDay).toList();
    final totals = dayTotals(dayStops);
    final dayDate = trip.dateForDay(activeDay);

    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          // ── Navy header ─────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: tripHeaderGradient),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  TripBackHeader(
                    onDark: true,
                    onBack: () => Navigator.of(context).pop(),
                    title: trip.name,
                    sub: formatTripRange(trip.startDate, trip.endDate),
                    trailing: TripIconButton(
                      icon: Icons.ios_share_rounded,
                      onDark: true,
                      onTap: () => _share(trip, stops),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DS.xl, 0, DS.xl, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusTint(trip.status),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '● ${tripStatusLabel(trip.status)}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (trip.destinations.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              trip.where,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DS.xl, 0, DS.xl, 18),
                    child: Row(
                      children: [
                        TravellerAvatarStack(
                          travellers: trip.travellers,
                          size: 32,
                          onDark: true,
                        ),
                        const SizedBox(width: 14),
                        _HeaderStat(
                          icon: Icons.route_outlined,
                          label: '${stops.length} stops',
                        ),
                        const SizedBox(width: 14),
                        _HeaderStat(
                          icon: Icons.calendar_today_outlined,
                          label: '${trip.dayCount} days',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Day tab strip ───────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
            decoration: const BoxDecoration(
              color: DT.bg,
              border: Border(bottom: BorderSide(color: DT.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DS.xl),
              child: Row(
                children: [
                  for (var n = 1; n <= trip.dayCount; n++)
                    Padding(
                      padding: EdgeInsets.only(right: n == trip.dayCount ? 0 : 8),
                      child: _DayTab(
                        day: n,
                        date: trip.dateForDay(n),
                        active: n == activeDay,
                        onTap: () => setState(() => _activeDay = n),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Day body ────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(DS.xl, 16, DS.xl, 20),
              children: [
                // Day header + totals
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${formatDayLabel(dayDate)} · Day $activeDay',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: DT.text,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (totals.minutes > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _TotalChip(
                                  icon: Icons.schedule_outlined,
                                  label: formatDuration(totals.minutes),
                                ),
                                if (totals.km > 0) ...[
                                  const SizedBox(width: 8),
                                  _TotalChip(
                                    icon: Icons.directions_car_outlined,
                                    label: '${totals.km.round()} km',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${dayStops.length} stop${dayStops.length == 1 ? '' : 's'}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: DT.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Navigate this day
                if (dayStops.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _navigateDay(dayStops),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: DT.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: DT.accent),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: DT.accentDeep,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.route_outlined,
                                size: 19, color: Colors.white),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Navigate this day',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: DT.accentDeep,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  'Opens the full route in Google Maps',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: DT.accentDeep.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.north_east_rounded,
                              size: 18, color: DT.accentDeep),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Timeline
                if (dayStops.isEmpty)
                  _EmptyDay(onAdd: () => _addStop(trip, activeDay))
                else
                  for (var i = 0; i < dayStops.length; i++)
                    _StopRow(
                      stop: dayStops[i],
                      last: i == dayStops.length - 1,
                      onTap: () => Navigator.of(context).push(
                        AppTheme.slideRoute(
                          StopDetailScreen(trip: trip, stopId: dayStops[i].id),
                        ),
                      ),
                    ),

                // Add-a-stop, inset to line up with the cards
                if (dayStops.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 72, top: 8),
                    child: _DashedButton(
                      label: 'Add a stop',
                      onTap: () => _addStop(trip, activeDay),
                    ),
                  ),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────
          TripFooter(
            child: Row(
              children: [
                Expanded(
                  child: TripPrimaryButton(
                    label: 'Add stop',
                    icon: Icons.add_rounded,
                    height: 50,
                    onTap: () => _addStop(trip, activeDay),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => showSnackBar(
                    context,
                    'Trip expenses are coming — travellers are already set up',
                  ),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: DT.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        size: 20, color: DT.accentDeep),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusTint(TripStatus s) => switch (s) {
      TripStatus.tentative => DT.warning.withValues(alpha: 0.28),
      TripStatus.confirmed => DT.accent.withValues(alpha: 0.28),
      TripStatus.settled => Colors.white.withValues(alpha: 0.18),
    };

// ─── Header bits ──────────────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _TotalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TotalChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: DT.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DT.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Day tab ──────────────────────────────────────────────────────────────────

class _DayTab extends StatelessWidget {
  final int day;
  final DateTime date;
  final bool active;
  final VoidCallback onTap;

  const _DayTab({
    required this.day,
    required this.date,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? DT.text : DT.surface,
          borderRadius: BorderRadius.circular(14),
          border: active ? null : Border.all(color: DT.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DAY $day',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: active ? Colors.white70 : DT.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : DT.text,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              tripWeekdays[date.weekday - 1],
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white70 : DT.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timeline row ─────────────────────────────────────────────────────────────

class _StopRow extends StatelessWidget {
  final ItineraryStop stop;
  final bool last;
  final VoidCallback onTap;

  const _StopRow({
    required this.stop,
    required this.last,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ty = stopTypeStyle(stop.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time column
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Text(
                stop.time.replaceAll(' ', ''),
                textAlign: TextAlign.right,
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: DT.text,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Rail
          Column(
            children: [
              // 12px dot, a 3px bg ring, then a 1.5px ring in the type colour.
              Container(
                margin: const EdgeInsets.only(top: 15),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: ty.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: DT.bg, width: 3),
                  boxShadow: [
                    BoxShadow(color: ty.color, spreadRadius: 1.5, blurRadius: 0),
                  ],
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 2),
                    color: DT.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stop.hasLeg) ...[
                    LegPill(
                      label: stop.legLabel,
                      icon: TripGlyphs.icon(
                        stop.icon == 'ferry' ? 'ferry' : 'car',
                      ),
                    ),
                    const SizedBox(height: 7),
                  ],
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: DT.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: DT.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: ty.soft,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(TripGlyphs.icon(stop.icon),
                                size: 20, color: ty.color),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: DT.text,
                                    letterSpacing: -0.2,
                                    height: 1.25,
                                  ),
                                ),
                                if ((stop.note ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    stop.note!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: DT.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: DT.textTertiary),
                        ],
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
}

// ─── Empty day ────────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyDay({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DT.border),
          ),
          child: const Icon(Icons.route_outlined, size: 28, color: DT.textTertiary),
        ),
        const SizedBox(height: 14),
        Text(
          'Nothing planned yet',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: DT.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add the first stop for this day.',
          style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary),
        ),
        const SizedBox(height: 16),
        _DashedButton(label: 'Add a stop', onTap: onAdd),
      ],
    );
  }
}

// ─── Dashed add button ────────────────────────────────────────────────────────

class _DashedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DashedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const DashedBorderPainter(radius: 13, strokeWidth: 1.5),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 17, color: DT.textSecondary),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: DT.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

