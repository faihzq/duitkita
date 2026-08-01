import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? name;
  final String? email;
  final String? phoneNumber;

  /// Lowercase handle, unique across accounts. The `usernames` collection is
  /// what actually enforces that; this is the readable copy.
  final String? username;
  final String? profileImageUrl;
  final bool showJdtMatches;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.uid,
    this.name,
    this.email,
    this.phoneNumber,
    this.username,
    this.profileImageUrl,
    this.showJdtMatches = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create a profile from Firebase data
  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      name: data['name'],
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      username: data['username'],
      profileImageUrl: data['profileImageUrl'],
      showJdtMatches: data['showJdtMatches'] ?? false,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  // Convert profile to a map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'showJdtMatches': showJdtMatches,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create a copy of the profile with some fields updated
  UserProfile copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? username,
    String? profileImageUrl,
    bool? showJdtMatches,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      showJdtMatches: showJdtMatches ?? this.showJdtMatches,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
