import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/itinerary_stop.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/trip_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/features/trips/itinerary_import.dart';
import 'package:duitkita/features/trips/trip_style.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

const _kExample = '''Day 1
12:30 PM Ibu departs Muar
3:00 PM Arrive Kajang - Pick up Angah
6:00 PM Maghrib at R&R Tapah

Day 2
8:45 AM Breakfast — Fizzy Cafe
10:00 AM Ferry to Langkawi @ Jeti Kuala Perlis''';

/// Paste a written itinerary and turn it into stops, rather than filling the
/// form in one stop at a time.
class ImportItineraryScreen extends ConsumerStatefulWidget {
  final TripModel trip;

  /// Lines before any "Day N" header land here.
  final int initialDay;

  const ImportItineraryScreen({
    super.key,
    required this.trip,
    required this.initialDay,
  });

  @override
  ConsumerState<ImportItineraryScreen> createState() =>
      _ImportItineraryScreenState();
}

class _ImportItineraryScreenState extends ConsumerState<ImportItineraryScreen> {
  final _text = TextEditingController();
  bool _reviewing = false;
  bool _saving = false;

  ImportResult _result = const ImportResult(stops: [], skipped: []);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    final result = parseItinerary(_text.text, startDay: widget.initialDay);
    if (result.isEmpty) {
      showSnackBar(
        context,
        'No stops found — each line needs a time, like "10:00 AM Ferry"',
        isError: true,
      );
      return;
    }
    setState(() {
      _result = result;
      _reviewing = true;
    });
  }

  /// Stops beyond the last day would be invisible behind the day tabs, so they
  /// are dropped rather than written where they cannot be seen.
  List<ParsedStop> get _importable =>
      _result.stops.where((s) => s.day <= widget.trip.dayCount).toList();

  int get _beyondTrip => _result.stops.length - _importable.length;

  Future<void> _import() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final count = await ref
          .read(tripServiceProvider)
          .addStops(
            widget.trip.id,
            _importable.map((s) => s.toStop()).toList(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        showSnackBar(context, 'Added $count stop${count == 1 ? '' : 's'}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnackBar(context, 'Could not import: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TripBackHeader(
              title: _reviewing ? 'Review import' : 'Paste itinerary',
              sub: widget.trip.name,
              onBack:
                  () =>
                      _reviewing
                          ? setState(() => _reviewing = false)
                          : Navigator.of(context).pop(),
            ),
            Expanded(child: _reviewing ? _buildReview() : _buildPaste()),
            TripFooter(
              child:
                  _reviewing
                      ? TripPrimaryButton(
                        label:
                            _importable.isEmpty
                                ? 'Nothing to import'
                                : 'Add ${_importable.length} stop'
                                    '${_importable.length == 1 ? '' : 's'}',
                        icon: Icons.check_rounded,
                        busy: _saving,
                        onTap: _importable.isEmpty ? null : _import,
                      )
                      : TripPrimaryButton(
                        label: 'Read itinerary',
                        icon: Icons.arrow_forward_rounded,
                        trailingIcon: true,
                        onTap: _text.text.trim().isEmpty ? null : _parse,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paste ───────────────────────────────────────────────────────────────

  Widget _buildPaste() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DS.xl, 4, DS.xl, 20),
      children: [
        TripField(
          label: 'Your itinerary',
          hint:
              'One stop per line, each starting with a time. '
              '"Day 2" on its own line moves to the next day.',
          child: TripInput(
            child: TripTextField(
              controller: _text,
              placeholder: _kExample,
              maxLines: 14,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DT.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DT.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHAT IT UNDERSTANDS',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: DT.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              for (final line in const [
                ['10:00 AM · 8.45am · 18:30', 'any of these time formats'],
                ['Day 2', 'starts a new day'],
                ['… - Pick up Angah', 'text after a dash becomes the note'],
                ['… @ Jeti Kuala Perlis', 'text after @ becomes the place'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          line[0],
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: DT.text,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Text(
                          line[1],
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            color: DT.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'The type of each stop is guessed from the wording — you can '
                'change any of it afterwards.',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  color: DT.textTertiary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Review ──────────────────────────────────────────────────────────────

  Widget _buildReview() {
    final byDay = <int, List<ParsedStop>>{};
    for (final s in _importable) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }
    final days = byDay.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(DS.xl, 8, DS.xl, 20),
      children: [
        if (_beyondTrip > 0)
          _Warning(
            text:
                '$_beyondTrip stop${_beyondTrip == 1 ? '' : 's'} fall beyond '
                'day ${widget.trip.dayCount}, the last day of this trip, and '
                'will not be imported. Extend the trip first to keep them.',
          ),
        if (_result.skipped.isNotEmpty)
          _Warning(
            text:
                '${_result.skipped.length} line'
                '${_result.skipped.length == 1 ? '' : 's'} had no time and were '
                'skipped: ${_result.skipped.take(3).map((s) => '"${s.text}"').join(', ')}'
                '${_result.skipped.length > 3 ? '…' : ''}',
          ),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Text(
              'Day $day · ${formatDayLabel(widget.trip.dateForDay(day))}',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: DT.text,
                letterSpacing: -0.3,
              ),
            ),
          ),
          for (final stop in byDay[day]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PreviewRow(stop: stop),
            ),
        ],
      ],
    );
  }
}

// ─── Preview row ──────────────────────────────────────────────────────────────

class _PreviewRow extends StatelessWidget {
  final ParsedStop stop;
  const _PreviewRow({required this.stop});

  @override
  Widget build(BuildContext context) {
    final ty = stopTypeStyle(stop.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              stop.time.replaceAll(' ', ''),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: DT.text,
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ty.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              TripGlyphs.icon(defaultGlyphFor(stop.type)),
              size: 17,
              color: ty.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DT.text,
                  ),
                ),
                if (stop.note != null || stop.place != null)
                  Text(
                    [
                      if (stop.note != null) stop.note!,
                      if (stop.place != null) '📍 ${stop.place}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: DT.textSecondary,
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

// ─── Warning ──────────────────────────────────────────────────────────────────

class _Warning extends StatelessWidget {
  final String text;
  const _Warning({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: DT.warningSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: DT.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 17, color: DT.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: DT.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
