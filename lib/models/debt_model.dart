import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DebtCategory {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const DebtCategory({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class DebtModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String creditor;
  final double totalAmount;
  final double monthlyPayment;
  final double totalPaid;
  final DateTime startDate;
  final int dueDay;
  final String category; // car, personal, housing, education, other
  final String type; // 'debt' or 'bill'
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isBill => type == 'bill';
  bool get isDebt => type == 'debt';

  DebtModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.creditor,
    required this.totalAmount,
    required this.monthlyPayment,
    this.totalPaid = 0,
    required this.startDate,
    this.dueDay = 1,
    this.category = 'other',
    this.type = 'debt',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remainingBalance => isBill ? 0 : (totalAmount - totalPaid).clamp(0, totalAmount);
  double get progressPercent => isBill ? 0 : (totalAmount > 0 ? (totalPaid / totalAmount).clamp(0, 1) : 0);
  int get estimatedTotalMonths => isBill ? 0 : (monthlyPayment > 0 ? (totalAmount / monthlyPayment).ceil() : 0);
  int get monthsRemaining => isBill ? 0 : (monthlyPayment > 0 ? (remainingBalance / monthlyPayment).ceil() : 0);

  DateTime get estimatedPayoffDate {
    if (monthlyPayment <= 0) return startDate;
    return DateTime(
      DateTime.now().year,
      DateTime.now().month + monthsRemaining,
    );
  }

  // ── Centralized category definitions ──

  static const debtCategories = [
    DebtCategory(value: 'car', label: 'Car', icon: Icons.directions_car_outlined, color: Color(0xFF1565C0)),
    DebtCategory(value: 'personal', label: 'Personal', icon: Icons.person_outline, color: Color(0xFF7B1FA2)),
    DebtCategory(value: 'housing', label: 'Housing', icon: Icons.home_outlined, color: Color(0xFFE65100)),
    DebtCategory(value: 'education', label: 'Education', icon: Icons.school_outlined, color: Color(0xFF00897B)),
    DebtCategory(value: 'other', label: 'Other', icon: Icons.receipt_long_outlined, color: Color(0xFF546E7A)),
  ];

  static const billCategories = [
    DebtCategory(value: 'internet', label: 'Internet', icon: Icons.wifi_outlined, color: Color(0xFF1565C0)),
    DebtCategory(value: 'phone', label: 'Phone', icon: Icons.phone_android_outlined, color: Color(0xFF00897B)),
    DebtCategory(value: 'streaming', label: 'Streaming', icon: Icons.tv_outlined, color: Color(0xFFE65100)),
    DebtCategory(value: 'insurance', label: 'Insurance', icon: Icons.shield_outlined, color: Color(0xFF7B1FA2)),
    DebtCategory(value: 'utilities', label: 'Utilities', icon: Icons.bolt_outlined, color: Color(0xFFC62828)),
    DebtCategory(value: 'subscription', label: 'Subscription', icon: Icons.autorenew_outlined, color: Color(0xFF00838F)),
    DebtCategory(value: 'other', label: 'Other', icon: Icons.receipt_long_outlined, color: Color(0xFF546E7A)),
  ];

  static List<DebtCategory> categoriesForType(String type) =>
      type == 'bill' ? billCategories : debtCategories;

  static DebtCategory? findCategory(String type, String categoryValue) {
    final list = categoriesForType(type);
    for (final cat in list) {
      if (cat.value == categoryValue) return cat;
    }
    return null;
  }

  DebtCategory get categoryInfo =>
      findCategory(type, category) ??
      DebtCategory(value: 'other', label: 'Other', icon: Icons.receipt_long_outlined, color: const Color(0xFF546E7A));

  static String categoryLabel(String category) {
    for (final cat in [...debtCategories, ...billCategories]) {
      if (cat.value == category) return cat.label;
    }
    return 'Other';
  }

  factory DebtModel.fromMap(Map<String, dynamic> data, String id) {
    return DebtModel(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      creditor: data['creditor'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      monthlyPayment: (data['monthlyPayment'] ?? 0.0).toDouble(),
      totalPaid: (data['totalPaid'] ?? 0.0).toDouble(),
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      dueDay: (data['dueDay'] as int?) ?? 1,
      category: data['category'] ?? 'other',
      type: data['type'] ?? 'debt',
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'creditor': creditor,
      'totalAmount': totalAmount,
      'monthlyPayment': monthlyPayment,
      'totalPaid': totalPaid,
      'startDate': startDate,
      'dueDay': dueDay,
      'category': category,
      'type': type,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  DebtModel copyWith({
    String? title,
    String? description,
    String? creditor,
    double? totalAmount,
    double? monthlyPayment,
    double? totalPaid,
    DateTime? startDate,
    int? dueDay,
    String? category,
    String? type,
    bool? isActive,
  }) {
    return DebtModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      creditor: creditor ?? this.creditor,
      totalAmount: totalAmount ?? this.totalAmount,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      totalPaid: totalPaid ?? this.totalPaid,
      startDate: startDate ?? this.startDate,
      dueDay: dueDay ?? this.dueDay,
      category: category ?? this.category,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
