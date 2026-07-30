import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/trip_model.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/trip_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/features/trips/itinerary_screen.dart';
import 'package:duitkita/features/trips/trip_date_picker.dart';
import 'package:duitkita/features/trips/trip_style.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

/// Creates the trip shell — the itinerary is filled in on the next screen.
class NewTripScreen extends ConsumerStatefulWidget {
  const NewTripScreen({super.key});

  @override
  ConsumerState<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends ConsumerState<NewTripScreen> {
  final _name = TextEditingController();
  final _destinations = <String>[];
  final _travellers = <TripTraveller>[];

  DateTime? _start;
  DateTime? _end;
  TripStatus _status = TripStatus.tentative;

  bool _saving = false;
  bool _seededSelf = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _name.text.trim().isNotEmpty && _start != null && _end != null;

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_start ?? now)
        : (_end ?? _start ?? now);
    final picked = await showTripDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: isStart ? 'TRIP STARTS' : 'TRIP ENDS',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // Keep the range valid — an end before the start makes no sense.
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
        if (_start != null && picked.isBefore(_start!)) _start = picked;
      }
    });
  }

  Future<void> _addDestination() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const _TextPromptDialog(
        title: 'Add a destination',
        hint: 'Kedah',
      ),
    );
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    if (!_destinations.contains(v)) setState(() => _destinations.add(v));
  }

  Future<void> _addTraveller() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _TextPromptDialog(
        title: 'Add a traveller',
        hint: 'name@email.com',
        keyboardType: TextInputType.emailAddress,
      ),
    );
    final v = email?.trim();
    if (v == null || v.isEmpty) return;

    final profiles = ref.read(profileServiceProvider);
    try {
      final uid = await profiles.getUserIdByEmail(v);
      if (uid == null) {
        if (mounted) {
          showSnackBar(context, 'No DuitKita account for $v', isError: true);
        }
        return;
      }
      if (_travellers.any((t) => t.userId == uid)) {
        if (mounted) showSnackBar(context, 'They are already on this trip');
        return;
      }
      final p = await profiles.getUserProfile(uid);
      if (!mounted) return;
      setState(() => _travellers.add(TripTraveller(
            userId: uid,
            name: p?.name ?? v.split('@').first,
            photoUrl: p?.profileImageUrl,
          )));
    } catch (e) {
      if (mounted) showSnackBar(context, 'Could not add them: $e', isError: true);
    }
  }

  Future<void> _create() async {
    if (!_canCreate || _saving) return;
    final me = ref.read(authControllerProvider.notifier).currentUser;
    if (me == null) {
      showSnackBar(context, 'You are not signed in', isError: true);
      return;
    }
    setState(() => _saving = true);
    // The design has no cover picker — the card emoji and colour band are
    // derived from the trip name, so they stay stable and vary between trips.
    final seed = _name.text.trim();
    try {
      final tripId = await ref.read(tripServiceProvider).createTrip(
            name: _name.text,
            createdBy: me.uid,
            startDate: _start!,
            endDate: _end!,
            destinations: _destinations,
            status: _status,
            emoji: autoTripEmoji(seed),
            bandGradient: TripBands.autoKey(seed),
            travellers: _travellers,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppTheme.slideRoute(ItineraryScreen(tripId: tripId)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnackBar(context, 'Could not create the trip: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The creator is always traveller #1 — seed them as soon as the profile
    // stream has a name, before the user touches anything.
    final me = ref.watch(authControllerProvider.notifier).currentUser;
    if (!_seededSelf && me != null) {
      final profile = ref.watch(userProfileStreamProvider(me.uid)).valueOrNull;
      final name = profile?.name ??
          me.displayName ??
          me.email?.split('@').first ??
          'You';
      _seededSelf = true;
      _travellers.add(TripTraveller(
        userId: me.uid,
        name: name,
        photoUrl: profile?.profileImageUrl,
      ));
    }

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TripBackHeader(
              title: 'New trip',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(DS.xl, 4, DS.xl, 20),
                children: [
                  // ── Name ────────────────────────────────────
                  TripField(
                    label: 'Trip name',
                    child: TripInput(
                      icon: Icons.edit_outlined,
                      big: true,
                      child: TripTextField(
                        controller: _name,
                        placeholder: 'Langkawi Road Trip',
                        capitalization: TextCapitalization.words,
                        inputFormatters: const [TitleCaseFormatter()],
                        big: true,
                      ),
                    ),
                  ),

                  // ── Destinations ────────────────────────────
                  TripField(
                    label: 'Destinations',
                    hint: "Tap to add each state or city you'll pass through",
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in _destinations)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _destinations.remove(d)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: DT.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.place_outlined,
                                      size: 14, color: DT.accentDeep),
                                  const SizedBox(width: 6),
                                  Text(
                                    d,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: DT.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: _addDestination,
                          child: CustomPaint(
                            painter: const DashedBorderPainter(radius: 999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: DT.surface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded,
                                      size: 14, color: DT.textSecondary),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Add',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
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

                  // ── Dates ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TripField(
                          label: 'Start date',
                          child: TripInput(
                            icon: Icons.calendar_today_outlined,
                            value:
                                _start == null ? null : formatTripDate(_start!),
                            placeholder: 'Pick a date',
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TripField(
                          label: 'End date',
                          child: TripInput(
                            icon: Icons.calendar_today_outlined,
                            value: _end == null ? null : formatTripDate(_end!),
                            placeholder: 'Pick a date',
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Travellers ──────────────────────────────
                  TripField(
                    label: 'Travellers',
                    hint: "They'll see the itinerary and share trip costs",
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: DT.surface,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: DT.border),
                      ),
                      child: Row(
                        children: [
                          TravellerAvatarStack(
                              travellers: _travellers, size: 34),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_travellers.length} added',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: DT.text,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _addTraveller,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: DT.accentSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  size: 18, color: DT.accentDeep),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Status ──────────────────────────────────
                  TripField(
                    label: 'Status',
                    gap: 0,
                    child: Row(
                      children: [
                        for (final s in [
                          TripStatus.tentative,
                          TripStatus.confirmed
                        ])
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: s == TripStatus.tentative ? 8 : 0),
                              child: GestureDetector(
                                onTap: () => setState(() => _status = s),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color:
                                        s == _status ? DT.text : DT.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: s == _status
                                        ? null
                                        : Border.all(color: DT.border),
                                  ),
                                  child: Center(
                                    child: Text(
                                      tripStatusLabel(s),
                                      style: GoogleFonts.manrope(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: s == _status
                                            ? Colors.white
                                            : DT.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TripFooter(
              child: TripPrimaryButton(
                label: 'Create & add itinerary',
                icon: Icons.arrow_forward_rounded,
                trailingIcon: true,
                busy: _saving,
                onTap: _canCreate ? _create : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Prompt dialog ────────────────────────────────────────────────────────────

/// Owns its own controller. A caller-created controller disposed right after
/// `showDialog` returns trips a `_dependents.isEmpty` assertion, because the
/// field is still mounted through the dialog's exit transition.
class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final TextInputType? keyboardType;

  const _TextPromptDialog({
    required this.title,
    required this.hint,
    this.keyboardType,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final hint = widget.hint;
    final keyboardType = widget.keyboardType;
    final controller = _controller;

    return AlertDialog(
      backgroundColor: DT.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.cardRadius)),
      title: Text(
        title,
        style: GoogleFonts.manrope(
            fontSize: 16, fontWeight: FontWeight.w800, color: DT.text),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboardType,
        textCapitalization: keyboardType == TextInputType.emailAddress
            ? TextCapitalization.none
            : TextCapitalization.words,
        cursorColor: DT.accent,
        style: GoogleFonts.manrope(
            fontSize: 15, fontWeight: FontWeight.w700, color: DT.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
              fontSize: 15, fontWeight: FontWeight.w500, color: DT.textTertiary),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: DT.border)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: DT.accent)),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700, color: DT.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text('Add',
              style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700, color: DT.accentDeep)),
        ),
      ],
    );
  }
}
