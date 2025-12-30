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
  final DateTime createdAt;

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
    required this.createdAt,
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
      month: data['month'] ?? DateTime.now().month,
      year: data['year'] ?? DateTime.now().year,
      notes: data['notes'],
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
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
      'createdAt': createdAt,
    };
  }

  String get monthYearKey => '$year-${month.toString().padLeft(2, '0')}';
}
