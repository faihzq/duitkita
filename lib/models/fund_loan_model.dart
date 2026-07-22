import 'package:cloud_firestore/cloud_firestore.dart';

/// A single repayment made against a [FundLoanModel].
class FundLoanRepayment {
  final double amount;
  final DateTime date;
  final String? note;
  final String recordedBy; // uid of admin who recorded it

  FundLoanRepayment({
    required this.amount,
    required this.date,
    this.note,
    this.recordedBy = '',
  });

  factory FundLoanRepayment.fromMap(Map<String, dynamic> data) {
    return FundLoanRepayment(
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      note: data['note'],
      recordedBy: data['recordedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'note': note,
        'recordedBy': recordedBy,
      };
}

/// Money borrowed from a group's fund (tabung) that is repaid over time.
///
/// The outstanding amount ([outstanding]) reduces the group's net balance;
/// each repayment restores the balance. When fully repaid the loan is
/// [settled] and has zero impact on the balance.
class FundLoanModel {
  final String id;
  final String groupId;
  final String borrowerId;
  final String borrowerName;
  final String title; // purpose, e.g. "Wiring"
  final String? note;
  final double principal; // amount borrowed
  final double monthlyRepayment; // planned monthly amount (0 = no plan)
  final List<FundLoanRepayment> repayments;
  final String status; // 'pending' | 'approved' | 'rejected' | 'settled'  ('active' = legacy approved)
  final String createdBy; // requester's uid
  final String createdByName; // requester's name
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  FundLoanModel({
    required this.id,
    required this.groupId,
    required this.borrowerId,
    required this.borrowerName,
    required this.title,
    this.note,
    required this.principal,
    this.monthlyRepayment = 0.0,
    this.repayments = const [],
    this.status = 'pending',
    required this.createdBy,
    required this.createdByName,
    this.approvedByName,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  double get amountRepaid =>
      repayments.fold<double>(0.0, (s, r) => s + r.amount);
  double get outstanding => (principal - amountRepaid).clamp(0.0, principal);
  double get progressPercent =>
      principal > 0 ? (amountRepaid / principal).clamp(0.0, 1.0) : 0.0;
  int get monthsRemaining =>
      monthlyRepayment > 0 ? (outstanding / monthlyRepayment).ceil() : 0;

  // Status helpers. Legacy loans stored 'active' as the approved state.
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get _isApproved => status == 'approved' || status == 'active';
  bool get isSettled => status == 'settled' || (_isApproved && outstanding <= 0.0001);
  bool get isActive => _isApproved && !isSettled; // approved and still owing
  // Only approved/settled loans draw money from the fund balance.
  bool get affectsBalance => _isApproved || status == 'settled';

  factory FundLoanModel.fromMap(Map<String, dynamic> data, String id) {
    return FundLoanModel(
      id: id,
      groupId: data['groupId'] ?? '',
      borrowerId: data['borrowerId'] ?? '',
      borrowerName: data['borrowerName'] ?? '',
      title: data['title'] ?? '',
      note: data['note'],
      principal: (data['principal'] ?? 0.0).toDouble(),
      monthlyRepayment: (data['monthlyRepayment'] ?? 0.0).toDouble(),
      repayments: ((data['repayments'] as List<dynamic>?) ?? [])
          .map((e) => FundLoanRepayment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      status: data['status'] ?? 'pending',
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      approvedByName: data['approvedByName'],
      approvedAt: data['approvedAt'] != null ? (data['approvedAt'] as Timestamp).toDate() : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'borrowerId': borrowerId,
        'borrowerName': borrowerName,
        'title': title,
        'note': note,
        'principal': principal,
        'monthlyRepayment': monthlyRepayment,
        'repayments': repayments.map((r) => r.toMap()).toList(),
        'status': status,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'approvedByName': approvedByName,
        'approvedAt': approvedAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
