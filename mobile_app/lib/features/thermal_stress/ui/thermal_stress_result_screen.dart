import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/models/thermal_result.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// Shows the backend's `/thermal/predict` result: an overall status banner,
/// confidence + severity cards, and a findings list built from the actual
/// response fields (no invented copy). [onBack] returns to the capture
/// screen; "Continue to Multimodal Assessment" is a placeholder until the
/// fused RGB/thermal/environmental assessment is wired up.
class ThermalStressResultScreen extends StatelessWidget {
  const ThermalStressResultScreen({super.key, required this.result, required this.onBack});

  final ThermalResult result;
  final VoidCallback onBack;

  Color get _accentColor {
    if (result.isHealthy) return AppColors.primaryGreen;
    switch (result.severity) {
      case 'Severe':
        return const Color(0xFFD32F2F);
      case 'Mild':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFFEF6C00);
    }
  }

  String get _statusHeadline {
    if (result.isHealthy) return 'HEALTHY — NO STRESS DETECTED';
    final severity = result.severity?.toUpperCase() ?? 'UNKNOWN';
    return '$severity PHYSIOLOGICAL STRESS';
  }

  List<String> get _findings {
    if (result.isHealthy) {
      return const [
        'No significant thermal anomalies detected.',
        'Leaf temperature pattern within normal range.',
      ];
    }

    final findings = <String>[];
    if (result.stressType != null) {
      findings.add('${result.stressType} pattern detected');
    }
    findings.add('Thermal anomaly detected in captured image');
    findings.add('Physiological stress evidence present');
    if (result.possibleEnvironmentalConfound == true) {
      findings.add('Possible environmental confound — verify ambient conditions');
    }
    return findings;
  }

  @override
  Widget build(BuildContext context) {
    final confidencePct = (result.modelConfidence * 100).round();

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
        const Text(
          'Thermal Stress Results',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.titleDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Thermal evidence from the submitted plant image.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overall Thermal Status',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
              ),
              const SizedBox(height: 4),
              Text(
                _statusHeadline,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _accentColor, height: 1.25),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MetricCard(label: 'Confidence', value: '$confidencePct%', color: AppColors.titleDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _MetricCard(
                  label: 'Severity',
                  value: result.severity ?? 'Healthy',
                  color: _accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thermal Findings', style: AppTextStyles.featureCardTitle),
              const SizedBox(height: 10),
              for (final finding in _findings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(color: AppColors.subtitleGrey, fontWeight: FontWeight.w700)),
                      Expanded(
                        child: Text(
                          finding,
                          style: const TextStyle(fontSize: 13, color: AppColors.subtitleGrey, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Continue to Multimodal Assessment',
          onPressed: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Multimodal Assessment — coming soon.')));
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
