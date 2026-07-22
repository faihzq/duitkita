import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/group_analytics.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/services/analytics_service.dart';
import 'package:duitkita/services/group_service.dart';

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
        backgroundColor: DT.bg,
        body: SafeArea(
          child: Column(children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.lg, 10, DS.lg, 0),
              child: Row(children: [
                _IconBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Analytics', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4)),
                  Text(groupName, style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ])),
                _IconBtn(
                  icon: Icons.refresh_rounded,
                  onTap: () => ref.invalidate(groupAnalyticsProvider(groupId)),
                ),
              ]),
            ),

            // ── Tab bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, 0),
              child: Container(
                height: 38,
                decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500),
                  labelColor: Colors.white,
                  unselectedLabelColor: DT.textSecondary,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(color: DT.primary, borderRadius: BorderRadius.circular(8)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  padding: const EdgeInsets.all(3),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Expenses'),
                    Tab(text: 'Members'),
                  ],
                ),
              ),
            ),

            // ── Tab body ────────────────────────────────────────
            Expanded(
              child: analyticsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
                error: (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(groupAnalyticsProvider(groupId))),
                data: (analytics) => membersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (members) => TabBarView(children: [
                    _OverviewTab(analytics: analytics),
                    _ExpensesTab(analytics: analytics),
                    _MembersTab(analytics: analytics, members: members),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Overview tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final GroupAnalytics analytics;
  const _OverviewTab({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, DS.xxxl),
      children: [
        Row(children: [
          Expanded(child: _StatCard(label: 'Collected', value: 'RM${analytics.totalCollected.toStringAsFixed(2)}', icon: Icons.account_balance_wallet_outlined, iconBg: DT.accentSoft, iconColor: DT.accentDeep)),
          const SizedBox(width: DS.sm),
          Expanded(child: _StatCard(label: 'Expenses', value: 'RM${analytics.totalExpenses.toStringAsFixed(2)}', icon: Icons.receipt_long_outlined, iconBg: DT.dangerSoft, iconColor: DT.danger)),
        ]),
        const SizedBox(height: DS.sm),
        Row(children: [
          Expanded(child: _StatCard(
            label: 'Net Balance',
            value: 'RM${analytics.netBalance.toStringAsFixed(2)}',
            icon: Icons.account_balance_outlined,
            iconBg: analytics.netBalance >= 0 ? DT.successSoft : DT.dangerSoft,
            iconColor: analytics.netBalance >= 0 ? DT.success : DT.danger,
          )),
          const SizedBox(width: DS.sm),
          Expanded(child: _StatCard(label: 'Payments', value: '${analytics.totalPayments}', icon: Icons.payments_outlined, iconBg: DT.primarySoft, iconColor: DT.primary)),
        ]),
        if (analytics.initialBalance != 0) ...[
          const SizedBox(height: DS.sm),
          Row(children: [
            Expanded(child: _StatCard(label: 'Starting Balance', value: 'RM${analytics.initialBalance.toStringAsFixed(2)}', icon: Icons.savings_outlined, iconBg: DT.warningSoft, iconColor: DT.warning)),
            const SizedBox(width: DS.sm),
            const Expanded(child: SizedBox()),
          ]),
        ],
        const SizedBox(height: DS.md),

        // Collection rate
        _CollectionRateCard(analytics: analytics),
        const SizedBox(height: DS.md),

        // Monthly trend
        if (analytics.monthlyCollections.isNotEmpty) ...[
          _SectionLabel(title: 'Monthly Trend', icon: Icons.bar_chart_rounded),
          const SizedBox(height: DS.sm),
          _MonthlyBarChart(data: analytics.monthlyCollections, barColor: DT.accent),
          const SizedBox(height: DS.md),
        ],

        // Yearly summary
        if (analytics.yearlyCollections.isNotEmpty) ...[
          _SectionLabel(title: 'Yearly Summary', icon: Icons.calendar_today_rounded),
          const SizedBox(height: DS.sm),
          _YearlySummaryCard(analytics: analytics),
          const SizedBox(height: DS.md),
        ],

        // Activity
        _SectionLabel(title: 'Activity', icon: Icons.timeline),
        const SizedBox(height: DS.sm),
        _ActivityCard(analytics: analytics),
      ],
    );
  }
}

// ─── Expenses tab ─────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final GroupAnalytics analytics;
  const _ExpensesTab({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, DS.xxxl),
      children: [
        Row(children: [
          Expanded(child: _StatusCard(label: 'Approved', count: analytics.approvedExpenseCount, amount: analytics.totalExpenses, color: DT.success, icon: Icons.check_circle_outline)),
          const SizedBox(width: 8),
          Expanded(child: _StatusCard(label: 'Pending', count: analytics.pendingExpenseCount, amount: analytics.pendingExpenseAmount, color: DT.warning, icon: Icons.hourglass_empty)),
          const SizedBox(width: 8),
          Expanded(child: _StatusCard(label: 'Rejected', count: analytics.rejectedExpenseCount, amount: null, color: DT.danger, icon: Icons.cancel_outlined)),
        ]),
        const SizedBox(height: DS.md),

        if (analytics.monthlyExpenses.isNotEmpty || analytics.monthlyCollections.isNotEmpty) ...[
          _SectionLabel(title: 'Collections vs Expenses', icon: Icons.compare_arrows),
          const SizedBox(height: DS.sm),
          _CollVsExpChart(analytics: analytics),
          const SizedBox(height: DS.md),
        ],

        if (analytics.expenseByRequester.isNotEmpty) ...[
          _SectionLabel(title: 'By Member', icon: Icons.person_outline),
          const SizedBox(height: DS.sm),
          _HorizontalBarList(entries: analytics.expenseByRequester, barColor: DT.danger),
          const SizedBox(height: DS.md),
        ],

        if (analytics.recentExpenses.isNotEmpty) ...[
          _SectionLabel(title: 'Recent Approved', icon: Icons.history),
          const SizedBox(height: DS.sm),
          _RecentExpensesList(expenses: analytics.recentExpenses),
        ],

        if (analytics.totalExpenseCount == 0)
          _EmptyState(icon: Icons.receipt_long_outlined, message: 'No expenses recorded yet'),
      ],
    );
  }
}

