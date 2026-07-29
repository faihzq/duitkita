import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/widgets/floating_field.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/fund_loan_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/services/fund_loan_service.dart';
import 'package:duitkita/services/group_service.dart';

class FundLoansScreen extends ConsumerWidget {
  final String groupId;
  final String groupName;
  final bool isAdmin;
  const FundLoansScreen({super.key, required this.groupId, required this.groupName, this.isAdmin = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(groupFundLoansStreamProvider(groupId));
    final myId = ref.watch(authControllerProvider.notifier).currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: DT.border)),
                      child: const Icon(Icons.arrow_back_rounded, size: 18, color: DT.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fund Loans', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: DT.text)),
                        Text(groupName, style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openAddLoan(context, ref),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: loansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.textSecondary))),
                data: (loans) {
                  final pending = loans.where((l) => l.isPending).toList();
                  final active = loans.where((l) => l.isActive).toList();
                  final settled = loans.where((l) => l.isSettled).toList();
                  final rejected = loans.where((l) => l.isRejected).toList();

                  // Summary reflects only approved loans (money actually drawn).
                  final approved = loans.where((l) => l.affectsBalance);
                  final loaned = approved.fold<double>(0, (s, l) => s + l.principal);
                  final repaid = approved.fold<double>(0, (s, l) => s + l.amountRepaid);
                  final outstanding = approved.fold<double>(0, (s, l) => s + l.outstanding);

                  Widget card(FundLoanModel l) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LoanCard(
                          loan: l,
                          isAdmin: isAdmin,
                          isOwner: l.borrowerId == myId || l.createdBy == myId,
                          onApprove: () => _approve(context, ref, l),
                          onReject: () => _reject(context, ref, l),
                          onRepay: () => _openRepay(context, ref, l),
                          onDelete: () => _confirmDelete(context, ref, l),
                        ),
                      );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      _SummaryCard(outstanding: outstanding, loaned: loaned, repaid: repaid, count: active.length),
                      const SizedBox(height: 16),
                      if (loans.isEmpty)
                        _EmptyState(isAdmin: isAdmin, onAdd: () => _openAddLoan(context, ref))
                      else ...[
                        if (pending.isNotEmpty) ...[
                          _sectionLabel(isAdmin ? 'Requests · needs approval' : 'Pending approval'),
                          ...pending.map(card),
                          const SizedBox(height: 8),
                        ],
                        if (active.isNotEmpty) ...[
                          _sectionLabel('Active'),
                          ...active.map(card),
                          const SizedBox(height: 8),
                        ],
                        if (settled.isNotEmpty) ...[
                          _sectionLabel('Settled'),
                          ...settled.map(card),
                          const SizedBox(height: 8),
                        ],
                        if (rejected.isNotEmpty) ...[
                          _sectionLabel('Rejected'),
                          ...rejected.map(card),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(text.toUpperCase(), style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: DT.textTertiary, letterSpacing: 0.5)),
      );

  // ── Actions ─────────────────────────────────────────────────
  void _openAddLoan(BuildContext context, WidgetRef ref) {
    final members = ref.read(groupMembersStreamProvider(groupId)).valueOrNull ?? [];
    final myId = ref.read(authControllerProvider.notifier).currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddLoanSheet(groupId: groupId, members: members, isAdmin: isAdmin, currentUserId: myId),
    );
  }

  void _openRepay(BuildContext context, WidgetRef ref, FundLoanModel loan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RepaySheet(loan: loan),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, FundLoanModel loan) async {
    final members = ref.read(groupMembersStreamProvider(groupId)).valueOrNull ?? [];
    final myId = ref.read(authControllerProvider.notifier).currentUser?.uid ?? '';
    final myName = members.firstWhere((m) => m.userId == myId,
        orElse: () => GroupMember(userId: myId, userName: 'Admin', isAdmin: true, joinedAt: DateTime.now(), totalPaid: 0, paymentCount: 0)).userName;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(fundLoanServiceProvider).approveFundLoan(loanId: loan.id, approvedByName: myName);
      messenger.showSnackBar(SnackBar(content: Text('Approved — RM${loan.principal.toStringAsFixed(2)} drawn from the fund')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: DT.danger));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, FundLoanModel loan) async {
    final ok = await _confirm(context, 'Reject request?', 'Reject "${loan.title}" from ${loan.borrowerName}? It won\'t affect the fund balance.', 'Reject');
    if (ok != true) return;
    await ref.read(fundLoanServiceProvider).rejectFundLoan(loanId: loan.id);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, FundLoanModel loan) async {
    final msg = loan.affectsBalance
        ? 'This removes "${loan.title}" and restores its outstanding amount to the fund balance.'
        : 'This removes "${loan.title}".';
    final ok = await _confirm(context, 'Delete loan?', msg, 'Delete');
    if (ok != true) return;
    await ref.read(fundLoanServiceProvider).deleteFundLoan(loan.id);
  }

  Future<bool?> _confirm(BuildContext context, String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: DT.text, fontSize: 17)),
        content: Text(body, style: GoogleFonts.manrope(color: DT.textSecondary, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.manrope(color: DT.textSecondary, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action, style: GoogleFonts.manrope(color: DT.danger, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double outstanding, loaned, repaid;
  final int count;
  const _SummaryCard({required this.outstanding, required this.loaned, required this.repaid, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [DT.headerGradientStart, DT.headerGradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(DS.heroRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OUTSTANDING', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('RM${outstanding.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text('$count active loan${count != 1 ? 's' : ''} drawn from the fund', style: GoogleFonts.manrope(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 16),
          Row(children: [
            _miniStat('Loaned', loaned),
            Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
            _miniStat('Repaid', repaid),
          ]),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RM${value.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: GoogleFonts.manrope(fontSize: 11, color: Colors.white60)),
        ],
      );
}

// ─── Loan card ────────────────────────────────────────────────────────────────

class _LoanCard extends StatelessWidget {
  final FundLoanModel loan;
  final bool isAdmin;
  final bool isOwner;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRepay;
  final VoidCallback onDelete;
  const _LoanCard({
    required this.loan,
    required this.isAdmin,
    required this.isOwner,
    required this.onApprove,
    required this.onReject,
    required this.onRepay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusFg, statusLabel) = switch (true) {
      _ when loan.isPending => (DT.warningSoft, DT.warning, 'Pending'),
      _ when loan.isRejected => (DT.dangerSoft, DT.danger, 'Rejected'),
      _ when loan.isSettled => (DT.successSoft, DT.success, 'Settled'),
      _ => (DT.catDebtsSoft, DT.catDebts, 'Active'),
    };
    final dim = loan.isRejected;

    return Opacity(
      opacity: dim ? 0.7 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(DS.cardRadius), border: Border.all(color: DT.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(11)),
                  child: Icon(loan.isSettled ? Icons.check_circle_outline_rounded : Icons.savings_outlined, size: 20, color: statusFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(loan.title, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: DT.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                          child: Text(statusLabel, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: statusFg)),
                        ),
                      ]),
                      Text('${loan.borrowerName} · borrowed RM${loan.principal.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary)),
                    ],
                  ),
                ),
                if (!loan.isPending && !loan.isRejected)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('RM${loan.outstanding.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: loan.isSettled ? DT.textTertiary : DT.text)),
                      Text(loan.isSettled ? 'settled' : 'left', style: GoogleFonts.manrope(fontSize: 10, color: DT.textTertiary)),
                    ],
                  ),
              ],
            ),

            // Progress (only for approved/settled)
            if (loan.affectsBalance) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: loan.progressPercent,
                  minHeight: 6,
                  backgroundColor: DT.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(loan.isSettled ? DT.success : DT.catDebts),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text('RM${loan.amountRepaid.toStringAsFixed(2)} repaid', style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (loan.monthlyRepayment > 0 && !loan.isSettled)
                  Text('RM${loan.monthlyRepayment.toStringAsFixed(0)}/mo · ${loan.monthsRemaining} mo left', style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary)),
              ]),
            ],

            if (loan.note != null) ...[
              const SizedBox(height: 8),
              Text(loan.note!, style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary, height: 1.3)),
            ],

            ..._actions(),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions() {
    // Pending: admin approves/rejects; owner can cancel their own request.
    if (loan.isPending) {
      if (isAdmin) {
        return [
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _btn('Reject', DT.surfaceAlt, DT.danger, onReject, outlined: true)),
            const SizedBox(width: 8),
            Expanded(child: _btn('Approve', DT.success, Colors.white, onApprove)),
          ]),
        ];
      }
      if (isOwner) {
        return [
          const SizedBox(height: 12),
          _btn('Cancel request', DT.surfaceAlt, DT.textSecondary, onDelete, outlined: true, fullWidth: true),
        ];
      }
      return [];
    }
    // Active: admin records repayments / deletes.
    if (loan.isActive && isAdmin) {
      return [
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _btn('Record repayment', DT.text, Colors.white, onRepay)),
          const SizedBox(width: 8),
          _iconBtn(Icons.delete_outline_rounded, onDelete),
        ]),
      ];
    }
    // Settled / rejected: admin can clean up.
    if ((loan.isSettled || loan.isRejected) && isAdmin) {
      return [
        const SizedBox(height: 12),
        _btn('Delete', DT.surfaceAlt, DT.textSecondary, onDelete, outlined: true, fullWidth: true),
      ];
    }
    return [];
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap, {bool outlined = false, bool fullWidth = false}) {
    final child = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: outlined ? bg : bg,
        borderRadius: BorderRadius.circular(10),
        border: outlined ? Border.all(color: DT.border) : null,
      ),
      child: Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    );
    return GestureDetector(onTap: onTap, child: child);
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: DT.border)),
          child: Icon(icon, size: 18, color: DT.textTertiary),
        ),
      );
}

