import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/makan_service.dart';
import 'package:duitkita/features/makan/makan_filter.dart';
import 'package:duitkita/features/makan/makan_geo.dart';
import 'package:duitkita/features/makan/makan_hours.dart';
import 'package:duitkita/features/makan/makan_location.dart';
import 'package:duitkita/features/makan/makan_spot_detail_screen.dart';
import 'package:duitkita/features/makan/makan_spot_form_screen.dart';
import 'package:duitkita/features/makan/makan_widgets.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';
import 'package:duitkita/widgets/dk_toast.dart';

/// Entry point for the Makan module: where to eat right now, or for a meal.
class MakanListScreen extends ConsumerStatefulWidget {
  const MakanListScreen({super.key});

  @override
  ConsumerState<MakanListScreen> createState() => _MakanListScreenState();
}

class _MakanListScreenState extends ConsumerState<MakanListScreen> {
  final _search = TextEditingController();
  final _random = Random();
  Timer? _tick;
  DateTime _now = DateTime.now();

  MealPeriod? _meal;
  bool _anyTime = false;
  String? _area;
  String? _source;

  /// "Near me": sorted by distance from [_here]. The position is read once per
  /// toggle (and on refresh), not tracked — a meal decision, not navigation.
  bool _nearMe = false;
  bool _locating = false;
  LatLng? _here;

  Future<void> _toggleNearMe() async {
    HapticFeedback.selectionClick();
    if (_nearMe) {
      setState(() => _nearMe = false);
      return;
    }
    await _locate();
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await currentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.position != null) {
        _here = result.position;
        _nearMe = true;
      }
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

  @override
  void initState() {
    super.initState();
    // "Open now" goes stale while the screen sits open; re-check each minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setWhen({MealPeriod? meal, bool anyTime = false}) {
    HapticFeedback.selectionClick();
    setState(() {
      _meal = meal;
      _anyTime = anyTime;
      _now = DateTime.now();
    });
  }

  void _open(MakanSpot s) {
    Navigator.of(context).push(
      AppTheme.slideRoute(
        MakanSpotDetailScreen(spotId: s.id, groupId: s.groupId),
      ),
    );
  }

  void _new() {
    Navigator.of(
      context,
    ).push(AppTheme.slideRoute(const MakanSpotFormScreen()));
  }

  String _heading(int count) {
    if (_anyTime) return 'All spots · $count';
    final meal = _meal;
    if (meal == null) return 'Open now · $count';
    final day = mealDay(meal, _now);
    final today = DateTime(_now.year, _now.month, _now.day);
    final diff = day.difference(today).inDays;
    final when = switch (diff) {
      0 => meal == MealPeriod.supper ? 'tonight' : 'today',
      1 => 'tomorrow',
      _ => 'last night',
    };
    return '${meal.label} $when · $count';
  }

  Future<void> _pickArea(List<String> areas) async {
    final picked = await _showOptions(
      title: 'Area',
      options: [('', 'All areas'), for (final a in areas) (a, a)],
      selected: _area ?? '',
    );
    if (picked == null) return;
    setState(() => _area = picked.isEmpty ? null : picked);
  }

  Future<void> _pickSource(List<GroupModel> groups) async {
    final picked = await _showOptions(
      title: 'List',
      options: [
        ('', 'All lists'),
        (makanSourceMine, 'My spots'),
        for (final g in groups) (g.id, g.name),
      ],
      selected: _source ?? '',
    );
    if (picked == null) return;
    setState(() => _source = picked.isEmpty ? null : picked);
  }

