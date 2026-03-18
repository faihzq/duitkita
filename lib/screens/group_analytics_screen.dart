import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:duitkita/services/analytics_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/models/group_analytics.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/config/app_theme.dart';

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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxScrolled) => [
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 22),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(groupAnalyticsProvider(groupId)),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Analytics',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          groupName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              bottom: const TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Expenses'),
                  Tab(text: 'Members'),
                ],
              ),
            ),
          ],
          body: analyticsAsync.when(
            data: (analytics) {
              return membersAsync.when(
                data: (members) {
                  return TabBarView(
                    children: [
                      _OverviewTab(analytics: analytics, members: members),
                      _ExpensesTab(analytics: analytics),
                      _MembersTab(analytics: analytics, members: members),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (e, _) => Center(child: Text('Error: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            error: (error, _) => _ErrorView(
              error: error.toString(),
              onRetry: () => ref.invalidate(groupAnalyticsProvider(groupId)),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAB 1: Overview
// ============================================================

class _OverviewTab extends StatelessWidget {
  final GroupAnalytics analytics;
  final List<GroupMember> members;

  const _OverviewTab({required this.analytics, required this.members});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Financial Summary
        _buildFinancialSummary(),
        const SizedBox(height: 20),

        // Collection Rate
        _CollectionRateCard(analytics: analytics),
        const SizedBox(height: 20),

        // Monthly Collections Chart
        if (analytics.monthlyCollections.isNotEmpty) ...[
          _SectionHeader(title: 'Monthly Trend', icon: Icons.bar_chart_rounded),
          const SizedBox(height: 12),
          _MonthlyBarChart(
            data: analytics.monthlyCollections,
            barGradient: AppTheme.cardGradient,
          ),
          const SizedBox(height: 20),
        ],

        // Yearly Summary
        if (analytics.yearlyCollections.isNotEmpty) ...[
          _SectionHeader(title: 'Yearly Summary', icon: Icons.calendar_today_rounded),
          const SizedBox(height: 12),
          _YearlySummaryCard(analytics: analytics),
          const SizedBox(height: 20),
        ],

        // Activity Stats
        _SectionHeader(title: 'Activity', icon: Icons.timeline),
        const SizedBox(height: 12),
        _ActivityCard(analytics: analytics, totalMembers: members.length),
      ],
    );
  }

  Widget _buildFinancialSummary() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _StatCard(
            label: 'Collected',
            value: 'RM${analytics.totalCollected.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet_outlined,
            gradient: AppTheme.successGradient,
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            label: 'Expenses',
            value: 'RM${analytics.totalExpenses.toStringAsFixed(2)}',
            icon: Icons.receipt_long_outlined,
            gradient: const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFE53935)]),
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(
            label: 'Net Balance',
            value: 'RM${analytics.netBalance.toStringAsFixed(2)}',
            icon: Icons.account_balance_outlined,
            gradient: analytics.netBalance >= 0
                ? AppTheme.successGradient
                : const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFE53935)]),
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            label: 'Payments',
            value: '${analytics.totalPayments}',
            icon: Icons.payments_outlined,
            gradient: AppTheme.cardGradient,
          )),
        ]),
      ],
    );
  }
}

// ============================================================
// TAB 2: Expenses
// ============================================================

class _ExpensesTab extends StatelessWidget {
  final GroupAnalytics analytics;

  const _ExpensesTab({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Status Cards
        _buildStatusRow(),
        const SizedBox(height: 20),

        // Collections vs Expenses chart
        if (analytics.monthlyExpenses.isNotEmpty ||
            analytics.monthlyCollections.isNotEmpty) ...[
          _SectionHeader(title: 'Collections vs Expenses', icon: Icons.compare_arrows),
          const SizedBox(height: 12),
          _CollectionsVsExpensesChart(analytics: analytics),
          const SizedBox(height: 20),
        ],

        // Expense by Requester
        if (analytics.expenseByRequester.isNotEmpty) ...[
          _SectionHeader(title: 'By Member', icon: Icons.person_outline),
          const SizedBox(height: 12),
          _HorizontalBarList(
            entries: analytics.expenseByRequester,
            barGradient: const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFE53935)]),
          ),
          const SizedBox(height: 20),
        ],

        // Recent Expenses
        if (analytics.recentExpenses.isNotEmpty) ...[
          _SectionHeader(title: 'Recent Approved', icon: Icons.history),
          const SizedBox(height: 12),
          _RecentExpensesList(expenses: analytics.recentExpenses),
        ],

        // Empty state
        if (analytics.totalExpenseCount == 0)
          _EmptySection(
            icon: Icons.receipt_long_outlined,
            message: 'No expenses recorded yet',
          ),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Expanded(child: _CompactStatusCard(
          label: 'Approved',
          count: analytics.approvedExpenseCount,
          amount: analytics.totalExpenses,
          color: AppTheme.success,
          icon: Icons.check_circle_outline,
        )),
        const SizedBox(width: 10),
        Expanded(child: _CompactStatusCard(
          label: 'Pending',
          count: analytics.pendingExpenseCount,
          amount: analytics.pendingExpenseAmount,
          color: AppTheme.warning,
          icon: Icons.hourglass_empty,
        )),
        const SizedBox(width: 10),
        Expanded(child: _CompactStatusCard(
          label: 'Rejected',
          count: analytics.rejectedExpenseCount,
          amount: null,
          color: AppTheme.error,
          icon: Icons.cancel_outlined,
        )),
      ],
    );
  }
}