// ─── Members tab ──────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final GroupAnalytics analytics;
  final List<GroupMember> members;
  const _MembersTab({required this.analytics, required this.members});

  String _name(String uid) => members.firstWhere((m) => m.userId == uid,
    orElse: () => GroupMember(userId: uid, userName: 'Unknown', isAdmin: false, joinedAt: DateTime.now(), totalPaid: 0, paymentCount: 0),
  ).userName;

  @override
  Widget build(BuildContext context) {
    final sorted = analytics.memberContributions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, DS.xxxl),
      children: [
        if (sorted.isNotEmpty) ...[
          _SectionLabel(title: 'Top Contributors', icon: Icons.emoji_events_outlined),
          const SizedBox(height: DS.sm),
          ...sorted.take(3).toList().asMap().entries.map((e) {
            final i = e.key;
            final uid = e.value.key;
            final amount = e.value.value;
            final count = analytics.memberPaymentCounts[uid] ?? 0;
            final medals = ['1st', '2nd', '3rd'];
            final medalColors = [const Color(0xFFFFB300), const Color(0xFF90A4AE), const Color(0xFF8D6E63)];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(DS.md),
              decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: medalColors[i].withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(medals[i], style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: medalColors[i])))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name(uid), style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
                  Text('$count payments', style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary)),
                ])),
                Text('RM${amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: DT.text)),
              ]),
            );
          }),
          const SizedBox(height: DS.md),
        ],

        if (sorted.isNotEmpty) ...[
          _SectionLabel(title: 'Contributions', icon: Icons.people_outline),
          const SizedBox(height: DS.sm),
          Container(
            padding: const EdgeInsets.all(DS.md),
            decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
            child: Column(
              children: sorted.take(5).toList().asMap().entries.map((e) {
                final uid = e.value.key;
                final amount = e.value.value;
                final pct = analytics.totalCollected > 0 ? amount / analytics.totalCollected : 0.0;
                const barColors = [DT.accent, DT.info, DT.warning, DT.catGroups, DT.success];
                final color = barColors[e.key % barColors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: DS.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(_name(uid), style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: DT.text), overflow: TextOverflow.ellipsis)),
                      Text('RM${amount.toStringAsFixed(2)} (${(pct * 100).toStringAsFixed(1)}%)', style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    _ProgressBar(fraction: pct.clamp(0.0, 1.0), color: color),
                  ]),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: DS.md),
        ],

        _SectionLabel(title: 'Activity', icon: Icons.timeline),
        const SizedBox(height: DS.sm),
        _ActivityCard(analytics: analytics, totalMembers: members.length),

        if (sorted.isEmpty)
          _EmptyState(icon: Icons.people_outline, message: 'No contributions yet'),
      ],
    );
  }
}

// ─── Shared card widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionLabel({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: DT.primarySoft, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 16, color: DT.primary)),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.2)),
  ]);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  const _StatCard({required this.label, required this.value, required this.icon, required this.iconBg, required this.iconColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DS.md),
    decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 16, color: iconColor)),
      const SizedBox(height: DS.sm),
      Text(value, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _StatusCard extends StatelessWidget {
  final String label;
  final int count;
  final double? amount;
  final Color color;
  final IconData icon;
  const _StatusCard({required this.label, required this.count, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 16, color: color)),
      const SizedBox(height: 8),
      Text(count.toString(), style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: DT.textSecondary)),
      if (amount != null) ...[
        const SizedBox(height: 2),
        Text('RM${amount!.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 10, color: DT.textTertiary), textAlign: TextAlign.center),
      ],
    ]),
  );
}

