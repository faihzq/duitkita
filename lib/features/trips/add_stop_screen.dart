import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/itinerary_stop.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/trip_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/features/trips/trip_style.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

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

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _day = (e?.day ?? widget.initialDay).clamp(1, widget.trip.dayCount);
    _type = e?.type ?? StopType.travel;
    _glyph = e?.icon ?? defaultGlyphFor(_type);
    _time = e != null
        ? _parseTime(e.time)
        : const TimeOfDay(hour: 9, minute: 0);
    _title.text = e?.title ?? '';
    _place.text = e?.placeQuery ?? '';
    _note.text = e?.note ?? '';
    _about.text = e?.about ?? '';
    if ((e?.legMinutes ?? 0) > 0) _legMins.text = '${e!.legMinutes}';
    if ((e?.legKm ?? 0) > 0) _legKm.text = '${e!.legKm!.round()}';
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _note.dispose();
    _about.dispose();
    _legMins.dispose();
    _legKm.dispose();
    super.dispose();
  }

  static TimeOfDay _parseTime(String label) {
    final m = minutesFromTimeLabel(label);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
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
      about: _emptyToNull(_about.text),
      legMinutes: int.tryParse(_legMins.text.trim()),
      legKm: double.tryParse(_legKm.text.trim()),
    );

    try {
      if (widget.editing != null) {
        await service.updateStop(widget.trip.id, stop);
      } else {
        await service.addStop(widget.trip.id, stop);
      }
      if (mounted) {
        Navigator.of(context).pop();
        showSnackBar(context, widget.editing != null ? 'Stop updated' : 'Stop added');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnackBar(context, 'Could not save the stop: $e', isError: true);
      }
    }
  }

  static String? _emptyToNull(String s) =>
      s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    final glyphs = TripGlyphs.forType(_type);

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
                                  horizontal: 13, vertical: 9),
                              decoration: BoxDecoration(
                                color: active ? DT.text : DT.surface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    active ? null : Border.all(color: DT.border),
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
                                      color: active
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
                      icon: Icons.schedule_rounded,
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
                    hint: 'Add a location so everyone can navigate there',
                    child: TripInput(
                      icon: Icons.place_rounded,
                      child: TripTextField(
                        controller: _place,
                        placeholder: 'Jeti Kuala Perlis',
                      ),
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
                                color: g == _glyph
                                    ? stopTypeStyle(_type).soft
                                    : DT.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: g == _glyph
                                      ? stopTypeStyle(_type).color
                                      : DT.border,
                                  width: g == _glyph ? 1.5 : 1,
                                ),
                              ),
                              child: Icon(
                                TripGlyphs.icon(g),
                                size: 20,
                                color: g == _glyph
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
                    hint: 'Feeds the day totals and the leg pill on the timeline',
                    child: Row(
                      children: [
                        Expanded(
                          child: TripInput(
                            icon: Icons.schedule_rounded,
                            child: _NumberField(
                              controller: _legMins,
                              placeholder: 'Minutes',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TripInput(
                            icon: Icons.directions_car_rounded,
                            child: _NumberField(
                              controller: _legKm,
                              placeholder: 'km',
                            ),
                          ),
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
        border: InputBorder.none,
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
