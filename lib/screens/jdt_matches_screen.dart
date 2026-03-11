import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/match_model.dart';
import 'package:duitkita/services/match_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/config/app_theme.dart';

class JdtMatchesScreen extends ConsumerStatefulWidget {
  const JdtMatchesScreen({super.key});

  @override
  ConsumerState<JdtMatchesScreen> createState() => _JdtMatchesScreenState();
}

class _JdtMatchesScreenState extends ConsumerState<JdtMatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.jdtRed,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'JDT Matches',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.jdtGradient),
                child: Stack(
                  children: [
                    // Soccer ball background
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.sports_soccer,
                        size: 180,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    // JDT Logo overlay
                    Positioned(
                      right: 16,
                      bottom: -10,
                      child: Image.asset(
                        'assets/images/jdt_logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.shield,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 100,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Results'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUpcomingTab(),
            _buildResultsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addMatchFab',
        onPressed: _showAddMatchDialog,
        backgroundColor: AppTheme.jdtRed,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUpcomingTab() {
    final matchesAsync = ref.watch(upcomingMatchesProvider);

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return _buildEmptyState('No upcoming matches', Icons.event_busy);
        }

        return RefreshIndicator(
          color: AppTheme.jdtRed,
          onRefresh: () async {
            ref.read(matchServiceProvider).clearCache();
            ref.invalidate(upcomingMatchesProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: matches.length,
            itemBuilder: (context, index) => _buildMatchCard(matches[index]),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.jdtRed),
      ),
      error: (error, _) => _buildErrorState(
        error.toString(),
        () {
          ref.read(matchServiceProvider).clearCache();
          ref.invalidate(upcomingMatchesProvider);
        },
      ),
    );
  }

  Widget _buildResultsTab() {
    final resultsAsync = ref.watch(recentResultsProvider);

    return resultsAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return _buildEmptyState('No recent results', Icons.scoreboard_outlined);
        }

        return RefreshIndicator(
          color: AppTheme.jdtRed,
          onRefresh: () async {
            ref.read(matchServiceProvider).clearCache();
            ref.invalidate(recentResultsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: matches.length,
            itemBuilder: (context, index) =>
                _buildMatchCard(matches[index], showScore: true),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.jdtRed),
      ),
      error: (error, _) => _buildErrorState(
        error.toString(),
        () {
          ref.read(matchServiceProvider).clearCache();
          ref.invalidate(recentResultsProvider);
        },
      ),
    );
  }

  Widget _buildMatchCard(MatchModel match, {bool showScore = false}) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr =
        '${match.matchDate.day} ${months[match.matchDate.month - 1]} ${match.matchDate.year}';
    final timeStr =
        '${match.matchDate.hour.toString().padLeft(2, '0')}:${match.matchDate.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // League header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: showScore ? AppTheme.textHint : AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      match.league,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$dateStr  $timeStr',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Match content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                // Home team
                Expanded(
                  child: Column(
                    children: [
                      _buildTeamLogo(match.homeTeamLogo),
                      const SizedBox(height: 10),
                      Text(
                        match.homeTeam,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Score or VS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: showScore && match.homeScore != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 4),
                          ),
                          child: Text(
                            '${match.homeScore} - ${match.awayScore}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: 1,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.jdtGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
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
                      _buildTeamLogo(match.awayTeamLogo),
                      const SizedBox(height: 10),
                      Text(
                        match.awayTeam,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
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
          if (match.venue != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text(
                    match.venue!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),

          // Manual badge + delete
          if (match.isManual)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      'Manually added',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.warning.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deleteMatch(match),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppTheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(String? logoUrl) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 4),
      ),
      padding: const EdgeInsets.all(6),
      child: logoUrl != null
          ? Image.network(
              logoUrl,
              errorBuilder: (_, __, ___) => Icon(
                Icons.shield_outlined,
                size: 28,
                color: Colors.grey.shade300,
              ),
            )
          : Icon(Icons.shield_outlined, size: 28, color: Colors.grey.shade300),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppTheme.textHint),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(fontSize: 13, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off, size: 40, color: AppTheme.error.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Failed to load matches',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.jdtRed),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMatch(MatchModel match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Delete Match'),
        content: const Text('Are you sure you want to delete this match?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final matchService = ref.read(matchServiceProvider);
      await matchService.deleteManualMatch(match.id);
      matchService.clearCache();
      ref.invalidate(upcomingMatchesProvider);
      ref.invalidate(recentResultsProvider);
      if (mounted) showSnackBar(context, 'Match deleted');
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to delete: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _showAddMatchDialog() async {
    final homeController = TextEditingController();
    final awayController = TextEditingController();
    final venueController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 20, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              title: const Text('Add Match', style: TextStyle(fontWeight: FontWeight.w700)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: homeController,
                      decoration: AppTheme.styledInput(
                        label: 'Home Team',
                        prefixIcon: Icons.shield_outlined,
                        hint: 'e.g. Johor Darul Ta\'zim',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: awayController,
                      decoration: AppTheme.styledInput(
                        label: 'Away Team',
                        prefixIcon: Icons.shield_outlined,
                        hint: 'e.g. Selangor FC',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: venueController,
                      decoration: AppTheme.styledInput(
                        label: 'Venue (optional)',
                        prefixIcon: Icons.location_on_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setDialogState(() => selectedDate = date);
                              }
                            },
                            label: Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (time != null) {
                                setDialogState(() => selectedTime = time);
                              }
                            },
                            label: Text(
                              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.jdtRed),
                  child: const Text('Add Match'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    if (homeController.text.trim().isEmpty || awayController.text.trim().isEmpty) {
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
        homeTeam: homeController.text.trim(),
        awayTeam: awayController.text.trim(),
        matchDate: matchDate,
        venue: venueController.text.trim().isEmpty
            ? null
            : venueController.text.trim(),
      );

      matchService.clearCache();
      ref.invalidate(upcomingMatchesProvider);
      ref.invalidate(recentResultsProvider);

      if (mounted) showSnackBar(context, 'Match added!');
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to add match: ${e.toString()}', isError: true);
      }
    }
  }
}
