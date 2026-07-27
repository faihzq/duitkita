import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/expense_model.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/utils/utils.dart';

enum _ReviewMode { none, approving, rejecting }

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final ExpenseModel expense;
  final String groupId;
  const ExpenseDetailScreen({super.key, required this.expense, required this.groupId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  _ReviewMode _mode = _ReviewMode.none;
  final _rejectNoteCtrl = TextEditingController();
  bool _receiptOpen = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _rejectNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(bool approve) async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final profile = await ref.read(profileServiceProvider).getUserProfile(userId);
      if (approve) {
        await ref.read(expenseServiceProvider).approveExpense(
          expenseId: widget.expense.id,
          approvedBy: userId,
          approvedByName: profile?.name ?? 'Unknown',
        );
        if (mounted) { showSnackBar(context, 'Expense approved!'); Navigator.of(context).pop(); }
      } else {
        await ref.read(expenseServiceProvider).rejectExpense(
          expenseId: widget.expense.id,
          rejectedBy: userId,
          rejectedByName: profile?.name ?? 'Unknown',
        );
        if (mounted) { showSnackBar(context, 'Expense rejected.'); Navigator.of(context).pop(); }
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatSubmitted(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Submitted ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Submitted ${diff.inHours}h ago';
    return 'Submitted ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));
    final expense = widget.expense;

    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final groupName = groupAsync.valueOrNull?.name ?? '';

    final isAdmin = membersAsync.valueOrNull?.any((m) => m.userId == userId && m.isAdmin) ?? false;
    final isPending = expense.status == ExpenseStatus.pending;
    final requesterIsAdmin = membersAsync.valueOrNull?.any((m) => m.userId == expense.requestedBy && m.isAdmin) ?? false;

    if (_mode == _ReviewMode.approving) {
      return _ConfirmScreen(
        expense: expense,
        isApprove: true,
        groupName: groupName,
        rejectNoteCtrl: _rejectNoteCtrl,
        isLoading: _isLoading,
        onBack: () => setState(() => _mode = _ReviewMode.none),
        onSubmit: () => _submit(true),
      );
    }
    if (_mode == _ReviewMode.rejecting) {
      return _ConfirmScreen(
        expense: expense,
        isApprove: false,
        groupName: groupName,
        rejectNoteCtrl: _rejectNoteCtrl,
        isLoading: _isLoading,
        onBack: () => setState(() => _mode = _ReviewMode.none),
        onSubmit: () => _submit(false),
      );
    }

    return Scaffold(
      backgroundColor: DT.bg,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Gradient header ────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [DT.headerGradientStart, DT.headerGradientEnd],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Expense review', style: GoogleFonts.manrope(
                            fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2,
                          )),
                          Text(
                            _formatSubmitted(expense.createdAt),
                            style: GoogleFonts.manrope(fontSize: 11, color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                      _StatusPill(status: expense.status),
                    ]),
                  ),
                ),
              ),

              // ── Scrollable body ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, (isPending && isAdmin) ? 16 : 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Hero card overlaps header by 12px
                    Transform.translate(
                      offset: const Offset(0, -12),
                      child: _HeroCard(expense: expense),
                    ),

                    _SectionLabel('Requested by'),
                    const SizedBox(height: 8),
                    _RequesterCard(expense: expense, requesterIsAdmin: requesterIsAdmin),
                    const SizedBox(height: 16),

                    if (expense.receiptUrl != null) ...[
                      _SectionLabel('Receipt'),
                      const SizedBox(height: 8),
                      _ReceiptCard(
                        receiptUrl: expense.receiptUrl!,
                        onTap: () => setState(() => _receiptOpen = true),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (expense.description != null && expense.description!.isNotEmpty) ...[
                      _SectionLabel('Description'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(DS.cardRadius),
                          border: Border.all(color: DT.border),
                        ),
                        child: Text(expense.description!, style: GoogleFonts.manrope(
                          fontSize: 13, color: DT.text, height: 1.5, fontWeight: FontWeight.w500,
                        )),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _SectionLabel('History'),
                    const SizedBox(height: 8),
                    _HistoryCard(expense: expense),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),

              // ── Action footer (admin + pending only) ──────────────────
              if (isPending && isAdmin)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: DT.surface,
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF0B1F3A).withValues(alpha: 0.06),
                        blurRadius: 24, offset: const Offset(0, -8),
                      )],
                    ),
                    child: Row(children: [
                      // Reject (1x)
                      Expanded(
                        child: GestureDetector(
                          onTap: _isLoading ? null : () => setState(() => _mode = _ReviewMode.rejecting),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: DT.dangerSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.close_rounded, size: 16, color: DT.danger),
                              const SizedBox(width: 6),
                              Text('Reject', style: GoogleFonts.manrope(
                                fontSize: 14, fontWeight: FontWeight.w800, color: DT.danger, letterSpacing: -0.2,
                              )),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Approve (2x)
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _isLoading ? null : () => setState(() => _mode = _ReviewMode.approving),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: DT.accent,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(
                                color: DT.accent.withValues(alpha: 0.35),
                                blurRadius: 20, offset: const Offset(0, 8),
                              )],
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.check_rounded, size: 16, color: DT.accentDeep),
                              const SizedBox(width: 6),
                              Text(
                                'Approve · RM ${expense.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.manrope(
                                  fontSize: 14, fontWeight: FontWeight.w800, color: DT.accentDeep, letterSpacing: -0.2,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ),

          // ── Receipt lightbox ──────────────────────────────────────────
          if (_receiptOpen)
            _ReceiptLightbox(
              receiptUrl: expense.receiptUrl!,
              onClose: () => setState(() => _receiptOpen = false),
            ),
        ],
      ),
    );
  }
}