// ─── Add loan sheet ───────────────────────────────────────────────────────────

class _AddLoanSheet extends ConsumerStatefulWidget {
  final String groupId;
  final List<GroupMember> members;
  final bool isAdmin;
  final String currentUserId;
  const _AddLoanSheet({required this.groupId, required this.members, required this.isAdmin, required this.currentUserId});

  @override
  ConsumerState<_AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends ConsumerState<_AddLoanSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _borrowerId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Admins can pick any borrower; members request for themselves.
    _borrowerId = widget.isAdmin
        ? (widget.members.isNotEmpty ? widget.members.first.userId : null)
        : widget.currentUserId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _monthlyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (_titleCtrl.text.trim().isEmpty || amount <= 0 || _borrowerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a purpose, amount, and borrower')));
      return;
    }
    setState(() => _busy = true);
    final me = widget.currentUserId;
    GroupMember pick(String id, String fallback) => widget.members.firstWhere(
          (m) => m.userId == id,
          orElse: () => GroupMember(userId: id, userName: fallback, isAdmin: false, joinedAt: DateTime.now(), totalPaid: 0, paymentCount: 0),
        );
    final borrower = pick(_borrowerId!, 'Member');
    final myName = pick(me, borrower.userName).userName;
    try {
      await ref.read(fundLoanServiceProvider).createFundLoan(
            groupId: widget.groupId,
            borrowerId: borrower.userId,
            borrowerName: borrower.userName,
            title: _titleCtrl.text,
            note: _noteCtrl.text,
            principal: amount,
            monthlyRepayment: double.tryParse(_monthlyCtrl.text.trim()) ?? 0,
            createdBy: me,
            createdByName: myName,
            autoApprove: widget.isAdmin,
            approverName: myName,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isAdmin ? 'Loan created' : 'Request submitted for admin approval'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: DT.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(color: DT.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.isAdmin ? 'New Fund Loan' : 'Request Fund Loan', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
            Text(widget.isAdmin ? 'Money drawn from the fund, repaid over time' : 'Sent to an admin for approval before the money is drawn', style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary)),
            const SizedBox(height: 18),
            if (widget.isAdmin) ...[
              _label('Borrower'),
              _borrowerDropdown(),
              const SizedBox(height: 14),
            ],
            FloatingField(controller: _titleCtrl, label: 'Purpose', icon: Icons.description_outlined, hint: 'e.g. Wiring'),
            FloatingField(controller: _amountCtrl, label: 'Amount to borrow', prefixText: 'RM ', icon: Icons.payments_outlined, hint: '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
            FloatingField(controller: _monthlyCtrl, label: 'Monthly repayment', optional: true, prefixText: 'RM ', icon: Icons.calendar_month_outlined, hint: '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
            FloatingField(controller: _noteCtrl, label: 'Note', optional: true, icon: Icons.notes_outlined, hint: 'Any details'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _busy ? null : _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _busy ? DT.textTertiary : DT.text, borderRadius: BorderRadius.circular(12)),
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isAdmin ? 'Create loan' : 'Submit request', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: DT.textSecondary)),
      );

  Widget _borrowerDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: DT.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _borrowerId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: DT.textTertiary),
          items: widget.members
              .map((m) => DropdownMenuItem(value: m.userId, child: Text(m.userName, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.text))))
              .toList(),
          onChanged: (v) => setState(() => _borrowerId = v),
        ),
      ),
    );
  }

}

