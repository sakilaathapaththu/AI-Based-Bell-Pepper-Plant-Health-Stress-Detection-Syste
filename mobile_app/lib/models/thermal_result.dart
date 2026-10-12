import 'package:cloud_firestore/cloud_firestore.dart';

/// A single "Thermal Stress Detection" submission: the backend's
/// `/thermal/predict` response for one uploaded/captured image. Stored
/// under `users/{uid}/thermal_results/{autoId}`.
class ThermalResult {
  const ThermalResult({
    required this.timestamp,
    required this.stressStatus,
    required this.modelConfidence,
    this.stressType,
    this.severity,
    this.thermalMetrics,
    this.possibleEnvironmentalConfound,
    this.modelVersion,
    this.imageUrl,
    this.sentToRecovery = false,
    this.createdAt,
    this.id,
  });

  /// Firestore document id (`users/{uid}/thermal_results/{id}`) - null when
  /// this instance wasn't built from a Firestore query.
  final String? id;

  final String timestamp;
  final String stressStatus;
  final double modelConfidence;
  final String? stressType;
  final String? severity;
  final Map<String, dynamic>? thermalMetrics;
  final bool? possibleEnvironmentalConfound;
  final String? modelVersion;

  /// Firebase Storage download URL for the uploaded thermal image this
  /// result was computed from (see ImageStorageService) - null if the
  /// upload failed or hasn't completed.
  final String? imageUrl;

  /// Tracks whether this saved result has already been forwarded to the
  /// Adaptive Recovery component. Sending is not wired up yet (Component 4
  /// integration is a later step) - this field just reserves the state so
  /// that step can read/update existing saved results later instead of
  /// needing a schema change.
  final bool sentToRecovery;
  final DateTime? createdAt;

  bool get isHealthy => stressStatus == 'Healthy';

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'stressStatus': stressStatus,
      'modelConfidence': modelConfidence,
      'stressType': stressType,
      'severity': severity,
      'thermalMetrics': thermalMetrics,
      'possibleEnvironmentalConfound': possibleEnvironmentalConfound,
      'modelVersion': modelVersion,
      'imageUrl': imageUrl,
      'sentToRecovery': sentToRecovery,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ThermalResult.fromApiResponse(
    Map<String, dynamic> response, {
    String? imageUrl,
  }) {
    return ThermalResult(
      timestamp: DateTime.now().toIso8601String(),
      stressStatus: response['stress_status'] as String? ?? 'Unknown',
      modelConfidence: (response['model_confidence'] as num?)?.toDouble() ?? 0,
      stressType: response['stress_type'] as String?,
      severity: response['severity'] as String?,
      thermalMetrics: (response['thermal_metrics'] as Map?)?.cast<String, dynamic>(),
      possibleEnvironmentalConfound: response['possible_environmental_confound'] as bool?,
      modelVersion: response['model_version'] as String?,
      imageUrl: imageUrl,
    );
  }

  factory ThermalResult.fromMap(Map<String, dynamic> map, {String? id}) {
    final timestamp = map['createdAt'];
    return ThermalResult(
      timestamp: map['timestamp'] as String? ?? '',
      stressStatus: map['stressStatus'] as String? ?? 'Unknown',
      modelConfidence: (map['modelConfidence'] as num?)?.toDouble() ?? 0,
      stressType: map['stressType'] as String?,
      severity: map['severity'] as String?,
      thermalMetrics: (map['thermalMetrics'] as Map?)?.cast<String, dynamic>(),
      possibleEnvironmentalConfound: map['possibleEnvironmentalConfound'] as bool?,
      modelVersion: map['modelVersion'] as String?,
      imageUrl: map['imageUrl'] as String?,
      sentToRecovery: map['sentToRecovery'] as bool? ?? false,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      id: id,
    );
  }
}
