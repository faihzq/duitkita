import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/expense_model.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/screens/add_expense_screen.dart';
import 'package:duitkita/screens/expense_detail_screen.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const ExpenseListScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  ExpenseStatus? _selectedFilter;
  int? _selectedYear; // null = All years
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.title}" (RM${expense.amount.toStringAsFixed(2)})?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final expenseService = ref.read(expenseServiceProvider);
      await expenseService.deleteExpense(expense.id);
      if (mounted) showSnackBar(context, 'Expense deleted');
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to delete expense', isError: true);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<ExpenseModel> expenses) {
    final pendingExpenses = expenses.where((e) => e.status == ExpenseStatus.pending).toList();
    setState(() {
      if (_selectedIds.length == pendingExpenses.length) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds
          ..clear()
          ..addAll(pendingExpenses.map((e) => e.id));
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchApprove() async {
    if (_selectedIds.isEmpty) return;

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    setState(() => _isProcessing = true);
    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);
      final expenseService = ref.read(expenseServiceProvider);

      final count = await expenseService.batchApproveExpenses(
        expenseIds: _selectedIds.toList(),
        approvedBy: userId,
        approvedByName: profile?.name ?? 'Admin',
      );

      if (!mounted) return;
      showSnackBar(context, '$count expense${count > 1 ? 's' : ''} approved');
      _exitSelectionMode();
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _batchReject() async {
    if (_selectedIds.isEmpty) return;

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    setState(() => _isProcessing = true);
    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);
      final expenseService = ref.read(expenseServiceProvider);

      final count = await expenseService.batchRejectExpenses(
        expenseIds: _selectedIds.toList(),
        rejectedBy: userId,
        rejectedByName: profile?.name ?? 'Admin',
      );

      if (!mounted) return;
      showSnackBar(context, '$count expense${count > 1 ? 's' : ''} rejected');
      _exitSelectionMode();
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(
      groupExpensesStreamProvider(widget.groupId),
    );
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));
    final isAdmin = membersAsync.whenOrNull(
      data: (members) {
        final current = members.where((m) => m.userId == userId);
        return current.isNotEmpty && current.first.isAdmin;
      },
    ) ?? false;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedIds.length} selected' : 'Expenses'),
        backgroundColor: _selectionMode ? AppTheme.textPrimary : AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _selectionMode
            ? [
                expensesAsync.when(
                  data: (expenses) {
                    final pendingExpenses = expenses.where((e) => e.status == ExpenseStatus.pending).toList();
                    final allSelected = _selectedIds.length == pendingExpenses.length && pendingExpenses.isNotEmpty;
                    return IconButton(
                      icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                      tooltip: allSelected ? 'Deselect All' : 'Select All',
                      onPressed: () => _toggleSelectAll(expenses),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Filter chips with gradient header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              gradient: _selectionMode ? null : AppTheme.primaryGradient,
              color: _selectionMode ? AppTheme.textPrimary : null,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildFilterChip('All', null),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', ExpenseStatus.pending),
                    const SizedBox(width: 8),
                    _buildFilterChip('Approved', ExpenseStatus.approved),
                    const SizedBox(width: 8),
                    _buildFilterChip('Rejected', ExpenseStatus.rejected),
                    const Spacer(),
                    _buildYearSelector(expensesAsync),
                  ],
                ),
              ],
            ),
          ),

          // Expense list
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                var filtered = _selectedFilter == null
                    ? expenses.toList()
                    : expenses.where((e) => e.status == _selectedFilter).toList();

                if (_selectedYear != null) {
                  filtered = filtered.where((e) => e.createdAt.year == _selectedYear).toList();
                }

                // Clean up selections for items no longer in the list
                _selectedIds.removeWhere((id) => !expenses.any((e) => e.id == id));

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: AppTheme.cardBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long, size: 48, color: AppTheme.textHint),
                        ),
                        const SizedBox(height: 16),
                        const Text('No expenses yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        const Text('Submit an expense request to get started',
                          style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length + 1, // +1 for summary card
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildYearlySummaryCard(filtered);
                    }
                    final expense = filtered[index - 1];
                    final isPending = expense.status == ExpenseStatus.pending;
                    final isSelected = _selectedIds.contains(expense.id);

                    if (_selectionMode && isPending) {
                      return _buildSelectableExpenseCard(expense, isSelected);
                    }

                    if (!isAdmin) return _buildExpenseCard(expense, isAdmin: false);
                    return Dismissible(
                      key: ValueKey(expense.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _deleteExpense(expense);
                        return false; // stream handles removal
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
                      ),
                      child: _buildExpenseCard(expense, isAdmin: isAdmin),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error loading expenses: $error',
                    style: const TextStyle(color: AppTheme.error),
                    textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  AppTheme.slideRoute(AddExpenseScreen(groupId: widget.groupId)),
                );
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Expense', style: TextStyle(fontWeight: FontWeight.w600)),
            ),

      // Bottom action bar for selection mode
      bottomNavigationBar: !_selectionMode || _selectedIds.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _batchReject,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: Text(
                          'Reject (${_selectedIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.error,
                          elevation: 0,
                          side: const BorderSide(color: AppTheme.error, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _batchApprove,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          'Approve (${_selectedIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildYearSelector(AsyncValue<List<ExpenseModel>> expensesAsync) {
    return expensesAsync.when(
      data: (expenses) {
        final years = expenses.map((e) => e.createdAt.year).toSet().toList()..sort((a, b) => b.compareTo(a));
        if (years.isEmpty) return const SizedBox.shrink();

        return PopupMenuButton<int?>(
          onSelected: (year) {
            setState(() {
              _selectedYear = year;
              if (_selectionMode) {
                _selectionMode = false;
                _selectedIds.clear();
              }
            });
          },
          itemBuilder: (context) => [
            PopupMenuItem<int?>(
              value: null,
              child: Text('All Years',
                style: TextStyle(
                  fontWeight: _selectedYear == null ? FontWeight.w700 : FontWeight.w500,
                  color: _selectedYear == null ? AppTheme.primary : AppTheme.textPrimary,
                )),
            ),
            ...years.map((y) => PopupMenuItem<int?>(
              value: y,
              child: Text('$y',
                style: TextStyle(
                  fontWeight: _selectedYear == y ? FontWeight.w700 : FontWeight.w500,
                  color: _selectedYear == y ? AppTheme.primary : AppTheme.textPrimary,
                )),
            )),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _selectedYear != null ? 1.0 : 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedYear?.toString() ?? 'Year',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _selectedYear != null ? AppTheme.primary : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 18,
                  color: _selectedYear != null ? AppTheme.primary : Colors.white.withValues(alpha: 0.85)),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildYearlySummaryCard(List<ExpenseModel> expenses) {
    double totalApproved = 0;
    double totalPending = 0;
    double totalRejected = 0;
    int approvedCount = 0;
    int pendingCount = 0;
    int rejectedCount = 0;

    for (final e in expenses) {
      switch (e.status) {
        case ExpenseStatus.approved:
          totalApproved += e.amount;
          approvedCount++;
        case ExpenseStatus.pending:
          totalPending += e.amount;
          pendingCount++;
        case ExpenseStatus.rejected:
          totalRejected += e.amount;
          rejectedCount++;
      }
    }

    final total = totalApproved + totalPending + totalRejected;
    final yearLabel = _selectedYear?.toString() ?? 'All Time';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(Icons.summarize_outlined, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text('Summary \u2022 $yearLabel',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${expenses.length} items',
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 14),
          // Total
          Row(
            children: [
              const Text('Total', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('RM${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Breakdown row
          Row(
            children: [
              Expanded(child: _summaryItem('Approved', approvedCount, totalApproved, AppTheme.success)),
              Container(width: 1, height: 36, color: AppTheme.cardBg),
              Expanded(child: _summaryItem('Pending', pendingCount, totalPending, AppTheme.warning)),
              Container(width: 1, height: 36, color: AppTheme.cardBg),
              Expanded(child: _summaryItem('Rejected', rejectedCount, totalRejected, AppTheme.error)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int count, double amount, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text('RM${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildFilterChip(String label, ExpenseStatus? status) {
    final isSelected = _selectedFilter == status;
    final chipColor = status != null ? _getStatusColor(status) : AppTheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = status;
          // Exit selection mode when changing filter
          if (_selectionMode) {
            _selectionMode = false;
            _selectedIds.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? chipColor : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableExpenseCard(ExpenseModel expense, bool isSelected) {
    final statusColor = _getStatusColor(expense.status);

    return GestureDetector(
      onTap: () => _toggleSelection(expense.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.4) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.textHint.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 14),

              // Status icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getStatusIcon(expense.status), color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(expense.requestedByName,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ),

              // Amount
              Text('RM${expense.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(ExpenseModel expense, {required bool isAdmin}) {
    final statusColor = _getStatusColor(expense.status);
    final statusLabel = expense.status.name[0].toUpperCase() + expense.status.name.substring(1);
    final isPending = expense.status == ExpenseStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () {
            Navigator.of(context).push(
              AppTheme.slideRoute(ExpenseDetailScreen(
                expense: expense,
                groupId: widget.groupId,
              )),
            );
          },
          onLongPress: isAdmin && isPending
              ? () {
                  setState(() {
                    _selectionMode = true;
                    _selectedIds.add(expense.id);
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getStatusIcon(expense.status), color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(expense.requestedByName,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      const SizedBox(height: 2),
                      Text(
                        '${expense.createdAt.day}/${expense.createdAt.month}/${expense.createdAt.year}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),

                // Amount & status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('RM${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(statusLabel,
                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
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

  IconData _getStatusIcon(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return Icons.schedule;
      case ExpenseStatus.approved:
        return Icons.check_circle;
      case ExpenseStatus.rejected:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return AppTheme.warning;
      case ExpenseStatus.approved:
        return AppTheme.success;
      case ExpenseStatus.rejected:
        return AppTheme.error;
    }
  }
}
