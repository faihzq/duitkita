import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/screens/groups_list_screen.dart';
import 'package:duitkita/screens/group_detail_screen.dart';
import 'package:duitkita/screens/expense_list_screen.dart';
import 'package:duitkita/screens/settings_screen.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/screens/debts_list_screen.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/widgets/jdt_upcoming_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.notifier).currentUser;
    final profileAsync = user != null
        ? ref.watch(userProfileStreamProvider(user.uid))
        : null;
    final profile = profileAsync?.valueOrNull;
    final displayName = profile?.name ??
        user?.displayName ??
        user?.email?.split('@').first ??
        'User';
    final profileImageUrl = profile?.profileImageUrl;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: CustomScrollView(
        slivers: [
          // Gradient Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppTheme.radiusXLarge),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              AppTheme.slideRoute(const SettingsScreen()),
                            ),
                            child: Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                                image: profileImageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(profileImageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: profileImageUrl == null
                                  ? Center(
                                      child: Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick stats row
                      if (user != null) _buildHeaderQuickStats(ref, user.uid),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // MONTHLY COMMITMENT DASHBOARD (Priority)
                if (user != null) _buildMonthlyCommitmentDashboard(context, ref, user.uid),

                // JDT Upcoming Matches Preview (only if enabled)
                if (profile?.showJdtMatches == true) ...[
                  const JdtUpcomingCard(),
                  const SizedBox(height: 24),
                ],

                // Pending Reviews Section (admin only)
                if (user != null) _buildPendingReviewsSection(context, ref, user.uid),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderQuickStats(WidgetRef ref, String userId) {
    final debtsAsync = ref.watch(userDebtsStreamProvider(userId));
    final groupsAsync = ref.watch(userGroupsStreamProvider(userId));

    return debtsAsync.when(
      data: (debts) => groupsAsync.when(
        data: (groups) {
          final debtMonthly = debts.where((d) => d.isDebt).fold<double>(0, (s, d) => s + d.monthlyPayment);
          final billMonthly = debts.where((d) => d.isBill).fold<double>(0, (s, d) => s + d.monthlyPayment);
          final groupMonthly = groups.fold<double>(0, (s, g) => s + g.monthlyAmount);
          final total = debtMonthly + billMonthly + groupMonthly;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                          Text('RM${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Items', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                          Text('${debts.length + groups.length}', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPendingReviewsSection(BuildContext context, WidgetRef ref, String userId) {
    final groupsAsync = ref.watch(userGroupsStreamProvider(userId));

    return groupsAsync.when(
      data: (groups) {
        // Filter groups where current user is creator (admin)
        final adminGroups = groups.where((g) => g.createdBy == userId).toList();
        if (adminGroups.isEmpty) return const SizedBox.shrink();

        final adminGroupIds = adminGroups.map((g) => g.id).toList();
        final groupNameMap = {for (var g in adminGroups) g.id: g.name};

        return Column(
          children: [
            // Pending Payments
            _buildPendingPaymentsCard(context, ref, adminGroupIds, groupNameMap),
            // Pending Expenses
            _buildPendingExpensesCard(context, ref, adminGroupIds, groupNameMap),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPendingPaymentsCard(
    BuildContext context,
    WidgetRef ref,
    List<String> groupIds,
    Map<String, String> groupNameMap,
  ) {
    final paymentService = ref.watch(paymentServiceProvider);

    return StreamBuilder(
      stream: paymentService.getPendingPaymentsForGroupsStream(groupIds),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? [];
        if (payments.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            _buildSectionHeader(
              icon: Icons.payments_outlined,
              title: 'Pending Payments',
              count: payments.length,
              color: const Color(0xFFF57C00),
            ),
            const SizedBox(height: 12),
            ...payments.take(5).map((payment) => _buildPendingPaymentTile(
              context,
              userName: payment.userName,
              amount: payment.amount,
              groupName: groupNameMap[payment.groupId] ?? 'Unknown',
              groupId: payment.groupId,
              date: payment.paymentDate,
            )),
            if (payments.length > 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '+${payments.length - 5} more pending',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildPendingExpensesCard(
    BuildContext context,
    WidgetRef ref,
    List<String> groupIds,
    Map<String, String> groupNameMap,
  ) {
    final expenseService = ref.watch(expenseServiceProvider);

    return StreamBuilder(
      stream: expenseService.getPendingExpensesForGroupsStream(groupIds),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? [];
        if (expenses.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            _buildSectionHeader(
              icon: Icons.receipt_long_outlined,
              title: 'Pending Expenses',
              count: expenses.length,
              color: const Color(0xFFE65100),
            ),
            const SizedBox(height: 12),
            ...expenses.take(5).map((expense) => _buildPendingExpenseTile(
              context,
              title: expense.title,
              requestedBy: expense.requestedByName,
              amount: expense.amount,
              groupName: groupNameMap[expense.groupId] ?? 'Unknown',
              groupId: expense.groupId,
              date: expense.createdAt,
            )),
            if (expenses.length > 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '+${expenses.length - 5} more pending',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingPaymentTile(
    BuildContext context, {
    required String userName,
    required double amount,
    required String groupName,
    required String groupId,
    required DateTime date,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        AppTheme.slideRoute(GroupDetailScreen(groupId: groupId)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: const Color(0xFFFFA726).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFFCC02)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        groupName,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'RM${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF57C00)),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingExpenseTile(
    BuildContext context, {
    required String title,
    required String requestedBy,
    required double amount,
    required String groupName,
    required String groupId,
    required DateTime date,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        AppTheme.slideRoute(ExpenseListScreen(groupId: groupId, groupName: groupName)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFB8C00)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'by $requestedBy',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        groupName,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFBE9E7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'RM${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCommitmentDashboard(BuildContext context, WidgetRef ref, String userId) {
    final debtsAsync = ref.watch(userDebtsStreamProvider(userId));
    final groupsAsync = ref.watch(userGroupsStreamProvider(userId));

    return debtsAsync.when(
      data: (debts) {
        return groupsAsync.when(
          data: (groups) {
            // Calculate debt amounts (loans)
            final activeDebts = debts.where((d) => d.isDebt).toList();
            final debtMonthly = activeDebts.fold<double>(0, (sum, d) => sum + d.monthlyPayment);
            final debtRemaining = activeDebts.fold<double>(0, (sum, d) => sum + d.remainingBalance);

            // Calculate bill amounts (recurring)
            final activeBills = debts.where((d) => d.isBill).toList();
            final billMonthly = activeBills.fold<double>(0, (sum, d) => sum + d.monthlyPayment);

            // Calculate group payments
            final groupMonthly = groups.fold<double>(0, (sum, g) => sum + g.monthlyAmount);

            // Grand total
            final grandTotal = debtMonthly + billMonthly + groupMonthly;

            if (grandTotal == 0 && groups.isEmpty && debts.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                // Section header
                Row(
                  children: [
                    Container(
                      width: 4, height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Monthly Commitments',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Grand total card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00695C), Color(0xFF00897B), Color(0xFF26A69A)],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00897B).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Monthly', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  'RM${grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (debtRemaining > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.trending_down_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Total debt remaining: RM${_formatAmount(debtRemaining)}',
                                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Breakdown rows
                if (groups.isNotEmpty)
                  _buildCommitmentBreakdownCard(
                    icon: Icons.groups_outlined,
                    iconColor: const Color(0xFF7B1FA2),
                    bgColor: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
                    title: 'Group Payments',
                    amount: groupMonthly,
                    subtitle: '${groups.length} group${groups.length > 1 ? 's' : ''}',
                    onTap: () => Navigator.of(context).push(AppTheme.slideRoute(const GroupsListScreen())),
                    items: groups.map((g) => _CommitmentItem(g.name, g.monthlyAmount)).toList(),
                  ),
                if (groups.isNotEmpty) const SizedBox(height: 8),

                if (activeDebts.isNotEmpty)
                  _buildCommitmentBreakdownCard(
                    icon: Icons.account_balance_outlined,
                    iconColor: const Color(0xFF1565C0),
                    bgColor: const Color(0xFF1565C0).withValues(alpha: 0.08),
                    title: 'Loan Payments',
                    amount: debtMonthly,
                    subtitle: '${activeDebts.length} debt${activeDebts.length > 1 ? 's' : ''}',
                    onTap: () => Navigator.of(context).push(AppTheme.slideRoute(const DebtsListScreen())),
                    items: activeDebts.map((d) => _CommitmentItem(d.title, d.monthlyPayment)).toList(),
                  ),
                if (activeDebts.isNotEmpty) const SizedBox(height: 8),

                if (activeBills.isNotEmpty)
                  _buildCommitmentBreakdownCard(
                    icon: Icons.receipt_outlined,
                    iconColor: const Color(0xFFE65100),
                    bgColor: const Color(0xFFE65100).withValues(alpha: 0.08),
                    title: 'Bills & Subscriptions',
                    amount: billMonthly,
                    subtitle: '${activeBills.length} bill${activeBills.length > 1 ? 's' : ''}',
                    onTap: () => Navigator.of(context).push(AppTheme.slideRoute(const DebtsListScreen())),
                    items: activeBills.map((d) => _CommitmentItem(d.title, d.monthlyPayment)).toList(),
                  ),
                if (activeBills.isNotEmpty) const SizedBox(height: 8),

                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCommitmentBreakdownCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required double amount,
    required String subtitle,
    required VoidCallback onTap,
    required List<_CommitmentItem> items,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Text(
                  'RM${amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: iconColor),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 16, color: AppTheme.textHint.withValues(alpha: 0.5)),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: () {
                    final visible = items.take(5).toList();
                    return visible.asMap().entries.map((entry) {
                      final item = entry.value;
                      final isLast = entry.key == visible.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.5), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'RM${item.amount.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: iconColor.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  }(),
                ),
              ),
              if (items.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '+${items.length - 5} more',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  }
}

class _CommitmentItem {
  final String name;
  final double amount;
  const _CommitmentItem(this.name, this.amount);
}