// ============================================================
// TAB 3: Members
// ============================================================

class _MembersTab extends StatelessWidget {
  final GroupAnalytics analytics;
  final List<GroupMember> members;

  const _MembersTab({required this.analytics, required this.members});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Top Contributors
        if (analytics.topContributor.isNotEmpty) ...[
          _SectionHeader(title: 'Top Contributors', icon: Icons.emoji_events_outlined),
          const SizedBox(height: 12),
          _buildTopContributors(),
          const SizedBox(height: 20),
        ],

        // Contribution Breakdown
        if (analytics.memberContributions.isNotEmpty) ...[
          _SectionHeader(title: 'Contributions', icon: Icons.people_outline),
          const SizedBox(height: 12),
          _buildContributionBars(),
          const SizedBox(height: 20),
        ],

        // Activity
        _SectionHeader(title: 'Activity', icon: Icons.timeline),
        const SizedBox(height: 12),
        _ActivityCard(analytics: analytics, totalMembers: members.length),

        if (analytics.memberContributions.isEmpty)
          _EmptySection(
            icon: Icons.people_outline,
            message: 'No member contributions yet',
          ),
      ],
    );
  }

  Widget _buildTopContributors() {
    final sorted = analytics.memberContributions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    const medalGradients = [
      LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFFD54F)]),
      LinearGradient(colors: [Color(0xFF90A4AE), Color(0xFFCFD8DC)]),
      LinearGradient(colors: [Color(0xFF8D6E63), Color(0xFFBCAAA4)]),
    ];
    const medals = ['1st', '2nd', '3rd'];

    return Column(
      children: top.asMap().entries.map((entry) {
        final i = entry.key;
        final c = entry.value;
        final name = _getMemberName(c.key);
        final count = analytics.memberPaymentCounts[c.key] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: medalGradients[i],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(medals[i],
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('$count payments', style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ),
              Text('RM${c.value.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContributionBars() {
    final sorted = analytics.memberContributions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    const gradients = [
      AppTheme.cardGradient,
      LinearGradient(colors: [Color(0xFF00897B), Color(0xFF00BFA5)]),
      LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF9800)]),
      LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
      LinearGradient(colors: [Color(0xFF00838F), Color(0xFF00ACC1)]),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: top.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          final name = _getMemberName(c.key);
          final pct = analytics.totalCollected > 0 ? (c.value / analytics.totalCollected) * 100 : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis)),
                    Text('RM${c.value.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                _GradientProgressBar(fraction: (pct / 100).clamp(0.0, 1.0), gradient: gradients[i % gradients.length]),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getMemberName(String userId) {
    return members
        .firstWhere((m) => m.userId == userId,
          orElse: () => GroupMember(userId: userId, userName: 'Unknown', isAdmin: false, joinedAt: DateTime.now(), totalPaid: 0, paymentCount: 0))
        .userName;
  }
}

