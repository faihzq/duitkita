import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/debt_model.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/screens/add_debt_screen.dart';
import 'package:duitkita/screens/debt_detail_screen.dart';
import 'package:duitkita/config/app_theme.dart';

class DebtsListScreen extends ConsumerStatefulWidget {
  const DebtsListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DebtsListScreen> createState() => _DebtsListScreenState();
}

class _DebtsListScreenState extends ConsumerState<DebtsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Active color based on selected tab
  Color get _activeColor {
    switch (_tabController.index) {
      case 1: return AppTheme.debtColor;
      case 2: return AppTheme.billColor;
      default: return AppTheme.debtColor;
    }
  }

  LinearGradient get _activeGradient {
    switch (_tabController.index) {
      case 1: return AppTheme.debtGradient;
      case 2: return AppTheme.billGradient;
      default: return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.debtColorDark, AppTheme.billColorDark, AppTheme.billColor],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Debts')),
        body: const Center(child: Text('You need to be logged in')),
      );
    }

    final debtsAsync = ref.watch(allUserDebtsStreamProvider(userId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Gradient Header
          SliverToBoxAdapter(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: _activeGradient,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppTheme.radiusXLarge),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (Navigator.of(context).canPop())
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: Navigator.of(context).canPop() ? 20 : 8),
                      const Text(
                        'Debts & Bills',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track your loans, bills & commitments',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 18),
                      debtsAsync.when(
                        data: (debts) {
                          final active = debts.where((d) => d.isActive).toList();
                          final activeDebts = active.where((d) => d.isDebt).toList();
                          final activeBills = active.where((d) => d.isBill).toList();
                          final totalMonthly = active.fold<double>(0, (sum, d) => sum + d.monthlyPayment);
                          final totalRemaining = activeDebts.fold<double>(0, (sum, d) => sum + d.remainingBalance);
                          return Column(
                            children: [
                              Row(
                                children: [
                                  _buildStatChip(Icons.account_balance_outlined, '${activeDebts.length} Loans'),
                                  const SizedBox(width: 10),
                                  _buildStatChip(Icons.receipt_outlined, '${activeBills.length} Bills'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildStatChip(Icons.calendar_month_outlined, 'RM${totalMonthly.toStringAsFixed(0)}/mo'),
                                  if (activeDebts.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    _buildStatChip(Icons.account_balance_wallet_outlined, 'RM${_formatAmount(totalRemaining)} left'),
                                  ],
                                ],
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: Container(
                color: AppTheme.surfaceBg,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: _activeColor,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: _activeColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    labelPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.view_list_outlined, size: 16),
                            SizedBox(width: 5),
                            Text('All'),
                          ],
                        ),
                      ),
                      Tab(
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_outlined, size: 16),
                            SizedBox(width: 5),
                            Text('Loans'),
                          ],
                        ),
                      ),
                      Tab(
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_outlined, size: 16),
                            SizedBox(width: 5),
                            Text('Bills'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: debtsAsync.when(
          data: (debts) {
            if (debts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: _activeColor.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.account_balance_outlined, size: 48, color: _activeColor.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(height: 20),
                    const Text('No debts or bills yet', style: TextStyle(fontSize: 18, color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your debts and bills\nto track your commitments',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        AppTheme.slideRoute(const AddDebtScreen()),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Debt or Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _activeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(context, debts, 'all'),
                _buildTabContent(context, debts, 'debt'),
                _buildTabContent(context, debts, 'bill'),
              ],
            );
          },
          loading: () => Center(child: CircularProgressIndicator(color: _activeColor)),
          error: (error, _) => Center(child: Text('Error: $error', style: const TextStyle(color: AppTheme.textSecondary))),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addDebtFab',
        backgroundColor: _activeColor,
        onPressed: () => Navigator.of(context).push(
          AppTheme.slideRoute(const AddDebtScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add New', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, List<DebtModel> debts, String filter) {
    final List<DebtModel> active;
    final List<DebtModel> completed;
    final String emptyLabel;
    final IconData emptyIcon;

    switch (filter) {
      case 'debt':
        active = debts.where((d) => d.isActive && d.isDebt).toList();
        completed = debts.where((d) => !d.isActive && d.isDebt).toList();
        emptyLabel = 'No loans yet';
        emptyIcon = Icons.account_balance_outlined;
        break;
      case 'bill':
        active = debts.where((d) => d.isActive && d.isBill).toList();
        completed = debts.where((d) => !d.isActive && d.isBill).toList();
        emptyLabel = 'No bills yet';
        emptyIcon = Icons.receipt_outlined;
        break;
      default:
        active = debts.where((d) => d.isActive).toList();
        completed = debts.where((d) => !d.isActive).toList();
        emptyLabel = 'No items yet';
        emptyIcon = Icons.account_balance_outlined;
    }

    if (active.isEmpty && completed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 48, color: AppTheme.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(emptyLabel, style: const TextStyle(fontSize: 16, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Tap + to add one',
              style: TextStyle(fontSize: 13, color: AppTheme.textHint.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        ...active.asMap().entries.map((e) => _buildDebtCard(context, e.value, e.key)),
        if (completed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 4, height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Completed (${completed.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textHint)),
              ],
            ),
          ),
          ...completed.asMap().entries.map((e) => _buildDebtCard(context, e.value, e.key, completed: true)),
        ],
      ],
    );
  }

  Widget _buildDebtCard(BuildContext context, DebtModel debt, int index, {bool completed = false}) {
    final catInfo = debt.categoryInfo;
    final typeColor = debt.isDebt ? AppTheme.debtColor : AppTheme.billColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: completed ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: completed ? [] : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => Navigator.of(context).push(
            AppTheme.slideRoute(DebtDetailScreen(debtId: debt.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        gradient: completed
                            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [catInfo.color, catInfo.color.withValues(alpha: 0.7)],
                              ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(catInfo.icon, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: completed ? AppTheme.textHint : AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            debt.creditor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildInfoTag(Icons.payments_outlined, 'RM${debt.monthlyPayment.toStringAsFixed(0)}/mo'),
                              const SizedBox(width: 8),
                              if (completed)
                                _buildInfoTag(Icons.check_circle_outline, 'Completed')
                              else if (debt.isBill)
                                _buildInfoTag(Icons.autorenew_outlined, 'Recurring')
                              else
                                _buildInfoTag(Icons.timer_outlined, '${debt.monthsRemaining} months left'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_forward_ios, size: 14, color: typeColor.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                if (!completed && debt.isDebt) ...[
                  const SizedBox(height: 14),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RM${_formatAmount(debt.totalPaid)} paid',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                          Text(
                            'RM${_formatAmount(debt.totalAmount)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textHint),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: debt.progressPercent,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            debt.progressPercent >= 0.75
                                ? AppTheme.success
                                : debt.progressPercent >= 0.5
                                    ? AppTheme.warning
                                    : AppTheme.debtColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(debt.progressPercent * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.debtColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textHint),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        ],
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _TabBarDelegate({required this.tabBar});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return tabBar;
  }

  @override
  double get maxExtent => 68;

  @override
  double get minExtent => 68;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
