import 'package:cloud_firestore/cloud_firestore.dart';

class DebtPaymentModel {
  final String id;
  final String debtId;
  final double amount;
  final DateTime paymentDate;
  final int month;
  final int year;
  final String? notes;
  final DateTime createdAt;

  DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    required this.month,
    required this.year,
    this.notes,
    required this.createdAt,
  });

  factory DebtPaymentModel.fromMap(Map<String, dynamic> data, String id) {
    return DebtPaymentModel(
      id: id,
      debtId: data['debtId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      paymentDate: data['paymentDate'] != null
          ? (data['paymentDate'] as Timestamp).toDate()
          : DateTime.now(),
      month: (data['month'] as int?) ?? 1,
      year: (data['year'] as int?) ?? DateTime.now().year,
      notes: data['notes'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'debtId': debtId,
      'amount': amount,
      'paymentDate': paymentDate,
      'month': month,
      'year': year,
      'notes': notes,
      'createdAt': createdAt,
    };
  }
}
