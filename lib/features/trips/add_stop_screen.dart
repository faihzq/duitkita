import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/itinerary_stop.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/route_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/services/trip_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/features/trips/attachment_cache.dart';
import 'package:duitkita/features/trips/map_link.dart';
import 'package:duitkita/features/trips/trip_style.dart';
import 'package:duitkita/features/trips/trip_time_picker.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

/// Where a new stop starts when its day has nothing on it yet.
const _kFallbackTime = TimeOfDay(hour: 9, minute: 0);

/// Gap left after the day's last stop. Deliberately a flat number rather than
/// something type-aware — a predictable default is easier to correct than a
/// clever one that guesses wrong.
const _kGapMinutes = 30;

/// Create a stop, or edit one when [editing] is supplied.
class AddStopScreen extends ConsumerStatefulWidget {
  final TripModel trip;
  final int initialDay;
  final ItineraryStop? editing;

  const AddStopScreen({
    super.key,
    required this.trip,
    required this.initialDay,
    this.editing,
  });

  @override
  ConsumerState<AddStopScreen> createState() => _AddStopScreenState();
}

class _AddStopScreenState extends ConsumerState<AddStopScreen> {
  late int _day;
  late TimeOfDay _time;
  late StopType _type;
  late String _glyph;

  final _title = TextEditingController();
  final _place = TextEditingController();
  final _note = TextEditingController();
  final _about = TextEditingController();
  final _legMins = TextEditingController();
  final _legKm = TextEditingController();
  final _mapUrl = TextEditingController();

  bool _saving = false;
  bool _resolvingLink = false;
  bool _estimatingLeg = false;

  /// Already uploaded, loaded when editing.
  late List<StopAttachment> _attachments;

  /// Picked this session — uploaded once the stop doc exists.
  final _pendingFiles = <PlatformFile>[];

