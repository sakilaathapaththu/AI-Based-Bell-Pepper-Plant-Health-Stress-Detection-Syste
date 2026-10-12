import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/models/recovery_assessment.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/models/recovery_plan.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/ui/recovery_plan_result_screen.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/ui/widgets/status_pill.dart';
import 'package:bell_pepper_app/services/adaptive_api_service.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/environmental_repository.dart';
import 'package:bell_pepper_app/services/rgb_repository.dart';
import 'package:bell_pepper_app/services/thermal_repository.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// Entry screen for Adaptive Recovery: fetches each component's latest
/// saved result, shows them for review, and lets the grower generate a
/// recovery plan from the unified backend. Embedded inside the Home tab
/// (keeping the shared top bar and bottom nav visible); [onBack] returns to
/// the dashboard.
///
/// When [onPlanGenerated] is provided (e.g. when pushed from
/// [AdaptiveRecoveryHomeScreen]), it's called instead of showing the plan
/// inline, so the caller can navigate to/update the Recovery Plan screen
/// itself. When omitted, this screen falls back to showing
/// [RecoveryPlanResultScreen] in place, preserving its original standalone
/// behavior.
class RecoveryAssessmentScreen extends StatefulWidget {
  const RecoveryAssessmentScreen({super.key, required this.onBack, this.onPlanGenerated});

  final VoidCallback onBack;
  final ValueChanged<RecoveryPlan>? onPlanGenerated;

  @override
  State<RecoveryAssessmentScreen> createState() => _RecoveryAssessmentScreenState();
}

class _RecoveryAssessmentScreenState extends State<RecoveryAssessmentScreen> {
  late Future<RecoveryAssessment> _assessmentFuture;
  bool _isGenerating = false;
  RecoveryPlan? _plan;

  @override
  void initState() {
    super.initState();
    _assessmentFuture = _loadAssessment();
  }

  Future<RecoveryAssessment> _loadAssessment() async {
    final user = AuthService().currentUser;
    if (user == null || user.isAnonymous) {
      return RecoveryAssessment.fromLatest();
    }

    final results = await Future.wait([
      RgbRepository().getLatestResult(user.uid).catchError((Object error, StackTrace _) {
        debugPrint('[RecoveryAssessment] RGB fetch failed: $error');
        return null;
      }),
      ThermalRepository().getLatestResult(user.uid).catchError((Object error, StackTrace _) {
        debugPrint('[RecoveryAssessment] Thermal fetch failed: $error');
        return null;
      }),
      EnvironmentalRepository().getLatestPrediction(user.uid).catchError((Object error, StackTrace _) {
        debugPrint('[RecoveryAssessment] Environmental fetch failed: $error');
        return null;
      }),
    ]);

    return RecoveryAssessment.fromLatest(
      rgb: results[0] as dynamic,
      thermal: results[1] as dynamic,
      environmental: results[2] as dynamic,
    );
  }

  Future<void> _generatePlan(RecoveryAssessment assessment) async {
    setState(() => _isGenerating = true);
    try {
      final rgb = assessment.rgbResult;
      final thermal = assessment.thermalResult;
      final environmental = assessment.environmentalPrediction;

      final plan = await AdaptiveApiService().generateRecoveryPlan(
        rgbResult: rgb == null
            ? null
            : {
                'plant_condition': rgb.plantCondition,
                'stress_type': rgb.stressType,
                'severity': rgb.severity,
                'confidence': rgb.confidence,
              },
        thermalResult: thermal == null
            ? null
            : {
                'stress_status': thermal.stressStatus,
                'stress_type': thermal.stressType,
                'severity': thermal.severity,
                'model_confidence': thermal.modelConfidence,
                'possible_environmental_confound': thermal.possibleEnvironmentalConfound,
              },
        environmentalResult: environmental?.recoveryHandoff,
      );

      // Mark exactly the Firestore docs used as inputs to this plan as sent,
      // so they aren't mistaken for not-yet-reviewed results later. Best
      // effort - failures here shouldn't block showing the generated plan.
      final user = AuthService().currentUser;
      if (user != null && !user.isAnonymous) {
        final updates = <Future<void>>[
          if (rgb?.id != null) RgbRepository().markSentToRecovery(user.uid, rgb!.id!),
          if (thermal?.id != null) ThermalRepository().markSentToRecovery(user.uid, thermal!.id!),
          if (environmental?.id != null)
            EnvironmentalRepository().markSentToRecovery(user.uid, environmental!.id!),
        ];
        if (updates.isNotEmpty) {
          unawaited(
            Future.wait(updates).catchError((Object error, StackTrace _) {
              debugPrint('[RecoveryAssessment] markSentToRecovery failed: $error');
              return <void>[];
            }),
          );
        }
      }

      if (!mounted) return;
      final onPlanGenerated = widget.onPlanGenerated;
      if (onPlanGenerated != null) {
        onPlanGenerated(plan);
      } else {
        setState(() => _plan = plan);
      }
    } catch (error) {
      debugPrint('[RecoveryAssessment] Generate plan failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not generate a recovery plan. Please try again.')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_plan != null) {
      return RecoveryPlanResultScreen(plan: _plan!, onBack: () => setState(() => _plan = null));
    }

    return FutureBuilder<RecoveryAssessment>(
      future: _assessmentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
          );
        }

