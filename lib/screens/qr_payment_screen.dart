import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/services/duitnow_service.dart';
import 'package:duitkita/utils/utils.dart';

class QrPaymentScreen extends StatelessWidget {
  final String recipientName;
  final String recipientPhone;
  final double amount;
  final String? notes;
  final VoidCallback? onPaymentMarkedAsPaid;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;

  const QrPaymentScreen({
    Key? key,
    required this.recipientName,
    required this.recipientPhone,
    required this.amount,
    this.notes,
    this.onPaymentMarkedAsPaid,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final duitnowService = DuitNowService();
    final formattedPhone = duitnowService.formatPhoneForDuitNow(recipientPhone);

    // Generate QR data
    final qrData = duitnowService.generateDuitNowQR(
      recipientId: formattedPhone,
      amount: amount,
      recipientName: recipientName,
      note: notes,
    );

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Pay with DuitNow'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Payment Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Amount',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.person_outline, 'Pay to', recipientName),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.phone_outlined, 'Phone', formattedPhone),
                  if (notes != null && notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.note_outlined, 'Note', notes!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bank Account Card (if available)
            if (bankName != null && accountNumber != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bank Transfer Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Transfer to this account',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 16),

                    // Bank Name
                    _buildBankInfoRow('Bank', bankName!, Icons.account_balance),
                    const SizedBox(height: 12),

                    // Account Number with copy button
                    Row(
                      children: [
                        Expanded(
                          child: _buildBankInfoRow('Account Number', accountNumber!, Icons.numbers),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: accountNumber!));
                              showSnackBar(context, 'Account number copied');
                            },
                            icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                            tooltip: 'Copy account number',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Account Holder Name
                    if (accountHolderName != null)
                      _buildBankInfoRow('Account Holder', accountHolderName!, Icons.person),
                  ],
                ),
              ),

            if (bankName != null && accountNumber != null) const SizedBox(height: 32),

            // QR Code Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Text(
                    bankName != null && accountNumber != null ? 'DuitNow QR Code' : 'Scan QR Code',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bankName != null && accountNumber != null
                        ? 'Alternative: Scan with your banking app'
                        : 'Use your banking app to scan',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                      errorStateBuilder: (context, error) {
                        return const Center(
                          child: Text(
                            'Error generating QR code',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Copy Phone Number Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: formattedPhone));
                      showSnackBar(context, 'Phone number copied');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Phone Number'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        bankName != null && accountNumber != null ? 'Payment Options' : 'How to Pay',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (bankName != null && accountNumber != null) ...[
                    const Text(
                      'Option 1: Bank Transfer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionStep('1', 'Open your banking app'),
                    const SizedBox(height: 8),
                    _buildInstructionStep('2', 'Select "Transfer" or "Pay"'),
                    const SizedBox(height: 8),
                    _buildInstructionStep('3', 'Enter account details shown above'),
                    const SizedBox(height: 8),
                    _buildInstructionStep('4', 'Complete the transfer'),
                    const SizedBox(height: 16),
                    const Text(
                      'Option 2: DuitNow QR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildInstructionStep(bankName != null && accountNumber != null ? '1' : '1', 'Open your banking app (Maybank, CIMB, etc.)'),
                  const SizedBox(height: 8),
                  _buildInstructionStep(bankName != null && accountNumber != null ? '2' : '2', 'Select "DuitNow" or "Scan QR"'),
                  const SizedBox(height: 8),
                  _buildInstructionStep(bankName != null && accountNumber != null ? '3' : '3', 'Scan the QR code ${bankName != null && accountNumber != null ? 'below' : 'above'}'),
                  const SizedBox(height: 8),
                  _buildInstructionStep(bankName != null && accountNumber != null ? '4' : '4', 'Complete the payment'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Mark as Paid Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showConfirmPaymentDialog(context);
                },
                icon: const Icon(Icons.check_circle_outline, size: 22),
                label: const Text(
                  'I\'ve Paid',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Payment will be marked as pending until confirmed by admin',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textHint),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildBankInfoRow(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  void _showConfirmPaymentDialog(BuildContext context) {
    showDialog(
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
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.success, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Confirm Payment'),
          ],
        ),
        content: const Text(
          'Have you completed the payment via DuitNow?\n\nThe payment will be marked as pending until the admin confirms it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Return to previous screen with success
              if (onPaymentMarkedAsPaid != null) {
                onPaymentMarkedAsPaid!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
            ),
            child: const Text('Yes, I\'ve Paid'),
          ),
        ],
      ),
    );
  }
}
