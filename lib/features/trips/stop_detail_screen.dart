import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/itinerary_stop.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/trip_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/features/trips/add_stop_screen.dart';
import 'package:duitkita/features/trips/attachment_cache.dart';
import 'package:duitkita/features/trips/trip_style.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

/// What the place is, plus the two ways to open it in Google Maps.
class StopDetailScreen extends ConsumerWidget {
  final TripModel trip;
  final String stopId;

  const StopDetailScreen({super.key, required this.trip, required this.stopId});

  Future<void> _open(BuildContext context, Uri url) async {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showSnackBar(context, 'Could not open Google Maps', isError: true);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ItineraryStop stop,
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
              'Remove this stop?',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DT.text,
              ),
            ),
            content: Text(
              '“${stop.title}” will be removed from the itinerary.',
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                color: DT.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: DT.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Remove',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: DT.danger,
                  ),
                ),
              ),
            ],
          ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(tripServiceProvider).deleteStop(trip.id, stop.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        showSnackBar(context, 'Stop removed');
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Could not remove the stop: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(tripStopsStreamProvider(trip.id)).valueOrNull;
    ItineraryStop? stop;
    for (final s in stops ?? const <ItineraryStop>[]) {
      if (s.id == stopId) stop = s;
    }

    if (stop == null) {
      return Scaffold(
        backgroundColor: DT.bg,
        body: SafeArea(
          child:
              stops == null
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: DT.accent,
                      strokeWidth: 2,
                    ),
                  )
                  : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'This stop is no longer on the trip',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DT.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to itinerary'),
                        ),
                      ],
                    ),
                  ),
        ),
      );
    }

    final s = stop;
    final ty = stopTypeStyle(s.type);
    final about = s.about?.trim();

    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          // ── Navy hero ───────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: tripHeaderGradient),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  TripBackHeader(
                    onDark: true,
                    onBack: () => Navigator.of(context).pop(),
                    title: 'Stop details',
                    sub: trip.name,
                    // Only the organiser changes the plan; everyone else reads
                    // it. Enforced in firestore.rules — this just hides the
                    // controls rather than offering an action that would fail.
                    trailing:
                        !trip.isOrganiser(
                              ref
                                  .watch(authControllerProvider.notifier)
                                  .currentUser
                                  ?.uid,
                            )
                            ? null
                            : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TripIconButton(
                                  icon: Icons.edit_outlined,
                                  onDark: true,
                                  onTap:
                                      () => Navigator.of(context).push(
                                        AppTheme.slideRoute(
                                          AddStopScreen(
                                            trip: trip,
                                            initialDay: s.day,
                                            editing: s,
                                          ),
                                        ),
                                      ),
                                ),
                                const SizedBox(width: 8),
                                TripIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  onDark: true,
                                  onTap: () => _confirmDelete(context, ref, s),
                                ),
                              ],
                            ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            TripGlyphs.icon(s.icon),
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      stopTypeLabel(s.type),
                                      style: GoogleFonts.manrope(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.schedule_outlined,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    s.time,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(DS.xl, 18, DS.xl, 20),
              children: [
                // Location card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: DT.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DT.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: DT.accentDeep,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LOCATION',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: DT.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.placeLabel,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: DT.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (s.hasLeg) ...[
                        const SizedBox(width: 10),
                        LegPill(
                          label: s.legLabel,
                          large: true,
                          icon: TripGlyphs.icon(
                            s.icon == 'ferry' ? 'ferry' : 'car',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // About
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                  child: Text(
                    'ABOUT THIS PLACE',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: DT.textSecondary,
                    ),
                  ),
                ),
                Text(
                  (about != null && about.isNotEmpty)
                      ? about
                      : _fallbackAbout(s.type),
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: DT.text,
                  ),
                ),

                // Tickets & documents
                if (s.hasTickets) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                    child: Text(
                      'TICKETS & DOCUMENTS',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: DT.textSecondary,
                      ),
                    ),
                  ),
                  for (final a in s.attachments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AttachmentTile(attachment: a),
                    ),
                ],

                // Stylised map preview — swap for a real static map later.
                const SizedBox(height: 20),
                _MapPreview(accent: ty.color),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────
          TripFooter(
            child: Row(
              children: [
                // 5 : 6 is the design's `flex: 1` / `flex: 1.2`, which
                // Expanded can't take as a fraction.
                Expanded(
                  flex: 5,
                  child: _FooterLink(
                    label: 'Open in Maps',
                    icon: Icons.place_outlined,
                    // Uses the saved share link when there is one, so this
                    // reopens the exact pin rather than searching by name.
                    onTap: () => _open(context, s.openUri),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: _FooterLink(
                    label: 'Directions',
                    icon: Icons.directions_car_outlined,
                    primary: true,
                    onTap:
                        () => _open(context, TripMaps.directions(s.mapQuery)),
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

String _fallbackAbout(StopType t) => switch (t) {
  StopType.travel =>
    'A leg of the journey — open the map to navigate and gauge drive time.',
  StopType.food => 'A food stop on the route — tap directions to find it.',
  StopType.sight => 'A stop worth a visit — open the map to see what’s around.',
  StopType.stay => 'Tonight’s stay — tap directions to drive there.',
  StopType.prayer => 'A short break on the road.',
};

// ─── Attachment tile ──────────────────────────────────────────────────────────

/// One ticket. Opens the cached copy when there is one, otherwise downloads it
/// first and keeps it — so a ticket viewed once is available at the gate with
/// no signal.
class _AttachmentTile extends ConsumerStatefulWidget {
  final StopAttachment attachment;
  const _AttachmentTile({required this.attachment});

  @override
  ConsumerState<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends ConsumerState<_AttachmentTile> {
  bool _busy = false;
  bool _offlineReady = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    final file = await ref
        .read(attachmentCacheProvider)
        .cached(widget.attachment);
    if (mounted) setState(() => _offlineReady = file != null);
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ref
          .read(attachmentCacheProvider)
          .resolve(widget.attachment);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _offlineReady = true;
      });
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        showSnackBar(
          context,
          'No app on this phone can open that file',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showSnackBar(
          context,
          'Could not download that ticket — connect and try once, and it will '
          'stay available offline',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                color: a.isPdf ? DT.dangerSoft : DT.infoSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                a.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                size: 19,
                color: a.isPdf ? DT.danger : DT.info,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (a.sizeLabel.isNotEmpty)
                        Text(
                          a.sizeLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: DT.textSecondary,
                          ),
                        ),
                      if (_offlineReady) ...[
                        if (a.sizeLabel.isNotEmpty)
                          Text(
                            ' · ',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              color: DT.textTertiary,
                            ),
                          ),
                        const Icon(
                          Icons.offline_pin_outlined,
                          size: 13,
                          color: DT.accentDeep,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Available offline',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: DT.accentDeep,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DT.accent,
                ),
              )
            else
              const Icon(
                Icons.open_in_new_rounded,
                size: 17,
                color: DT.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Footer link ──────────────────────────────────────────────────────────────

class _FooterLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _FooterLink({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: primary ? DT.text : DT.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: DT.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: primary ? Colors.white : DT.text),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primary ? Colors.white : DT.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stylised map preview ─────────────────────────────────────────────────────

/// Placeholder for a real map: a gradient panel with faint road lines and a
/// centred pin. Swap for a static-map image or `google_maps_flutter` mini-map.
class _MapPreview extends StatelessWidget {
  final Color accent;
  const _MapPreview({required this.accent});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 128,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DT.accentSoft, DT.primarySoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: DT.border),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _RoadsPainter())),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Icon(
                  Icons.place_outlined,
                  size: 38,
                  color: DT.accentDeep,
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Approx. location · tap below to open',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: DT.textSecondary,
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

class _RoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Curves are authored against a 360×128 box and scaled to fit.
    final sx = size.width / 360, sy = size.height / 128;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    void road(Path path, Color color, double width) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    road(
      Path()
        ..moveTo(-10 * sx, 40 * sy)
        ..cubicTo(
          p(60, 20).dx,
          p(60, 20).dy,
          p(90, 70).dx,
          p(90, 70).dy,
          p(160, 55).dx,
          p(160, 55).dy,
        )
        ..cubicTo(
          p(230, 40).dx,
          p(230, 40).dy,
          p(300, 20).dx,
          p(300, 20).dy,
          p(380, 46).dx,
          p(380, 46).dy,
        ),
      DT.borderStrong,
      6,
    );
    road(
      Path()
        ..moveTo(-10 * sx, 95 * sy)
        ..cubicTo(
          p(80, 80).dx,
          p(80, 80).dy,
          p(120, 110).dx,
          p(120, 110).dy,
          p(200, 92).dx,
          p(200, 92).dy,
        )
        ..cubicTo(
          p(280, 74).dx,
          p(280, 74).dy,
          p(320, 70).dx,
          p(320, 70).dy,
          p(380, 96).dx,
          p(380, 96).dy,
        ),
      DT.border,
      10,
    );
    road(
      Path()
        ..moveTo(110 * sx, -10 * sy)
        ..cubicTo(
          p(120, 40).dx,
          p(120, 40).dy,
          p(90, 80).dx,
          p(90, 80).dy,
          p(130, 138).dx,
          p(130, 138).dy,
        ),
      DT.border,
      5,
    );
  }

  @override
  bool shouldRepaint(_RoadsPainter oldDelegate) => false;
}
