import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

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
    extends ConsumerState<PendingPaymentsReviewScreen> {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

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

    final userId =
        ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    setState(() => _isProcessing = true);
    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);
      final paymentService = ref.read(paymentServiceProvider);

      final count = await paymentService.batchVerifyPayments(
        paymentIds: _selectedIds.toList(),
        status: status,
        verifiedBy: userId,
        verifiedByName: profile?.name ?? 'Admin',
        rejectionReason: rejectionReason,
      );

      if (!mounted) return;
      final action = status == 'confirmed' ? 'confirmed' : 'rejected';
      showSnackBar(context, '$count payment${count > 1 ? 's' : ''} $action');
      _selectedIds.clear();
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showBatchRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, color: AppTheme.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reject ${_selectedIds.length} Payment${_selectedIds.length > 1 ? 's' : ''}?',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Provide a reason for rejection (optional):',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Wrong amount, invalid receipt...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _batchAction('rejected', rejectionReason: reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingPaymentsStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Review Payments'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header with select all
          pendingAsync.when(
            data: (payments) {
              if (payments.isEmpty) return const SizedBox.shrink();
              final allSelected = _selectedIds.length == payments.length && payments.isNotEmpty;
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleSelectAll(payments),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: allSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 18,
                              color: allSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              allSelected ? 'Deselect All' : 'Select All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: allSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_selectedIds.length}/${payments.length} selected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Payment list
          Expanded(
            child: pendingAsync.when(
              data: (payments) {
                // Remove selections that are no longer in the list
                _selectedIds.removeWhere((id) => !payments.any((p) => p.id == id));

                if (payments.isEmpty) {
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
                          child: const Icon(Icons.check_circle_outline, size: 48, color: AppTheme.success),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No pending payments',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All payments have been reviewed',
                          style: TextStyle(fontSize: 13, color: AppTheme.textHint),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    final isSelected = _selectedIds.contains(payment.id);
                    return _buildPaymentCard(payment, isSelected);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $error', style: const TextStyle(color: AppTheme.error)),
                ),
              ),
            ),
          ),
        ],
      ),

      // Bottom action bar
      bottomNavigationBar: _selectedIds.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _showBatchRejectDialog,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: Text(
                          'Reject (${_selectedIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.error,
                          elevation: 0,
                          side: const BorderSide(color: AppTheme.error, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _batchAction('confirmed'),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          'Confirm (${_selectedIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.rate_review_outlined, color: Color(0xFFFFA726), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Details',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'By ${payment.userName}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(modalContext),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade200),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Payment Amount',
                            style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'RM${payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Payment details
                    _buildDetailRow(Icons.calendar_today_outlined, 'Payment Date', dateStr),
                    _buildDetailRow(Icons.payment_outlined, 'Payment Method', methodLabel),
                    _buildDetailRow(Icons.date_range_outlined, 'For Month', '${_getMonthName(payment.month)} ${payment.year}'),
                    if (payment.transactionReference != null && payment.transactionReference!.isNotEmpty)
                      _buildDetailRow(Icons.tag, 'Reference', payment.transactionReference!),
                    if (payment.notes != null && payment.notes!.isNotEmpty)
                      _buildDetailRow(Icons.notes_outlined, 'Notes', payment.notes!),

                    // Receipt image
                    if (payment.receiptUrl != null && payment.receiptUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Receipt',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          payment.receiptUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, color: AppTheme.textHint, size: 32),
                                  SizedBox(height: 4),
                                  Text('Failed to load receipt', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // No receipt notice
                    if (payment.receiptUrl == null || payment.receiptUrl!.isEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE0B2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No receipt uploaded for this payment',
                                style: TextStyle(fontSize: 13, color: Color(0xFFF57C00), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Select / deselect button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
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
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppTheme.primary : Colors.white,
                          foregroundColor: isSelected ? Colors.white : AppTheme.primary,
                          elevation: 0,
                          side: isSelected ? null : const BorderSide(color: AppTheme.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
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

  Widget _buildPaymentCard(PaymentModel payment, bool isSelected) {
    final methodLabel = switch (payment.paymentMethod) {
      'duitnow' => 'DuitNow',
      'online_banking' => 'Online Banking',
      'cash' => 'Cash',
      _ => payment.paymentMethod,
    };
    final dateStr =
        '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}';

    return GestureDetector(
      onTap: () => _showPaymentDetailModal(payment),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.4) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Checkbox - tap to toggle selection
              GestureDetector(
                onTap: () => _toggleSelection(payment.id),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.textHint.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              ),

              // Receipt indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: payment.receiptUrl != null
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  payment.receiptUrl != null ? Icons.receipt_long : Icons.receipt_long_outlined,
                  color: payment.receiptUrl != null ? AppTheme.success : AppTheme.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.userName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$methodLabel  -  $dateStr',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                    ),
                    if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        payment.notes!,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Amount
              Text(
                'RM${payment.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
