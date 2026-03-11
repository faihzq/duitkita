import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  final String groupId;

  const PaymentHistoryScreen({Key? key, required this.groupId})
    : super(key: key);

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  String? _selectedMemberId;
  String? _selectedMemberName;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  bool _isPdfUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.pdf') ||
        lowerUrl.contains('application/pdf') ||
        lowerUrl.contains('%2Fpdf');
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

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _selectedMemberId = null;
      _selectedMemberName = null;
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      builder: (context, child) {
        return Theme(
          data: AppTheme.theme.copyWith(
            colorScheme: AppTheme.theme.colorScheme.copyWith(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final paymentsAsync = ref.watch(
      groupPaymentsStreamProvider(widget.groupId),
    );
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: paymentsAsync.when(
        data: (allPayments) {
          if (allPayments.isEmpty) {
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
                  const Text('No payments yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  const Text('Payment records will appear here',
                    style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
            );
          }

          // Check if current user is admin
          final isAdmin = membersAsync.whenOrNull(
            data: (members) => members.any((m) => m.userId == userId && m.isAdmin),
          ) ?? false;

          final payments = _applyFilters(allPayments);

          // Get unique members from all payments for filter
          final membersList = membersAsync.whenOrNull(
            data: (members) => members,
          ) ?? [];

          return Column(
            children: [
              // Filter bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Date filter chip
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDateRange,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: _filterStartDate != null
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 16,
                                    color: _filterStartDate != null
                                        ? AppTheme.primary
                                        : Colors.white.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _filterStartDate != null
                                          ? '${_filterStartDate!.day}/${_filterStartDate!.month} - ${_filterEndDate!.day}/${_filterEndDate!.month}'
                                          : 'Date Range',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _filterStartDate != null
                                            ? AppTheme.primary
                                            : Colors.white.withValues(alpha: 0.85),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_filterStartDate != null)
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _filterStartDate = null;
                                        _filterEndDate = null;
                                      }),
                                      child: const Icon(Icons.close, size: 16, color: AppTheme.textHint),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Member filter chip
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showMemberPicker(membersList),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedMemberId != null
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 16,
                                    color: _selectedMemberId != null
                                        ? AppTheme.primary
                                        : Colors.white.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedMemberName ?? 'Member',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedMemberId != null
                                            ? AppTheme.primary
                                            : Colors.white.withValues(alpha: 0.85),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_selectedMemberId != null)
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _selectedMemberId = null;
                                        _selectedMemberName = null;
                                      }),
                                      child: const Icon(Icons.close, size: 16, color: AppTheme.textHint),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Clear all button
                        if (_hasFilters) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _clearFilters,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.filter_alt_off, size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Results count
                    if (_hasFilters) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${payments.length} of ${allPayments.length} payments',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Payment list
              Expanded(
                child: payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_list_off, size: 48, color: AppTheme.textHint.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text('No payments match filters',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.filter_alt_off, size: 16),
                              label: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              final isPdf = payment.receiptUrl != null && _isPdfUrl(payment.receiptUrl!);
              final isFirst = index == 0;
              final isLast = index == payments.length - 1;

              // Check if this is the first payment of a new month
              final isNewMonth = index == 0 ||
                  payment.monthYearKey != payments[index - 1].monthYearKey;

              return Column(
                children: [
                  // Month header if new month
                  if (isNewMonth) ...[
                    if (index > 0) const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _getMonthYearLabel(payment.monthYearKey),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Timeline item
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline indicator column
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              // Top line
                              if (!isFirst && !isNewMonth)
                                Container(
                                  width: 2,
                                  height: 12,
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                ),
                              if (isFirst || isNewMonth)
                                const SizedBox(height: 12),

                              // Circle dot
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primary,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),

                              // Bottom line
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Payment card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showPaymentDetail(context, payment),
                            child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: AppTheme.cardShadow,
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.successGradient,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          payment.userName.isNotEmpty
                                              ? payment.userName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Name and date
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            payment.userName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 12,
                                                color: AppTheme.textHint,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textHint,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Amount + status
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: payment.paymentStatus == 'confirmed'
                                                ? AppTheme.success.withValues(alpha: 0.1)
                                                : payment.paymentStatus == 'pending'
                                                    ? const Color(0xFFFFF3E0)
                                                    : AppTheme.error.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'RM${payment.amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: payment.paymentStatus == 'confirmed'
                                                  ? AppTheme.success
                                                  : payment.paymentStatus == 'pending'
                                                      ? const Color(0xFFF57C00)
                                                      : AppTheme.error,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: payment.paymentStatus == 'confirmed'
                                                ? AppTheme.success.withValues(alpha: 0.1)
                                                : payment.paymentStatus == 'pending'
                                                    ? const Color(0xFFFFF3E0)
                                                    : AppTheme.error.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            payment.paymentStatus == 'confirmed'
                                                ? 'Confirmed'
                                                : payment.paymentStatus == 'pending'
                                                    ? 'Pending'
                                                    : 'Rejected',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: payment.paymentStatus == 'confirmed'
                                                  ? AppTheme.success
                                                  : payment.paymentStatus == 'pending'
                                                      ? const Color(0xFFF57C00)
                                                      : AppTheme.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Notes
                                if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.note_outlined,
                                          size: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            payment.notes!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Rejection reason
                                if (payment.paymentStatus == 'rejected' &&
                                    payment.rejectionReason != null &&
                                    payment.rejectionReason!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: AppTheme.error,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Rejected: ${payment.rejectionReason}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.error,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Actions row
                                if (payment.receiptUrl != null || isAdmin) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Receipt button
                                      if (payment.receiptUrl != null) ...[
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              if (isPdf) {
                                                _openPdfReceipt(context, payment.receiptUrl!);
                                              } else {
                                                _showReceiptImage(context, payment.receiptUrl!);
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isPdf
                                                    ? AppTheme.error.withValues(alpha: 0.1)
                                                    : AppTheme.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isPdf ? Icons.picture_as_pdf : Icons.receipt,
                                                    size: 16,
                                                    color: isPdf ? AppTheme.error : AppTheme.primary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'View Receipt',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: isPdf ? AppTheme.error : AppTheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],

                                      // Delete button (admin only)
                                      if (isAdmin) ...[
                                        if (payment.receiptUrl != null) const SizedBox(width: 8),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _deletePayment(context, payment),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.error.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.delete_outline,
                                                    size: 16,
                                                    color: AppTheme.error,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.error,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
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
                  ),
                ],
              );
            },
          ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 16),
                Text('Error loading payments: $error',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(groupPaymentsStreamProvider(widget.groupId)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentDetail(BuildContext context, PaymentModel payment) {
    final isPdf = payment.receiptUrl != null && _isPdfUrl(payment.receiptUrl!);
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final methodLabels = {
      'cash': 'Cash',
      'duitnow': 'DuitNow',
      'online_banking': 'Online Banking',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: payment.paymentStatus == 'confirmed'
                                ? AppTheme.successGradient
                                : payment.paymentStatus == 'pending'
                                    ? const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFF57C00)])
                                    : const LinearGradient(colors: [Color(0xFFEF5350), Color(0xFFC62828)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              payment.userName.isNotEmpty ? payment.userName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(payment.userName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: payment.paymentStatus == 'confirmed'
                                      ? AppTheme.success.withValues(alpha: 0.1)
                                      : payment.paymentStatus == 'pending'
                                          ? const Color(0xFFFFF3E0)
                                          : AppTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  payment.paymentStatus == 'confirmed'
                                      ? 'Confirmed'
                                      : payment.paymentStatus == 'pending'
                                          ? 'Pending'
                                          : 'Rejected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: payment.paymentStatus == 'confirmed'
                                        ? AppTheme.success
                                        : payment.paymentStatus == 'pending'
                                            ? const Color(0xFFF57C00)
                                            : AppTheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'RM${payment.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Details card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _detailRow(Icons.calendar_month, 'Payment For', '${monthNames[payment.month - 1]} ${payment.year}'),
                          const Divider(height: 24),
                          _detailRow(Icons.access_time, 'Payment Date', '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}'),
                          const Divider(height: 24),
                          _detailRow(Icons.payment, 'Method', methodLabels[payment.paymentMethod] ?? payment.paymentMethod),
                          if (payment.transactionReference != null && payment.transactionReference!.isNotEmpty) ...[
                            const Divider(height: 24),
                            _detailRow(Icons.tag, 'Reference', payment.transactionReference!),
                          ],
                          if (payment.recipientPhone != null && payment.recipientPhone!.isNotEmpty) ...[
                            const Divider(height: 24),
                            _detailRow(Icons.phone, 'Recipient', payment.recipientPhone!),
                          ],
                          const Divider(height: 24),
                          _detailRow(Icons.schedule, 'Submitted', '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year} ${payment.createdAt.hour.toString().padLeft(2, '0')}:${payment.createdAt.minute.toString().padLeft(2, '0')}'),
                        ],
                      ),
                    ),

                    // Notes
                    if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.note_outlined, size: 16, color: AppTheme.textSecondary),
                                SizedBox(width: 8),
                                Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(payment.notes!, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ],

                    // Verification info
                    if (payment.verifiedByName != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: payment.paymentStatus == 'confirmed'
                              ? AppTheme.success.withValues(alpha: 0.08)
                              : AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: payment.paymentStatus == 'confirmed'
                                ? AppTheme.success.withValues(alpha: 0.2)
                                : AppTheme.error.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  payment.paymentStatus == 'confirmed' ? Icons.verified : Icons.cancel,
                                  size: 16,
                                  color: payment.paymentStatus == 'confirmed' ? AppTheme.success : AppTheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  payment.paymentStatus == 'confirmed' ? 'Verified by' : 'Rejected by',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: payment.paymentStatus == 'confirmed' ? AppTheme.success : AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(payment.verifiedByName!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            if (payment.verifiedAt != null)
                              Text(
                                '${payment.verifiedAt!.day}/${payment.verifiedAt!.month}/${payment.verifiedAt!.year} ${payment.verifiedAt!.hour.toString().padLeft(2, '0')}:${payment.verifiedAt!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // Rejection reason
                    if (payment.paymentStatus == 'rejected' &&
                        payment.rejectionReason != null &&
                        payment.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: AppTheme.error),
                                SizedBox(width: 8),
                                Text('Rejection Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.error)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(payment.rejectionReason!, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ],

                    // Receipt button
                    if (payment.receiptUrl != null) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (isPdf) {
                              _openPdfReceipt(context, payment.receiptUrl!);
                            } else {
                              _showReceiptImage(context, payment.receiptUrl!);
                            }
                          },
                          icon: Icon(isPdf ? Icons.picture_as_pdf : Icons.receipt, size: 18),
                          label: Text(isPdf ? 'View PDF Receipt' : 'View Receipt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textHint),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Flexible(
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), textAlign: TextAlign.end),
        ),
      ],
    );
  }

  void _showMemberPicker(List<GroupMember> members) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Filter by Member',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ),
              // All members option
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_outline, color: AppTheme.primary, size: 20),
                ),
                title: const Text('All Members', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _selectedMemberId == null
                    ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 22)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedMemberId = null;
                    _selectedMemberName = null;
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              ...members.map((member) => ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                title: Text(member.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: member.isAdmin
                    ? const Text('Admin', style: TextStyle(fontSize: 12, color: AppTheme.primary))
                    : null,
                trailing: _selectedMemberId == member.userId
                    ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 22)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedMemberId = member.userId;
                    _selectedMemberName = member.userName;
                  });
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPdfReceipt(BuildContext context, String pdfUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text('Downloading receipt...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/receipt_$timestamp.pdf');
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;
        nav.pop();

        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done && mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not open PDF: ${result.message}'), backgroundColor: AppTheme.error),
          );
        }
      } else {
        if (mounted) {
          nav.pop();
          messenger.showSnackBar(
            const SnackBar(content: Text('Failed to download receipt'), backgroundColor: AppTheme.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(content: Text('Error opening receipt: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showReceiptImage(BuildContext context, String receiptUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusMedium),
                  topRight: Radius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
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
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(50.0),
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(50.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppTheme.error.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text('Failed to load receipt',
                              style: TextStyle(color: AppTheme.textHint)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthYearLabel(String key) {
    final parts = key.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return '${months[month - 1]} $year';
  }

  Future<void> _deletePayment(BuildContext context, PaymentModel payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever, color: AppTheme.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Delete Payment')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this payment?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        payment.userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'RM${payment.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.error),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.deletePaymentWithStats(
        paymentId: payment.id,
        groupId: payment.groupId,
        userId: payment.userId,
        amount: payment.amount,
      );

      if (mounted) {
        showSnackBar(context, 'Payment deleted successfully');
        // Refresh the list
        ref.invalidate(groupPaymentsStreamProvider(widget.groupId));
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to delete payment: $e', isError: true);
      }
    }
  }
}
