import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  final String groupId;

  const PaymentHistoryScreen({super.key, required this.groupId});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  String? _selectedMemberId;
  String? _selectedMemberName;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  bool _isPdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.pdf') || lower.contains('application/pdf') || lower.contains('%2Fpdf');
  }

  bool get _hasFilters =>
      _selectedMemberId != null || _filterStartDate != null || _filterEndDate != null;

  List<PaymentModel> _applyFilters(List<PaymentModel> payments) {
    var filtered = payments;
    if (_selectedMemberId != null) {
      filtered = filtered.where((p) => p.userId == _selectedMemberId).toList();
    }
    if (_filterStartDate != null) {
      final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
      filtered = filtered.where((p) => !p.paymentDate.isBefore(start)).toList();
    }
    if (_filterEndDate != null) {
      final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
      filtered = filtered.where((p) => !p.paymentDate.isAfter(end)).toList();
    }
    filtered.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return filtered;
  }

  String _getPaymentDateKey(PaymentModel p) =>
      '${p.paymentDate.year}-${p.paymentDate.month.toString().padLeft(2, '0')}';

  void _clearFilters() => setState(() {
        _selectedMemberId = null;
        _selectedMemberName = null;
        _filterStartDate = null;
        _filterEndDate = null;
      });

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: DT.primary,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
      });
    }
  }

  String _getMonthYearLabel(String key) {
    final parts = key.split('-');
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[int.parse(parts[1]) - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final paymentsAsync = ref.watch(groupPaymentsStreamProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: DT.bg,
      appBar: AppBar(
        backgroundColor: DT.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Payment History',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: paymentsAsync.when(
        data: (allPayments) {
          if (allPayments.isEmpty) {
            return _EmptyState(onRetry: null);
          }

          final isAdmin = membersAsync.whenOrNull(
                data: (members) => members.any((m) => m.userId == userId && m.isAdmin),
              ) ??
              false;

          final payments = _applyFilters(allPayments);
          final membersList = membersAsync.whenOrNull(data: (m) => m) ?? <GroupMember>[];

          return Column(
            children: [
              _FilterBar(
                hasFilters: _hasFilters,
                filterStartDate: _filterStartDate,
                filterEndDate: _filterEndDate,
                selectedMemberName: _selectedMemberName,
                selectedMemberId: _selectedMemberId,
                onPickDate: _pickDateRange,
                onClearDate: () => setState(() {
                  _filterStartDate = null;
                  _filterEndDate = null;
                }),
                onPickMember: () => _showMemberPicker(membersList),
                onClearMember: () => setState(() {
                  _selectedMemberId = null;
                  _selectedMemberName = null;
                }),
                onClearAll: _clearFilters,
                filteredCount: payments.length,
                totalCount: allPayments.length,
              ),
              _StatRow(payments: payments),
              Expanded(
                child: payments.isEmpty
                    ? _EmptyState(onRetry: _clearFilters)
                    : ListView.builder(
                        padding: const EdgeInsets.all(DS.lg),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          final isPdf = payment.receiptUrl != null && _isPdfUrl(payment.receiptUrl!);
                          final isFirst = index == 0;
                          final isLast = index == payments.length - 1;
                          final dateKey = _getPaymentDateKey(payment);
                          final isNewMonth = index == 0 || dateKey != _getPaymentDateKey(payments[index - 1]);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isNewMonth) ...[
                                if (index > 0) const SizedBox(height: DS.sm),
                                _MonthHeader(label: _getMonthYearLabel(dateKey)),
                                const SizedBox(height: DS.md),
                              ],
                              _TimelineItem(
                                payment: payment,
                                isFirst: isFirst,
                                isLast: isLast,
                                isNewMonth: isNewMonth,
                                isPdf: isPdf,
                                isAdmin: isAdmin,
                                onTap: () => _showPaymentDetail(context, payment),
                                onViewReceipt: () => isPdf
                                    ? _openPdfReceipt(context, payment.receiptUrl!)
                                    : _showReceiptImage(context, payment.receiptUrl!),
                                onDelete: () => _deletePayment(context, payment),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: DT.primary)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(DS.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: DT.danger),
                const SizedBox(height: DS.lg),
                Text('Error loading payments: $error',
                    style: GoogleFonts.manrope(color: DT.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: DS.lg),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(groupPaymentsStreamProvider(widget.groupId)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text('Retry', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Modals ----------

  void _showPaymentDetail(BuildContext context, PaymentModel payment) {
    final isPdf = payment.receiptUrl != null && _isPdfUrl(payment.receiptUrl!);
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const methodLabels = {'cash': 'Cash', 'duitnow': 'DuitNow', 'online_banking': 'Online Banking'};

    Color statusColor = switch (payment.paymentStatus) {
      'confirmed' => DT.success,
      'rejected' => DT.danger,
      _ => DT.warning,
    };
    Color statusSoft = switch (payment.paymentStatus) {
      'confirmed' => DT.successSoft,
      'rejected' => DT.dangerSoft,
      _ => DT.warningSoft,
    };
    String statusLabel = switch (payment.paymentStatus) {
      'confirmed' => 'Confirmed',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
        decoration: const BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(DS.heroRadius)),
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(DS.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: DS.xl),
                    decoration: BoxDecoration(color: DT.border, borderRadius: BorderRadius.circular(2)),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: payment.paymentStatus == 'confirmed'
                                ? [DT.success, DT.accentDeep]
                                : payment.paymentStatus == 'rejected'
                                    ? [DT.danger, const Color(0xFFC62828)]
                                    : [DT.warning, const Color(0xFFF57C00)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            payment.userName.isNotEmpty ? payment.userName[0].toUpperCase() : '?',
                            style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: DS.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(payment.userName,
                                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
                            const SizedBox(height: DS.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusSoft,
                                borderRadius: BorderRadius.circular(DS.chipRadius),
                              ),
                              child: Text(statusLabel,
                                  style: GoogleFonts.manrope(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                            ),
                          ],
                        ),
                      ),
                      Text('RM${payment.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.manrope(
                              fontSize: 22, fontWeight: FontWeight.w800, color: DT.primary)),
                    ],
                  ),

                  const SizedBox(height: DS.xxl),

                  // Details card
                  Container(
                    padding: const EdgeInsets.all(DS.lg),
                    decoration: BoxDecoration(
                      color: DT.surfaceAlt,
                      borderRadius: BorderRadius.circular(DS.cardRadius),
                      border: Border.all(color: DT.border),
                    ),
                    child: Column(
                      children: [
                        _DetailRow(Icons.calendar_month_rounded, 'Payment For',
                            '${monthNames[payment.month - 1]} ${payment.year}'),
                        const Divider(height: 24, color: DT.border),
                        _DetailRow(Icons.access_time_rounded, 'Payment Date',
                            '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}'),
                        const Divider(height: 24, color: DT.border),
                        _DetailRow(Icons.payment_rounded, 'Method',
                            methodLabels[payment.paymentMethod] ?? payment.paymentMethod),
                        if (payment.transactionReference != null &&
                            payment.transactionReference!.isNotEmpty) ...[
                          const Divider(height: 24, color: DT.border),
                          _DetailRow(Icons.tag_rounded, 'Reference', payment.transactionReference!),
                        ],
                        if (payment.recipientPhone != null && payment.recipientPhone!.isNotEmpty) ...[
                          const Divider(height: 24, color: DT.border),
                          _DetailRow(Icons.phone_rounded, 'Recipient', payment.recipientPhone!),
                        ],
                        const Divider(height: 24, color: DT.border),
                        _DetailRow(
                          Icons.schedule_rounded,
                          'Submitted',
                          '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}'
                          ' ${payment.createdAt.hour.toString().padLeft(2, '0')}:${payment.createdAt.minute.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                  ),

                  // Notes
                  if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                    const SizedBox(height: DS.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(DS.lg),
                      decoration: BoxDecoration(
                        color: DT.surfaceAlt,
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                        border: Border.all(color: DT.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.note_outlined, size: 16, color: DT.textSecondary),
                            const SizedBox(width: DS.sm),
                            Text('Notes',
                                style: GoogleFonts.manrope(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: DT.textSecondary)),
                          ]),
                          const SizedBox(height: DS.sm),
                          Text(payment.notes!,
                              style: GoogleFonts.manrope(fontSize: 14, color: DT.text)),
                        ],
                      ),
                    ),
                  ],

                  // Verification info
                  if (payment.verifiedByName != null) ...[
                    const SizedBox(height: DS.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(DS.lg),
                      decoration: BoxDecoration(
                        color: statusSoft,
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(
                              payment.paymentStatus == 'confirmed'
                                  ? Icons.verified_rounded
                                  : Icons.cancel_rounded,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: DS.sm),
                            Text(
                              payment.paymentStatus == 'confirmed' ? 'Verified by' : 'Rejected by',
                              style: GoogleFonts.manrope(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: statusColor),
                            ),
                          ]),
                          const SizedBox(height: DS.sm),
                          Text(payment.verifiedByName!,
                              style: GoogleFonts.manrope(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: DT.text)),
                          if (payment.verifiedAt != null)
                            Text(
                              '${payment.verifiedAt!.day}/${payment.verifiedAt!.month}/${payment.verifiedAt!.year}'
                              ' ${payment.verifiedAt!.hour.toString().padLeft(2, '0')}:${payment.verifiedAt!.minute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.manrope(fontSize: 12, color: DT.textTertiary),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Rejection reason
                  if (payment.paymentStatus == 'rejected' &&
                      payment.rejectionReason != null &&
                      payment.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: DS.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(DS.lg),
                      decoration: BoxDecoration(
                        color: DT.dangerSoft,
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                        border: Border.all(color: DT.danger.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: DT.danger),
                            const SizedBox(width: DS.sm),
                            Text('Rejection Reason',
                                style: GoogleFonts.manrope(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: DT.danger)),
                          ]),
                          const SizedBox(height: DS.sm),
                          Text(payment.rejectionReason!,
                              style: GoogleFonts.manrope(fontSize: 14, color: DT.text)),
                        ],
                      ),
                    ),
                  ],

                  // Receipt button
                  if (payment.receiptUrl != null) ...[
                    const SizedBox(height: DS.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (isPdf) {
                            _openPdfReceipt(context, payment.receiptUrl!);
                          } else {
                            _showReceiptImage(context, payment.receiptUrl!);
                          }
                        },
                        icon: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.receipt_rounded, size: 18),
                        label: Text(
                          isPdf ? 'View PDF Receipt' : 'View Receipt',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DT.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DS.cardRadius)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMemberPicker(List<GroupMember> members) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DT.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(DS.heroRadius))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: DT.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(DS.lg),
              child: Text('Filter by Member',
                  style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w700, color: DT.text)),
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: DT.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.people_outline_rounded, color: DT.primary, size: 20),
              ),
              title: Text('All Members',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: DT.text)),
              trailing: _selectedMemberId == null
                  ? const Icon(Icons.check_circle_rounded, color: DT.primary, size: 22)
                  : null,
              onTap: () {
                setState(() {
                  _selectedMemberId = null;
                  _selectedMemberName = null;
                });
                Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1, color: DT.border),
            ...members.map((member) => ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: DT.primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: Center(
                      child: Text(
                        member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
                        style: GoogleFonts.manrope(
                            color: DT.primary, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                  title: Text(member.userName,
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: DT.text)),
                  subtitle: member.isAdmin
                      ? Text('Admin',
                          style: GoogleFonts.manrope(fontSize: 12, color: DT.accent))
                      : null,
                  trailing: _selectedMemberId == member.userId
                      ? const Icon(Icons.check_circle_rounded, color: DT.primary, size: 22)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedMemberId = member.userId;
                      _selectedMemberName = member.userName;
                    });
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: DS.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdfReceipt(BuildContext context, String pdfUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(DS.xxl),
          decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(DS.cardRadius)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: DT.primary),
              const SizedBox(height: DS.lg),
              Text('Downloading receipt...',
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.text)),
            ],
          ),
        ),
      ),
    );

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(response.bodyBytes);
        if (!mounted) return;
        nav.pop();
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done && mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not open PDF: ${result.message}'), backgroundColor: DT.danger),
          );
        }
      } else {
        if (mounted) {
          nav.pop();
          messenger.showSnackBar(
            const SnackBar(content: Text('Failed to download receipt'), backgroundColor: DT.danger),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(content: Text('Error opening receipt: $e'), backgroundColor: DT.danger),
        );
      }
    }
  }

  void _showReceiptImage(BuildContext context, String receiptUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: DT.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: DS.lg, vertical: DS.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [DT.headerGradientStart, DT.headerGradientEnd]),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(DS.cardRadius),
                  topRight: Radius.circular(DS.cardRadius),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Receipt',
                        style: GoogleFonts.manrope(
                            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(ctx).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  receiptUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Padding(
                      padding: const EdgeInsets.all(50),
                      child: CircularProgressIndicator(
                        color: DT.primary,
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (ctx, _, __) => Padding(
                    padding: const EdgeInsets.all(50),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: DT.danger.withValues(alpha: 0.5)),
                        const SizedBox(height: DS.lg),
                        Text('Failed to load receipt',
                            style: GoogleFonts.manrope(color: DT.textTertiary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePayment(BuildContext context, PaymentModel payment) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(DS.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(DS.sm),
                  decoration:
                      BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(DS.sm)),
                  child: const Icon(Icons.delete_forever_rounded, color: DT.danger, size: 22),
                ),
                const SizedBox(width: DS.md),
                Text('Delete Payment',
                    style: GoogleFonts.manrope(
                        fontSize: 17, fontWeight: FontWeight.w800, color: DT.text)),
              ]),
              const SizedBox(height: DS.lg),
              Text('Are you sure you want to delete this payment?',
                  style: GoogleFonts.manrope(fontSize: 14, color: DT.textSecondary)),
              const SizedBox(height: DS.lg),
              Container(
                padding: const EdgeInsets.all(DS.md),
                decoration: BoxDecoration(
                    color: DT.surfaceAlt,
                    borderRadius: BorderRadius.circular(DS.md),
                    border: Border.all(color: DT.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoLine(Icons.person_outline_rounded, payment.userName, DT.textSecondary),
                    const SizedBox(height: DS.xs),
                    _InfoLine(Icons.payments_outlined, 'RM${payment.amount.toStringAsFixed(2)}', DT.success),
                    const SizedBox(height: DS.xs),
                    _InfoLine(
                      Icons.calendar_today_outlined,
                      '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                      DT.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DS.md),
              Container(
                padding: const EdgeInsets.all(DS.sm),
                decoration: BoxDecoration(
                    color: DT.dangerSoft, borderRadius: BorderRadius.circular(DS.sm)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: DT.danger),
                  const SizedBox(width: DS.sm),
                  Expanded(
                    child: Text('This action cannot be undone',
                        style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary)),
                  ),
                ]),
              ),
              const SizedBox(height: DS.xxl),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DT.textSecondary,
                      side: const BorderSide(color: DT.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.cardRadius)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: DS.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DT.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.cardRadius)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    child: Text('Delete',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.deletePaymentWithStats(
        paymentId: payment.id,
        groupId: payment.groupId,
        userId: payment.userId,
        amount: payment.amount,
      );
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Payment deleted successfully')));
        ref.invalidate(groupPaymentsStreamProvider(widget.groupId));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete payment: $e'), backgroundColor: DT.danger),
        );
      }
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final bool hasFilters;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;
  final String? selectedMemberId;
  final String? selectedMemberName;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final VoidCallback onPickMember;
  final VoidCallback onClearMember;
  final VoidCallback onClearAll;
  final int filteredCount;
  final int totalCount;

  const _FilterBar({
    required this.hasFilters,
    required this.filterStartDate,
    required this.filterEndDate,
    required this.selectedMemberId,
    required this.selectedMemberName,
    required this.onPickDate,
    required this.onClearDate,
    required this.onPickMember,
    required this.onClearMember,
    required this.onClearAll,
    required this.filteredCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(DS.lg, DS.sm, DS.lg, DS.md),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [DT.headerGradientStart, DT.headerGradientEnd]),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _FilterChip(
                icon: Icons.date_range_rounded,
                label: filterStartDate != null
                    ? '${filterStartDate!.day}/${filterStartDate!.month} – ${filterEndDate!.day}/${filterEndDate!.month}'
                    : 'Date Range',
                active: filterStartDate != null,
                onTap: onPickDate,
                onClear: filterStartDate != null ? onClearDate : null,
              )),
              const SizedBox(width: DS.sm),
              Expanded(child: _FilterChip(
                icon: Icons.person_outline_rounded,
                label: selectedMemberName ?? 'Member',
                active: selectedMemberId != null,
                onTap: onPickMember,
                onClear: selectedMemberId != null ? onClearMember : null,
              )),
              if (hasFilters) ...[
                const SizedBox(width: DS.sm),
                GestureDetector(
                  onTap: onClearAll,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(DS.md),
                    ),
                    child: const Icon(Icons.filter_alt_off_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
          if (hasFilters) ...[
            const SizedBox(height: DS.sm),
            Text(
              '$filteredCount of $totalCount payments',
              style: GoogleFonts.manrope(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(DS.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? DT.primary : Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: DS.sm),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? DT.primary : Colors.white.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 16, color: DT.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final List<PaymentModel> payments;

  const _StatRow({required this.payments});

  @override
  Widget build(BuildContext context) {
    final confirmed = payments.where((p) => p.paymentStatus == 'confirmed').toList();
    final pending = payments.where((p) => p.paymentStatus == 'pending').toList();
    final confirmedAmt = confirmed.fold(0.0, (s, p) => s + p.amount);
    final pendingAmt = pending.fold(0.0, (s, p) => s + p.amount);

    return Container(
      padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, DS.md),
      color: DT.surface,
      child: Row(
        children: [
          _StatChip(
            icon: Icons.check_circle_outline_rounded,
            label: 'Confirmed',
            count: confirmed.length,
            amount: confirmedAmt,
            color: DT.success,
            softColor: DT.successSoft,
          ),
          const SizedBox(width: DS.sm),
          _StatChip(
            icon: Icons.schedule_rounded,
            label: 'Pending',
            count: pending.length,
            amount: pendingAmt,
            color: DT.warning,
            softColor: DT.warningSoft,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final double amount;
  final Color color;
  final Color softColor;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.amount,
    required this.color,
    required this.softColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.md, vertical: DS.sm),
        decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(DS.md)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: DS.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.manrope(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                  Text(
                    'RM${amount.toStringAsFixed(2)} · $count',
                    style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w700, color: DT.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String label;

  const _MonthHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.lg, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [DT.headerGradientStart, DT.headerGradientEnd]),
        borderRadius: BorderRadius.circular(DS.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white),
          const SizedBox(width: DS.sm),
          Text(label,
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final PaymentModel payment;
  final bool isFirst;
  final bool isLast;
  final bool isNewMonth;
  final bool isPdf;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onViewReceipt;
  final VoidCallback onDelete;

  const _TimelineItem({
    required this.payment,
    required this.isFirst,
    required this.isLast,
    required this.isNewMonth,
    required this.isPdf,
    required this.isAdmin,
    required this.onTap,
    required this.onViewReceipt,
    required this.onDelete,
  });

  Color get _statusColor => switch (payment.paymentStatus) {
        'confirmed' => DT.success,
        'rejected' => DT.danger,
        _ => DT.warning,
      };

  Color get _statusSoft => switch (payment.paymentStatus) {
        'confirmed' => DT.successSoft,
        'rejected' => DT.dangerSoft,
        _ => DT.warningSoft,
      };

  String get _statusLabel => switch (payment.paymentStatus) {
        'confirmed' => 'Confirmed',
        'rejected' => 'Rejected',
        _ => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst && !isNewMonth)
                  Container(width: 2, height: 12, color: DT.primary.withValues(alpha: 0.25))
                else
                  const SizedBox(height: 12),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DT.primary,
                    border: Border.all(color: DT.surface, width: 2),
                    boxShadow: [BoxShadow(color: DT.primary.withValues(alpha: 0.25), blurRadius: 4)],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: DT.primary.withValues(alpha: 0.25))),
              ],
            ),
          ),

          const SizedBox(width: DS.md),

          // Card
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: DS.lg),
                padding: const EdgeInsets.all(DS.lg),
                decoration: BoxDecoration(
                  color: DT.surface,
                  borderRadius: BorderRadius.circular(DS.cardRadius),
                  border: Border.all(color: DT.border),
                  boxShadow: [
                    BoxShadow(color: DT.primary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: DT.primarySoft,
                            borderRadius: BorderRadius.circular(DS.md),
                          ),
                          child: Center(
                            child: Text(
                              payment.userName.isNotEmpty ? payment.userName[0].toUpperCase() : '?',
                              style: GoogleFonts.manrope(
                                  color: DT.primary, fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: DS.md),

                        // Name & date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(payment.userName,
                                  style: GoogleFonts.manrope(
                                      fontSize: 15, fontWeight: FontWeight.w700, color: DT.text)),
                              const SizedBox(height: 3),
                              Row(children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: DT.textTertiary),
                                const SizedBox(width: 4),
                                Text(
                                  '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                                  style: GoogleFonts.manrope(fontSize: 12, color: DT.textTertiary),
                                ),
                              ]),
                            ],
                          ),
                        ),

                        // Amount + status badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                  color: _statusSoft,
                                  borderRadius: BorderRadius.circular(DS.chipRadius)),
                              child: Text('RM${payment.amount.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                      fontSize: 15, fontWeight: FontWeight.w800, color: _statusColor)),
                            ),
                            const SizedBox(height: 4),
                            Text(_statusLabel,
                                style: GoogleFonts.manrope(
                                    fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor)),
                          ],
                        ),
                      ],
                    ),

                    // Notes
                    if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                      const SizedBox(height: DS.md),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: DT.surfaceAlt, borderRadius: BorderRadius.circular(DS.sm)),
                        child: Row(children: [
                          const Icon(Icons.note_outlined, size: 14, color: DT.textSecondary),
                          const SizedBox(width: DS.xs + 2),
                          Expanded(
                            child: Text(payment.notes!,
                                style: GoogleFonts.manrope(
                                    fontSize: 12, color: DT.textSecondary,
                                    fontStyle: FontStyle.italic)),
                          ),
                        ]),
                      ),
                    ],

                    // Rejection reason
                    if (payment.paymentStatus == 'rejected' &&
                        payment.rejectionReason != null &&
                        payment.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: DS.sm),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: DT.dangerSoft,
                          borderRadius: BorderRadius.circular(DS.sm),
                          border: Border.all(color: DT.danger.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded, size: 14, color: DT.danger),
                          const SizedBox(width: DS.xs + 2),
                          Expanded(
                            child: Text('Rejected: ${payment.rejectionReason}',
                                style: GoogleFonts.manrope(
                                    fontSize: 12, color: DT.danger, fontWeight: FontWeight.w500)),
                          ),
                        ]),
                      ),
                    ],

                    // Actions row
                    if (payment.receiptUrl != null || isAdmin) ...[
                      const SizedBox(height: DS.md),
                      Row(
                        children: [
                          if (payment.receiptUrl != null)
                            Expanded(
                              child: _ActionButton(
                                icon: isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.receipt_rounded,
                                label: 'View Receipt',
                                color: isPdf ? DT.danger : DT.primary,
                                softColor: isPdf ? DT.dangerSoft : DT.primarySoft,
                                onTap: onViewReceipt,
                              ),
                            ),
                          if (isAdmin) ...[
                            if (payment.receiptUrl != null) const SizedBox(width: DS.sm),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete',
                                color: DT.danger,
                                softColor: DT.dangerSoft,
                                onTap: onDelete,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color softColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.softColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.md, vertical: 10),
        decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(DS.sm)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: DS.xs + 2),
            Text(label,
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onRetry;

  const _EmptyState({this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isFiltered = onRetry != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(DS.xxl),
            decoration: const BoxDecoration(color: DT.primarySoft, shape: BoxShape.circle),
            child: Icon(
              isFiltered ? Icons.filter_list_off_rounded : Icons.receipt_long_rounded,
              size: 48, color: DT.textTertiary,
            ),
          ),
          const SizedBox(height: DS.lg),
          Text(
            isFiltered ? 'No payments match filters' : 'No payments yet',
            style: GoogleFonts.manrope(
                fontSize: 16, fontWeight: FontWeight.w600, color: DT.textSecondary),
          ),
          const SizedBox(height: DS.xs),
          Text(
            isFiltered ? 'Try adjusting your filters' : 'Payment records will appear here',
            style: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
          ),
          if (isFiltered) ...[
            const SizedBox(height: DS.lg),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: Text('Clear Filters',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(foregroundColor: DT.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DT.textTertiary),
        const SizedBox(width: DS.md),
        Expanded(
          child: Text(label,
              style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
        ),
        Flexible(
          child: Text(value,
              style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w600, color: DT.text),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoLine(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: DT.textSecondary),
      const SizedBox(width: DS.xs + 2),
      Text(text,
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}