        final assessment = snapshot.data ?? RecoveryAssessment.fromLatest();
        return _AssessmentView(
          assessment: assessment,
          onBack: widget.onBack,
          isGenerating: _isGenerating,
          onGenerate: () => _generatePlan(assessment),
        );
      },
    );
  }
}

class _AssessmentView extends StatelessWidget {
  const _AssessmentView({
    required this.assessment,
    required this.onBack,
    required this.isGenerating,
    required this.onGenerate,
  });

  final RecoveryAssessment assessment;
  final VoidCallback onBack;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final missing = assessment.missingComponentLabels;
    final canGenerate = assessment.isComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onBack,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.featureIconBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.primaryGreen),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Recovery Assessment', style: AppTextStyles.screenTitle),
        const SizedBox(height: 4),
        const Text('Review inputs before generating plan', style: AppTextStyles.screenSubtitle),
        const SizedBox(height: 22),
        const Text('Stress assessment', style: AppTextStyles.featureCardTitle),
        const SizedBox(height: 12),
        _ComponentCard(
          label: 'RGB',
          statusLabel: assessment.rgbResult == null
              ? null
              : (assessment.rgbResult!.isHealthy
                    ? 'HEALTHY'
                    : (assessment.rgbResult!.severity ?? 'MODERATE').toUpperCase()),
          detailBuilder: (context) => _RgbDetails(result: assessment.rgbResult),
        ),
        const SizedBox(height: 10),
        _ComponentCard(
          label: 'Thermal',
          statusLabel: assessment.thermalResult == null
              ? null
              : (assessment.thermalResult!.isHealthy
                    ? 'HEALTHY'
                    : (assessment.thermalResult!.severity ?? 'MODERATE').toUpperCase()),
          detailBuilder: (context) => _ThermalDetails(result: assessment.thermalResult),
        ),
        const SizedBox(height: 10),
        _ComponentCard(
          label: 'Environment',
          statusLabel: assessment.environmentalPrediction == null
              ? null
              : _environmentStatusLabel(assessment.environmentalPrediction!),
          detailBuilder: (context) =>
              _EnvironmentDetails(prediction: assessment.environmentalPrediction),
        ),
        const SizedBox(height: 22),
        const Text('Context', style: AppTextStyles.featureCardTitle),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _ContextRow(
                label: 'Growth stage',
                value: assessment.environmentalPrediction?.growthStage,
              ),
              const Divider(height: 24),
              _ContextRow(
                label: 'Conditions',
                value: assessment.environmentalPrediction?.stressType,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (missing.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFEF6C00), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Missing today\'s ${missing.join(', ')} data. Generate a scan/reading for '
                    '${missing.length > 1 ? 'these components' : 'this component'} to enable the recovery plan.',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A5A00), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        PrimaryButton(
          label: 'Generate Recovery Plan',
          onPressed: canGenerate ? onGenerate : null,
          isLoading: isGenerating,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _environmentStatusLabel(dynamic prediction) {
    final level = (prediction.risk60m['level'] as String?)?.toUpperCase();
    if (level == null || level.isEmpty) return 'MODERATE';
    if (level == 'HIGH') return 'HIGH RISK';
    return '$level RISK';
  }
}

/// A "Stress assessment" card that is tappable: it collapses to just the
/// label + status pill (as before) and, on tap, expands in place via
/// [AnimatedSize] to reveal [detailBuilder]'s full result breakdown. Expand
/// state is simple local widget state, matching the rest of this screen.
class _ComponentCard extends StatefulWidget {
  const _ComponentCard({required this.label, required this.statusLabel, required this.detailBuilder});

  final String label;
  final String? statusLabel;
  final WidgetBuilder detailBuilder;

  @override
  State<_ComponentCard> createState() => _ComponentCardState();
}

class _ComponentCardState extends State<_ComponentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(widget.label, style: AppTextStyles.featureCardTitle),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: AppColors.subtitleGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.statusLabel == null
                        ? const StatusPill(label: 'No data for today', isNeutral: true)
                        : StatusPill(label: widget.statusLabel!),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: widget.detailBuilder(context),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared styling for a single field row inside an expanded card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.titleDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDataToday extends StatelessWidget {
  const _NoDataToday({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(fontSize: 12.5, color: AppColors.subtitleGrey, height: 1.4),
    );
  }
}