// ─── Repay sheet ──────────────────────────────────────────────────────────────

class _RepaySheet extends ConsumerStatefulWidget {
  final FundLoanModel loan;
  const _RepaySheet({required this.loan});

  @override
  ConsumerState<_RepaySheet> createState() => _RepaySheetState();
}

class _RepaySheetState extends ConsumerState<_RepaySheet> {
  late final TextEditingController _amountCtrl;
  final _noteCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final suggested = widget.loan.monthlyRepayment > 0
        ? widget.loan.monthlyRepayment.clamp(0, widget.loan.outstanding)
        : widget.loan.outstanding;
    _amountCtrl = TextEditingController(text: suggested.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _busy = true);
    final me = ref.read(authControllerProvider.notifier).currentUser?.uid ?? '';
    try {
      await ref.read(fundLoanServiceProvider).recordRepayment(
            loanId: widget.loan.id,
            amount: amount,
            note: _noteCtrl.text,
            recordedBy: me,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: DT.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: DT.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Record Repayment', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
          Text('${widget.loan.title} · RM${widget.loan.outstanding.toStringAsFixed(2)} outstanding', style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary)),
          const SizedBox(height: 18),
          Text('Amount (RM)', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: DT.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: DT.text),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.payments_outlined, size: 18, color: DT.textTertiary),
              filled: true, fillColor: DT.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          Text('Note — optional', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: DT.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.text),
            decoration: InputDecoration(
              hintText: 'e.g. July repayment',
              hintStyle: GoogleFonts.manrope(fontSize: 14, color: DT.textTertiary),
              prefixIcon: const Icon(Icons.notes_outlined, size: 18, color: DT.textTertiary),
              filled: true, fillColor: DT.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _busy ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _busy ? DT.textTertiary : DT.success, borderRadius: BorderRadius.circular(12)),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save repayment', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onAdd;
  const _EmptyState({required this.isAdmin, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: DT.border)),
            child: const Icon(Icons.savings_outlined, size: 32, color: DT.textTertiary),
          ),
          const SizedBox(height: 16),
          Text('No fund loans yet', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: DT.text)),
          const SizedBox(height: 6),
          Text(isAdmin
              ? 'Track money borrowed from the fund and repaid over time. Each loan lowers the fund balance until it\'s paid back.'
              : 'Need to borrow from the fund? Submit a request and an admin will review it.',
              textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(12)),
              child: Text(isAdmin ? 'Add fund loan' : 'Request fund loan', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
