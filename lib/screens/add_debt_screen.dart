import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/debt_model.dart';
import 'package:duitkita/services/debt_service.dart';
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

  bool get _isDebt => _type == 'debt';
  Color get _accentColor => _isDebt ? DT.catDebts : DT.catBills;

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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: DT.primary),
        ),
        child: child!,
      ),
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
      showSnackBar(context, _isDebt ? 'Owed To is required' : 'Provider is required', isError: true);
      return;
    }
    final totalAmount = _isDebt ? (double.tryParse(totalStr) ?? -1) : 0.0;
    if (_isDebt && totalAmount <= 0) {
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
      showSnackBar(context, 'Due day must be between 1–28', isError: true);
      return;
    }
    final totalPaid = _isDebt ? (double.tryParse(totalPaidStr) ?? 0) : 0.0;

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(debtServiceProvider).createDebt(
        userId: userId,
        title: title,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
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
        showSnackBar(context, _isDebt ? 'Debt added!' : 'Bill added!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────
          _Header(isDebt: _isDebt, accentColor: _accentColor),

          // ── Scrollable form ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DS.xl, DS.xl, DS.xl, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type toggle
                  _TypeToggle(
                    isDebt: _isDebt,
                    onDebt: () => setState(() { _type = 'debt'; _category = 'other'; }),
                    onBill: () => setState(() { _type = 'bill'; _category = 'other'; }),
                  ),
                  const SizedBox(height: DS.xl),

                  // Category
                  _SectionLabel('Category'),
                  const SizedBox(height: DS.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final sel = _category == cat.value;
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: sel ? _accentColor : DT.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sel ? _accentColor : DT.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.icon, size: 15, color: sel ? Colors.white : DT.textSecondary),
                              const SizedBox(width: 6),
                              Text(cat.label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : DT.text)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: DS.xl),

                  // Title
                  _Field(controller: _titleController, label: _isDebt ? 'Debt Title' : 'Bill Title', icon: Icons.title_rounded, hint: _isDebt ? 'e.g., Car Loan Myvi' : 'e.g., Unifi, Netflix', capitalization: TextCapitalization.words),
                  const SizedBox(height: DS.md),

                  // Creditor / Provider
                  _Field(controller: _creditorController, label: _isDebt ? 'Owed To' : 'Provider', icon: Icons.business_outlined, hint: _isDebt ? 'e.g., Maybank, PTPTN' : 'e.g., Astro, TNB', capitalization: TextCapitalization.words),
                  const SizedBox(height: DS.md),

                  // Amount row
                  if (_isDebt)
                    Row(children: [
                      Expanded(child: _Field(controller: _totalAmountController, label: 'Total Amount (RM)', icon: Icons.account_balance_wallet_outlined, hint: '50000', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))])),
                      const SizedBox(width: DS.md),
                      Expanded(child: _Field(controller: _monthlyPaymentController, label: 'Monthly (RM)', icon: Icons.calendar_month_outlined, hint: '800', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))])),
                    ])
                  else
                    Row(children: [
                      Expanded(child: _Field(controller: _monthlyPaymentController, label: 'Monthly (RM)', icon: Icons.payments_outlined, hint: '150', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))])),
                      const SizedBox(width: DS.md),
                      Expanded(child: _Field(controller: _dueDayController, label: 'Due Day (1–28)', icon: Icons.event_outlined, hint: '1', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                    ]),
                  const SizedBox(height: DS.md),

                  // Debt-only: already paid + due day
                  if (_isDebt) ...[
                    Row(children: [
                      Expanded(child: _Field(controller: _totalPaidController, label: 'Already Paid (RM)', icon: Icons.payments_outlined, hint: '0', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))])),
                      const SizedBox(width: DS.md),
                      Expanded(child: _Field(controller: _dueDayController, label: 'Due Day (1–28)', icon: Icons.event_outlined, hint: '1', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                    ]),
                    const SizedBox(height: DS.md),

                    // Start date
                    GestureDetector(
                      onTap: _pickStartDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DT.border),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_outlined, size: 18, color: DT.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${_startDate.day}/${_startDate.month}/${_startDate.year}', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
                            ],
                          )),
                          Icon(Icons.edit_calendar_outlined, size: 16, color: DT.textTertiary),
                        ]),
                      ),
                    ),
                    const SizedBox(height: DS.md),
                  ],

                  // Notes
                  _Field(controller: _descriptionController, label: 'Notes (optional)', icon: Icons.notes_rounded, hint: 'Any additional details...', maxLines: 2),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Sticky CTA ───────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DS.xl, DS.sm, DS.xl, DS.md),
          child: GestureDetector(
            onTap: _isLoading ? null : _createDebt,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                color: _isLoading ? _accentColor.withValues(alpha: 0.6) : _accentColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(_isDebt ? 'Add Debt' : 'Add Bill', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isDebt;
  final Color accentColor;
  const _Header({required this.isDebt, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DT.primary, isDebt ? const Color(0xFF1A2E50) : const Color(0xFF2A1F0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DS.xl, DS.sm, DS.xl, DS.xxl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDebt ? 'Add Debt' : 'Add Bill',
                      style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
                    ),
                    Text(
                      isDebt ? 'Track a new loan or commitment' : 'Track a recurring bill or subscription',
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isDebt ? Icons.account_balance_outlined : Icons.receipt_outlined, size: 20, color: accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Type toggle ──────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final bool isDebt;
  final VoidCallback onDebt;
  final VoidCallback onBill;
  const _TypeToggle({required this.isDebt, required this.onDebt, required this.onBill});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DT.border),
      ),
      child: Row(children: [
        _Tab(label: 'Debt / Loan', icon: Icons.account_balance_outlined, selected: isDebt, color: DT.catDebts, onTap: onDebt),
        _Tab(label: 'Bill / Subscription', icon: Icons.receipt_outlined, selected: !isDebt, color: DT.catBills, onTap: onBill),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.icon, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : DT.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : DT.textSecondary)),
          ],
        ),
      ),
    ),
  );
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.textTertiary, letterSpacing: 0.5),
  );
}

// ─── Text field ───────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: capitalization,
    inputFormatters: inputFormatters,
    maxLines: maxLines,
    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.text),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary),
      hintStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
      prefixIcon: Icon(icon, size: 18, color: DT.textSecondary),
      filled: true,
      fillColor: DT.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
    ),
  );
}
