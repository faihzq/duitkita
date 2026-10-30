import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/models/match_model.dart';
import 'package:duitkita/services/match_service.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/widgets/floating_field.dart';
import 'package:duitkita/utils/utils.dart';

// JDT brand colours (not in global DT — JDT-only feature)
const _jdtRed = Color(0xFFD32F2F);
const _jdtRedDark = Color(0xFFC62828);
const _jdtRedLight = Color(0xFFE53935);
const _jdtGold = Color(0xFFFFB300);
const _jdtGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_jdtRedDark, _jdtRed, _jdtRedLight],
);

class JdtMatchesScreen extends ConsumerStatefulWidget {
  const JdtMatchesScreen({super.key});

  @override
  ConsumerState<JdtMatchesScreen> createState() => _JdtMatchesScreenState();
}

class _JdtMatchesScreenState extends ConsumerState<JdtMatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Which side's fixtures are on screen. JDT first — it is what the tab was
  /// built for and what most people open it to see.
  FootballTeam _team = FootballTeam.jdt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.read(matchServiceProvider).clearCache();
    ref.invalidate(upcomingMatchesProvider);
    ref.invalidate(recentResultsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      body: NestedScrollView(
        headerSliverBuilder:
            (context, innerBoxIsScrolled) => [
              SliverAppBar(
                // Toolbar and expanded height are the same, so the bar never
                // collapses and FlexibleSpaceBar holds its background at full
                // opacity (its fade is skipped outright when maxExtent equals
                // minExtent). A fixed header also means the crest below keeps
                // one size instead of being animated between two.
                toolbarHeight: _kToolbarHeight,
                expandedHeight: _kToolbarHeight + _kTabsHeight,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: _jdtRed,
                foregroundColor: Colors.white,
                titleSpacing: 20,
                // Without an `actions` widget the title would run the full
                // width and slide under the crest, so the room is reserved here
                // instead.
                title: Padding(
                  padding: const EdgeInsets.only(right: 96),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_team.label} Matches',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // The competition, under a short gold rule. The header was
                      // a single line of white text against a lot of empty red;
                      // this gives the left side something to balance the crest.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: _jdtGold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              _team.fallbackLeague.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.78),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(gradient: _jdtGradient),
                    child: Stack(
                      children: [
                        // Light falling on the crest corner. Without it the
                        // medallion sits on flat red and reads as pasted on.
                        Positioned(
                          right: -40,
                          top: -50,
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.16),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Soccer ball watermark
                        Positioned(
                          right: -20,
                          bottom: -20,
                          child: Icon(
                            Icons.sports_soccer_rounded,
                            size: 180,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        // The crest, run off the top-right corner so the Stack
                        // crops it and the tabs bar covers its foot. Painting
                        // it here rather than in the toolbar is only safe
                        // because this header never collapses: FlexibleSpaceBar
                        // fades its background out as a bar shrinks, and skips
                        // the fade entirely when maxExtent equals minExtent.
                        // Slightly under full opacity so it sits in the
                        // gradient rather than on top of it.
                        Positioned(
                          right: -28,
                          top: -20,
                          child: Opacity(
                            opacity: 0.9,
                            child: _TeamCrest(team: _team, size: 150),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(_kTabsHeight),
                  child: Container(
                    color: _jdtRed,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // One sunken track holding both options, rather than
                        // two separate outlined pills. A segmented control
                        // reads as "pick one of these"; two loose outlines read
                        // as two unrelated buttons that happen to sit together.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.17),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.13),
                              ),
                            ),
                            child: Row(
                              children: [
                                for (final team in FootballTeam.values)
                                  Expanded(
                                    child: _TeamChip(
                                      label: team.label,
                                      selected: _team == team,
                                      onTap:
                                          () => setState(() => _team = team),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.label,
                          // Rounded cap and a little inset, so the gold reads
                          // as a deliberate marker rather than a cut edge.
                          indicator: const UnderlineTabIndicator(
                            borderSide: BorderSide(color: _jdtGold, width: 3),
                            borderRadius: BorderRadius.all(
                              Radius.circular(3),
                            ),
                            insets: EdgeInsets.symmetric(horizontal: 4),
                          ),
                          // Material 3 draws its own hairline under the whole
                          // bar, which cuts across the red and fights the gold.
                          dividerColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withValues(
                            alpha: 0.58,
                          ),
                          labelStyle: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                          unselectedLabelStyle: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                          tabs: const [
                            Tab(text: 'Upcoming'),
                            Tab(text: 'Results'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _MatchTab(
              provider: upcomingMatchesProvider(_team),
              emptyIcon: Icons.event_busy_rounded,
              emptyMessage: 'No upcoming matches',
              showScore: false,
              onRefresh: _refreshAll,
              onDelete: _deleteMatch,
            ),
            _MatchTab(
              provider: recentResultsProvider(_team),
              emptyIcon: Icons.scoreboard_outlined,
              emptyMessage: 'No recent results',
              showScore: true,
              onRefresh: _refreshAll,
              onDelete: _deleteMatch,
            ),
          ],
        ),
      ),
      floatingActionButton:
          _team != FootballTeam.jdt
              ? null
              : FloatingActionButton(
                heroTag: 'addMatchFab',
                onPressed: _showAddMatchDialog,
                backgroundColor: _jdtRed,
                foregroundColor: Colors.white,
                elevation: 2,
                child: const Icon(Icons.add_rounded),
              ),
    );
  }

  Future<void> _deleteMatch(MatchModel match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.cardRadius),
            ),
            backgroundColor: DT.surface,
            child: Padding(
              padding: const EdgeInsets.all(DS.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(DS.sm),
                        decoration: BoxDecoration(
                          color: DT.dangerSoft,
                          borderRadius: BorderRadius.circular(DS.sm),
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: DT.danger,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: DS.md),
                      Text(
                        'Delete Match',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: DT.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DS.lg),
                  Text(
                    'Remove this match from the schedule?',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: DT.textSecondary,
                    ),
                  ),
                  const SizedBox(height: DS.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(DS.md),
                    decoration: BoxDecoration(
                      color: DT.surfaceAlt,
                      borderRadius: BorderRadius.circular(DS.md),
                      border: Border.all(color: DT.border),
                    ),
                    child: Text(
                      '${match.homeTeam}  vs  ${match.awayTeam}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DT.text,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: DS.xxl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DT.textSecondary,
                            side: const BorderSide(color: DT.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DS.cardRadius,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: DS.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DT.danger,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DS.cardRadius,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                          ),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirmed != true) return;

    try {
      final matchService = ref.read(matchServiceProvider);
      await matchService.deleteManualMatch(match.id);
      matchService.clearCache();
      ref.invalidate(upcomingMatchesProvider);
      ref.invalidate(recentResultsProvider);
      if (mounted) {
        showSnackBar(context, 'Match deleted');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to delete: $e', isError: true);
      }
    }
  }

  Future<void> _showAddMatchDialog() async {
    final homeCtrl = TextEditingController();
    final awayCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 20, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.cardRadius),
                  ),
                  backgroundColor: DT.surface,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(DS.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(DS.sm),
                                decoration: BoxDecoration(
                                  color: _jdtRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(DS.sm),
                                ),
                                child: const Icon(
                                  Icons.sports_soccer_rounded,
                                  color: _jdtRed,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: DS.md),
                              Text(
                                'Add Match',
                                style: GoogleFonts.manrope(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: DT.text,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DS.xxl),

                          // Home team
                          FloatingField(
                            controller: homeCtrl,
                            gap: 0,
                            label: 'Home team',
                            icon: Icons.shield_outlined,
                            hint: "e.g. Johor Darul Ta'zim",
                            capitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: DS.md),

                          // Away team
                          FloatingField(
                            controller: awayCtrl,
                            gap: 0,
                            label: 'Away team',
                            icon: Icons.shield_outlined,
                            hint: 'e.g. Selangor FC',
                            capitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: DS.md),

                          // Venue
                          FloatingField(
                            controller: venueCtrl,
                            gap: 0,
                            label: 'Venue',
                            icon: Icons.location_on_outlined,
                            hint: 'e.g. Stadium Larkin',
                            optional: true,
                            capitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: DS.lg),

                          // Date + time row
                          Row(
                            children: [
                              Expanded(
                                child: _DateTimeButton(
                                  icon: Icons.calendar_today_rounded,
                                  label:
                                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: ctx,
                                      initialDate: selectedDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (d != null) {
                                      setDialogState(() => selectedDate = d);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: DS.sm),
                              Expanded(
                                child: _DateTimeButton(
                                  icon: Icons.access_time_rounded,
                                  label:
                                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                  onTap: () async {
                                    final t = await showTimePicker(
                                      context: ctx,
                                      initialTime: selectedTime,
                                    );
                                    if (t != null) {
                                      setDialogState(() => selectedTime = t);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DS.xxl),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: DT.textSecondary,
                                    side: const BorderSide(color: DT.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        DS.cardRadius,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: DS.md),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _jdtRed,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        DS.cardRadius,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Add Match',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );

    if (result != true) return;

    if (homeCtrl.text.trim().isEmpty || awayCtrl.text.trim().isEmpty) {
      if (mounted) {
        showSnackBar(context, 'Please enter both team names', isError: true);
      }
      return;
    }

    try {
      final matchDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      final matchService = ref.read(matchServiceProvider);
      await matchService.addManualMatch(
        homeTeam: homeCtrl.text.trim(),
        awayTeam: awayCtrl.text.trim(),
        matchDate: matchDate,
        venue: venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
      );
      matchService.clearCache();
      ref.invalidate(upcomingMatchesProvider);
      ref.invalidate(recentResultsProvider);
      if (mounted) {
        showSnackBar(context, 'Match added!');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to add match: $e', isError: true);
      }
    }
  }
}

// ─── Tab widget ────────────────────────────────────────────────────

class _MatchTab extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<MatchModel>>> provider;
  final IconData emptyIcon;
  final String emptyMessage;
  final bool showScore;
  final VoidCallback onRefresh;
  final Future<void> Function(MatchModel) onDelete;

  const _MatchTab({
    required this.provider,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.showScore,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(provider);

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return _EmptyState(icon: emptyIcon, message: emptyMessage);
        }
        return RefreshIndicator(
          color: _jdtRed,
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(DS.lg, DS.lg, DS.lg, 96),
            itemCount: matches.length,
            itemBuilder:
                (context, index) => _MatchCard(
                  match: matches[index],
                  showScore: showScore,
                  onDelete: onDelete,
                ),
          ),
        );
      },
      loading:
          () => const Center(child: CircularProgressIndicator(color: _jdtRed)),
      error: (error, _) => _ErrorState(onRetry: onRefresh),
    );
  }
}

// ─── Match card ─────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final MatchModel match;
  final bool showScore;
  final Future<void> Function(MatchModel) onDelete;

  const _MatchCard({
    required this.match,
    required this.showScore,
    required this.onDelete,
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    // Calendar days apart, not hours: a kick-off twenty hours away can still
    // be tomorrow, and one four hours back can still be yesterday. Both sides
    // are flattened to midnight so the comparison is about the date on the
    // card, not the distance between two instants.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDay = DateTime(
      match.matchDate.year,
      match.matchDate.month,
      match.matchDate.day,
    );
    final dayOffset = matchDay.difference(today).inDays;

    final weekday = _weekdays[match.matchDate.weekday - 1];
    final dateStr = switch (dayOffset) {
      0 => 'Today · $weekday',
      1 => 'Tomorrow · $weekday',
      -1 => 'Yesterday · $weekday',
      _ =>
        '$weekday, ${match.matchDate.day} ${_months[match.matchDate.month - 1]} '
            '${match.matchDate.year}',
    };
    // The Results section of the source page shows a score where fixtures show
    // a kick-off, so a finished match has no time to display — rendering one
    // anyway printed "00:00" on every result. Manually added matches do carry
    // a real time, so those keep it.
    final hasKickOff =
        !showScore ||
        match.isManual ||
        match.matchDate.hour != 0 ||
        match.matchDate.minute != 0;
    final timeStr =
        hasKickOff
            ? '  ${match.matchDate.hour.toString().padLeft(2, '0')}:${match.matchDate.minute.toString().padLeft(2, '0')}'
            : '';

    return Container(
      margin: const EdgeInsets.only(bottom: DS.md),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // League header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.lg,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: DT.surfaceAlt,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DS.cardRadius),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: showScore ? DT.textTertiary : DT.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DS.sm),
                Expanded(
                  child: Text(
                    match.league,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: DT.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '$dateStr$timeStr',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: DT.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Teams row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.lg,
              vertical: DS.xl,
            ),
            child: Row(
              children: [
                // Home team
                Expanded(
                  child: Column(
                    children: [
                      _TeamLogo(match.homeTeamLogo),
                      const SizedBox(height: 10),
                      Text(
                        match.homeTeam,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DT.text,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Score or VS badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DS.md),
                  child:
                      showScore && match.homeScore != null
                          ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DS.lg,
                              vertical: DS.sm + 2,
                            ),
                            decoration: BoxDecoration(
                              color: DT.surfaceAlt,
                              borderRadius: BorderRadius.circular(DS.md),
                              border: Border.all(color: DT.border),
                            ),
                            child: Text(
                              '${match.homeScore} – ${match.awayScore}',
                              style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: DT.text,
                                letterSpacing: 1,
                              ),
                            ),
                          )
                          : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DS.md,
                              vertical: DS.sm,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_jdtRedDark, _jdtRedLight],
                              ),
                              borderRadius: BorderRadius.circular(DS.md),
                            ),
                            child: Text(
                              'VS',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                ),

                // Away team
                Expanded(
                  child: Column(
                    children: [
                      _TeamLogo(match.awayTeamLogo),
                      const SizedBox(height: 10),
                      Text(
                        match.awayTeam,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DT.text,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Venue
          if (match.venue != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: DS.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: DT.textTertiary,
                  ),
                  const SizedBox(width: DS.xs),
                  Text(
                    match.venue!,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: DT.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Manual badge + delete
          if (match.isManual) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: DS.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DT.warningSoft,
                      borderRadius: BorderRadius.circular(DS.chipRadius),
                    ),
                    child: Text(
                      'Manually added',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: DT.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.sm),
                  GestureDetector(
                    onTap: () => onDelete(match),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: DT.danger.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String? logoUrl;

  const _TeamLogo(this.logoUrl);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: DT.surfaceAlt,
        borderRadius: BorderRadius.circular(DS.md),
        border: Border.all(color: DT.border),
      ),
      child:
          logoUrl != null
              ? Image.network(
                logoUrl!,
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) => Icon(
                      Icons.shield_outlined,
                      size: 28,
                      color: DT.borderStrong,
                    ),
              )
              : Icon(Icons.shield_outlined, size: 28, color: DT.borderStrong),
    );
  }
}

// ─── Empty / error states ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(DS.xxl),
            decoration: BoxDecoration(
              color: _jdtRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: _jdtRed.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: DS.xl),
          Text(
            message,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: DT.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DS.sm),
          Text(
            'Pull down to refresh',
            style: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(DS.xl),
            decoration: const BoxDecoration(
              color: DT.dangerSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: DT.danger.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: DS.xl),
          Text(
            'Failed to load matches',
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: DT.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DS.lg),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Retry',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _jdtRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.cardRadius),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16, color: DT.textSecondary),
      label: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: DT.text,
        ),
      ),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: DT.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.md),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: DS.md),
        backgroundColor: DT.surfaceAlt,
      ),
    );
  }
}

/// Segmented control for picking whose fixtures to show. Deliberately plain —
/// it sits on the crest artwork, where a heavier control would compete with it.
/// Header geometry, named because the two have to agree: the app bar's
/// minExtent is toolbar + bottom, and matching expandedHeight to that sum is
/// what keeps the header from collapsing.
const double _kToolbarHeight = 96;
// Chips track (40) + its bottom padding (8) + TabBar (46), with headroom for
// a larger system font scale before the column overflows its fixed height.
const double _kTabsHeight = 100;

class _TeamChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TeamChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The selected side is a solid white pill with red text: on a red header
    // the strongest contrast available is the absence of red, and it beats
    // tinting white-on-white-ish, which is what the old translucent fill did.
    const duration = Duration(milliseconds: 180);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: duration,
          curve: Curves.easeOut,
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color:
                selected ? _jdtRedDark : Colors.white.withValues(alpha: 0.78),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// The team's crest for the header.
///
/// The bundled copy paints on the first frame and works offline; the published
/// URL covers an asset that fails to decode, and a plain shield covers both
/// going wrong, so nothing here can show a broken image.
class _TeamCrest extends StatelessWidget {
  final FootballTeam team;

  /// Side of the square the crest is drawn into. Bounded rather than free to
  /// grow: the crest sits in the toolbar's action slot, which would otherwise
  /// stretch it to the full toolbar height and shove the title aside.
  final double size;

  const _TeamCrest({required this.team, this.size = 38});

  @override
  Widget build(BuildContext context) {
    Widget shield() => Icon(
      Icons.shield_rounded,
      color: Colors.white.withValues(alpha: 0.25),
      size: size,
    );

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        team.crestAsset,
        fit: BoxFit.contain,
        errorBuilder:
            (_, __, ___) => Image.network(
              team.crestUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => shield(),
              // No spinner: the crest is decoration beside a title, and a
              // flicker of progress indicator there reads as breakage.
              loadingBuilder:
                  (context, child, progress) =>
                      progress == null ? child : const SizedBox.shrink(),
            ),
      ),
    );
  }
}
