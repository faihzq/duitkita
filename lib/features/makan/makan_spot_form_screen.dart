import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/makan_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/features/makan/makan_filter.dart';
import 'package:duitkita/features/makan/makan_geo.dart';
import 'package:duitkita/features/makan/makan_hours_editor.dart';
import 'package:duitkita/features/makan/makan_location.dart';
import 'package:duitkita/features/makan/makan_style.dart';
import 'package:duitkita/features/makan/makan_widgets.dart';
import 'package:duitkita/features/trips/map_link.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';
import 'package:duitkita/widgets/dk_toast.dart';

/// Add a spot, or edit [spot] when given.
class MakanSpotFormScreen extends ConsumerStatefulWidget {
  final MakanSpot? spot;
  const MakanSpotFormScreen({super.key, this.spot});

  @override
  ConsumerState<MakanSpotFormScreen> createState() =>
      _MakanSpotFormScreenState();
}

class _MakanSpotFormScreenState extends ConsumerState<MakanSpotFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final TextEditingController _menuInput;
  late final TextEditingController _map;
  late final TextEditingController _notes;
  late Set<String> _categories;
  late List<String> _menu;
  late WeeklyHours _hours;

  /// Where a new spot is saved: null for personal, else a group id. Fixed once
  /// created — moving between lists would mean a different document path.
  String? _groupId;
  bool _saving = false;

  /// A GPS pin taken while standing at the spot. Wins over coordinates read
  /// off the Maps link, since it is where the user actually ate.
  LatLng? _pin;
  bool _locating = false;

  Future<void> _pinHere() async {
    setState(() => _locating = true);
    final result = await currentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.position != null) _pin = result.position;
    });
    final problem = result.problem;
    if (problem != null) {
      final fixable =
          problem == LocationProblem.serviceOff ||
          problem == LocationProblem.deniedForever;
      DkToast.warning(
        context,
        locationProblemMessage(problem),
        actionLabel: fixable ? 'Settings' : null,
        onAction: fixable ? () => openFixFor(problem) : null,
      );
    }
  }

  bool get _editing => widget.spot != null;

  @override
  void initState() {
    super.initState();
    final s = widget.spot;
    _name = TextEditingController(text: s?.name ?? '');
    _area = TextEditingController(text: s?.area ?? '');
    _menuInput = TextEditingController();
    _map = TextEditingController(text: s?.mapLink ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _categories = {...?s?.categories};
    _menu = [...?s?.menu];
    _hours = {...?s?.hours};
    _groupId = s?.groupId;
    // Stored lat/lng is only a pin if it did not come from the link; otherwise
    // changing the link would leave the old coordinates behind.
    if (s != null && s.lat != null && s.lng != null) {
      final fromLink = parseLatLng(s.mapQuery);
      if (fromLink == null || fromLink.lat != s.lat || fromLink.lng != s.lng) {
        _pin = (lat: s.lat!, lng: s.lng!);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _menuInput.dispose();
    _map.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _addMenu() {
    // Commas let several dishes go in at once: "nasi lemak, roti canai".
    final items =
        _menuInput.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (items.isEmpty) return;
    setState(() {
      for (final item in items) {
        final exists = _menu.any((m) => m.toLowerCase() == item.toLowerCase());
        if (!exists) _menu.add(item);
      }
      _menuInput.clear();
    });
  }

  /// Turns whatever was pasted into a directions destination. A Maps link is
  /// resolved to coordinates or a place name; plain text is already a name.
  Future<String?> _resolveMap(String link) async {
    if (link.isEmpty) return null;
    final prev = widget.spot;
    if (prev != null && prev.mapLink == link) return prev.mapQuery;
    if (!looksLikeMapUrl(link)) return link;
    return (await resolveMapLink(link))?.query;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final area = _area.text.trim();
    if (name.isEmpty || area.isEmpty) {
      showSnackBar(context, 'Name and area are required', isError: true);
      return;
    }
    // Pick up a dish typed but not yet added.
    if (_menuInput.text.trim().isNotEmpty) _addMenu();

    final user = ref.read(authControllerProvider.notifier).currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final link = _map.text.trim();
      final query = await _resolveMap(link);
      final coords = _pin ?? parseLatLng(query);
      final notes = _notes.text.trim();
      final service = ref.read(makanServiceProvider);
      final prev = widget.spot;

      if (prev != null) {
        await service.updateSpot(
          MakanSpot(
            id: prev.id,
            groupId: prev.groupId,
            name: name,
            area: area,
            categories: _categories.toList(),
            menu: _menu,
            hours: _hours,
            mapLink: link.isEmpty ? null : link,
            mapQuery: query,
            lat: coords?.lat,
            lng: coords?.lng,
            notes: notes.isEmpty ? null : notes,
            addedBy: prev.addedBy,
            addedByName: prev.addedByName,
            createdAt: prev.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        final profile =
            ref.read(userProfileStreamProvider(user.uid)).valueOrNull;
        final now = DateTime.now();
        await service.addSpot(
          MakanSpot(
            id: '',
            name: name,
            area: area,
            categories: _categories.toList(),
            menu: _menu,
            hours: _hours,
            mapLink: link.isEmpty ? null : link,
            mapQuery: query,
            lat: coords?.lat,
            lng: coords?.lng,
            notes: notes.isEmpty ? null : notes,
            addedBy: user.uid,
            addedByName: profile?.name ?? user.displayName ?? '',
            createdAt: now,
            updatedAt: now,
          ),
          groupId: _groupId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnackBar(context, _editing ? 'Spot updated' : 'Spot added');
    } catch (e) {
      if (mounted) showSnackBar(context, 'Could not save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final groups =
        userId == null
            ? const <GroupModel>[]
            : ref.watch(userGroupsStreamProvider(userId)).valueOrNull ??
                const <GroupModel>[];
    final knownAreas =
        userId == null
            ? const <String>[]
            : makanAreas(
              ref.watch(allMakanSpotsProvider(userId)).valueOrNull ?? const [],
            );
    final typedArea = _area.text.trim().toLowerCase();
    final areaHints =
        knownAreas
            .where(
              (a) =>
                  a.toLowerCase() != typedArea &&
                  (typedArea.isEmpty || a.toLowerCase().contains(typedArea)),
            )
            .take(8)
            .toList();

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TripBackHeader(
              title: _editing ? 'Edit spot' : 'Add a spot',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(DS.xl, 0, DS.xl, 24),
                children: [
                  TripField(
                    label: 'Name',
                    child: TripInput(
                      big: true,
                      child: TripTextField(
                        controller: _name,
                        big: true,
                        placeholder: 'Warung Mak Teh',
                        capitalization: TextCapitalization.words,
                        inputFormatters: const [TitleCaseFormatter()],
                      ),
                    ),
                  ),
                  TripField(
                    label: 'Area',
                    gap: areaHints.isEmpty ? 16 : 8,
                    child: TripInput(
                      icon: Icons.place_outlined,
                      child: TripTextField(
                        controller: _area,
                        placeholder: 'Bangi',
                        capitalization: TextCapitalization.words,
                        inputFormatters: const [TitleCaseFormatter()],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  if (areaHints.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in areaHints)
                            MakanChip(
                              label: a,
                              selected: false,
                              onTap: () => setState(() => _area.text = a),
                            ),
                        ],
                      ),
                    ),

                  TripField(
                    label: 'Type of place',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (label, emoji) in makanCategories)
                          MakanChip(
                            label: '$emoji $label',
                            selected: _categories.contains(label),
                            onTap:
                                () => setState(() {
                                  if (!_categories.remove(label)) {
                                    _categories.add(label);
                                  }
                                }),
                          ),
                      ],
                    ),
                  ),

                  TripField(
                    label: 'Menu',
                    hint: 'Separate dishes with commas to add several at once.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TripInput(
                                icon: Icons.restaurant_menu_outlined,
                                child: TextField(
                                  controller: _menuInput,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _addMenu(),
                                  cursorColor: DT.accent,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: DT.text,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    hintText: 'Nasi lemak, roti canai',
                                    hintStyle: GoogleFonts.manrope(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                      color: DT.textTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TripIconButton(
                              icon: Icons.add_rounded,
                              onTap: _addMenu,
                            ),
                          ],
                        ),
                        if (_menu.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in _menu)
                                InputChip(
                                  label: Text(m),
                                  labelStyle: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: DT.text,
                                  ),
                                  backgroundColor: DT.surface,
                                  side: const BorderSide(color: DT.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  onDeleted:
                                      () => setState(() => _menu.remove(m)),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  TripField(
                    label: 'Opening hours',
                    hint:
                        'A closing time before the opening time means it '
                        'stays open past midnight.',
                    child: MakanHoursEditor(
                      initial: _hours,
                      onChanged: (h) => _hours = h,
                    ),
                  ),

                  TripField(
                    label: 'Location',
                    hint:
                        'Paste a Google Maps link or type the place name. '
                        'At the spot now? Pin it so "Near me" knows where it is.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TripInput(
                          icon: Icons.map_outlined,
                          child: TripTextField(
                            controller: _map,
                            placeholder: 'https://maps.app.goo.gl/…',
                            capitalization: TextCapitalization.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_pin == null)
                          MakanChip(
                            label: _locating ? 'Locating…' : '📍 I\'m here now',
                            selected: false,
                            onTap: _locating ? () {} : _pinHere,
                          )
                        else
                          Row(
                            children: [
                              const Icon(
                                Icons.push_pin_rounded,
                                size: 16,
                                color: DT.catMakan,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Pinned at ${_pin!.lat.toStringAsFixed(5)}, '
                                  '${_pin!.lng.toStringAsFixed(5)}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: DT.catMakan,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _pin = null),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  TripField(
                    label: 'Notes',
                    child: TripInput(
                      child: TripTextField(
                        controller: _notes,
                        placeholder: 'Parking susah lepas 1pm, try teh tarik',
                        maxLines: 3,
                      ),
                    ),
                  ),

                  if (!_editing && groups.isNotEmpty)
                    TripField(
                      label: 'Save to',
                      hint:
                          'Spots in a group list can be seen and edited by '
                          'everyone in that group.',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          MakanChip(
                            label: 'My spots',
                            selected: _groupId == null,
                            onTap: () => setState(() => _groupId = null),
                          ),
                          for (final g in groups)
                            MakanChip(
                              label: '${g.iconEmoji ?? '👥'} ${g.name}',
                              selected: _groupId == g.id,
                              onTap: () => setState(() => _groupId = g.id),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            TripFooter(
              child: TripPrimaryButton(
                label: _editing ? 'Save changes' : 'Add spot',
                busy: _saving,
                onTap: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
