import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/debt_model.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/widgets/floating_field.dart';

const _kDueDays = [1, 5, 10, 15, 25, 28];

class AddDebtScreen extends ConsumerStatefulWidget {
  const AddDebtScreen({super.key});
  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _titleController = TextEditingController();
  final _creditorController = TextEditingController();
  final _totalController = TextEditingController();      // debt total (hero)
  final _monthlyController = TextEditingController();     // debt monthly / bill amount (hero)
  final _descController = TextEditingController();

  String _type = 'debt'; // 'debt' | 'bill'
  String _category = 'other';
  int _dueDay = 15;
  final DateTime _startDate = DateTime.now();
  bool _isLoading = false;

  bool get _isDebt => _type == 'debt';
  Color get _accent => _isDebt ? DT.catDebts : DT.catBills;
  List<DebtCategory> get _categories => DebtModel.categoriesForType(_type);

  // Hero = total for a debt, monthly for a bill.
  TextEditingController get _heroController => _isDebt ? _totalController : _monthlyController;

  @override
  void initState() {
    super.initState();
    _totalController.addListener(_refresh);
    _monthlyController.addListener(_refresh);
    _titleController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _titleController.dispose();
    _creditorController.dispose();
    _totalController.dispose();
    _monthlyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _switchType(String t) => setState(() {
    _type = t;
    _category = _categories.first.value; // keep category valid for the new type
  });

  double get _heroNum => double.tryParse(_heroController.text.trim()) ?? 0;
  double get _totalNum => double.tryParse(_totalController.text.trim()) ?? 0;
  double get _monthlyNum => double.tryParse(_monthlyController.text.trim()) ?? 0;
  int get _payoffMonths => _isDebt && _totalNum > 0 && _monthlyNum > 0 ? (_totalNum / _monthlyNum).ceil() : 0;

  bool get _canSubmit {
    if (_titleController.text.trim().isEmpty) return false;
    if (_heroNum <= 0) return false;
    if (_isDebt && _monthlyNum <= 0) return false;
    return !_isLoading;
  }

  String _payoffLabel() {
    final m = _payoffMonths;
    final y = m ~/ 12, r = m % 12;
    if (y == 0) return '$m month${m == 1 ? '' : 's'}';
    if (r == 0) return '$y year${y == 1 ? '' : 's'}';
    return '${y}y ${r}m';
  }

  Future<void> _create() async {
    if (!_canSubmit) return;
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) {
      showSnackBar(context, 'User not logged in', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(debtServiceProvider).createDebt(
        userId: userId,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        creditor: _creditorController.text.trim(),
        totalAmount: _isDebt ? _totalNum : 0.0,     // bills carry no balance
        monthlyPayment: _monthlyNum,                 // = hero for a bill
        startDate: _startDate,
        dueDay: _dueDay,
        category: _category,
        type: _type,
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
      body: Column(children: [
        // ── Gradient header + type toggle ──────────────────────────────
        Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [DT.primary, _isDebt ? const Color(0xFF1A2E50) : const Color(0xFF2A1F0A)])),
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
            child: Column(children: [
              Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context), child: Container(
                  width: 38, height: 38, alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_isDebt ? 'Add Debt' : 'Add Bill', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
                  Text(_isDebt ? 'Track a loan you’re paying down' : 'Track a recurring monthly bill',
                    style: GoogleFonts.manrope(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                ])),
              ]),
              const SizedBox(height: 16),
              // Segmented toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  _TypeTab(label: 'Debt', icon: Icons.credit_card_outlined, selected: _isDebt, onTap: () => _switchType('debt')),
                  _TypeTab(label: 'Bill', icon: Icons.receipt_long_outlined, selected: !_isDebt, onTap: () => _switchType('bill')),
                ]),
              ),
            ]),
          )),
        ),

        // ── Amount hero (overlaps header) ──────────────────────────────
        Transform.translate(offset: const Offset(0, -12), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DT.border),
              boxShadow: [BoxShadow(color: DT.primary.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isDebt ? 'TOTAL AMOUNT' : 'MONTHLY AMOUNT',
                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('RM', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: DT.textTertiary)),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _heroController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  style: GoogleFonts.manrope(fontSize: 40, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -1.2, height: 1.0),
                  decoration: InputDecoration(
                    isDense: true, filled: false, border: InputBorder.none,
                    enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero,
                    hintText: '0.00',
                    hintStyle: GoogleFonts.manrope(fontSize: 40, fontWeight: FontWeight.w800, color: DT.textTertiary, letterSpacing: -1.2)),
                )),
              ]),
              const SizedBox(height: 4),
              Text(_isDebt ? 'Current outstanding balance' : 'Charged every month',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500, color: DT.textSecondary)),
            ]),
          ),
        )),

        // ── Scrollable form ────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FloatingField(controller: _titleController, label: 'Title', icon: Icons.edit_outlined,
              hint: _isDebt ? 'e.g. Car loan, PTPTN' : 'e.g. Unifi fibre, Netflix', capitalization: TextCapitalization.words),
            FloatingField(controller: _creditorController, label: _isDebt ? 'Lender' : 'Biller', icon: Icons.account_balance_outlined,
              hint: _isDebt ? 'Who you owe' : 'Company you pay', capitalization: TextCapitalization.words),

            const SizedBox(height: 4),
            _Label('CATEGORY'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3, shrinkWrap: true, padding: EdgeInsets.zero, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.55,
              children: _categories.map((cat) {
                final sel = _category == cat.value;
                return GestureDetector(onTap: () => setState(() => _category = cat.value), child: Container(
                  decoration: BoxDecoration(
                    color: sel ? _accent.withValues(alpha: 0.12) : DT.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? _accent : DT.border, width: 1.5)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(cat.icon, size: 18, color: sel ? _accent : DT.textSecondary),
                    const SizedBox(height: 6),
                    Text(cat.label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.text)),
                  ]),
                ));
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Monthly payment — debt only (a bill's monthly IS the hero)
            if (_isDebt)
              FloatingField(controller: _monthlyController, label: 'Monthly payment', icon: Icons.payments_outlined,
                hint: 'How much you repay each month', prefixText: 'RM ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),

            _Label('DUE DAY EACH MONTH'),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _kDueDays.map((day) {
              final sel = _dueDay == day;
              return GestureDetector(onTap: () => setState(() => _dueDay = day), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? DT.text : DT.surface, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? DT.text : DT.border)),
                child: Text('$day${day == 1 ? 'st' : 'th'}',
                  style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : DT.text)),
              ));
            }).toList()),
            const SizedBox(height: 16),

            // Payoff preview — debt only
            if (_isDebt && _payoffMonths > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: DT.catDebts.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(width: 40, height: 40, alignment: Alignment.center,
                    decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.schedule_rounded, size: 19, color: DT.catDebts)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Paid off in ${_payoffLabel()}', style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.2)),
                    Text('$_payoffMonths payment${_payoffMonths == 1 ? '' : 's'} of RM ${_monthlyNum.toStringAsFixed(0)}',
                      style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w500, color: DT.textSecondary)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            FloatingField(controller: _descController, label: 'Notes', icon: Icons.notes_rounded,
              hint: 'Any additional details', optional: true, maxLines: 3),
          ]),
        )),
      ]),

      // ── Sticky footer CTA ───────────────────────────────────────────
      bottomNavigationBar: SafeArea(child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(color: DT.surface, border: Border(top: BorderSide(color: DT.border))),
        child: GestureDetector(onTap: _canSubmit ? _create : null, child: AnimatedContainer(
          duration: const Duration(milliseconds: 150), height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: _canSubmit ? DT.text : DT.surfaceAlt, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_heroNum > 0 ? 'RM ${_heroNum.toStringAsFixed(2)}${_isDebt ? '' : '/mo'}' : 'Enter amount',
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: _canSubmit ? Colors.white70 : DT.textTertiary)),
            _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_isDebt ? 'Add debt' : 'Add bill',
                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: _canSubmit ? Colors.white : DT.textTertiary, letterSpacing: -0.2)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: _canSubmit ? Colors.white : DT.textTertiary),
                ]),
          ]),
        )),
      )),
    );
  }
}

// ─── Type toggle tab ────────────────────────────────────────────────────────
class _TypeTab extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _TypeTab({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 15, color: selected ? DT.text : Colors.white70),
      const SizedBox(width: 7),
      Text(label, style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected ? DT.text : Colors.white70)),
    ]),
  )));
}

// ─── Section label ──────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 4),
    child: Text(text, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: DT.textSecondary, letterSpacing: 0.5)));
}