// ============================================================
// SHARED WIDGETS
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const _StatCard({required this.label, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _CompactStatusCard extends StatelessWidget {
  final String label;
  final int count;
  final double? amount;
  final Color color;
  final IconData icon;

  const _CompactStatusCard({required this.label, required this.count, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(count.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          if (amount != null) ...[
            const SizedBox(height: 4),
            Text('RM${amount!.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _CollectionRateCard extends StatelessWidget {
  final GroupAnalytics analytics;

  const _CollectionRateCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final rate = analytics.collectionRate.clamp(0.0, 100.0);
    final color = rate >= 75
        ? const Color(0xFF00BFA5)
        : rate >= 50
            ? const Color(0xFFFF9800)
            : const Color(0xFFE53935);
    final gradient = rate >= 75
        ? AppTheme.successGradient
        : rate >= 50
            ? const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF9800)])
            : const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFE53935)]);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
                  child: const Icon(Icons.speed, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Collection Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20)),
                child: Text('${rate.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: LinearProgressIndicator(value: rate / 100, backgroundColor: AppTheme.cardBg, color: color, minHeight: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _labelValue('Collected', 'RM${analytics.totalCollected.toStringAsFixed(2)}', AppTheme.success),
              _labelValue('Expected', 'RM${analytics.expectedTotal.toStringAsFixed(2)}', AppTheme.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, double> data;
  final Gradient barGradient;

  const _MonthlyBarChart({required this.data, required this.barGradient});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final recent = sorted.length > 6 ? sorted.sublist(sorted.length - 6) : sorted;

    if (recent.isEmpty) return const SizedBox.shrink();

    final maxVal = recent.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) {
                return BarTooltipItem(
                  '${recent[group.x.toInt()].key}\nRM${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, reservedSize: 30,
                getTitlesWidget: (val, meta) {
                  if (val.toInt() >= recent.length) return const Text('');
                  final parts = recent[val.toInt()].key.split('-');
                  const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  final label = parts.length > 1 ? monthNames[(int.tryParse(parts[1]) ?? 1) - 1] : '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, reservedSize: 44,
                getTitlesWidget: (val, meta) => Text(val.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: maxVal > 0 ? maxVal / 5 : 1,
            getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.cardBg, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(recent.length, (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: recent[i].value,
                gradient: barGradient,
                width: 24,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          )),
        ),
      ),
    );
  }
}

class _CollectionsVsExpensesChart extends StatelessWidget {
  final GroupAnalytics analytics;

  const _CollectionsVsExpensesChart({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final months = <String>{...analytics.monthlyCollections.keys, ...analytics.monthlyExpenses.keys}.toList()..sort();
    final recent = months.length > 6 ? months.sublist(months.length - 6) : months;
    if (recent.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    for (final m in recent) {
      final c = analytics.monthlyCollections[m] ?? 0;
      final e = analytics.monthlyExpenses[m] ?? 0;
      if (c > maxVal) maxVal = c;
      if (e > maxVal) maxVal = e;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Spacer(),
            _legendDot(AppTheme.primary, 'Collected'),
            const SizedBox(width: 12),
            _legendDot(AppTheme.error, 'Expenses'),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal * 1.2 : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      final label = ri == 0 ? 'Collected' : 'Expenses';
                      return BarTooltipItem('$label\nRM${rod.toY.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        if (val.toInt() >= recent.length) return const Text('');
                        final parts = recent[val.toInt()].split('-');
                        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        final label = parts.length > 1 ? monthNames[(int.tryParse(parts[1]) ?? 1) - 1] : '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 40,
                      getTitlesWidget: (val, meta) => Text(val.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.cardBg, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(recent.length, (i) {
                  final m = recent[i];
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(toY: analytics.monthlyCollections[m] ?? 0, color: AppTheme.primary, width: 12,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    BarChartRodData(toY: analytics.monthlyExpenses[m] ?? 0, color: AppTheme.error, width: 12,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HorizontalBarList extends StatelessWidget {
  final Map<String, double> entries;
  final Gradient barGradient;

  const _HorizontalBarList({required this.entries, required this.barGradient});

  @override
  Widget build(BuildContext context) {
    final sorted = entries.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final maxVal = sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: sorted.map((e) {
          final fraction = maxVal > 0 ? e.value / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                    Text('RM${e.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                _GradientProgressBar(fraction: fraction.clamp(0.0, 1.0), gradient: barGradient),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  final double fraction;
  final Gradient gradient;

  const _GradientProgressBar({required this.fraction, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(4)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: Container(decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(4))),
      ),
    );
  }
}

class _RecentExpensesList extends StatelessWidget {
  final List<ExpenseItem> expenses;

  const _RecentExpensesList({required this.expenses});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: expenses.map((e) {
          final date = '${e.date.day} ${_months[e.date.month - 1]} ${e.date.year}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, size: 18, color: AppTheme.error),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${e.requestedByName} - $date', style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                ),
                Text('-RM${e.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.error)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final GroupAnalytics analytics;
  final int totalMembers;

  const _ActivityCard({required this.analytics, required this.totalMembers});

  @override
  Widget build(BuildContext context) {
    final inactive = totalMembers - analytics.activeMembers;
    final rate = totalMembers > 0 ? (analytics.activeMembers / totalMembers) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _row('Active Members', analytics.activeMembers.toString(), Icons.check_circle_outline, AppTheme.success),
          Divider(color: AppTheme.cardBg, height: 24),
          _row('Inactive Members', inactive.toString(), Icons.cancel_outlined, AppTheme.error),
          Divider(color: AppTheme.cardBg, height: 24),
          _row('Activity Rate', '${rate.toStringAsFixed(1)}%', Icons.speed, AppTheme.primary),
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _YearlySummaryCard extends StatelessWidget {
  final GroupAnalytics analytics;

  const _YearlySummaryCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final years = <int>{...analytics.yearlyCollections.keys, ...analytics.yearlyExpenses.keys}.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: years.map((year) {
          final collected = analytics.yearlyCollections[year] ?? 0.0;
          final expenses = analytics.yearlyExpenses[year] ?? 0.0;
          final net = collected - expenses;

          return Padding(
            padding: EdgeInsets.only(bottom: year != years.last ? 16 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (year != years.first)
                  Divider(color: AppTheme.cardBg, height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$year',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    const Spacer(),
                    Text(
                      net >= 0 ? '+RM${net.toStringAsFixed(2)}' : '-RM${net.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: net >= 0 ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _yearStat('Collected', collected, AppTheme.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _yearStat('Expenses', expenses, AppTheme.error)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _yearStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('RM${amount.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.cardBg, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: AppTheme.textHint),
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 14, color: AppTheme.textHint)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.error_outline, size: 40, color: AppTheme.error.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          const Text('Failed to load analytics',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
