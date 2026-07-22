import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/models/expense_model.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/screens/expense_detail_screen.dart';

class PendingPaymentsReviewScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const PendingPaymentsReviewScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<PendingPaymentsReviewScreen> createState() =>
      _PendingPaymentsReviewScreenState();
}

class _PendingPaymentsReviewScreenState
    extends ConsumerState<PendingPaymentsReviewScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<PaymentModel> payments) {
    setState(() {
      if (_selectedIds.length == payments.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(payments.map((p) => p.id));
      }
    });
  }

  Future<void> _batchAction(String status, {String? rejectionReason}) async {
    if (_selectedIds.isEmpty) return;
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    setState(() => _isProcessing = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final profile = await ref.read(profileServiceProvider).getUserProfile(userId);
      final count = await ref.read(paymentServiceProvider).batchVerifyPayments(
        paymentIds: _selectedIds.toList(),
        status: status,
        verifiedBy: userId,
        verifiedByName: profile?.name ?? 'Admin',
        rejectionReason: rejectionReason,
      );

      if (!mounted) return;
      final action = status == 'confirmed' ? 'confirmed' : 'rejected';
      messenger.showSnackBar(_snackBar(
        '$count payment${count > 1 ? 's' : ''} $action',
        color: status == 'confirmed' ? DT.success : DT.danger,
      ));
      setState(() => _selectedIds.clear());
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(_snackBar('Error: $e', color: DT.danger));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  SnackBar _snackBar(String text, {required Color color}) => SnackBar(
        content: Text(text, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  void _showBatchRejectDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.heroRadius)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DS.sm),
              decoration: BoxDecoration(
                color: DT.dangerSoft,
                borderRadius: BorderRadius.circular(DS.md),
              ),
              child: const Icon(Icons.close_rounded, color: DT.danger, size: 20),
            ),
            const SizedBox(width: DS.md),
            Expanded(
              child: Text(
                'Reject ${_selectedIds.length} Payment${_selectedIds.length > 1 ? 's' : ''}?',
                style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide a reason for rejection (optional):',
              style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary),
            ),
            const SizedBox(height: DS.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.manrope(fontSize: 14, color: DT.text),
              decoration: InputDecoration(
                hintText: 'e.g. Wrong amount, invalid receipt...',
                hintStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
                filled: true,
                fillColor: DT.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.md),
                  borderSide: const BorderSide(color: DT.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.md),
                  borderSide: const BorderSide(color: DT.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.md),
                  borderSide: const BorderSide(color: DT.text, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(DS.md),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.manrope(color: DT.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _batchAction('rejected', rejectionReason: reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DT.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.md)),
            ),
            child: Text('Reject', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingPaymentsStreamProvider(widget.groupId));
    final expensesAsync = ref.watch(pendingExpensesStreamProvider(widget.groupId));

    final paymentCount = pendingAsync.valueOrNull?.length ?? 0;
    final expenseCount = expensesAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: DT.bg,
      appBar: AppBar(
        backgroundColor: DT.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DT.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review', style: GoogleFonts.manrope(
              fontSize: 17, fontWeight: FontWeight.w700, color: DT.text,
            )),
            Text(widget.groupName, style: GoogleFonts.manrope(
              fontSize: 12, color: DT.textSecondary,
            )),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45),
          child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: DT.border))),
            child: TabBar(
              controller: _tabController,
              labelColor: DT.text,
              unselectedLabelColor: DT.textTertiary,
              indicatorColor: DT.text,
              indicatorWeight: 2,
              labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: paymentCount > 0 ? 'Payments ($paymentCount)' : 'Payments'),
                Tab(text: expenseCount > 0 ? 'Expenses ($expenseCount)' : 'Expenses'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Payments tab ─────────────────────────────────────────
          Column(
            children: [
              pendingAsync.maybeWhen(
                data: (payments) {
                  if (payments.isEmpty) return const SizedBox.shrink();
                  final allSelected = _selectedIds.length == payments.length;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.md, DS.screenPad, DS.md),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [DT.headerGradientStart, DT.headerGradientEnd],
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleSelectAll(payments),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: DS.md, vertical: DS.sm),
                            decoration: BoxDecoration(
                              color: allSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(DS.chipRadius),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                  size: 17,
                                  color: allSelected ? DT.text : Colors.white.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  allSelected ? 'Deselect All' : 'Select All',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: allSelected ? DT.text : Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedIds.length}/${payments.length} selected',
                          style: GoogleFonts.manrope(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              Expanded(
                child: pendingAsync.when(
                  data: (payments) {
                    _selectedIds.removeWhere((id) => !payments.any((p) => p.id == id));
                    if (payments.isEmpty) return _EmptyState(label: 'No pending payments to review');
                    return ListView.builder(
                      padding: const EdgeInsets.all(DS.screenPad),
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        return _PaymentCard(
                          payment: payment,
                          isSelected: _selectedIds.contains(payment.id),
                          onTap: () => _showPaymentDetailModal(payment),
                          onToggle: () => _toggleSelection(payment.id),
                          onApprove: () => _quickApprove(payment),
                          onReject: () => _quickReject(payment),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: DT.text, strokeWidth: 2.5)),
                  error: (e, _) => Center(child: Padding(
                    padding: const EdgeInsets.all(DS.xxl),
                    child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.danger)),
                  )),
                ),
              ),
              // Batch action footer (payments only)
              if (_selectedIds.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: DT.surface,
                      border: Border(top: BorderSide(color: DT.border)),
                    ),
                    padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.md, DS.screenPad, DS.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isProcessing ? null : _showBatchRejectDialog,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: Text('Reject (${_selectedIds.length})',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DT.danger,
                              side: const BorderSide(color: DT.danger, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: DS.md),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : () => _batchAction('confirmed'),
                            icon: _isProcessing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text('Confirm (${_selectedIds.length})',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DT.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: DT.border,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Expenses tab ─────────────────────────────────────────
          expensesAsync.when(
            data: (expenses) {
              if (expenses.isEmpty) return _EmptyState(label: 'No pending expense requests');
              return ListView.builder(
                padding: const EdgeInsets.all(DS.screenPad),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return _ExpenseCard(
                    expense: expense,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ExpenseDetailScreen(expense: expense, groupId: widget.groupId),
                    )),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: DT.text, strokeWidth: 2.5)),
            error: (e, _) => Center(child: Padding(
              padding: const EdgeInsets.all(DS.xxl),
              child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.danger)),
            )),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetailModal(PaymentModel payment) {
    final methodLabel = switch (payment.paymentMethod) {
      'duitnow' => 'DuitNow',
      'online_banking' => 'Online Banking',
      'cash' => 'Cash',
      _ => payment.paymentMethod,
    };
    final dateStr =
        '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(DS.heroRadius)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: DS.md),
              width: 40, height: 4,
              decoration: BoxDecoration(color: DT.border, borderRadius: BorderRadius.circular(2)),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.lg, DS.screenPad, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DS.md),
                    decoration: BoxDecoration(
                      color: DT.warningSoft,
                      borderRadius: BorderRadius.circular(DS.cardRadius),
                    ),
                    child: const Icon(Icons.rate_review_outlined, color: DT.warning, size: 22),
                  ),
                  const SizedBox(width: DS.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Details', style: GoogleFonts.manrope(
                          fontSize: 18, fontWeight: FontWeight.w800, color: DT.text,
                        )),
                        Text('By ${payment.userName}', style: GoogleFonts.manrope(
                          fontSize: 13, color: DT.textSecondary,
                        )),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(modalContext),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: DT.surfaceAlt,
                        borderRadius: BorderRadius.circular(DS.sm),
                        border: Border.all(color: DT.border),
                      ),
                      child: const Icon(Icons.close, size: 18, color: DT.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: DS.lg),
            Container(height: 1, color: DT.border),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.lg, DS.screenPad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(DS.xl),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [DT.headerGradientStart, DT.headerGradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                      ),
                      child: Column(
                        children: [
                          Text('Payment Amount', style: GoogleFonts.manrope(
                            fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w500,
                          )),
                          const SizedBox(height: 6),
                          Text(
                            'RM${payment.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DS.xl),

                    _buildDetailRow(Icons.calendar_today_outlined, 'Payment Date', dateStr),
                    _buildDetailRow(Icons.payment_outlined, 'Payment Method', methodLabel),
                    _buildDetailRow(Icons.date_range_outlined, 'For Month', '${_getMonthName(payment.month)} ${payment.year}'),
                    if (payment.transactionReference != null && payment.transactionReference!.isNotEmpty)
                      _buildDetailRow(Icons.tag, 'Reference', payment.transactionReference!),
                    if (payment.notes != null && payment.notes!.isNotEmpty)
                      _buildDetailRow(Icons.notes_outlined, 'Notes', payment.notes!),

                    // Receipt
                    if (payment.receiptUrl != null && payment.receiptUrl!.isNotEmpty) ...[
                      const SizedBox(height: DS.lg),
                      Text('Receipt', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: DT.text,
                      )),
                      const SizedBox(height: DS.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                        child: Image.network(
                          payment.receiptUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: DT.surfaceAlt,
                                borderRadius: BorderRadius.circular(DS.cardRadius),
                              ),
                              child: const Center(child: CircularProgressIndicator(color: DT.text, strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, _, __) => Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: DT.surfaceAlt,
                              borderRadius: BorderRadius.circular(DS.cardRadius),
                              border: Border.all(color: DT.border),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.broken_image_outlined, color: DT.textTertiary, size: 28),
                                  const SizedBox(height: 4),
                                  Text('Failed to load receipt', style: GoogleFonts.manrope(
                                    fontSize: 12, color: DT.textTertiary,
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: DS.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(DS.md),
                        decoration: BoxDecoration(
                          color: DT.warningSoft,
                          borderRadius: BorderRadius.circular(DS.md),
                          border: Border.all(color: DT.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: DT.warning, size: 18),
                            const SizedBox(width: DS.sm),
                            Expanded(
                              child: Text(
                                'No receipt uploaded for this payment',
                                style: GoogleFonts.manrope(
                                  fontSize: 13, color: DT.warning, fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: DS.xxl),
                  ],
                ),
              ),
            ),

            // Select / deselect CTA
            Container(
              decoration: const BoxDecoration(
                color: DT.surface,
                border: Border(top: BorderSide(color: DT.border)),
              ),
              padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.md, DS.screenPad, DS.xl),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: StatefulBuilder(
                    builder: (context, setModalState) {
                      final isSelected = _selectedIds.contains(payment.id);
                      return ElevatedButton.icon(
                        onPressed: () {
                          _toggleSelection(payment.id);
                          setModalState(() {});
                        },
                        icon: Icon(
                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 20,
                        ),
                        label: Text(
                          isSelected ? 'Selected' : 'Select for Review',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? DT.text : DT.surface,
                          foregroundColor: isSelected ? Colors.white : DT.text,
                          elevation: 0,
                          side: isSelected ? null : const BorderSide(color: DT.border, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DS.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(DS.sm),
            decoration: BoxDecoration(
              color: DT.primarySoft,
              borderRadius: BorderRadius.circular(DS.sm),
            ),
            child: Icon(icon, size: 16, color: DT.text),
          ),
          const SizedBox(width: DS.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.manrope(
                  fontSize: 11, color: DT.textTertiary, fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.manrope(
                  fontSize: 15, color: DT.text, fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month.clamp(1, 12)];
  }

  Future<void> _quickApprove(PaymentModel payment) async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = await ref.read(profileServiceProvider).getUserProfile(userId);
      await ref.read(paymentServiceProvider).batchVerifyPayments(
        paymentIds: [payment.id],
        status: 'confirmed',
        verifiedBy: userId,
        verifiedByName: profile?.name ?? 'Admin',
      );
      if (!mounted) return;
      messenger.showSnackBar(_snackBar('Payment approved', color: DT.success));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(_snackBar('Error: $e', color: DT.danger));
    }
  }

  Future<void> _quickReject(PaymentModel payment) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.heroRadius)),
        title: Text('Reject Payment?', style: GoogleFonts.manrope(
          fontSize: 17, fontWeight: FontWeight.w800, color: DT.text,
        )),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.manrope(fontSize: 14, color: DT.text),
          decoration: InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
            filled: true,
            fillColor: DT.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.md),
              borderSide: const BorderSide(color: DT.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.md),
              borderSide: const BorderSide(color: DT.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DS.md),
              borderSide: const BorderSide(color: DT.text, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(DS.md),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.manrope(color: DT.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: DT.danger, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.md)),
            ),
            child: Text('Reject', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = await ref.read(profileServiceProvider).getUserProfile(userId);
      await ref.read(paymentServiceProvider).batchVerifyPayments(
        paymentIds: [payment.id],
        status: 'rejected',
        verifiedBy: userId,
        verifiedByName: profile?.name ?? 'Admin',
        rejectionReason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      if (!mounted) return;
      messenger.showSnackBar(_snackBar('Payment rejected', color: DT.danger));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(_snackBar('Error: $e', color: DT.danger));
    }
  }
}

// ─── Payment card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final PaymentModel payment;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentCard({
    required this.payment,
    required this.isSelected,
    required this.onTap,
    required this.onToggle,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final methodLabel = switch (payment.paymentMethod) {
      'duitnow' => 'DuitNow',
      'online_banking' => 'Online Banking',
      'cash' => 'Cash',
      _ => payment.paymentMethod,
    };
    final dateStr =
        '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}';
    final hasReceipt = payment.receiptUrl != null && payment.receiptUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: DS.sm),
        decoration: BoxDecoration(
          color: isSelected ? DT.primarySoft : DT.surface,
          borderRadius: BorderRadius.circular(DS.cardRadius),
          border: Border.all(
            color: isSelected ? DT.borderStrong : DT.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DS.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: onToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: DS.md),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: isSelected ? DT.text : Colors.transparent,
                          borderRadius: BorderRadius.circular(DS.sm),
                          border: Border.all(
                            color: isSelected ? DT.text : DT.borderStrong,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    ),
                  ),

                  // Receipt icon
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: hasReceipt ? DT.successSoft : DT.warningSoft,
                      borderRadius: BorderRadius.circular(DS.md),
                    ),
                    child: Icon(
                      hasReceipt ? Icons.receipt_long : Icons.receipt_long_outlined,
                      color: hasReceipt ? DT.success : DT.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: DS.md),

                  // Name + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payment.userName, style: GoogleFonts.manrope(
                          fontSize: 15, fontWeight: FontWeight.w700, color: DT.text,
                        ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text('$methodLabel  ·  $dateStr', style: GoogleFonts.manrope(
                          fontSize: 12, color: DT.textTertiary,
                        )),
                        if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(payment.notes!, style: GoogleFonts.manrope(
                            fontSize: 11, color: DT.textTertiary,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),

                  // Amount
                  Text('RM${payment.amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(
                    fontSize: 15, fontWeight: FontWeight.w800, color: DT.text,
                  )),
                ],
              ),

              Container(height: 1, color: DT.border, margin: const EdgeInsets.symmetric(vertical: DS.sm)),

              // Quick actions
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: Text('Reject', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w700,
                      )),
                      style: TextButton.styleFrom(
                        foregroundColor: DT.danger,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  Container(width: 1, height: 18, color: DT.border),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: Text('Approve', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w700,
                      )),
                      style: TextButton.styleFrom(
                        foregroundColor: DT.success,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(DS.xxl),
            decoration: const BoxDecoration(color: DT.successSoft, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, size: 48, color: DT.success),
          ),
          const SizedBox(height: DS.lg),
          Text('All clear!', style: GoogleFonts.manrope(
            fontSize: 18, fontWeight: FontWeight.w700, color: DT.text,
          )),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 14, color: DT.textSecondary,
          )),
        ],
      ),
    );
  }
}

// ─── Expense card ─────────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  const _ExpenseCard({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = '${expense.createdAt.day}/${expense.createdAt.month}/${expense.createdAt.year}';
    final hasReceipt = expense.receiptUrl != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: DS.sm),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DS.cardRadius),
          border: Border.all(color: DT.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DS.md),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: DT.warningSoft,
                  borderRadius: BorderRadius.circular(DS.md),
                ),
                child: const Icon(Icons.receipt_long_outlined, color: DT.warning, size: 20),
              ),
              const SizedBox(width: DS.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.title, style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w700, color: DT.text,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${expense.requestedByName}  ·  $dateStr${hasReceipt ? '  ·  Receipt' : ''}',
                        style: GoogleFonts.manrope(fontSize: 12, color: DT.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: DS.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('RM${expense.amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(
                    fontSize: 15, fontWeight: FontWeight.w800, color: DT.text,
                  )),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DT.warningSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Review', style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w700, color: DT.warning,
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
