import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/debt_model.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class AddDebtScreen extends ConsumerStatefulWidget {
  const AddDebtScreen({super.key});

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _titleController = TextEditingController();
  final _creditorController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _monthlyPaymentController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDayController = TextEditingController(text: '1');
  final _totalPaidController = TextEditingController(text: '0');
  String _category = 'other';
  String _type = 'debt'; // 'debt' or 'bill'
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _creditorController.dispose();
    _totalAmountController.dispose();
    _monthlyPaymentController.dispose();
    _descriptionController.dispose();
    _dueDayController.dispose();
    _totalPaidController.dispose();
    super.dispose();
  }

  List<DebtCategory> get _categories => DebtModel.categoriesForType(_type);

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _createDebt() async {
    final title = _titleController.text.trim();
    final creditor = _creditorController.text.trim();
    final totalStr = _totalAmountController.text.trim();
    final monthlyStr = _monthlyPaymentController.text.trim();
    final dueDayStr = _dueDayController.text.trim();
    final totalPaidStr = _totalPaidController.text.trim();

    if (title.isEmpty) {
      showSnackBar(context, 'Title is required', isError: true);
      return;
    }
    if (creditor.isEmpty) {
      showSnackBar(context, _type == 'bill' ? 'Provider is required' : 'Owed To is required', isError: true);
      return;
    }
    final bool isBill = _type == 'bill';
    final totalAmount = isBill ? 0.0 : (double.tryParse(totalStr) ?? -1);
    if (!isBill && (totalAmount <= 0)) {
      showSnackBar(context, 'Enter a valid total amount', isError: true);
      return;
    }
    final monthlyPayment = double.tryParse(monthlyStr);
    if (monthlyPayment == null || monthlyPayment <= 0) {
      showSnackBar(context, 'Enter a valid monthly amount', isError: true);
      return;
    }
    final dueDay = int.tryParse(dueDayStr) ?? 1;
    if (dueDay < 1 || dueDay > 28) {
      showSnackBar(context, 'Due day must be between 1-28', isError: true);
      return;
    }
    final totalPaid = isBill ? 0.0 : (double.tryParse(totalPaidStr) ?? 0);

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final debtService = ref.read(debtServiceProvider);
      await debtService.createDebt(
        userId: userId,
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        creditor: creditor,
        totalAmount: totalAmount,
        monthlyPayment: monthlyPayment,
        startDate: _startDate,
        dueDay: dueDay,
        category: _category,
        type: _type,
        totalPaid: totalPaid,
      );

      if (mounted) {
        showSnackBar(context, _type == 'bill' ? 'Bill added successfully!' : 'Debt added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to add debt: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: _type == 'debt' ? AppTheme.debtGradient : AppTheme.billGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusXLarge)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          const SizedBox(width: 12),
                          Text(_type == 'bill' ? 'Add Bill' : 'Add Debt', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _type == 'bill' ? 'Track a recurring bill or subscription' : 'Track a new loan or commitment',
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Form
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Debt / Bill toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _type = 'debt'; _category = 'other'; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _type == 'debt' ? AppTheme.debtColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_outlined, size: 18, color: _type == 'debt' ? Colors.white : AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text('Debt / Loan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _type == 'debt' ? Colors.white : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _type = 'bill'; _category = 'other'; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _type == 'bill' ? AppTheme.billColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_outlined, size: 18, color: _type == 'bill' ? Colors.white : AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text('Bill / Subscription', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _type == 'bill' ? Colors.white : AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Category selector
                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _category == cat.value;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? cat.color : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? cat.color : Colors.grey.shade300,
                          ),
                          boxShadow: isSelected ? [BoxShadow(color: cat.color.withValues(alpha: 0.3), blurRadius: 8)] : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 18, color: isSelected ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              cat.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Title
                TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  decoration: AppTheme.styledInput(
                    label: 'Debt Title',
                    prefixIcon: Icons.title,
                    hint: 'e.g., Car Loan Myvi',
                  ),
                ),
                const SizedBox(height: 16),

                // Creditor / Provider
                TextField(
                  controller: _creditorController,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  decoration: AppTheme.styledInput(
                    label: _type == 'bill' ? 'Provider' : 'Owed To',
                    prefixIcon: Icons.business_outlined,
                    hint: _type == 'bill' ? 'e.g., Astro, Maxis, TNB' : 'e.g., Maybank, Ali, PTPTN',
                  ),
                ),
                const SizedBox(height: 16),

                // Total Amount & Monthly Payment (row) — hide total for bills
                if (_type == 'debt')
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _totalAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          decoration: AppTheme.styledInput(
                            label: 'Total Amount (RM)',
                            prefixIcon: Icons.account_balance_wallet_outlined,
                            hint: '50000',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _monthlyPaymentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          decoration: AppTheme.styledInput(
                            label: 'Monthly (RM)',
                            prefixIcon: Icons.calendar_month_outlined,
                            hint: '800',
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_type == 'bill')
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _monthlyPaymentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          decoration: AppTheme.styledInput(
                            label: 'Monthly Amount (RM)',
                            prefixIcon: Icons.payments_outlined,
                            hint: '150',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dueDayController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          decoration: AppTheme.styledInput(
                            label: 'Due Day (1-28)',
                            prefixIcon: Icons.event_outlined,
                            hint: '1',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),

                // Total Already Paid & Due Day (row) — only for debts
                if (_type == 'debt')
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _totalPaidController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          decoration: AppTheme.styledInput(
                            label: 'Already Paid (RM)',
                            prefixIcon: Icons.payments_outlined,
                            hint: '0',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dueDayController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          decoration: AppTheme.styledInput(
                            label: 'Due Day (1-28)',
                            prefixIcon: Icons.event_outlined,
                            hint: '1',
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_type == 'debt')
                  const SizedBox(height: 16),

                // Start Date — only for debts
                if (_type == 'debt')
                GestureDetector(
                  onTap: _pickStartDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 20, color: AppTheme.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_calendar_outlined, size: 18, color: AppTheme.textHint),
                      ],
                    ),
                  ),
                ),
                if (_type == 'debt')
                  const SizedBox(height: 16),

                // Description
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  decoration: AppTheme.styledInput(
                    label: 'Notes (optional)',
                    prefixIcon: Icons.notes_outlined,
                    hint: 'Any additional details...',
                  ),
                ),
                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createDebt,
                    icon: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Icon(Icons.add_circle_outline, size: 22),
                    label: Text(
                      _isLoading ? '' : (_type == 'bill' ? 'Add Bill' : 'Add Debt'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _type == 'debt' ? AppTheme.debtColor : AppTheme.billColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
