import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/debt_model.dart';
import 'package:duitkita/models/debt_payment_model.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class DebtDetailScreen extends ConsumerWidget {
  final String debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(debtStreamProvider(debtId));
    final paymentsAsync = ref.watch(debtPaymentsStreamProvider(debtId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: debtAsync.when(
        data: (debt) {
          if (debt == null) {
            return const Center(child: Text('Debt not found'));
          }
          final typeColor = debt.isDebt ? AppTheme.debtColor : AppTheme.billColor;
          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: debt.isDebt ? AppTheme.debtGradient : AppTheme.billGradient,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusXLarge)),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              PopupMenuButton<String>(
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                                ),
                                onSelected: (value) => _handleMenuAction(context, ref, value, debt),
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  if (debt.isActive)
                                    const PopupMenuItem(value: 'complete', child: Text('Mark as Completed')),
                                  if (!debt.isActive)
                                    const PopupMenuItem(value: 'reactivate', child: Text('Reactivate')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.error))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            debt.title,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            debt.creditor,
                            style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 20),

                          // Progress circle — only for debts
                          if (debt.isDebt) ...[
                            Center(
                              child: SizedBox(
                                width: 120, height: 120,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 120, height: 120,
                                      child: CircularProgressIndicator(
                                        value: debt.progressPercent,
                                        strokeWidth: 10,
                                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${(debt.progressPercent * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                        Text(
                                          'paid off',
                                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Bill badge
                          if (debt.isBill) ...[
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.autorenew, color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      'RM${debt.monthlyPayment.toStringAsFixed(2)}/month',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Summary cards
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        if (debt.isDebt) ...[
                          Row(
                            children: [
                              Expanded(child: _buildSummaryItem('Total Amount', 'RM${_formatAmount(debt.totalAmount)}', debt.isDebt ? AppTheme.debtColor : AppTheme.billColor)),
                              Container(width: 1, height: 40, color: Colors.grey.shade200),
                              Expanded(child: _buildSummaryItem('Total Paid', 'RM${_formatAmount(debt.totalPaid)}', AppTheme.success)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(height: 1, color: Colors.grey.shade100),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildSummaryItem('Remaining', 'RM${_formatAmount(debt.remainingBalance)}', AppTheme.warning)),
                              Container(width: 1, height: 40, color: Colors.grey.shade200),
                              Expanded(child: _buildSummaryItem('Monthly', 'RM${_formatAmount(debt.monthlyPayment)}', AppTheme.primary)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(height: 1, color: Colors.grey.shade100),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  'Months Left',
                                  '${debt.monthsRemaining}',
                                  const Color(0xFF1565C0),
                                ),
                              ),
                              Container(width: 1, height: 40, color: Colors.grey.shade200),
                              Expanded(
                                child: _buildSummaryItem(
                                  'Est. Payoff',
                                  '${_monthName(debt.estimatedPayoffDate.month)} ${debt.estimatedPayoffDate.year}',
                                  const Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (debt.isBill) ...[
                          Row(
                            children: [
                              Expanded(child: _buildSummaryItem('Monthly Amount', 'RM${_formatAmount(debt.monthlyPayment)}', debt.isDebt ? AppTheme.debtColor : AppTheme.billColor)),
                              Container(width: 1, height: 40, color: Colors.grey.shade200),
                              Expanded(child: _buildSummaryItem('Due Day', '${debt.dueDay}', AppTheme.primary)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(height: 1, color: Colors.grey.shade100),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildSummaryItem('Type', 'Recurring Bill', const Color(0xFF1565C0))),
                              Container(width: 1, height: 40, color: Colors.grey.shade200),
                              Expanded(child: _buildSummaryItem('Total Paid', 'RM${_formatAmount(debt.totalPaid)}', AppTheme.success)),
                            ],
                          ),
                        ],
                        if (debt.description != null && debt.description!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Divider(height: 1, color: Colors.grey.shade100),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes_outlined, size: 16, color: AppTheme.textHint),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(debt.description!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Record payment button
              if (debt.isActive)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _showRecordPaymentSheet(context, ref, debt),
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        label: const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: typeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ),

              // Payment history header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Container(
                        width: 4, height: 20,
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Payment History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),

              // Payment history
              paymentsAsync.when(
                data: (payments) {
                  if (payments.isEmpty) {
                    return SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textHint.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text('No payments recorded yet', style: TextStyle(fontSize: 14, color: AppTheme.textHint)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildPaymentTile(context, ref, payments[index], debt),
                        childCount: payments.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.debtColor))),
                ),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.debtColor)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildPaymentTile(BuildContext context, WidgetRef ref, DebtPaymentModel payment, DebtModel debt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: Icon(Icons.check_circle_outline, color: AppTheme.success, size: 22)),
        ),
        title: Text(
          'RM${payment.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}${payment.notes != null && payment.notes!.isNotEmpty ? ' - ${payment.notes}' : ''}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.error.withValues(alpha: 0.6)),
          onPressed: () => _confirmDeletePayment(context, ref, payment, debt),
        ),
      ),
    );
  }

  void _showRecordPaymentSheet(BuildContext context, WidgetRef ref, DebtModel debt) {
    final amountController = TextEditingController(text: debt.monthlyPayment.toStringAsFixed(2));
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Record Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text('for ${debt.title}', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 20),

              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                decoration: AppTheme.styledInput(
                  label: 'Amount (RM)',
                  prefixIcon: Icons.payments_outlined,
                  hint: debt.monthlyPayment.toStringAsFixed(2),
                ),
              ),
              const SizedBox(height: 14),

              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 12),
                      Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: notesController,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                decoration: AppTheme.styledInput(
                  label: 'Notes (optional)',
                  prefixIcon: Icons.notes_outlined,
                  hint: 'e.g., Monthly installment',
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      showSnackBar(ctx, 'Enter a valid amount', isError: true);
                      return;
                    }

                    try {
                      final debtService = ref.read(debtServiceProvider);
                      await debtService.addDebtPayment(
                        debtId: debtId,
                        amount: amount,
                        paymentDate: selectedDate,
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      );

                      // Check if debt is fully paid (skip for bills)
                      if (debt.isDebt && debt.totalPaid + amount >= debt.totalAmount) {
                        await debtService.markDebtComplete(debtId);
                      }

                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        showSnackBar(context, 'Payment recorded!');
                      }
                    } catch (e) {
                      if (ctx.mounted) showSnackBar(ctx, 'Failed: $e', isError: true);
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: const Text('Save Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: debt.isDebt ? AppTheme.debtColor : AppTheme.billColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDebtSheet(BuildContext context, WidgetRef ref, DebtModel debt) {
    final titleController = TextEditingController(text: debt.title);
    final creditorController = TextEditingController(text: debt.creditor);
    final monthlyController = TextEditingController(text: debt.monthlyPayment.toStringAsFixed(2));
    final totalAmountController = TextEditingController(text: debt.totalAmount.toStringAsFixed(2));
    final dueDayController = TextEditingController(text: debt.dueDay.toString());
    final descriptionController = TextEditingController(text: debt.description ?? '');
    String category = debt.category;

    final categories = DebtModel.categoriesForType(debt.type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit ${debt.isBill ? 'Bill' : 'Debt'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 20),

                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  decoration: AppTheme.styledInput(label: 'Title', prefixIcon: Icons.title, hint: 'e.g., Car Loan'),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: creditorController,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  decoration: AppTheme.styledInput(
                    label: debt.isBill ? 'Provider' : 'Owed To',
                    prefixIcon: Icons.business_outlined,
                    hint: debt.isBill ? 'e.g., Astro, Maxis' : 'e.g., Maybank',
                  ),
                ),
                const SizedBox(height: 14),

                if (debt.isDebt) ...[
                  TextField(
                    controller: totalAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    decoration: AppTheme.styledInput(label: 'Total Amount (RM)', prefixIcon: Icons.account_balance_wallet_outlined, hint: '50000'),
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: monthlyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        decoration: AppTheme.styledInput(label: 'Monthly (RM)', prefixIcon: Icons.calendar_month_outlined, hint: '800'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: dueDayController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        decoration: AppTheme.styledInput(label: 'Due Day (1-28)', prefixIcon: Icons.event_outlined, hint: '1'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category selector
                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final isSelected = category == cat.value;
                    return GestureDetector(
                      onTap: () => setSheetState(() => category = cat.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? cat.color : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? cat.color : Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              cat.label,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  decoration: AppTheme.styledInput(label: 'Notes (optional)', prefixIcon: Icons.notes_outlined, hint: 'Any additional details...'),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final creditor = creditorController.text.trim();
                      if (title.isEmpty) {
                        showSnackBar(ctx, 'Title is required', isError: true);
                        return;
                      }
                      if (creditor.isEmpty) {
                        showSnackBar(ctx, '${debt.isBill ? "Provider" : "Owed To"} is required', isError: true);
                        return;
                      }
                      final monthly = double.tryParse(monthlyController.text.trim());
                      if (monthly == null || monthly <= 0) {
                        showSnackBar(ctx, 'Enter a valid monthly amount', isError: true);
                        return;
                      }
                      final dueDay = int.tryParse(dueDayController.text.trim()) ?? 1;
                      if (dueDay < 1 || dueDay > 28) {
                        showSnackBar(ctx, 'Due day must be between 1-28', isError: true);
                        return;
                      }

                      final updateData = <String, dynamic>{
                        'title': title,
                        'creditor': creditor,
                        'monthlyPayment': monthly,
                        'dueDay': dueDay,
                        'category': category,
                        'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      };

                      if (debt.isDebt) {
                        final totalAmount = double.tryParse(totalAmountController.text.trim());
                        if (totalAmount == null || totalAmount <= 0) {
                          showSnackBar(ctx, 'Enter a valid total amount', isError: true);
                          return;
                        }
                        updateData['totalAmount'] = totalAmount;
                      }

                      try {
                        final debtService = ref.read(debtServiceProvider);
                        await debtService.updateDebt(debtId, updateData);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          showSnackBar(context, '${debt.isBill ? "Bill" : "Debt"} updated!');
                        }
                      } catch (e) {
                        if (ctx.mounted) showSnackBar(ctx, 'Failed: $e', isError: true);
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: debt.isDebt ? AppTheme.debtColor : AppTheme.billColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeletePayment(BuildContext context, WidgetRef ref, DebtPaymentModel payment, DebtModel debt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        title: const Text('Delete Payment?'),
        content: Text('Remove RM${payment.amount.toStringAsFixed(2)} payment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final debtService = ref.read(debtServiceProvider);
                await debtService.deleteDebtPayment(
                  debtId: debtId,
                  paymentId: payment.id,
                  amount: payment.amount,
                );
                // Reactivate if was completed
                if (!debt.isActive) {
                  await debtService.reactivateDebt(debtId);
                }
                if (context.mounted) showSnackBar(context, 'Payment deleted');
              } catch (e) {
                if (context.mounted) showSnackBar(context, 'Failed: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action, DebtModel debt) {
    final debtService = ref.read(debtServiceProvider);

    if (action == 'edit') {
      _showEditDebtSheet(context, ref, debt);
      return;
    } else if (action == 'complete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          title: const Text('Mark as Completed?'),
          content: const Text('This debt will be moved to completed section.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await debtService.markDebtComplete(debtId);
                if (context.mounted) showSnackBar(context, 'Debt marked as completed!');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              child: const Text('Complete'),
            ),
          ],
        ),
      );
    } else if (action == 'reactivate') {
      debtService.reactivateDebt(debtId);
      showSnackBar(context, 'Debt reactivated');
    } else if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          title: const Text('Delete Debt?'),
          content: const Text('This will permanently delete this debt and all its payment history.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await debtService.deleteDebt(debtId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  showSnackBar(context, 'Debt deleted');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }

  static String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1) % 12];
  }
}