  Future<String?> _showOptions({
    required String title,
    required List<(String, String)> options,
    required String selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => _Sheet(
            title: title,
            child: Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final (value, label) in options)
                    ListTile(
                      onTap: () => Navigator.pop(ctx, value),
                      title: Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: DT.text,
                        ),
                      ),
                      trailing:
                          value == selected
                              ? const Icon(
                                Icons.check_rounded,
                                color: DT.accentDeep,
                              )
                              : null,
                    ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _pickForMe(
    List<MakanSpot> pool,
    Map<String, String> groupNames,
  ) async {
    if (pool.isEmpty) return;
    HapticFeedback.mediumImpact();
    var pick = pool[_random.nextInt(pool.length)];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheet) => _Sheet(
                  title: 'How about…',
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(DS.xl, 4, DS.xl, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MakanSpotCard(
                          spot: pick,
                          now: _now,
                          groupName: groupNames[pick.groupId],
                          onTap: () {
                            Navigator.pop(ctx);
                            _open(pick);
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (pool.length > 1) ...[
                              Expanded(
                                child: _OutlineButton(
                                  label: 'Pick again',
                                  icon: Icons.casino_outlined,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    final others =
                                        pool.where((s) => s != pick).toList();
                                    setSheet(
                                      () =>
                                          pick =
                                              others[_random.nextInt(
                                                others.length,
                                              )],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: TripPrimaryButton(
                                label: 'Let\'s go',
                                height: 48,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _open(pick);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final spotsAsync = ref.watch(allMakanSpotsProvider(userId));
    final spots = spotsAsync.valueOrNull ?? const <MakanSpot>[];
    final groups =
        ref.watch(userGroupsStreamProvider(userId)).valueOrNull ??
        const <GroupModel>[];
    final groupNames = {for (final g in groups) g.id: g.name};

    final result = filterSpots(
      spots,
      MakanQuery(
        meal: _meal,
        anyTime: _anyTime,
        area: _area,
        source: _source,
        text: _search.text,
      ),
      _now,
    );
    final distances =
        _nearMe && _here != null
            ? distancesFrom(_here!, spots)
            : const <String, double>{};
    final available =
        _nearMe
            ? sortByDistance(result.available, distances)
            : result.available;
    final unavailable =
        _nearMe
            ? sortByDistance(result.unavailable, distances)
            : result.unavailable;
    // With "Near me" on, "Pick for me" stays within a short drive when it can.
    final nearby =
        available
            .where((s) => (distances[s.id] ?? double.infinity) <= 5)
            .toList();
    final pickPool = _nearMe && nearby.length > 1 ? nearby : available;
    final areas = makanAreas(spots);
    final current = mealPeriodFor(_now);

    final sourceLabel = switch (_source) {
      null => 'All lists',
      makanSourceMine => 'My spots',
      final id => groupNames[id] ?? 'Group',
    };

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            TripBackHeader(
              title: 'Places to eat',
              sub: 'What\'s open, and what\'s on the menu',
              onBack: () => Navigator.of(context).pop(),
              trailing: GestureDetector(
                onTap: _new,
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
                      const Icon(
                        Icons.add_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add',
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
            ),

            if (spotsAsync.isLoading && spots.isEmpty)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: DT.accent,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (spots.isEmpty)
              Expanded(child: _EmptyState(onCreate: _new))
            else ...[
              // ── Search ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(DS.xl, 0, DS.xl, 10),
                child: TripInput(
                  icon: Icons.search_rounded,
                  child: TripTextField(
                    controller: _search,
                    placeholder: 'Search a dish, place or area',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),

              // ── When ──────────────────────────────────────────
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: DS.xl),
                  children: [
                    MakanChip(
                      label: '${current.emoji} Now',
                      selected: _meal == null && !_anyTime,
                      onTap: () => _setWhen(),
                    ),
                    for (final p in MealPeriod.values) ...[
                      const SizedBox(width: 8),
                      MakanChip(
                        label: p.label,
                        selected: _meal == p,
                        onTap: () => _setWhen(meal: p),
                      ),
                    ],
                    const SizedBox(width: 8),
                    MakanChip(
                      label: 'Any time',
                      selected: _anyTime,
                      onTap: () => _setWhen(anyTime: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Where / which list ────────────────────────────
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: DS.xl),
                  children: [
                    MakanChip(
                      label: _locating ? 'Locating…' : '📍 Near me',
                      selected: _nearMe,
                      onTap: _toggleNearMe,
                    ),
                    const SizedBox(width: 8),
                    MakanChip(
                      label: _area ?? 'All areas',
                      selected: _area != null,
                      trailingIcon: Icons.keyboard_arrow_down_rounded,
                      onTap: () => _pickArea(areas),
                    ),
                    if (groups.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      MakanChip(
                        label: sourceLabel,
                        selected: _source != null,
                        trailingIcon: Icons.keyboard_arrow_down_rounded,
                        onTap: () => _pickSource(groups),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Results ───────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(DS.xl, 14, DS.xl, 110),
                  children: [
                    _SectionHead(_heading(available.length)),
                    if (_nearMe && distances.isEmpty)
                      const _Hint(
                        'None of your spots has a location yet. Paste a '
                        'Google Maps link or pin it with "I\'m here now" '
                        'when editing a spot.',
                      ),
                    if (available.isEmpty)
                      const _NoMatch()
                    else
                      for (final s in available)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MakanSpotCard(
                            spot: s,
                            now: _now,
                            groupName: groupNames[s.groupId],
                            highlight: result.menuHits[s.id] ?? const [],
                            distanceKm: distances[s.id],
                            onTap: () => _open(s),
                          ),
                        ),
                    if (unavailable.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _SectionHead('Closed then · ${unavailable.length}'),
                      Opacity(
                        opacity: 0.6,
                        child: Column(
                          children: [
                            for (final s in unavailable)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: MakanSpotCard(
                                  spot: s,
                                  now: _now,
                                  groupName: groupNames[s.groupId],
                                  highlight: result.menuHits[s.id] ?? const [],
                                  distanceKm: distances[s.id],
                                  onTap: () => _open(s),
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
          ],
        ),
      ),
      floatingActionButton:
          pickPool.length > 1
              ? FloatingActionButton.extended(
                onPressed: () => _pickForMe(pickPool, groupNames),
                backgroundColor: DT.catMakan,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.casino_outlined),
                label: Text(
                  'Pick for me',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
              )
              : null,
    );
  }
}

// ─── Pieces ───────────────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  final String title;
  const _SectionHead(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.infoSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: DT.info,
          height: 1.4,
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DT.border),
      ),
      child: Text(
        'Nothing open for this. Try another time or area.',
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: DT.textSecondary,
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _Sheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: DT.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: DT.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.xl, 0, DS.xl, 8),
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DT.text,
                letterSpacing: -0.3,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: DT.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: DT.text),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: DT.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              color: DT.catMakanSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text('🍛', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Where to eat?',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: DT.text,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save the places you like to eat, with their hours and menu. '
            'Then see what\'s open for breakfast, lunch or supper at a glance.',
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
                    'Add your first spot',
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
