import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/debt_model.dart';
import 'package:duitkita/models/debt_payment_model.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/utils/utils.dart';

class DebtDetailScreen extends ConsumerWidget {
  final String debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(debtStreamProvider(debtId));
    final paymentsAsync = ref.watch(debtPaymentsStreamProvider(debtId));

    return Scaffold(
      backgroundColor: DT.bg,
      body: debtAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.danger))),
        data: (debt) {
          if (debt == null) {
            return Center(child: Text('Not found', style: GoogleFonts.manrope(color: DT.textSecondary)));
          }

          final accentColor = debt.isDebt ? DT.catDebts : DT.catBills;

          return CustomScrollView(
            slivers: [
              // ── Navy header ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: DT.primary,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(DS.xl, DS.sm, DS.xl, DS.xxl),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Top row: back + menu
                        Row(children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                          const Spacer(),
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(debt.isDebt ? Icons.account_balance_outlined : Icons.receipt_outlined, size: 12, color: accentColor),
                              const SizedBox(width: 5),
                              Text(debt.isDebt ? 'Loan' : 'Bill', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: accentColor)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (v) => _handleMenu(context, ref, v, debt),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            color: DT.surface,
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: _menuItem(Icons.edit_outlined, 'Edit', DT.text)),
                              if (debt.isActive)
                                PopupMenuItem(value: 'complete', child: _menuItem(Icons.check_circle_outline_rounded, 'Mark Completed', DT.success)),
                              if (!debt.isActive)
                                PopupMenuItem(value: 'reactivate', child: _menuItem(Icons.replay_rounded, 'Reactivate', DT.accent)),
                              PopupMenuItem(value: 'delete', child: _menuItem(Icons.delete_outline_rounded, 'Delete', DT.danger)),
                            ],
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ]),
                        const SizedBox(height: DS.lg),

                        // Title + creditor
                        Text(debt.title, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.business_outlined, size: 13, color: Colors.white.withValues(alpha: 0.55)),
                          const SizedBox(width: 5),
                          Text(debt.creditor, style: GoogleFonts.manrope(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                        ]),
                        const SizedBox(height: DS.xl),

                        // Loan: circular progress
                        if (debt.isDebt)
                          Center(
                            child: SizedBox(
                              width: 110, height: 110,
                              child: Stack(alignment: Alignment.center, children: [
                                SizedBox(
                                  width: 110, height: 110,
                                  child: CircularProgressIndicator(
                                    value: debt.progressPercent,
                                    strokeWidth: 9,
                                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                  ),
                                ),
                                Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text('${(debt.progressPercent * 100).toStringAsFixed(1)}%',
                                    style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                  Text('paid off', style: GoogleFonts.manrope(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                                ]),
                              ]),
                            ),
                          ),

                        // Bill: recurring amount badge
                        if (debt.isBill)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.autorenew_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text('RM${debt.monthlyPayment.toStringAsFixed(2)}/month',
                                  style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                              ]),
                            ),
                          ),

                        if (!debt.isActive) ...[
                          const SizedBox(height: DS.md),
                          Center(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: DT.success.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 13, color: DT.accent),
                              const SizedBox(width: 5),
                              Text('Completed', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: DT.accent)),
                            ]),
                          )),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),

              // ── Stats card ───────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(DS.xl, DS.xl, DS.xl, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: DT.surface,
                      borderRadius: BorderRadius.circular(DS.cardRadius),
                      border: Border.all(color: DT.border),
                    ),
                    child: Column(children: [
                      if (debt.isDebt) ...[
                        _StatRow(cells: [
                          _StatCell('Total', 'RM${_fmt(debt.totalAmount)}', accentColor),
                          _StatCell('Paid', 'RM${_fmt(debt.totalPaid)}', DT.success),
                        ]),
                        _Divider(),
                        _StatRow(cells: [
                          _StatCell('Remaining', 'RM${_fmt(debt.remainingBalance)}', DT.warning),
                          _StatCell('Monthly', 'RM${_fmt(debt.monthlyPayment)}', DT.primary),
                        ]),
                        _Divider(),
                        _StatRow(cells: [
                          _StatCell('Months Left', '${debt.monthsRemaining}', DT.catDebts),
                          _StatCell('Est. Payoff', '${_month(debt.estimatedPayoffDate.month)} ${debt.estimatedPayoffDate.year}', DT.catBills),
                        ]),
                      ],
                      if (debt.isBill) ...[
                        _StatRow(cells: [
                          _StatCell('Monthly', 'RM${_fmt(debt.monthlyPayment)}', accentColor),
                          _StatCell('Due Day', '${debt.dueDay}th', DT.primary),
                        ]),
                        _Divider(),
                        _StatRow(cells: [
                          _StatCell('Type', 'Recurring', DT.catDebts),
                          _StatCell('Total Paid', 'RM${_fmt(debt.totalPaid)}', DT.success),
                        ]),
                      ],
                      if (debt.description != null && debt.description!.isNotEmpty) ...[
                        Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: DS.lg), color: DT.border),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, DS.md),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.notes_rounded, size: 15, color: DT.textTertiary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(debt.description!, style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4))),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),

              // ── Record payment button ────────────────────────────
              if (debt.isActive)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(DS.xl, DS.md, DS.xl, 0),
                  sliver: SliverToBoxAdapter(
                    child: GestureDetector(
                      onTap: () => _showRecordPayment(context, ref, debt),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('Record Payment', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                ),

              // ── Payment history header ───────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(DS.xl, DS.xxl, DS.xl, DS.sm),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    Container(width: 3, height: 16, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text('Payment History', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.2)),
                  ]),
                ),
              ),

              // ── Payments ─────────────────────────────────────────
              paymentsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2))),
                ),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.danger)))),
                data: (payments) {
                  if (payments.isEmpty) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(DS.xl, DS.sm, DS.xl, DS.xxxl),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(DS.cardRadius), border: Border.all(color: DT.border)),
                          child: Column(children: [
                            const Icon(Icons.receipt_long_outlined, size: 34, color: DT.textTertiary),
                            const SizedBox(height: 10),
                            Text('No payments recorded yet', style: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary)),
                          ]),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(DS.xl, 0, DS.xl, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _PaymentTile(
                          payment: payments[i],
                          onDelete: () => _confirmDeletePayment(context, ref, payments[i], debt),
                        ),
                        childCount: payments.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _menuItem(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 10),
    Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
  ]);

  void _handleMenu(BuildContext context, WidgetRef ref, String action, DebtModel debt) {
    final svc = ref.read(debtServiceProvider);
    switch (action) {
      case 'edit':
        _showEditSheet(context, ref, debt);
      case 'complete':
        _dtDialog(context,
          icon: Icons.check_circle_outline_rounded, iconColor: DT.success,
          title: 'Mark as Completed?', body: 'This debt will be moved to the completed section.',
          confirmLabel: 'Complete', confirmColor: DT.success,
          onConfirm: () async {
            await svc.markDebtComplete(debtId);
            if (context.mounted) showSnackBar(context, 'Marked as completed!');
          },
        );
      case 'reactivate':
        svc.reactivateDebt(debtId);
        showSnackBar(context, 'Reactivated');
      case 'delete':
        _dtDialog(context,
          icon: Icons.delete_outline_rounded, iconColor: DT.danger,
          title: 'Delete ${debt.isBill ? "Bill" : "Debt"}?',
          body: 'This will permanently delete "${debt.title}" and all payment history.',
          confirmLabel: 'Delete', confirmColor: DT.danger,
          onConfirm: () async {
            await svc.deleteDebt(debtId);
            if (context.mounted) { Navigator.of(context).pop(); showSnackBar(context, 'Deleted'); }
          },
        );
    }
  }

  void _confirmDeletePayment(BuildContext context, WidgetRef ref, DebtPaymentModel payment, DebtModel debt) {
    _dtDialog(context,
      icon: Icons.delete_outline_rounded, iconColor: DT.danger,
      title: 'Delete Payment?',
      body: 'Remove RM${payment.amount.toStringAsFixed(2)} payment from ${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}?',
      confirmLabel: 'Delete', confirmColor: DT.danger,
      onConfirm: () async {
        final svc = ref.read(debtServiceProvider);
        await svc.deleteDebtPayment(debtId: debtId, paymentId: payment.id, amount: payment.amount);
        if (!debt.isActive) await svc.reactivateDebt(debtId);
        if (context.mounted) showSnackBar(context, 'Payment deleted');
      },
    );
  }

  void _dtDialog(BuildContext context, {
    required IconData icon, required Color iconColor,
    required String title, required String body,
    required String confirmLabel, required Color confirmColor,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(height: 14),
            Text(title, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.textSecondary)))),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () async { Navigator.pop(ctx); await onConfirm(); },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: confirmColor, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(confirmLabel, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showRecordPayment(BuildContext context, WidgetRef ref, DebtModel debt) {
    final amountCtrl = TextEditingController(text: debt.monthlyPayment.toStringAsFixed(2));
    final notesCtrl  = TextEditingController();
    DateTime date    = DateTime.now();
    final accentColor = debt.isDebt ? DT.catDebts : DT.catBills;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DT.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(DS.xl, DS.xl, DS.xl, MediaQuery.of(ctx).viewInsets.bottom + DS.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: DS.lg),
            Text('Record Payment', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
            const SizedBox(height: 2),
            Text('for ${debt.title}', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
            const SizedBox(height: DS.lg),

            _SheetField(controller: amountCtrl, label: 'Amount (RM)', icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
            const SizedBox(height: DS.md),

            GestureDetector(
              onTap: () async {
                final p = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now(),
                  builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: DT.primary)), child: child!));
                if (p != null) setS(() => date = p);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: DT.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: DT.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Payment Date', style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${date.day}/${date.month}/${date.year}', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
                  ])),
                  const Icon(Icons.edit_calendar_outlined, size: 16, color: DT.textTertiary),
                ]),
              ),
            ),
            const SizedBox(height: DS.md),

            _SheetField(controller: notesCtrl, label: 'Notes (optional)', icon: Icons.notes_rounded, hint: 'e.g., Monthly installment'),
            const SizedBox(height: DS.xl),

            GestureDetector(
              onTap: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) { showSnackBar(ctx, 'Enter a valid amount', isError: true); return; }
                try {
                  final svc = ref.read(debtServiceProvider);
                  await svc.addDebtPayment(debtId: debtId, amount: amount, paymentDate: date,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
                  if (debt.isDebt && debt.totalPaid + amount >= debt.totalAmount) await svc.markDebtComplete(debtId);
                  if (ctx.mounted) { Navigator.of(ctx).pop(); showSnackBar(context, 'Payment recorded!'); }
                } catch (e) { if (ctx.mounted) showSnackBar(ctx, 'Failed: $e', isError: true); }
              },
              child: Container(
                height: 50, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Save Payment', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, DebtModel debt) {
    final titleCtrl   = TextEditingController(text: debt.title);
    final creditorCtrl = TextEditingController(text: debt.creditor);
    final monthlyCtrl = TextEditingController(text: debt.monthlyPayment.toStringAsFixed(2));
    final totalCtrl   = TextEditingController(text: debt.totalAmount.toStringAsFixed(2));
    final dueDayCtrl  = TextEditingController(text: debt.dueDay.toString());
    final descCtrl    = TextEditingController(text: debt.description ?? '');
    String category   = debt.category;
    final accentColor = debt.isDebt ? DT.catDebts : DT.catBills;
    final categories  = DebtModel.categoriesForType(debt.type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DT.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(DS.xl, DS.xl, DS.xl, MediaQuery.of(ctx).viewInsets.bottom + DS.xl),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: DS.lg),
              Text('Edit ${debt.isBill ? "Bill" : "Debt"}', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
              const SizedBox(height: DS.lg),

              _SheetField(controller: titleCtrl, label: 'Title', icon: Icons.title_rounded, capitalization: TextCapitalization.words),
              const SizedBox(height: DS.md),
              _SheetField(controller: creditorCtrl, label: debt.isBill ? 'Provider' : 'Owed To', icon: Icons.business_outlined, capitalization: TextCapitalization.words),
              const SizedBox(height: DS.md),

              if (debt.isDebt) ...[
                _SheetField(controller: totalCtrl, label: 'Total Amount (RM)', icon: Icons.account_balance_wallet_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
                const SizedBox(height: DS.md),
              ],

              Row(children: [
                Expanded(child: _SheetField(controller: monthlyCtrl, label: 'Monthly (RM)', icon: Icons.calendar_month_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))])),
                const SizedBox(width: DS.md),
                Expanded(child: _SheetField(controller: dueDayCtrl, label: 'Due Day (1–28)', icon: Icons.event_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
              ]),
              const SizedBox(height: DS.md),

              Text('CATEGORY', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.textTertiary, letterSpacing: 0.5)),
              const SizedBox(height: DS.sm),
              Wrap(spacing: 8, runSpacing: 8, children: categories.map((cat) {
                final sel = category == cat.value;
                return GestureDetector(
                  onTap: () => setS(() => category = cat.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? accentColor : DT.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? accentColor : DT.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(cat.icon, size: 14, color: sel ? Colors.white : DT.textSecondary),
                      const SizedBox(width: 5),
                      Text(cat.label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : DT.text)),
                    ]),
                  ),
                );
              }).toList()),
              const SizedBox(height: DS.md),

              _SheetField(controller: descCtrl, label: 'Notes (optional)', icon: Icons.notes_rounded, maxLines: 2),
              const SizedBox(height: DS.xl),

              GestureDetector(
                onTap: () async {
                  final title    = titleCtrl.text.trim();
                  final creditor = creditorCtrl.text.trim();
                  if (title.isEmpty) { showSnackBar(ctx, 'Title is required', isError: true); return; }
                  if (creditor.isEmpty) { showSnackBar(ctx, '${debt.isBill ? "Provider" : "Owed To"} is required', isError: true); return; }
                  final monthly = double.tryParse(monthlyCtrl.text.trim());
                  if (monthly == null || monthly <= 0) { showSnackBar(ctx, 'Enter a valid monthly amount', isError: true); return; }
                  final dueDay = int.tryParse(dueDayCtrl.text.trim()) ?? 1;
                  if (dueDay < 1 || dueDay > 28) { showSnackBar(ctx, 'Due day must be 1–28', isError: true); return; }

                  final data = <String, dynamic>{
                    'title': title, 'creditor': creditor, 'monthlyPayment': monthly,
                    'dueDay': dueDay, 'category': category,
                    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  };
                  if (debt.isDebt) {
                    final total = double.tryParse(totalCtrl.text.trim());
                    if (total == null || total <= 0) { showSnackBar(ctx, 'Enter a valid total amount', isError: true); return; }
                    data['totalAmount'] = total;
                  }
                  try {
                    await ref.read(debtServiceProvider).updateDebt(debtId, data);
                    if (ctx.mounted) { Navigator.of(ctx).pop(); showSnackBar(context, '${debt.isBill ? "Bill" : "Debt"} updated!'); }
                  } catch (e) { if (ctx.mounted) showSnackBar(ctx, 'Failed: $e', isError: true); }
                },
                child: Container(
                  height: 50, decoration: BoxDecoration(color: DT.primary, borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Save Changes', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  }

  static String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

// ─── Stats layout ──────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final List<_StatCell> cells;
  const _StatRow({required this.cells});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(children: [
      for (int i = 0; i < cells.length; i++) ...[
        if (i > 0) Container(width: 1, color: DT.border),
        Expanded(child: cells[i]),
      ],
    ]),
  );
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCell(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    child: Column(children: [
      Text(value, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3)),
      const SizedBox(height: 3),
      Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: DT.textTertiary)),
    ]),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(height: 1, color: DT.border);
}

// ─── Payment tile ──────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  final DebtPaymentModel payment;
  final VoidCallback onDelete;
  const _PaymentTile({required this.payment, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(DS.cardRadius), border: Border.all(color: DT.border)),
    child: IntrinsicHeight(
      child: Row(children: [
        Container(
          width: 3,
          decoration: const BoxDecoration(
            color: DT.success,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.cardRadius), bottomLeft: Radius.circular(DS.cardRadius)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: DT.successSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.check_circle_outline_rounded, color: DT.success, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RM${payment.amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: DT.text)),
                const SizedBox(height: 2),
                Row(children: [
                  Text('${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                    style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary)),
                  if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: DT.textTertiary, shape: BoxShape.circle))),
                    Flexible(child: Text(payment.notes!, style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary), overflow: TextOverflow.ellipsis)),
                  ],
                ]),
              ])),
              GestureDetector(
                onTap: onDelete,
                child: Container(width: 32, height: 32, decoration: BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline_rounded, size: 16, color: DT.danger)),
              ),
            ]),
          ),
        ),
      ]),
    ),
  );
}

// ─── Sheet input field ─────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
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
      filled: true, fillColor: DT.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
    ),
  );
}
