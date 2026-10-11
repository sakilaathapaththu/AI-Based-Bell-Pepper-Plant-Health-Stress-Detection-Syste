import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bell_pepper_app/models/thermal_result.dart';

/// Thin wrapper around the `users/{uid}/thermal_results` Firestore
/// subcollection so screens depend on this instead of the Firestore SDK
/// directly. Saving happens on the mobile app side - the backend only
/// predicts, it never persists anything itself.
class ThermalRepository {
  ThermalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _results(String uid) =>
      _firestore.collection('users').doc(uid).collection('thermal_results');

  Future<void> saveResult(String uid, ThermalResult result) {
    return _results(uid).add(result.toMap());
  }

  Future<List<ThermalResult>> getResults(String uid) async {
    final snapshot = await _results(uid).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => ThermalResult.fromMap(doc.data())).toList();
  }
}