// ─── Confirmation sub-screen ───────────────────────────────────────────────────

class _ConfirmScreen extends StatefulWidget {
  final ExpenseModel expense;
  final bool isApprove;
  final String groupName;
  final TextEditingController rejectNoteCtrl;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _ConfirmScreen({
    required this.expense,
    required this.isApprove,
    required this.groupName,
    required this.rejectNoteCtrl,
    required this.isLoading,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  State<_ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<_ConfirmScreen> {
  bool _canSubmit = true;

  @override
  void initState() {
    super.initState();
    if (!widget.isApprove) {
      _canSubmit = widget.rejectNoteCtrl.text.trim().length >= 3;
      widget.rejectNoteCtrl.addListener(_checkNote);
    }
  }

  @override
  void dispose() {
    if (!widget.isApprove) widget.rejectNoteCtrl.removeListener(_checkNote);
    super.dispose();
  }

  void _checkNote() {
    final ok = widget.rejectNoteCtrl.text.trim().length >= 3;
    if (ok != _canSubmit) setState(() => _canSubmit = ok);
  }

  void _appendQuickNote(String text) {
    final current = widget.rejectNoteCtrl.text.trim();
    widget.rejectNoteCtrl.text = current.isEmpty ? text : '$current · $text';
    widget.rejectNoteCtrl.selection = TextSelection.collapsed(offset: widget.rejectNoteCtrl.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final isApprove = widget.isApprove;

    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: DT.surface,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: DT.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: DT.border),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 18, color: DT.text),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isApprove ? 'Confirm approval' : 'Reject expense',
                  style: GoogleFonts.manrope(
                    fontSize: 16, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.2,
                  ),
                ),
              ]),
            ),
          ),
          Container(height: 1, color: DT.border),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Icon + title
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
                  child: Center(
                    child: Column(children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: isApprove ? DT.accentSoft : DT.dangerSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isApprove ? Icons.check_rounded : Icons.close_rounded,
                          size: 28,
                          color: isApprove ? DT.accentDeep : DT.danger,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isApprove
                            ? 'Approve RM ${expense.amount.toStringAsFixed(2)}?'
                            : 'Reject this expense?',
                        style: GoogleFonts.manrope(
                          fontSize: 22, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isApprove
                            ? '${expense.requestedByName} will be notified and the expense will be recorded against ${widget.groupName}.'
                            : '${expense.requestedByName} will see your reason and can resubmit with changes.',
                        style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Review card
                Container(
                  decoration: BoxDecoration(
                    color: DT.surface,
                    borderRadius: BorderRadius.circular(DS.cardRadius),
                    border: Border.all(color: DT.border),
                  ),
                  child: Column(children: [
                    _ReviewRow(label: 'Expense', value: expense.title),
                    _ReviewRow(label: 'Amount', value: 'RM ${expense.amount.toStringAsFixed(2)}', emphasize: true),
                    _ReviewRow(label: 'Requester', value: expense.requestedByName),
                    _ReviewRow(label: 'Group', value: widget.groupName, last: true),
                  ]),
                ),

                // Rejection reason
                if (!isApprove) ...[
                  const SizedBox(height: 16),
                  Text('REASON · REQUIRED', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700, color: DT.textSecondary, letterSpacing: 0.5,
                  )),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: DT.surface,
                      borderRadius: BorderRadius.circular(DS.cardRadius),
                      border: Border.all(color: DT.border),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: TextField(
                      controller: widget.rejectNoteCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500, color: DT.text),
                      decoration: InputDecoration(
                        hintText: 'e.g. Receipt unclear, please resubmit with itemized photo',
                        hintStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      for (final t in ['Receipt unclear', 'Wrong amount', 'Not group-related', 'Need more detail'])
                        GestureDetector(
                          onTap: () => _appendQuickNote(t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: DT.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: DT.border),
                            ),
                            child: Text('+ $t', style: GoogleFonts.manrope(
                              fontSize: 11, fontWeight: FontWeight.w600, color: DT.text,
                            )),
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 80),
              ]),
            ),
          ),

          // Footer
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: DT.surface,
                border: Border(top: BorderSide(color: DT.border)),
              ),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: DT.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: DT.border),
                      ),
                      child: Center(child: Text('Cancel', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: DT.text,
                      ))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: (!_canSubmit || widget.isLoading) ? null : widget.onSubmit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      decoration: BoxDecoration(
                        color: !_canSubmit
                            ? DT.surfaceAlt
                            : isApprove ? DT.accent : DT.danger,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (widget.isLoading)
                          SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isApprove ? DT.accentDeep : Colors.white,
                            ),
                          )
                        else ...[
                          Icon(
                            isApprove ? Icons.check_rounded : Icons.close_rounded,
                            size: 16,
                            color: !_canSubmit
                                ? DT.textTertiary
                                : isApprove ? DT.accentDeep : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isApprove ? 'Approve & record' : 'Reject & notify',
                            style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.2,
                              color: !_canSubmit
                                  ? DT.textTertiary
                                  : isApprove ? DT.accentDeep : Colors.white,
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small widgets ─────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final ExpenseStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ExpenseStatus.pending  => (DT.warning, 'Pending'),
      ExpenseStatus.approved => (DT.success, 'Approved'),
      ExpenseStatus.rejected => (DT.danger, 'Rejected'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        status == ExpenseStatus.pending
            ? _PulsingDot(color: color)
            : Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.1,
        )),
      ]),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
  );
}

