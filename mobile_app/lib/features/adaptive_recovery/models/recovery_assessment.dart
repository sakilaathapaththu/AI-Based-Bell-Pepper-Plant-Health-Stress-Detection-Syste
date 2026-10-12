import 'package:bell_pepper_app/models/rgb_result.dart';
import 'package:bell_pepper_app/models/stress_prediction.dart';
import 'package:bell_pepper_app/models/thermal_result.dart';

/// Truncates a [DateTime] to its calendar day (local time), so results from
/// the same day can be compared regardless of time-of-day.
DateTime dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

/// Combines the latest RGB / Thermal / Environmental results for a user and
/// figures out which ones belong to "today" (the target date for a recovery
/// plan), treating any component whose latest result falls on a different
/// day as missing rather than erroring.
///
/// Target date selection: if 2+ of the available results share today's
/// calendar date, today is the target date. Otherwise the most recent date
/// among the available results is used. Any component whose latest result
/// isn't on the target date is treated as missing for that date.
class RecoveryAssessment {
  const RecoveryAssessment({
    required this.rgbResult,
    required this.thermalResult,
    required this.environmentalPrediction,
    required this.targetDate,
  });

  final RgbResult? rgbResult;
  final ThermalResult? thermalResult;
  final StressPrediction? environmentalPrediction;
  final DateTime? targetDate;

  factory RecoveryAssessment.fromLatest({
    RgbResult? rgb,
    ThermalResult? thermal,
    StressPrediction? environmental,
  }) {
    final dates = <DateTime>[
      if (rgb?.createdAt != null) dateOnly(rgb!.createdAt!),
      if (thermal?.createdAt != null) dateOnly(thermal!.createdAt!),
      if (environmental?.createdAt != null) dateOnly(environmental!.createdAt!),
    ];

    if (dates.isEmpty) {
      return const RecoveryAssessment(
        rgbResult: null,
        thermalResult: null,
        environmentalPrediction: null,
        targetDate: null,
      );
    }

    final today = dateOnly(DateTime.now());
    final todayCount = dates.where((d) => d == today).length;

    DateTime targetDate;
    if (todayCount >= 2) {
      targetDate = today;
    } else {
      dates.sort((a, b) => b.compareTo(a));
      targetDate = dates.first;
    }

    final rgbOnTarget = rgb?.createdAt != null && dateOnly(rgb!.createdAt!) == targetDate ? rgb : null;
    final thermalOnTarget =
        thermal?.createdAt != null && dateOnly(thermal!.createdAt!) == targetDate ? thermal : null;
    final environmentalOnTarget =
        environmental?.createdAt != null && dateOnly(environmental!.createdAt!) == targetDate
        ? environmental
        : null;

    return RecoveryAssessment(
      rgbResult: rgbOnTarget,
      thermalResult: thermalOnTarget,
      environmentalPrediction: environmentalOnTarget,
      targetDate: targetDate,
    );
  }

  bool get isComplete =>
      rgbResult != null && thermalResult != null && environmentalPrediction != null;

  List<String> get missingComponentLabels => [
    if (rgbResult == null) 'RGB',
    if (thermalResult == null) 'Thermal',
    if (environmentalPrediction == null) 'Environment',
  ];
}