class _CollectionRateCard extends StatelessWidget {
  final GroupAnalytics analytics;
  const _CollectionRateCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final rate = analytics.collectionRate.clamp(0.0, 100.0);
    final color = rate >= 75 ? DT.success : rate >= 50 ? DT.warning : DT.danger;

    return Container(
      padding: const EdgeInsets.all(DS.md),
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)), child: Icon(Icons.speed, size: 16, color: color)),
          const SizedBox(width: 8),
          Text('Collection Rate', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(DS.chipRadius)),
            child: Text('${rate.toStringAsFixed(1)}%', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        const SizedBox(height: DS.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: rate / 100, backgroundColor: DT.border, color: color, minHeight: 8),
        ),
        const SizedBox(height: DS.md),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _labelValue('Collected', 'RM${analytics.totalCollected.toStringAsFixed(2)}', DT.success),
          _labelValue('Expected', 'RM${analytics.expectedTotal.toStringAsFixed(2)}', DT.textSecondary),
        ]),
      ]),
    );
  }

  Widget _labelValue(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.manrope(fontSize: 10, color: DT.textTertiary, fontWeight: FontWeight.w500)),
    Text(value, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, double> data;
  final Color barColor;
  const _MonthlyBarChart({required this.data, required this.barColor});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final recent = sorted.length > 6 ? sorted.sublist(sorted.length - 6) : sorted;
    if (recent.isEmpty) return const SizedBox.shrink();
    final maxVal = recent.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(DS.md, DS.lg, DS.md, DS.md),
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.25,
        barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, _, rod, __) {
            final label = recent[g.x.toInt()].key;
            return BarTooltipItem('$label\nRM${rod.toY.toStringAsFixed(0)}', GoogleFonts.manrope(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700));
          },
        )),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 28,
            getTitlesWidget: (val, _) {
              if (val.toInt() >= recent.length) return const Text('');
              final parts = recent[val.toInt()].key.split('-');
              const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
              final label = parts.length > 1 ? months[(int.tryParse(parts[1]) ?? 1) - 1] : '';
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: GoogleFonts.manrope(fontSize: 9, color: DT.textSecondary, fontWeight: FontWeight.w600)));
            },
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, _) => Text(val.toInt().toString(), style: GoogleFonts.manrope(fontSize: 9, color: DT.textTertiary)))),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: DT.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(recent.length, (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: recent[i].value, color: barColor, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
        ])),
      )),
    );
  }
}

class _CollVsExpChart extends StatelessWidget {
  final GroupAnalytics analytics;
  const _CollVsExpChart({required this.analytics});

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
      padding: const EdgeInsets.all(DS.md),
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _LegendDot(color: DT.accent, label: 'Collected'),
          const SizedBox(width: DS.md),
          _LegendDot(color: DT.danger, label: 'Expenses'),
        ]),
        const SizedBox(height: DS.md),
        SizedBox(height: 180, child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal > 0 ? maxVal * 1.2 : 100,
          barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, _, rod, ri) {
              final l = ri == 0 ? 'Collected' : 'Expenses';
              return BarTooltipItem('$l\nRM${rod.toY.toStringAsFixed(0)}', GoogleFonts.manrope(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700));
            },
          )),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
              getTitlesWidget: (val, _) {
                if (val.toInt() >= recent.length) return const Text('');
                final parts = recent[val.toInt()].split('-');
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                final label = parts.length > 1 ? months[(int.tryParse(parts[1]) ?? 1) - 1] : '';
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: GoogleFonts.manrope(fontSize: 9, color: DT.textSecondary)));
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (val, _) => Text(val.toInt().toString(), style: GoogleFonts.manrope(fontSize: 9, color: DT.textTertiary)))),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: DT.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(recent.length, (i) {
            final m = recent[i];
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: analytics.monthlyCollections[m] ?? 0, color: DT.accent, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
              BarChartRodData(toY: analytics.monthlyExpenses[m] ?? 0, color: DT.danger, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ]);
          }),
        ))),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.manrope(fontSize: 10, color: DT.textSecondary, fontWeight: FontWeight.w600)),
  ]);
}

class _HorizontalBarList extends StatelessWidget {
  final Map<String, double> entries;
  final Color barColor;
  const _HorizontalBarList({required this.entries, required this.barColor});

