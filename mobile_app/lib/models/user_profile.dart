import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-backed profile stored alongside each Firebase Auth user, under
/// `users/{uid}`. Holds app-specific fields that don't belong on the
/// Firebase Auth user record itself.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    this.createdAt,
  });

  final String uid;
  final String fullName;
  final String email;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return UserProfile(
      uid: uid,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
