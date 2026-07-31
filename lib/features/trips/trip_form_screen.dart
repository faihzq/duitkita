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

/// Creates a trip, or edits one when [editing] is supplied.
///
/// One screen for both: the fields are identical, and creation only differs in
/// where it goes afterwards.
class TripFormScreen extends ConsumerStatefulWidget {
  final TripModel? editing;

  const TripFormScreen({super.key, this.editing});

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _name = TextEditingController();
  final _destinations = <String>[];
  final _travellers = <TripTraveller>[];

  DateTime? _start;
  DateTime? _end;
  TripStatus _status = TripStatus.tentative;

  bool _saving = false;
  bool _seededSelf = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _name.text = e.name;
      _destinations.addAll(e.destinations);
      _travellers.addAll(e.travellers);
      _start = e.startDate;
      _end = e.endDate;
      _status = e.status;
      // The travellers came from the trip, so don't add the current user again.
      _seededSelf = true;
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _start != null && _end != null;

  /// Who owns the trip — the creator when editing, otherwise whoever is filling
  /// the form in. They cannot be removed from their own trip.
  String? get _organiserId =>
      widget.editing?.createdBy ??
      ref.read(authControllerProvider.notifier).currentUser?.uid;

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

  /// Shortening a trip can push existing stops past the last day, where the day
  /// tabs no longer reach them. Warn before that happens rather than silently
  /// hiding someone's planning.
  Future<bool> _confirmShortening() async {
    final trip = widget.editing;
    if (trip == null) return true;

    final newDayCount =
        DateTime(_end!.year, _end!.month, _end!.day)
                .difference(DateTime(_start!.year, _start!.month, _start!.day))
                .inDays +
            1;

    final stops =
        ref.read(tripStopsStreamProvider(trip.id)).valueOrNull ?? const [];
    final orphaned = stops.where((s) => s.day > newDayCount).length;
    if (orphaned == 0) return true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.cardRadius)),
        title: Text(
          'Shorten the trip?',
          style: GoogleFonts.manrope(
              fontSize: 16, fontWeight: FontWeight.w800, color: DT.text),
        ),
        content: Text(
          '$orphaned stop${orphaned == 1 ? '' : 's'} sit after the new end '
          'date. They stay saved, but you will not see them until you extend '
          'the trip again.',
          style: GoogleFonts.manrope(fontSize: 13.5, color: DT.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700, color: DT.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Shorten anyway',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700, color: DT.danger)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    if (_isEditing) return _update();

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

  Future<void> _update() async {
    final trip = widget.editing!;
    if (!await _confirmShortening()) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(tripServiceProvider).updateTrip(
            trip.copyWith(
              name: _name.text.trim(),
              destinations: _destinations,
              startDate: _start,
              endDate: _end,
              status: _status,
              travellerIds: _travellers.map((t) => t.userId).toList(),
              travellers: _travellers,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop();
        showSnackBar(context, 'Trip updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnackBar(context, 'Could not save the trip: $e', isError: true);
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
              title: _isEditing ? 'Edit trip' : 'New trip',
              sub: _isEditing ? widget.editing!.name : null,
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

                  // Named list, so travellers can be removed individually —
                  // the avatar stack alone gives nothing to tap. Always shown
                  // when editing, so it doesn't vanish as you remove people.
                  if (_isEditing || _travellers.length > 1)
                    TripField(
                      label: 'On this trip',
                      child: Column(
                        children: [
                          for (final t in _travellers)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TravellerRow(
                                traveller: t,
                                // The organiser stays: they own the trip, and
                                // removing them would orphan it.
                                isOrganiser: t.userId == _organiserId,
                                onRemove: () =>
                                    setState(() => _travellers.remove(t)),
                              ),
                            ),
                        ],
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
                label: _isEditing ? 'Save changes' : 'Create & add itinerary',
                icon: _isEditing
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                trailingIcon: !_isEditing,
                busy: _saving,
                onTap: _canSave ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Traveller row ────────────────────────────────────────────────────────────

class _TravellerRow extends StatelessWidget {
  final TripTraveller traveller;
  final bool isOrganiser;
  final VoidCallback onRemove;

  const _TravellerRow({
    required this.traveller,
    required this.isOrganiser,
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
          TripAvatar(
            name: traveller.name,
            imageUrl: traveller.photoUrl,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              traveller.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: DT.text,
              ),
            ),
          ),
          if (isOrganiser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DT.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Organiser',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: DT.textSecondary,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child:
                    Icon(Icons.close_rounded, size: 17, color: DT.textSecondary),
              ),
            ),
        ],
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
