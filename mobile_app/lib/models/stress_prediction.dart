import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved "Predict Future Stress" result: the backend's
/// `/environmental/predict` response, stored as-is under
/// `users/{uid}/stress_predictions/{autoId}` when the user taps
/// "Save Result".
///
/// [recoveryHandoff] is kept separately (it's the exact payload the
/// Adaptive Recovery component expects as its `environmental_result`
/// input - see unified-backend/app/services/adaptive_service.py) and
/// [sentToRecovery] tracks whether this saved prediction has already been
/// forwarded there. Sending is not wired up yet - this field just reserves
/// the state so that step can read/update existing saved records later
/// instead of needing a schema change.
class StressPrediction {
  const StressPrediction({
    required this.predictionTimestamp,
    required this.growthStage,
    required this.stressType,
    required this.risk30m,
    required this.risk60m,
    required this.mainContributingFactors,
    required this.explanation,
    required this.currentEnvironment,
    required this.recoveryHandoff,
    this.sentToRecovery = false,
    this.createdAt,
    this.id,
  });

  /// Firestore document id (`users/{uid}/stress_predictions/{id}`) - null
  /// when this instance wasn't built from a Firestore query.
  final String? id;

  final String predictionTimestamp;
  final String growthStage;
  final String stressType;
  final Map<String, dynamic> risk30m;
  final Map<String, dynamic> risk60m;
  final List<String> mainContributingFactors;
  final String explanation;
  final Map<String, dynamic> currentEnvironment;
  final Map<String, dynamic> recoveryHandoff;
  final bool sentToRecovery;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'predictionTimestamp': predictionTimestamp,
      'growthStage': growthStage,
      'stressType': stressType,
      'risk30m': risk30m,
      'risk60m': risk60m,
      'mainContributingFactors': mainContributingFactors,
      'explanation': explanation,
      'currentEnvironment': currentEnvironment,
      'recoveryHandoff': recoveryHandoff,
      'sentToRecovery': sentToRecovery,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory StressPrediction.fromMap(Map<String, dynamic> map, {String? id}) {
    final timestamp = map['createdAt'];
    return StressPrediction(
      predictionTimestamp: map['predictionTimestamp'] as String? ?? '',
      growthStage: map['growthStage'] as String? ?? '',
      stressType: map['stressType'] as String? ?? '',
      risk30m: Map<String, dynamic>.from(map['risk30m'] as Map? ?? {}),
      risk60m: Map<String, dynamic>.from(map['risk60m'] as Map? ?? {}),
      mainContributingFactors: List<String>.from(
        map['mainContributingFactors'] as List? ?? [],
      ),
      explanation: map['explanation'] as String? ?? '',
      currentEnvironment: Map<String, dynamic>.from(
        map['currentEnvironment'] as Map? ?? {},
      ),
      recoveryHandoff: Map<String, dynamic>.from(
        map['recoveryHandoff'] as Map? ?? {},
      ),
      sentToRecovery: map['sentToRecovery'] as bool? ?? false,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      id: id,
    );
  }

  /// Builds a [StressPrediction] directly from the backend's
  /// `/environmental/predict` JSON response body.
  factory StressPrediction.fromApiResponse(Map<String, dynamic> response) {
    return StressPrediction(
      predictionTimestamp: response['prediction_timestamp'] as String? ?? '',
      growthStage: response['growth_stage'] as String? ?? '',
      stressType: response['stress_type'] as String? ?? '',
      risk30m: Map<String, dynamic>.from(response['risk_30m'] as Map? ?? {}),
      risk60m: Map<String, dynamic>.from(response['risk_60m'] as Map? ?? {}),
      mainContributingFactors: List<String>.from(
        response['main_contributing_factors'] as List? ?? [],
      ),
      explanation: response['explanation'] as String? ?? '',
      currentEnvironment: Map<String, dynamic>.from(
        response['current_environment'] as Map? ?? {},
      ),
      recoveryHandoff: Map<String, dynamic>.from(
        response['recovery_handoff'] as Map? ?? {},
      ),
    );
  }
}
