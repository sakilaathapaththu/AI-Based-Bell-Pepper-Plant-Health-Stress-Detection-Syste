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
    return snapshot.docs.map((doc) => ThermalResult.fromMap(doc.data(), id: doc.id)).toList();
  }

  Future<ThermalResult?> getLatestResult(String uid) async {
    // See RgbRepository.getLatestResult for why this reads from the server
    // rather than the local cache (avoids a pending-serverTimestamp race
    // that can hide or misorder a just-saved result).
    final snapshot = await _results(uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snapshot.docs.isEmpty) return null;
    return ThermalResult.fromMap(snapshot.docs.first.data(), id: snapshot.docs.first.id);
  }

  /// Marks a saved result as forwarded to Adaptive Recovery. Called right
  /// after a recovery plan is successfully generated using this doc as one
  /// of its inputs.
  Future<void> markSentToRecovery(String uid, String id) {
    return _results(uid).doc(id).update({
      'sentToRecovery': true,
      'sentToRecoveryAt': FieldValue.serverTimestamp(),
    });
  }
}
