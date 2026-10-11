import 'package:cloud_firestore/cloud_firestore.dart';

/// A single "Scan Plant" (RGB) submission: the backend's `/rgb/predict`
/// response for one uploaded/captured image. Stored under
/// `users/{uid}/rgb_results/{autoId}`.
class RgbResult {
  const RgbResult({
    required this.timestamp,
    required this.plantCondition,
    required this.confidence,
    this.stressType,
    this.severity,
    this.modelVersion,
    this.imageUrl,
    this.sentToRecovery = false,
    this.createdAt,
  });

  final String timestamp;
  final String plantCondition;
  final double confidence;
  final String? stressType;
  final String? severity;
  final String? modelVersion;

  /// Firebase Storage download URL for the uploaded RGB image this result
  /// was computed from (see ImageStorageService) - null if the upload
  /// failed or hasn't completed.
  final String? imageUrl;

  /// Tracks whether this saved result has already been forwarded to the
  /// Adaptive Recovery component. Sending is not wired up yet (Component 4
  /// integration is a later step) - this field just reserves the state so
  /// that step can read/update existing saved results later instead of
  /// needing a schema change.
  final bool sentToRecovery;
  final DateTime? createdAt;

  bool get isHealthy => plantCondition == 'Healthy';

  /// [stressType] with underscores turned into spaces (e.g.
  /// "Nutrient_Deficiency" -> "Nutrient Deficiency") for display.
  String? get displayStressType => stressType?.replaceAll('_', ' ');

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'plantCondition': plantCondition,
      'confidence': confidence,
      'stressType': stressType,
      'severity': severity,
      'modelVersion': modelVersion,
      'imageUrl': imageUrl,
      'sentToRecovery': sentToRecovery,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory RgbResult.fromApiResponse(Map<String, dynamic> response, {String? imageUrl}) {
    return RgbResult(
      timestamp: DateTime.now().toIso8601String(),
      plantCondition: response['plant_condition'] as String? ?? 'Unknown',
      confidence: (response['confidence'] as num?)?.toDouble() ?? 0,
      stressType: response['stress_type'] as String?,
      severity: response['severity'] as String?,
      modelVersion: response['model_version'] as String?,
      imageUrl: imageUrl,
    );
  }

  factory RgbResult.fromMap(Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return RgbResult(
      timestamp: map['timestamp'] as String? ?? '',
      plantCondition: map['plantCondition'] as String? ?? 'Unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      stressType: map['stressType'] as String?,
      severity: map['severity'] as String?,
      modelVersion: map['modelVersion'] as String?,
      imageUrl: map['imageUrl'] as String?,
      sentToRecovery: map['sentToRecovery'] as bool? ?? false,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
