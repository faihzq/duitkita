import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseStatus { pending, approved, rejected }

class ExpenseModel {
  final String id;
  final String groupId;
  final String requestedBy;
  final String requestedByName;
  final String title;
  final String? description;
  final double amount;
  final ExpenseStatus status;
  final String? receiptUrl;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final String? rejectedByName;
  final DateTime? rejectedAt;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.requestedBy,
    required this.requestedByName,
    required this.title,
    this.description,
    required this.amount,
    required this.status,
    this.receiptUrl,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedByName,
    this.rejectedAt,
    required this.createdAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> data, String id) {
    return ExpenseModel(
      id: id,
      groupId: data['groupId'] ?? '',
      requestedBy: data['requestedBy'] ?? '',
      requestedByName: data['requestedByName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      amount: (data['amount'] ?? 0.0).toDouble(),
      status: ExpenseStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ExpenseStatus.pending,
      ),
      receiptUrl: data['receiptUrl'],
      approvedBy: data['approvedBy'],
      approvedByName: data['approvedByName'],
      approvedAt:
          data['approvedAt'] != null
              ? (data['approvedAt'] as Timestamp).toDate()
              : null,
      rejectedBy: data['rejectedBy'],
      rejectedByName: data['rejectedByName'],
      rejectedAt:
          data['rejectedAt'] != null
              ? (data['rejectedAt'] as Timestamp).toDate()
              : null,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'title': title,
      'description': description,
      'amount': amount,
      'status': status.name,
      'receiptUrl': receiptUrl,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt,
      'rejectedBy': rejectedBy,
      'rejectedByName': rejectedByName,
      'rejectedAt': rejectedAt,
      'createdAt': createdAt,
    };
  }
}