  @override
  Widget build(BuildContext context) {
    final sorted = entries.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final maxVal = sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(DS.md),
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
      child: Column(children: sorted.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: DS.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(e.key, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: DT.text), overflow: TextOverflow.ellipsis)),
            Text('RM${e.value.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: DT.text)),
          ]),
          const SizedBox(height: 6),
          _ProgressBar(fraction: (maxVal > 0 ? e.value / maxVal : 0.0).clamp(0.0, 1.0), color: barColor),
        ]),
      )).toList()),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double fraction;
  final Color color;
  const _ProgressBar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(value: fraction, backgroundColor: DT.border, color: color, minHeight: 6),
  );
}

class _RecentExpensesList extends StatelessWidget {
  final List<ExpenseItem> expenses;
  const _RecentExpensesList({required this.expenses});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DS.md),
    decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
    child: Column(children: expenses.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: DS.sm),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long_outlined, size: 17, color: DT.danger)),
        const SizedBox(width: DS.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: DT.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${e.requestedByName} · ${e.date.day} ${_months[e.date.month - 1]} ${e.date.year}', style: GoogleFonts.manrope(fontSize: 10, color: DT.textSecondary)),
        ])),
        Text('-RM${e.amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.danger)),
      ]),
    )).toList()),
  );
}

class _ActivityCard extends StatelessWidget {
  final GroupAnalytics analytics;
  final int totalMembers;
  const _ActivityCard({required this.analytics, this.totalMembers = 0});

  @override
  Widget build(BuildContext context) {
    final tm = totalMembers > 0 ? totalMembers : analytics.activeMembers;
    final inactive = tm - analytics.activeMembers;
    final rate = tm > 0 ? (analytics.activeMembers / tm) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(DS.md),
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
      child: Column(children: [
        _row('Active Members', analytics.activeMembers.toString(), Icons.check_circle_outline, DT.success),
        Divider(color: DT.border, height: 20),
        _row('Inactive Members', inactive < 0 ? '0' : inactive.toString(), Icons.cancel_outlined, DT.danger),
        Divider(color: DT.border, height: 20),
        _row('Activity Rate', '${rate.toStringAsFixed(1)}%', Icons.speed, DT.accent),
      ]),
    );
  }

  Widget _row(String label, String value, IconData icon, Color color) => Row(children: [
    Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 16, color: color)),
    const SizedBox(width: DS.sm),
    Expanded(child: Text(label, style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, fontWeight: FontWeight.w500))),
    Text(value, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
  ]);
}

class _YearlySummaryCard extends StatelessWidget {
  final GroupAnalytics analytics;
  const _YearlySummaryCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final years = <int>{...analytics.yearlyCollections.keys, ...analytics.yearlyExpenses.keys}.toList()..sort((a, b) => b.compareTo(a));
    return Container(
      padding: const EdgeInsets.all(DS.md),
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
      child: Column(children: years.map((yr) {
        final collected = analytics.yearlyCollections[yr] ?? 0.0;
        final expenses = analytics.yearlyExpenses[yr] ?? 0.0;
        final net = collected - expenses;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (yr != years.first) Divider(color: DT.border, height: 24),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: DT.primarySoft, borderRadius: BorderRadius.circular(8)), child: Text('$yr', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: DT.primary))),
            const Spacer(),
            Text(net >= 0 ? '+RM${net.toStringAsFixed(2)}' : '-RM${net.abs().toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: net >= 0 ? DT.success : DT.danger)),
          ]),
          const SizedBox(height: DS.sm),
          Row(children: [
            Expanded(child: _yearStat('Collected', collected, DT.success)),
            const SizedBox(width: DS.sm),
            Expanded(child: _yearStat('Expenses', expenses, DT.danger)),
          ]),
        ]);
      }).toList()),
    );
  }

  Widget _yearStat(String label, double amount, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.manrope(fontSize: 10, color: DT.textTertiary, fontWeight: FontWeight.w500)),
    const SizedBox(height: 2),
    Text('RM${amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(DS.xl), decoration: const BoxDecoration(color: DT.primarySoft, shape: BoxShape.circle), child: Icon(icon, size: 32, color: DT.textSecondary)),
      const SizedBox(height: DS.md),
      Text(message, style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(DS.xl), decoration: BoxDecoration(color: DT.dangerSoft, shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 36, color: DT.danger)),
      const SizedBox(height: DS.md),
      Text('Failed to load analytics', style: GoogleFonts.manrope(fontSize: 14, color: DT.textSecondary, fontWeight: FontWeight.w600)),
      const SizedBox(height: DS.md),
      GestureDetector(
        onTap: onRetry,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: DS.xl, vertical: DS.sm), decoration: BoxDecoration(color: DT.primary, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.refresh, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text('Retry', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ])),
      ),
    ]),
  );
}

// ─── Icon button ──────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 20, color: DT.text),
    ),
  );
}
