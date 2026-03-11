import 'package:flutter_riverpod/flutter_riverpod.dart';

final duitnowServiceProvider = Provider<DuitNowService>((ref) {
  return DuitNowService();
});

class DuitNowService {
  /// Generate DuitNow QR code data
  ///
  /// Parameters:
  /// - [recipientId]: Phone number (e.g., 60123456789) or DuitNow ID
  /// - [amount]: Payment amount in RM
  /// - [recipientName]: Name of the person receiving payment
  /// - [note]: Optional payment note/reference
  String generateDuitNowQR({
    required String recipientId,
    required double amount,
    required String recipientName,
    String? note,
  }) {
    // For DuitNow QR, we'll use a simplified format
    // In production, you'd want to use the full EMVCo standard

    // Format: DUITNOW|ID|AMOUNT|NAME|NOTE
    final qrData = [
      'DUITNOW',
      recipientId,
      amount.toStringAsFixed(2),
      recipientName,
      note ?? '',
    ].join('|');

    return qrData;
  }

  /// Generate a more detailed DuitNow QR string following EMVCo-like format
  String generateDetailedDuitNowQR({
    required String recipientId,
    required double amount,
    required String recipientName,
    String? note,
  }) {
    // This is a simplified EMVCo-style format
    // Actual DuitNow QR uses more complex encoding

    final buffer = StringBuffer();

    // Payload Format Indicator
    buffer.write('00020101');

    // Point of Initiation Method (11 = static, 12 = dynamic)
    buffer.write('010212');

    // Merchant Account Information - DuitNow
    // Tag 26: Merchant Account Information
    final merchantInfo = '0016MY.DUITNOW.MOBILE01${recipientId.length.toString().padLeft(2, '0')}$recipientId';
    buffer.write('26${merchantInfo.length.toString().padLeft(2, '0')}$merchantInfo');

    // Transaction Currency (458 = MYR)
    buffer.write('5303458');

    // Transaction Amount
    final amountStr = amount.toStringAsFixed(2);
    buffer.write('54${amountStr.length.toString().padLeft(2, '0')}$amountStr');

    // Country Code
    buffer.write('5802MY');

    // Merchant Name
    final nameLength = recipientName.length.toString().padLeft(2, '0');
    buffer.write('59$nameLength$recipientName');

    // Additional Data (note/reference)
    if (note != null && note.isNotEmpty) {
      final noteData = '01${note.length.toString().padLeft(2, '0')}$note';
      buffer.write('62${noteData.length.toString().padLeft(2, '0')}$noteData');
    }

    // CRC (simplified - would need proper CRC-16 calculation in production)
    buffer.write('6304');

    return buffer.toString();
  }

  /// Parse DuitNow QR data
  Map<String, dynamic>? parseDuitNowQR(String qrData) {
    try {
      if (qrData.startsWith('DUITNOW|')) {
        final parts = qrData.split('|');
        if (parts.length >= 4) {
          return {
            'recipientId': parts[1],
            'amount': double.tryParse(parts[2]) ?? 0.0,
            'recipientName': parts[3],
            'note': parts.length > 4 ? parts[4] : null,
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Validate Malaysian phone number for DuitNow
  bool isValidMalaysianPhone(String phone) {
    // Remove spaces and dashes
    final cleaned = phone.replaceAll(RegExp(r'[\s-]'), '');

    // Check if it starts with 60 or +60 (Malaysia country code)
    if (cleaned.startsWith('+60')) {
      return cleaned.length == 12 || cleaned.length == 13;
    } else if (cleaned.startsWith('60')) {
      return cleaned.length == 11 || cleaned.length == 12;
    } else if (cleaned.startsWith('0')) {
      // Local format (0xx-xxxxxxx)
      return cleaned.length == 10 || cleaned.length == 11;
    }

    return false;
  }

  /// Format phone number for DuitNow (convert to international format)
  String formatPhoneForDuitNow(String phone) {
    // Remove spaces and dashes
    var cleaned = phone.replaceAll(RegExp(r'[\s-]'), '');

    // Remove + if present
    cleaned = cleaned.replaceAll('+', '');

    // Convert local format (0xx) to international (60xx)
    if (cleaned.startsWith('0')) {
      cleaned = '60${cleaned.substring(1)}';
    }

    // Ensure it starts with 60
    if (!cleaned.startsWith('60')) {
      cleaned = '60$cleaned';
    }

    return cleaned;
  }
}
