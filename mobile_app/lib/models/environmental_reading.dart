import 'package:cloud_firestore/cloud_firestore.dart';

/// A single "Check Current Environment" submission: the readings the user
/// entered, plus the backend's per-field status verdict for those readings.
/// Stored under `users/{uid}/environmental_readings/{autoId}`.
class EnvironmentalReading {
  const EnvironmentalReading({
    required this.timestamp,
    required this.growthStage,
    required this.airTemperatureC,
    required this.relativeHumidityPct,
    required this.lightIntensityLux,
    required this.soilTemperatureC,
    required this.environmentStatus,
    this.createdAt,
  });

  final String timestamp;
  final String growthStage;
  final double airTemperatureC;
  final double relativeHumidityPct;
  final double lightIntensityLux;
  final double soilTemperatureC;

  /// Raw `environment_status` map returned by the backend's
  /// `/environmental/check-environment` endpoint (per-field value/status/
  /// suitable_range/adjustment_direction) - stored as-is so the result
  /// screen can be rebuilt from history without re-calling the backend.
  final Map<String, dynamic> environmentStatus;

  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'growthStage': growthStage,
      'airTemperatureC': airTemperatureC,
      'relativeHumidityPct': relativeHumidityPct,
      'lightIntensityLux': lightIntensityLux,
      'soilTemperatureC': soilTemperatureC,
      'environmentStatus': environmentStatus,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory EnvironmentalReading.fromMap(Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return EnvironmentalReading(
      timestamp: map['timestamp'] as String? ?? '',
      growthStage: map['growthStage'] as String? ?? '',
      airTemperatureC: (map['airTemperatureC'] as num?)?.toDouble() ?? 0,
      relativeHumidityPct: (map['relativeHumidityPct'] as num?)?.toDouble() ?? 0,
      lightIntensityLux: (map['lightIntensityLux'] as num?)?.toDouble() ?? 0,
      soilTemperatureC: (map['soilTemperatureC'] as num?)?.toDouble() ?? 0,
      environmentStatus: Map<String, dynamic>.from(map['environmentStatus'] as Map? ?? {}),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