class _HeroCard extends StatelessWidget {
  final ExpenseModel expense;
  const _HeroCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DT.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20, offset: const Offset(0, 6),
        )],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: DT.catBillsSoft, borderRadius: BorderRadius.circular(6)),
          child: Text('GROUP EXPENSE', style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700, color: DT.catBills, letterSpacing: 0.3,
          )),
        ),
        const SizedBox(height: 8),
        Text(expense.title, style: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.3,
        )),
        const SizedBox(height: 6),
        Text('RM ${expense.amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(
          fontSize: 40, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -1.4, height: 1,
        )),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: DT.border))),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 13, color: DT.textSecondary),
            const SizedBox(width: 4),
            Text(_fmtDate(expense.createdAt), style: GoogleFonts.manrope(
              fontSize: 11, color: DT.textSecondary, fontWeight: FontWeight.w600,
            )),
            const SizedBox(width: 14),
            const Icon(Icons.access_time_outlined, size: 13, color: DT.textSecondary),
            const SizedBox(width: 4),
            Text(_fmtTime(expense.createdAt), style: GoogleFonts.manrope(
              fontSize: 11, color: DT.textSecondary, fontWeight: FontWeight.w600,
            )),
          ]),
        ),
      ]),
    );
  }

  String _fmtDate(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: DT.textSecondary, letterSpacing: 0.5),
  );
}

class _RequesterCard extends ConsumerWidget {
  final ExpenseModel expense;
  final bool requesterIsAdmin;
  const _RequesterCard({required this.expense, required this.requesterIsAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = expense.requestedByName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();

    final photoUrl = ref.watch(userProfileStreamProvider(expense.requestedBy)).valueOrNull?.profileImageUrl;

    // Requester's track record across the group's other expenses (this one
    // excluded), so 'Approved'/'Past rejections' reflect real history.
    final allExpenses = ref.watch(groupExpensesStreamProvider(expense.groupId)).valueOrNull ?? [];
    final theirs = allExpenses.where((e) => e.requestedBy == expense.requestedBy && e.id != expense.id);
    final approvedCount = theirs.where((e) => e.status == ExpenseStatus.approved).length;
    final rejectedCount = theirs.where((e) => e.status == ExpenseStatus.rejected).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
      ),
      child: Column(children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 44, height: 44,
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initialsTile(initials))
                  : _initialsTile(initials),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(expense.requestedByName, style: GoogleFonts.manrope(
              fontSize: 15, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.2,
            )),
            Text(requesterIsAdmin ? 'Admin' : 'Group Member', style: GoogleFonts.manrope(
              fontSize: 11, color: DT.textSecondary, fontWeight: FontWeight.w500,
            )),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _TrustStat(
            icon: Icons.check_circle_outline_rounded,
            iconColor: DT.success,
            label: 'Approved',
            value: '$approvedCount',
          )),
          const SizedBox(width: 8),
          Expanded(child: _TrustStat(
            icon: Icons.cancel_outlined,
            iconColor: DT.danger,
            label: 'Past rejections',
            value: '$rejectedCount',
          )),
        ]),
      ]),
    );
  }

  Widget _initialsTile(String initials) => Container(
    color: DT.primarySoft,
    alignment: Alignment.center,
    child: Text(initials.isNotEmpty ? initials : '?', style: GoogleFonts.manrope(
      fontSize: 16, fontWeight: FontWeight.w800, color: DT.text,
    )),
  );
}

