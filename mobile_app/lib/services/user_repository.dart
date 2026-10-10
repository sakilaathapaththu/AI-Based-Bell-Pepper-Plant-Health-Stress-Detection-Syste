import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bell_pepper_app/models/user_profile.dart';

/// Thin wrapper around the `users` Firestore collection so screens depend on
/// this instead of the Firestore SDK directly.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createUserProfile(UserProfile profile) {
    return _users.doc(profile.uid).set(profile.toMap());
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserProfile.fromMap(uid, data);
  }
}
