import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/onboarding/models/onboarding_slide.dart';

/// A single capability row shown on an onboarding slide.
class OnboardingFeatureCard extends StatelessWidget {
  const OnboardingFeatureCard({super.key, required this.feature});

  final OnboardingFeature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.featureIconBackground,
              shape: BoxShape.circle,
            ),
            child: Text(feature.badge, style: AppTextStyles.featureBadge),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.title, style: AppTextStyles.featureCardTitle),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: AppTextStyles.featureCardDescription,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
