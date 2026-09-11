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

  /// Push reminders for the fixtures of every team the tab follows — JDT and
  /// Malaysia. Separate from [showJdtMatches] because wanting the tab and
  /// wanting to be woken by it are different wishes; the scheduled reminder
  /// function reads this field alone.
  ///
  /// The name still says Jdt because renaming the stored field would silently
  /// reset the preference for everyone who has already turned it on.
  final bool notifyJdtMatches;
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
    this.notifyJdtMatches = false,
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
      notifyJdtMatches: data['notifyJdtMatches'] ?? false,
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
      'notifyJdtMatches': notifyJdtMatches,
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
    bool? notifyJdtMatches,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      showJdtMatches: showJdtMatches ?? this.showJdtMatches,
      notifyJdtMatches: notifyJdtMatches ?? this.notifyJdtMatches,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
