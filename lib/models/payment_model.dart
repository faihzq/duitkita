import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final double amount;
  final DateTime paymentDate;
  final int month;
  final int year;
  final String? notes;
  final String? receiptUrl;
  final DateTime createdAt;
  final String paymentMethod; // 'cash', 'duitnow', 'online_banking'
  final String paymentStatus; // 'pending', 'confirmed', 'rejected'
  final String? recipientPhone; // For DuitNow payments
  final String? transactionReference; // Reference number
  final String? verifiedBy; // Admin userId who verified
  final String? verifiedByName; // Admin name
  final DateTime? verifiedAt; // When verified
  final String? rejectionReason; // Reason for rejection

  PaymentModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.paymentDate,
    required this.month,
    required this.year,
    this.notes,
    this.receiptUrl,
    required this.createdAt,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'pending',
    this.recipientPhone,
    this.transactionReference,
    this.verifiedBy,
    this.verifiedByName,
    this.verifiedAt,
    this.rejectionReason,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> data, String id) {
    return PaymentModel(
      id: id,
      groupId: data['groupId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      paymentDate:
          data['paymentDate'] != null
              ? (data['paymentDate'] as Timestamp).toDate()
              : DateTime.now(),
      month: (data['month'] as int?) ?? DateTime.now().month,
      year: (data['year'] as int?) ?? DateTime.now().year,
      notes: data['notes'],
      receiptUrl: data['receiptUrl'],
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      recipientPhone: data['recipientPhone'],
      transactionReference: data['transactionReference'],
      verifiedBy: data['verifiedBy'],
      verifiedByName: data['verifiedByName'],
      verifiedAt: data['verifiedAt'] != null
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'paymentDate': paymentDate,
      'month': month,
      'year': year,
      'notes': notes,
      'receiptUrl': receiptUrl,
      'createdAt': createdAt,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'recipientPhone': recipientPhone,
      'transactionReference': transactionReference,
      'verifiedBy': verifiedBy,
      'verifiedByName': verifiedByName,
      'verifiedAt': verifiedAt,
      'rejectionReason': rejectionReason,
    };
  }

}