class _RgbDetails extends StatelessWidget {
  const _RgbDetails({required this.result});

  final dynamic result;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const _NoDataToday(message: 'No scan recorded today for this component.');
    }
    final r = result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              r.imageUrl as String,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _DetailRow(label: 'Plant condition', value: r.plantCondition as String),
        _DetailRow(label: 'Confidence', value: '${((r.confidence as double) * 100).round()}%'),
        _DetailRow(label: 'Stress type', value: (r.displayStressType as String?) ?? '—'),
        _DetailRow(label: 'Severity', value: (r.severity as String?) ?? '—'),
        _DetailRow(label: 'Model version', value: (r.modelVersion as String?) ?? '—'),
        _DetailRow(label: 'Recorded at', value: _formatTimestamp(r.createdAt as DateTime?)),
      ],
    );
  }
}

class _ThermalDetails extends StatelessWidget {
  const _ThermalDetails({required this.result});

  final dynamic result;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const _NoDataToday(message: 'No scan recorded today for this component.');
    }
    final r = result;
    final metrics = (r.thermalMetrics as Map<String, dynamic>?) ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              r.imageUrl as String,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _DetailRow(label: 'Stress status', value: r.stressStatus as String),
        _DetailRow(label: 'Model confidence', value: '${((r.modelConfidence as double) * 100).round()}%'),
        _DetailRow(label: 'Stress type', value: (r.stressType as String?) ?? '—'),
        _DetailRow(label: 'Severity', value: (r.severity as String?) ?? '—'),
        _DetailRow(
          label: 'Environmental confound',
          value: r.possibleEnvironmentalConfound == true ? 'Possible' : 'None noted',
        ),
        if (metrics.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Thermal metrics',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.titleDark),
          ),
          const SizedBox(height: 6),
          ...metrics.entries.map((e) => _DetailRow(label: _humanize(e.key), value: '${e.value}')),
        ],
        _DetailRow(label: 'Model version', value: (r.modelVersion as String?) ?? '—'),
        _DetailRow(label: 'Recorded at', value: _formatTimestamp(r.createdAt as DateTime?)),
      ],
    );
  }

  static String _humanize(String key) {
    final withSpaces = key.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    final spaced = withSpaces.replaceAll('_', ' ');
    return spaced.isEmpty ? spaced : spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _EnvironmentDetails extends StatelessWidget {
  const _EnvironmentDetails({required this.prediction});

  final dynamic prediction;

  @override
  Widget build(BuildContext context) {
    if (prediction == null) {
      return const _NoDataToday(message: 'No scan recorded today for this component.');
    }
    final p = prediction;
    final risk30 = (p.risk30m as Map<String, dynamic>?) ?? const {};
    final risk60 = (p.risk60m as Map<String, dynamic>?) ?? const {};
    final factors = (p.mainContributingFactors as List?)?.cast<String>() ?? const <String>[];
    final handoff = (p.recoveryHandoff as Map<String, dynamic>?) ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(label: 'Growth stage', value: (p.growthStage as String?)?.isNotEmpty == true ? p.growthStage as String : '—'),
        _DetailRow(label: 'Stress type', value: (p.stressType as String?)?.isNotEmpty == true ? p.stressType as String : '—'),
        _DetailRow(label: '30-min risk', value: _formatRisk(risk30)),
        _DetailRow(label: '60-min risk', value: _formatRisk(risk60)),
        if (factors.isNotEmpty)
          _DetailRow(label: 'Contributing factors', value: factors.join(', ')),
        if ((p.explanation as String?)?.isNotEmpty == true) _DetailRow(label: 'Explanation', value: p.explanation as String),
        if (handoff.isNotEmpty)
          _DetailRow(label: 'Recovery handoff', value: handoff.entries.map((e) => '${e.key}: ${e.value}').join(', ')),
        _DetailRow(label: 'Recorded at', value: _formatTimestamp(p.createdAt as DateTime?)),
      ],
    );
  }

  static String _formatRisk(Map<String, dynamic> risk) {
    if (risk.isEmpty) return '—';
    final level = risk['level'];
    final score = risk['score'] ?? risk['probability'];
    if (level == null && score == null) return '—';
    final parts = <String>[];
    if (level != null) parts.add('$level'.toUpperCase());
    if (score != null) parts.add('$score');
    return parts.join(' · ');
  }
}

String _formatTimestamp(DateTime? dateTime) {
  if (dateTime == null) return '—';
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
        ),
        Text(
          (value == null || value!.isEmpty) ? '—' : value!,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.titleDark),
        ),
      ],
    );
  }
}
