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
      memberCount: data['memberCount'] ?? 0,
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
    };
  }

  GroupModel copyWith({
    String? name,
    String? description,
    double? monthlyAmount,
    List<String>? memberIds,
    int? memberCount,
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
    );
  }
}
