import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';
import 'package:bell_pepper_app/ui/widgets/secondary_button.dart';

/// Shows the backend's `/environmental/predict` result: stress type,
/// 30/60-minute risk forecasts, the rule-based explanation, and main
/// contributing factors. "Save Result" persists this prediction to
/// Firestore (mobile-app side); "Send to Recovery" is a placeholder for
/// now - Component 4 (Adaptive Recovery) integration is a later step.
class FutureStressPredictionScreen extends StatelessWidget {
  const FutureStressPredictionScreen({
    super.key,
    required this.growthStage,
    required this.stressType,
    required this.risk30m,
    required this.risk60m,
    required this.explanation,
    required this.mainContributingFactors,
    required this.onBack,
    required this.onSaveResult,
    required this.onSendToRecovery,
    this.isSaving = false,
    this.isSaved = false,
  });

  final String growthStage;
  final String stressType;
  final Map<String, dynamic> risk30m;
  final Map<String, dynamic> risk60m;
  final String explanation;
  final List<String> mainContributingFactors;
  final VoidCallback onBack;
  final VoidCallback onSaveResult;
  final VoidCallback onSendToRecovery;
  final bool isSaving;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
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
          'Future Stress Prediction',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.titleDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'AI-predicted plant stress risk based on the current environmental factors and selected growth stage.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Stress Type : ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.titleDark),
              ),
              Text(
                stressType,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFD32F2F)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _RiskCard(
          badgeText: '30',
          title: 'Next 30 Minutes',
          subtitle: 'Short-term outlook',
          level: risk30m['level'] as String? ?? '—',
          score: risk30m['score'],
          badgeColor: const Color(0xFFFFE0B2),
        ),
        const SizedBox(height: 14),
        _RiskCard(
          badgeText: '60',
          title: 'Next 60 Minutes',
          subtitle: 'Medium-term outlook',
          level: risk60m['level'] as String? ?? '—',
          score: risk60m['score'],
          badgeColor: const Color(0xFFFFCDD2),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.featureIconBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Why this risk level?',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.titleDark),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                explanation,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.subtitleGrey, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Main Contributing Factors',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.titleDark),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final factor in mainContributingFactors) _FactorChip(text: factor),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: isSaved ? 'Saved' : 'Save Result',
                onPressed: isSaved ? null : onSaveResult,
                isLoading: isSaving,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: PrimaryButton(
                label: 'Send to Recovery',
                onPressed: onSendToRecovery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.score,
    required this.badgeColor,
  });

  final String badgeText;
  final String title;
  final String subtitle;
  final String level;
  final dynamic score;
  final Color badgeColor;

  Color get _levelColor {
    switch (level) {
      case 'High':
        return const Color(0xFFD32F2F);
      case 'Moderate':
        return const Color(0xFFEF6C00);
      default:
        return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
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
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                child: Text(badgeText, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.titleDark)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.titleDark)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.subtitleGrey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _levelColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$level Risk',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _levelColor),
                ),
              ),
              Text(
                '${score ?? '—'}%',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _levelColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FactorChip extends StatelessWidget {
  const _FactorChip({required this.text});

  final String text;

  Color get _color {
    final lower = text.toLowerCase();
    if (lower.contains('high') || lower.contains('temp')) return const Color(0xFFEF6C00);
    if (lower.contains('low') || lower.contains('humidity')) return const Color(0xFF1976D2);
    return AppColors.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _color),
      ),
    );
  }
}
