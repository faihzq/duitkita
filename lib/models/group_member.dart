import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMember {
  final String userId;
  final String userName;
  final String? userEmail;
  final bool isAdmin;
  final DateTime joinedAt;
  final double totalPaid;
  final int paymentCount;

  GroupMember({
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.isAdmin,
    required this.joinedAt,
    required this.totalPaid,
    required this.paymentCount,
  });

  factory GroupMember.fromMap(Map<String, dynamic> data) {
    return GroupMember(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'],
      isAdmin: data['isAdmin'] ?? false,
      joinedAt:
          data['joinedAt'] != null
              ? (data['joinedAt'] as Timestamp).toDate()
              : DateTime.now(),
      totalPaid: (data['totalPaid'] ?? 0.0).toDouble(),
      paymentCount: data['paymentCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'isAdmin': isAdmin,
      'joinedAt': joinedAt,
      'totalPaid': totalPaid,
      'paymentCount': paymentCount,
    };
  }

  GroupMember copyWith({
    String? userName,
    String? userEmail,
    bool? isAdmin,
    double? totalPaid,
    int? paymentCount,
  }) {
    return GroupMember(
      userId: userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      isAdmin: isAdmin ?? this.isAdmin,
      joinedAt: joinedAt,
      totalPaid: totalPaid ?? this.totalPaid,
      paymentCount: paymentCount ?? this.paymentCount,
    );
  }
}