class _TrustStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _TrustStat({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, size: 16, color: iconColor),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w800, color: DT.text, height: 1,
        )),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 10, color: DT.textSecondary, fontWeight: FontWeight.w600,
        )),
      ]),
    ]),
  );
}

class _ReceiptCard extends StatelessWidget {
  final String receiptUrl;
  final VoidCallback onTap;
  const _ReceiptCard({required this.receiptUrl, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            receiptUrl,
            width: 72, height: 90,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(width: 72, height: 90, color: DT.surfaceAlt,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: DT.accent))),
            errorBuilder: (_, __, ___) => Container(
              width: 72, height: 90,
              decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.receipt_long_outlined, color: DT.textTertiary, size: 28),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('receipt.jpg', style: GoogleFonts.manrope(
            fontSize: 13, fontWeight: FontWeight.w700, color: DT.text,
          )),
          const SizedBox(height: 2),
          Text('Tap to expand', style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: DT.successSoft, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check, size: 10, color: DT.success),
              const SizedBox(width: 4),
              Text('Receipt attached', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700, color: DT.success,
              )),
            ]),
          ),
        ])),
        const Icon(Icons.chevron_right_rounded, size: 18, color: DT.textTertiary),
      ]),
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  final ExpenseModel expense;
  const _HistoryCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, Color bg, Color color, String title, String subtitle})>[
      (
        icon: Icons.upload_outlined,
        bg: DT.accentSoft,
        color: DT.accentDeep,
        title: 'Expense submitted',
        subtitle: expense.requestedByName,
      ),
    ];

    if (expense.status == ExpenseStatus.approved && expense.approvedByName != null) {
      items.add((
        icon: Icons.check_circle_outline_rounded,
        bg: DT.successSoft,
        color: DT.success,
        title: 'Approved by ${expense.approvedByName}',
        subtitle: expense.approvedAt != null ? _fmt(expense.approvedAt!) : '',
      ));
    }
    if (expense.status == ExpenseStatus.rejected && expense.rejectedByName != null) {
      items.add((
        icon: Icons.cancel_outlined,
        bg: DT.dangerSoft,
        color: DT.danger,
        title: 'Rejected by ${expense.rejectedByName}',
        subtitle: expense.rejectedAt != null ? _fmt(expense.rejectedAt!) : '',
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
      ),
      child: Column(children: [
        for (int i = 0; i < items.length; i++)
          _TimelineItem(
            icon: items[i].icon,
            iconBg: items[i].bg,
            iconColor: items[i].color,
            title: items[i].title,
            subtitle: items[i].subtitle,
            isLast: i == items.length - 1,
          ),
      ]),
    );
  }

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLast;

  const _TimelineItem({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle, required this.isLast,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        if (!isLast)
          Expanded(child: Container(
            width: 1.5, color: DT.border,
            margin: const EdgeInsets.only(top: 2),
          )),
      ]),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.text)),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary, height: 1.4)),
          ]),
        ),
      ),
    ]),
  );
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final bool last;

  const _ReviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      border: Border(bottom: last ? BorderSide.none : const BorderSide(color: DT.border)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.manrope(
        fontSize: 12, color: DT.textSecondary, fontWeight: FontWeight.w600,
      )),
      Text(value, style: GoogleFonts.manrope(
        fontSize: emphasize ? 16 : 13,
        fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
        color: DT.text,
        letterSpacing: emphasize ? -0.3 : 0,
      )),
    ]),
  );
}

class _ReceiptLightbox extends StatelessWidget {
  final String receiptUrl;
  final VoidCallback onClose;
  const _ReceiptLightbox({required this.receiptUrl, required this.onClose});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onClose,
    child: Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Stack(children: [
        Center(
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                receiptUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                errorBuilder: (_, __, ___) => Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: DT.textTertiary, size: 40)),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 16,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ]),
    ),
  );
}
