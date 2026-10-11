import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bell_pepper_app/models/rgb_result.dart';

/// Thin wrapper around the `users/{uid}/rgb_results` Firestore subcollection
/// so screens depend on this instead of the Firestore SDK directly. Saving
/// happens on the mobile app side - the backend only predicts, it never
/// persists anything itself.
class RgbRepository {
  RgbRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _results(String uid) =>
      _firestore.collection('users').doc(uid).collection('rgb_results');

  Future<void> saveResult(String uid, RgbResult result) {
    return _results(uid).add(result.toMap());
  }

  Future<List<RgbResult>> getResults(String uid) async {
    final snapshot = await _results(uid).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => RgbResult.fromMap(doc.data())).toList();
  }

  Future<RgbResult?> getLatestResult(String uid) async {
    final snapshot = await _results(
      uid,
    ).orderBy('createdAt', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return RgbResult.fromMap(snapshot.docs.first.data());
  }
}
