import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final double monthlyAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> memberIds;
  final int memberCount;
  final int reminderDay; // Day of month for payment reminder (1-28)
  final String? bankName; // Bank name (e.g., Maybank, CIMB)
  final String? accountNumber; // Bank account number
  final String? accountHolderName; // Name on the bank account
  final bool autoApprovePayments; // Auto-approve payments without admin review
  final bool autoApproveExpenses; // Auto-approve expenses without admin review

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.monthlyAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.memberIds,
    required this.memberCount,
    this.reminderDay = 28,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
    this.autoApprovePayments = false,
    this.autoApproveExpenses = false,
  });

  factory GroupModel.fromMap(Map<String, dynamic> data, String id) {
    return GroupModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      monthlyAmount: (data['monthlyAmount'] ?? 30.0).toDouble(),
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      memberCount: (data['memberCount'] as int?) ?? 0,
      reminderDay: (data['reminderDay'] as int?) ?? 28,
      bankName: data['bankName'],
      accountNumber: data['accountNumber'],
      accountHolderName: data['accountHolderName'],
      autoApprovePayments: data['autoApprovePayments'] ?? false,
      autoApproveExpenses: data['autoApproveExpenses'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'monthlyAmount': monthlyAmount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'memberIds': memberIds,
      'memberCount': memberCount,
      'reminderDay': reminderDay,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolderName': accountHolderName,
      'autoApprovePayments': autoApprovePayments,
      'autoApproveExpenses': autoApproveExpenses,
    };
  }

  GroupModel copyWith({
    String? name,
    String? description,
    double? monthlyAmount,
    List<String>? memberIds,
    int? memberCount,
    int? reminderDay,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
    bool? autoApprovePayments,
    bool? autoApproveExpenses,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      memberIds: memberIds ?? this.memberIds,
      memberCount: memberCount ?? this.memberCount,
      reminderDay: reminderDay ?? this.reminderDay,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      autoApprovePayments: autoApprovePayments ?? this.autoApprovePayments,
      autoApproveExpenses: autoApproveExpenses ?? this.autoApproveExpenses,
    );
  }
}
