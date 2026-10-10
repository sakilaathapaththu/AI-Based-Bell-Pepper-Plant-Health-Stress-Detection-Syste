import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bell_pepper_app/models/environmental_reading.dart';
import 'package:bell_pepper_app/models/stress_prediction.dart';

/// Thin wrapper around the `users/{uid}/environmental_readings` and
/// `users/{uid}/stress_predictions` Firestore subcollections so screens
/// depend on this instead of the Firestore SDK directly. Saving happens on
/// the mobile app side - the backend only predicts/evaluates, it never
/// persists anything itself.
class EnvironmentalRepository {
  EnvironmentalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _readings(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('environmental_readings');

  CollectionReference<Map<String, dynamic>> _predictions(String uid) =>
      _firestore.collection('users').doc(uid).collection('stress_predictions');

  Future<void> saveReading(String uid, EnvironmentalReading reading) {
    return _readings(uid).add(reading.toMap());
  }

  Future<List<EnvironmentalReading>> getReadings(String uid) async {
    final snapshot = await _readings(
      uid,
    ).orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => EnvironmentalReading.fromMap(doc.data()))
        .toList();
  }

  Future<void> savePrediction(String uid, StressPrediction prediction) {
    return _predictions(uid).add(prediction.toMap());
  }

  Future<List<StressPrediction>> getPredictions(String uid) async {
    final snapshot = await _predictions(
      uid,
    ).orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => StressPrediction.fromMap(doc.data()))
        .toList();
  }
}