  /// Set once the user picks a time themselves, after which switching days
  /// must not overwrite their choice.
  bool _timeTouched = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _day = (e?.day ?? widget.initialDay).clamp(1, widget.trip.dayCount);
    _type = e?.type ?? StopType.travel;
    _glyph = e?.icon ?? defaultGlyphFor(_type);
    // Editing keeps the stop's own time; a new stop picks up where the day
    // left off, which is resolved once the stops stream is readable in build.
    _time = e != null ? _parseTime(e.time) : _kFallbackTime;
    _title.text = e?.title ?? '';
    _place.text = e?.placeQuery ?? '';
    _note.text = e?.note ?? '';
    _about.text = e?.about ?? '';
    _mapUrl.text = e?.mapUrl ?? '';
    _attachments = List.of(e?.attachments ?? const []);
    if ((e?.legMinutes ?? 0) > 0) _legMins.text = '${e!.legMinutes}';
    if ((e?.legKm ?? 0) > 0) _legKm.text = '${e!.legKm!.round()}';
    // Both drive the footer CTA and the leg-lookup button's enabled state.
    _title.addListener(() => setState(() {}));
    _place.addListener(() => setState(() {}));
    _mapUrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _note.dispose();
    _about.dispose();
    _legMins.dispose();
    _legKm.dispose();
    _mapUrl.dispose();
    super.dispose();
  }

  static TimeOfDay _parseTime(String label) {
    final m = minutesFromTimeLabel(label);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  /// [_kGapMinutes] after the day's last stop, or [_kFallbackTime] when the day
  /// is empty. Clamped to 23:59 so a late stop can't push the default past
  /// midnight and land the new stop at the top of the day.
  static TimeOfDay _defaultTimeFor(List<ItineraryStop> stops, int day) {
    var latest = -1;
    for (final s in stops) {
      if (s.day != day) continue;
      final m = minutesFromTimeLabel(s.time);
      if (m > latest) latest = m;
    }
    if (latest < 0) return _kFallbackTime;
    final m = (latest + _kGapMinutes).clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  /// The stop this leg is measured from: the latest one earlier in the day.
  /// Excludes the stop being edited, and anything with no mappable text.
  ItineraryStop? _previousStop(List<ItineraryStop> stops) {
    final now = _time.hour * 60 + _time.minute;
    ItineraryStop? best;
    var bestMinutes = -1;
    for (final s in stops) {
      if (s.day != _day || s.id == widget.editing?.id) continue;
      if (s.mapQuery.trim().isEmpty) continue;
      final m = minutesFromTimeLabel(s.time);
      if (m <= now && m > bestMinutes) {
        bestMinutes = m;
        best = s;
      }
    }
    return best;
  }

  /// Where this stop is, for the Maps lookup — the place if given, else the
  /// title, matching how [ItineraryStop.mapQuery] resolves on save.
  String get _legDestination {
    final place = _place.text.trim();
    return place.isNotEmpty ? place : _title.text.trim();
  }

  /// Asks the Routes API for this leg and fills the two fields. Traffic-aware
  /// when the previous stop's departure is still in the future.
  Future<void> _autoFillLeg(ItineraryStop previous) async {
    if (_estimatingLeg) return;
    setState(() => _estimatingLeg = true);
    try {
      final estimate = await ref.read(routeServiceProvider).computeLeg(
            origin: previous.mapQuery,
            destination: _legDestination,
            departAt: RouteService.departureAt(
              widget.trip.dateForDay(_day),
              previous.time,
            ),
          );
      if (!mounted) return;
      _legMins.text = '${estimate.minutes}';
      _legKm.text = '${estimate.km.round()}';
      showSnackBar(
        context,
        'Estimated ${formatDuration(estimate.minutes)} · '
        '${estimate.km.round()} km',
      );
    } on RouteFailure catch (e) {
      if (mounted) showSnackBar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _estimatingLeg = false);
    }
  }

  Future<void> _openLegInMaps(ItineraryStop previous) async {
    final url = TripMaps.leg(previous.mapQuery, _legDestination);
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showSnackBar(context, 'Could not open Google Maps', isError: true);
    }
  }

  /// Reduces the pasted share link to `lat,lng` and drops it into Place, so
  /// directions and the day route target the exact pin. The link itself is kept
  /// either way — it is what "Open in Maps" launches.
  Future<void> _pinFromLink() async {
    final url = _mapUrl.text.trim();
    if (url.isEmpty || _resolvingLink) return;

    setState(() => _resolvingLink = true);
    final coords = await resolveMapLink(url);
    if (!mounted) return;
    setState(() => _resolvingLink = false);

    if (coords == null) {
      showSnackBar(
        context,
        'Could not read a location from that link — it still opens fine, but '
        'directions will use the place name',
        isError: true,
      );
      return;
    }
    _place.text = coords;
    showSnackBar(context, 'Pinned to $coords');
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: StorageService.allowedExtensions,
    );
    if (result == null || !mounted) return;

    final tooBig = <String>[];
    final accepted = <PlatformFile>[];
    for (final f in result.files) {
      if (f.path == null) continue;
      if (f.size > StorageService.maxFileSizeBytes) {
        tooBig.add(f.name);
      } else {
        accepted.add(f);
      }
    }

    setState(() => _pendingFiles.addAll(accepted));
    if (tooBig.isNotEmpty) {
      showSnackBar(
        context,
        '${tooBig.join(', ')} — over the 10MB limit',
        isError: true,
      );
    }
  }

  /// Removes a already-uploaded attachment, dropping the Storage object and its
  /// cached copy too. Only persisted when the stop is saved.
  Future<void> _removeAttachment(StopAttachment attachment) async {
    setState(() => _attachments.remove(attachment));
    await ref.read(attachmentCacheProvider).evict(attachment);
    await ref.read(storageServiceProvider).deleteTripAttachment(attachment.url);
  }

  /// Uploads anything picked this session. The stop doc must exist first —
  /// its id is part of the Storage path.
  Future<List<StopAttachment>> _uploadPending(String stopId) async {
    if (_pendingFiles.isEmpty) return _attachments;

    final storage = ref.read(storageServiceProvider);
    final uploaded = <StopAttachment>[];
    for (final f in _pendingFiles) {
      try {
        final data = await storage.uploadTripAttachment(
          tripId: widget.trip.id,
          stopId: stopId,
          file: File(f.path!),
          fileName: f.name,
        );
        uploaded.add(StopAttachment.fromMap(data));
      } catch (_) {
        // Keep the stop and the other files; report at the end.
      }
    }
    if (uploaded.length < _pendingFiles.length && mounted) {
      final failed = _pendingFiles.length - uploaded.length;
      showSnackBar(context, '$failed attachment(s) failed to upload',
          isError: true);
    }
    return [..._attachments, ...uploaded];
  }

  Future<void> _pickTime() async {
    final picked = await showTripTimePicker(context: context, initial: _time);
    if (picked == null) return;
    // From here the time is the user's, so switching days must leave it alone.
    setState(() {
      _time = picked;
      _timeTouched = true;
    });
  }

  void _selectType(StopType t) {
    setState(() {
      // Keep a hand-picked glyph only while it still suits the new type.
      if (!TripGlyphs.forType(t).contains(_glyph)) _glyph = defaultGlyphFor(t);
      _type = t;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final service = ref.read(tripServiceProvider);
    final stop = ItineraryStop(
      id: widget.editing?.id ?? '',
      day: _day,
      order: _time.hour * 60 + _time.minute,
      time: formatTimeOfDay(_time),
      title: _title.text.trim(),
      note: _emptyToNull(_note.text),
      type: _type,
      icon: _glyph,
      placeQuery: _emptyToNull(_place.text),
      mapUrl: _emptyToNull(_mapUrl.text),
      about: _emptyToNull(_about.text),
      legMinutes: int.tryParse(_legMins.text.trim()),
      legKm: double.tryParse(_legKm.text.trim()),
      attachments: _attachments,
    );

    try {
      // Attachments upload under the stop's id, so the doc has to exist first;
      // a second write then attaches them.
      if (widget.editing != null) {
        await service.updateStop(widget.trip.id, stop);
        final all = await _uploadPending(stop.id);
        if (all.length != _attachments.length) {
          await service.updateStop(
              widget.trip.id, stop.copyWith(attachments: all));
        }
      } else {
        final newId = await service.addStop(widget.trip.id, stop);
        final all = await _uploadPending(newId);
        if (all.isNotEmpty) {
          await service.updateStop(
            widget.trip.id,
            stop.copyWith(attachments: all).withId(newId),
          );
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
        showSnackBar(
          context,
          widget.editing != null ? 'Stop updated' : 'Stop added',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnackBar(context, 'Could not save the stop: $e', isError: true);
      }
    }
  }

  static String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    final glyphs = TripGlyphs.forType(_type);

    // Resolve the default here rather than in initState: the stops stream may
    // not have emitted yet on open, and the day chips can change _day later.
    // Re-running while untouched is what makes switching days re-default.
    final stops =
        ref.watch(tripStopsStreamProvider(widget.trip.id)).valueOrNull;
    if (!editing && !_timeTouched && stops != null) {
      _time = _defaultTimeFor(stops, _day);
    }
    // Resolved after the time above, so the leg follows the chosen slot.
    final previous = _previousStop(stops ?? const []);

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TripBackHeader(
              title: editing ? 'Edit stop' : 'Add a stop',
              sub: widget.trip.name,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(DS.xl, 4, DS.xl, 20),
                children: [
                  // ── Day ─────────────────────────────────────
                  TripField(
                    label: 'Day',
                    child: SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.trip.dayCount,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final n = i + 1;
                          final date = widget.trip.dateForDay(n);
                          final active = n == _day;
                          return GestureDetector(
                            onTap: () => setState(() => _day = n),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: active ? DT.text : DT.surface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    active
                                        ? null
                                        : Border.all(color: DT.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: active ? Colors.white : DT.text,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    tripWeekdays[date.weekday - 1],
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          active
                                              ? Colors.white70
                                              : DT.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Time ────────────────────────────────────
                  TripField(
                    label: 'Time',
                    child: TripInput(
                      icon: Icons.schedule_outlined,
                      value: formatTimeOfDay(_time),
                      onTap: _pickTime,
                    ),
                  ),

                  // ── Title ───────────────────────────────────
                  TripField(
                    label: "What's happening?",
                    child: TripInput(
                      big: true,
                      child: TripTextField(
                        controller: _title,
                        placeholder: 'Ferry to Langkawi',
                        big: true,
                      ),
                    ),
                  ),

                  // ── Place ───────────────────────────────────
                  TripField(
                    label: 'Place',
                    hint: 'A name, an address, or coordinates like '
                        '2.0453, 102.5689 copied from a dropped pin',
                    child: TripInput(
                      icon: Icons.place_outlined,
                      child: TripTextField(
                        controller: _place,
                        placeholder: 'Jeti Kuala Perlis',
                        capitalization: TextCapitalization.words,
                        inputFormatters: const [TitleCaseFormatter()],
                      ),
                    ),
                  ),

                  // ── Map link ────────────────────────────────
                  TripField(
                    label: 'Map link (optional)',
                    hint: 'Share a place from Google Maps and paste it here — '
                        'more exact than a name, which can match the wrong spot',
                    child: Column(
                      children: [
                        TripInput(
                          icon: Icons.link_rounded,
                          child: TripTextField(
                            controller: _mapUrl,
                            placeholder: 'https://maps.app.goo.gl/…',
                            capitalization: TextCapitalization.none,
                          ),
                        ),
                        if (looksLikeMapUrl(_mapUrl.text)) ...[
                          const SizedBox(height: 8),
                          _PinFromLinkButton(
                            busy: _resolvingLink,
                            onTap: _pinFromLink,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Type ────────────────────────────────────
                  TripField(
                    label: 'Type',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in StopType.values)
                          _TypeChip(
                            type: t,
                            active: t == _type,
                            onTap: () => _selectType(t),
                          ),
                      ],
                    ),
                  ),

                  // ── Icon ────────────────────────────────────
                  TripField(
                    label: 'Icon',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in glyphs)
                          GestureDetector(
                            onTap: () => setState(() => _glyph = g),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    g == _glyph
                                        ? stopTypeStyle(_type).soft
                                        : DT.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      g == _glyph
                                          ? stopTypeStyle(_type).color
                                          : DT.border,
                                  width: g == _glyph ? 1.5 : 1,
                                ),
                              ),
                              child: Icon(
                                TripGlyphs.icon(g),
                                size: 20,
                                color:
                                    g == _glyph
                                        ? stopTypeStyle(_type).color
                                        : DT.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Drive estimate ──────────────────────────
                  TripField(
                    label: 'Drive from the previous stop (optional)',
                    hint:
                        'Feeds the day totals and the leg pill on the timeline',
                    child: Column(
                      children: [
                        if (previous != null) ...[
                          _AutoFillLegButton(
                            busy: _estimatingLeg,
                            enabled: _legDestination.isNotEmpty,
                            onTap: () => _autoFillLeg(previous),
                          ),
                          const SizedBox(height: 8),
                          _LegLookupButton(
                            from: previous.title,
                            departAt: previous.time,
                            enabled: _legDestination.isNotEmpty,
                            onTap: () => _openLegInMaps(previous),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TripInput(
                                icon: Icons.schedule_outlined,
                                child: _NumberField(
                                  controller: _legMins,
                                  placeholder: 'Minutes',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TripInput(
                                icon: Icons.directions_car_outlined,
                                child: _NumberField(
                                  controller: _legKm,
                                  placeholder: 'km',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Note ────────────────────────────────────
                  TripField(
                    label: 'Note (optional)',
                    child: TripInput(
                      child: TripTextField(
                        controller: _note,
                        placeholder:
                            'Book ferry tickets the night before — first boat fills up fast.',
                        maxLines: 3,
                      ),
                    ),
                  ),

                  // ── Tickets ─────────────────────────────────
                  TripField(
                    label: 'Tickets & documents (optional)',
                    hint: 'Entry tickets, bookings, ferry passes. Images and '
                        'PDFs up to 10MB — opened once, they stay available '
                        'offline.',
                    child: Column(
                      children: [
                        for (final a in _attachments)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AttachmentRow(
                              name: a.name,
                              detail: a.sizeLabel,
                              isPdf: a.isPdf,
                              onRemove: () => _removeAttachment(a),
                            ),
                          ),
                        for (final f in _pendingFiles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AttachmentRow(
                              name: f.name,
                              detail: 'Uploads when you save',
                              isPdf: f.extension?.toLowerCase() == 'pdf',
                              onRemove: () =>
                                  setState(() => _pendingFiles.remove(f)),
                            ),
                          ),
                        GestureDetector(
                          onTap: _pickAttachments,
                          child: CustomPaint(
                            painter:
                                const DashedBorderPainter(radius: 13, strokeWidth: 1.5),
                            child: Container(
                              height: 46,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: DT.surface,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.attach_file_rounded,
                                      size: 17, color: DT.textSecondary),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Attach a ticket',
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
                        ),
                      ],
                    ),
                  ),

                  // ── About ───────────────────────────────────
                  TripField(
                    label: 'About this place (optional)',
                    gap: 0,
                    child: TripInput(
                      child: TripTextField(
                        controller: _about,
                        placeholder:
                            'What is it, and why is it worth the stop?',
                        maxLines: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TripFooter(
              child: TripPrimaryButton(
                label: editing ? 'Save changes' : 'Save stop',
                icon: Icons.check_rounded,
                busy: _saving,
                onTap: _title.text.trim().isEmpty ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Type chip ────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final StopType type;
  final bool active;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ty = stopTypeStyle(type);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? ty.soft : DT.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? ty.color : DT.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TripGlyphs.icon(defaultGlyphFor(type)),
              size: 16,
              color: active ? ty.color : DT.textTertiary,
            ),
            const SizedBox(width: 7),
            Text(
              stopTypeLabel(type),
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? ty.color : DT.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pin from link ────────────────────────────────────────────────────────────

/// Expands the pasted share link and writes its coordinates into Place.
class _PinFromLinkButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _PinFromLinkButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: DT.accentSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: DT.accent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: DT.accentDeep),
              )
            else
              const Icon(Icons.my_location_rounded,
                  size: 17, color: DT.accentDeep),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                busy ? 'Reading link…' : 'Use exact location from this link',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: DT.accentDeep,
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

// ─── Attachment row ───────────────────────────────────────────────────────────

/// A ticket in the form — saved or still pending upload.
class _AttachmentRow extends StatelessWidget {
  final String name;
  final String detail;
  final bool isPdf;
  final VoidCallback onRemove;

  const _AttachmentRow({
    required this.name,
    required this.detail,
    required this.isPdf,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isPdf ? DT.dangerSoft : DT.infoSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
              size: 17,
              color: isPdf ? DT.danger : DT.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DT.text,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DT.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 17, color: DT.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Auto-fill leg ────────────────────────────────────────────────────────────

/// Fills the drive time and distance from the Google Routes API. The values
/// stay editable — it is a starting point, not a lock.
class _AutoFillLegButton extends StatelessWidget {
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const _AutoFillLegButton({
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = enabled && !busy;
    return GestureDetector(
      onTap: on ? onTap : null,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          color: on ? DT.text : DT.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
          border: on ? null : Border.all(color: DT.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(Icons.auto_awesome_outlined,
                  size: 17, color: on ? Colors.white : DT.textTertiary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                busy ? 'Asking Google Maps…' : 'Calculate drive automatically',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : DT.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Leg lookup ───────────────────────────────────────────────────────────────

/// Opens just this leg in Google Maps so the drive time and distance can be
/// read off and typed in. Maps deep links are one-way — nothing is returned —
/// so the two fields stay manual by design.
class _LegLookupButton extends StatelessWidget {
  final String from;

  /// The previous stop's time. Maps URLs have no `departure_time` parameter —
  /// only the Directions API does — so this is surfaced for the user to set
  /// via Maps' own "Depart at" control once the route opens.
  final String departAt;
  final bool enabled;
  final VoidCallback onTap;

  const _LegLookupButton({
    required this.from,
    required this.departAt,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? DT.accentDeep : DT.textTertiary;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: enabled ? DT.accentSoft : DT.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: enabled ? DT.accent : DT.border),
        ),
        child: Row(
          children: [
            Icon(Icons.route_outlined, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enabled ? 'Check this leg in Maps' : 'Add a place first',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    enabled
                        ? 'From “$from” — in Maps set “Depart at” to $departAt '
                            'for traffic, then type the time and distance below'
                        : 'Then you can measure the drive from “$from”',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: fg.withValues(alpha: 0.8),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 8),
              Icon(Icons.north_east_rounded, size: 16, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Numeric field ────────────────────────────────────────────────────────────

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;

  const _NumberField({required this.controller, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      cursorColor: DT.accent,
      style: GoogleFonts.manrope(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: DT.text,
        letterSpacing: -0.2,
      ),
      decoration: InputDecoration(
        isDense: true,
        // See TripTextField — the global InputDecorationTheme fills in any
        // border/fill left null, which double-borders the field.
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        hintText: placeholder,
        hintStyle: GoogleFonts.manrope(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: DT.textTertiary,
        ),
      ),
    );
  }
}
