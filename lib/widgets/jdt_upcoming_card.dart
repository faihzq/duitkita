import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/match_model.dart';
import 'package:duitkita/services/match_service.dart';
import 'package:duitkita/screens/jdt_matches_screen.dart';
import 'package:duitkita/config/app_theme.dart';

class JdtUpcomingCard extends ConsumerWidget {
  const JdtUpcomingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingMatchesProvider);
    final resultsAsync = ref.watch(recentResultsProvider);

    return upcomingAsync.when(
      data: (upcoming) {
        if (upcoming.isNotEmpty) {
          final display = upcoming.take(2).toList();
          return _buildCard(
            context,
            title: 'JDT Upcoming Matches',
            icon: Icons.schedule,
            child: Column(
              children: [
                ...display.map((m) => _buildMatchRow(m, showScore: false)),
                _buildSeeAllButton(context),
              ],
            ),
          );
        }

        return resultsAsync.when(
          data: (results) {
            if (results.isEmpty) {
              return _buildCard(
                context,
                title: 'JDT Matches',
                icon: Icons.sports_soccer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 36, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'No upcoming fixtures scheduled yet',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      _buildSeeAllButton(context),
                    ],
                  ),
                ),
              );
            }

            final display = results.take(2).toList();
            return _buildCard(
              context,
              title: 'JDT Latest Results',
              icon: Icons.emoji_events_outlined,
              child: Column(
                children: [
                  ...display.map((m) => _buildMatchRow(m, showScore: true)),
                  _buildSeeAllButton(context),
                ],
              ),
            );
          },
          loading: () => _buildCard(
            context,
            title: 'JDT Matches',
            icon: Icons.sports_soccer,
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            ),
          ),
          error: (_, __) => _buildCard(
            context,
            title: 'JDT Matches',
            icon: Icons.sports_soccer,
            child: _buildErrorContent(ref),
          ),
        );
      },
      loading: () => _buildCard(
        context,
        title: 'JDT Matches',
        icon: Icons.sports_soccer,
        child: const Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ),
        ),
      ),
      error: (_, __) => _buildCard(
        context,
        title: 'JDT Matches',
        icon: Icons.sports_soccer,
        child: _buildErrorContent(ref),
      ),
    );
  }

  Widget _buildSeeAllButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        AppTheme.slideRoute(const JdtMatchesScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'See All Matches',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.cloud_off, color: Colors.white.withValues(alpha: 0.5), size: 32),
          const SizedBox(height: 8),
          Text(
            'Could not load matches',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              ref.invalidate(upcomingMatchesProvider);
              ref.invalidate(recentResultsProvider);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.jdtGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppTheme.jdtRed.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildMatchRow(MatchModel match, {required bool showScore}) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr =
        '${match.matchDate.day} ${months[match.matchDate.month - 1]}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 4),
      ),
      child: Row(
        children: [
          // Home team
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    match.homeTeam,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildTeamBadge(match.homeTeamLogo),
              ],
            ),
          ),

          // Score / Time / Date
          Container(
            width: 70,
            alignment: Alignment.center,
            child: Column(
              children: [
                if (showScore && match.homeScore != null)
                  Text(
                    '${match.homeScore} - ${match.awayScore}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  )
                else
                  Text(
                    '${match.matchDate.hour.toString().padLeft(2, '0')}:${match.matchDate.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Away team
          Expanded(
            child: Row(
              children: [
                _buildTeamBadge(match.awayTeamLogo),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    match.awayTeam,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamBadge(String? logoUrl) {
    if (logoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          logoUrl,
          width: 24,
          height: 24,
          errorBuilder: (_, __, ___) => Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.shield, size: 16, color: Colors.white70),
          ),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.shield, size: 16, color: Colors.white70),
    );
  }
}
