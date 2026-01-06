import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:duitkita/services/analytics_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/models/group_analytics.dart';
import 'package:duitkita/models/group_member.dart';

class GroupAnalyticsScreen extends ConsumerWidget {
  final String groupId;
  final String groupName;

  const GroupAnalyticsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(groupAnalyticsProvider(groupId));
    final membersAsync = ref.watch(groupMembersStreamProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Group Analytics')),
      body: analyticsAsync.when(
        data: (analytics) {
          return membersAsync.when(
            data: (members) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Group Statistics & Analytics',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Summary Cards
                      _buildSummaryCards(analytics),
                      const SizedBox(height: 24),

                      // Collection Rate Progress
                      _buildCollectionRateCard(analytics),
                      const SizedBox(height: 24),

                      // Monthly Collections Chart
                      if (analytics.monthlyCollections.isNotEmpty) ...[
                        _buildSectionTitle('Monthly Collections'),
                        const SizedBox(height: 16),
                        _buildMonthlyChart(analytics),
                        const SizedBox(height: 24),
                      ],

                      // Member Contributions
                      if (analytics.memberContributions.isNotEmpty) ...[
                        _buildSectionTitle('Member Contributions'),
                        const SizedBox(height: 16),
                        _buildMemberContributionsChart(analytics, members),
                        const SizedBox(height: 24),
                      ],

                      // Top Contributors
                      if (analytics.topContributor.isNotEmpty) ...[
                        _buildSectionTitle('Top Contributors'),
                        const SizedBox(height: 16),
                        _buildTopContributors(analytics, members),
                        const SizedBox(height: 24),
                      ],

                      // Payment Activity
                      _buildSectionTitle('Payment Activity'),
                      const SizedBox(height: 16),
                      _buildActivityStats(analytics, members.length),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, stack) =>
                    Center(child: Text('Error loading members: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading analytics: $error'),
              ),
            ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSummaryCards(GroupAnalytics analytics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Collected',
                'RM${analytics.totalCollected.toStringAsFixed(2)}',
                Icons.account_balance_wallet,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Payments',
                analytics.totalPayments.toString(),
                Icons.payment,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Average Payment',
                'RM${analytics.averagePaymentAmount.toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Members',
                '${analytics.activeMembers}',
                Icons.people,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionRateCard(GroupAnalytics analytics) {
    final rate = analytics.collectionRate.clamp(0.0, 100.0);
    final color =
        rate >= 75
            ? Colors.green
            : rate >= 50
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collection Rate',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: Colors.grey.shade300,
              color: color,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collected: RM${analytics.totalCollected.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                'Expected: RM${analytics.expectedTotal.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(GroupAnalytics analytics) {
    final sortedEntries =
        analytics.monthlyCollections.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    // Limit to last 6 months for better visualization
    final recentEntries =
        sortedEntries.length > 6
            ? sortedEntries.sublist(sortedEntries.length - 6)
            : sortedEntries;

    if (recentEntries.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('No payment data available'),
      );
    }

    final maxAmount = recentEntries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final monthYear = recentEntries[group.x.toInt()].key;
                final amount = rod.toY;
                return BarTooltipItem(
                  '$monthYear\nRM${amount.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= recentEntries.length) {
                    return const Text('');
                  }
                  final monthYear = recentEntries[value.toInt()].key;
                  final parts = monthYear.split('-');
                  final month = parts.length > 1 ? parts[1] : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(month, style: const TextStyle(fontSize: 10)),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxAmount / 5,
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            recentEntries.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: recentEntries[index].value,
                  color: Colors.blue,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberContributionsChart(
    GroupAnalytics analytics,
    List<GroupMember> members, // CHANGED: Properly typed as List<GroupMember>
  ) {
    final sortedContributions =
        analytics.memberContributions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Limit to top 5 contributors for better visualization
    final topContributions =
        sortedContributions.length > 5
            ? sortedContributions.sublist(0, 5)
            : sortedContributions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children:
            topContributions.map((entry) {
              // FIXED: Return GroupMember instead of null
              final member = members.firstWhere(
                (m) => m.userId == entry.key,
                orElse:
                    () => GroupMember(
                      userId: entry.key,
                      userName: 'Unknown',
                      isAdmin: false,
                      joinedAt: DateTime.now(),
                      totalPaid: 0.0,
                      paymentCount: 0,
                    ),
              );
              final userName = member.userName;
              final percentage = (entry.value / analytics.totalCollected) * 100;
              final color = _getColorForIndex(topContributions.indexOf(entry));

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'RM${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        color: color,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildTopContributors(
    GroupAnalytics analytics,
    List<GroupMember> members, // CHANGED: Properly typed as List<GroupMember>
  ) {
    final sortedContributions =
        analytics.memberContributions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final topThree =
        sortedContributions.length > 3
            ? sortedContributions.sublist(0, 3)
            : sortedContributions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children:
            topThree.asMap().entries.map((entry) {
              final index = entry.key;
              final contribution = entry.value;
              // FIXED: Return GroupMember instead of null
              final member = members.firstWhere(
                (m) => m.userId == contribution.key,
                orElse:
                    () => GroupMember(
                      userId: contribution.key,
                      userName: 'Unknown',
                      isAdmin: false,
                      joinedAt: DateTime.now(),
                      totalPaid: 0.0,
                      paymentCount: 0,
                    ),
              );
              final userName = member.userName;
              final paymentCount =
                  analytics.memberPaymentCounts[contribution.key] ?? 0;

              final medal =
                  index == 0
                      ? '🥇'
                      : index == 1
                      ? '🥈'
                      : '🥉';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(medal, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('$paymentCount payments'),
                  trailing: Text(
                    'RM${contribution.value.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildActivityStats(GroupAnalytics analytics, int totalMembers) {
    final inactiveMembers = totalMembers - analytics.activeMembers;
    final activityRate =
        totalMembers > 0 ? (analytics.activeMembers / totalMembers) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _buildActivityRow(
            'Active Members',
            analytics.activeMembers.toString(),
            Colors.green,
          ),
          const Divider(),
          _buildActivityRow(
            'Inactive Members',
            inactiveMembers.toString(),
            Colors.red,
          ),
          const Divider(),
          _buildActivityRow(
            'Activity Rate',
            '${activityRate.toStringAsFixed(1)}%',
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}
