import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/models/rgb_result.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';
import 'package:bell_pepper_app/ui/widgets/secondary_button.dart';

/// Shows the backend's `/rgb/predict` result for the just-captured image:
/// plant condition, severity/confidence, a short explanation, and actions
/// to save the result or send it on to the Adaptive Recovery component
/// (placeholder until that integration is wired up).
class RgbStressResultScreen extends StatelessWidget {
  const RgbStressResultScreen({
    super.key,
    required this.result,
    required this.imageBytes,
    required this.onBack,
    required this.onScanAgain,
    required this.onSaveResult,
    required this.onSendToRecovery,
    this.isSaving = false,
    this.isSaved = false,
  });

  final RgbResult result;
  final Uint8List imageBytes;
  final VoidCallback onBack;
  final VoidCallback onScanAgain;
  final VoidCallback onSaveResult;
  final VoidCallback onSendToRecovery;
  final bool isSaving;
  final bool isSaved;

  Color get _conditionColor => result.isHealthy ? AppColors.primaryGreen : const Color(0xFFEF6C00);

  String get _detectionExplanation {
    if (result.isHealthy) {
      return 'Leaf color and texture patterns are consistent with a healthy plant.';
    }
    switch (result.stressType) {
      case 'Aphid':
        return 'Leaf curling and discoloration patterns consistent with aphid activity contributed to this prediction.';
      case 'Thrips':
        return 'Silvery leaf streaking and scarring patterns consistent with thrips damage contributed to this prediction.';
      case 'Nutrient_Deficiency':
        return 'Leaf yellowing and reduced greenness patterns consistent with a nutrient deficiency contributed to this prediction.';
      default:
        return 'Visible leaf color and texture patterns contributed to this prediction.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final confidencePct = (result.confidence * 100).round();
    final title = result.isHealthy ? 'Healthy' : (result.displayStressType ?? 'Stress Detected');

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
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: 180,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.featureIconBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.memory(imageBytes, fit: BoxFit.cover),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'RGB Image',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.titleDark),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Plant condition',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _conditionColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      result.plantCondition.toUpperCase(),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _conditionColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.titleDark),
              ),
              const SizedBox(height: 6),
              Text(
                _detectionExplanation,
                style: const TextStyle(fontSize: 13, color: AppColors.subtitleGrey, height: 1.35),
              ),
              const Divider(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Severity',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.severity ?? '—',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _conditionColor),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confidence',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$confidencePct%',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.titleDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.featureIconBackground,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What the model detected',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.titleDark),
              ),
              const SizedBox(height: 6),
              Text(
                _detectionExplanation,
                style: const TextStyle(fontSize: 12.5, color: AppColors.subtitleGrey, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Send to Recovery System', onPressed: onSendToRecovery),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(label: 'Scan Again', onPressed: onScanAgain),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SecondaryButton(
                label: isSaved ? 'Saved' : 'Save Result',
                onPressed: isSaved ? null : onSaveResult,
                isLoading: isSaving,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Sends: Stress Type • Severity • Confidence • Plant ID',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.loadingGrey),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
