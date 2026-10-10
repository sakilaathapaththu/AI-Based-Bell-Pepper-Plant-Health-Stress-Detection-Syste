import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';

/// One tappable tile in the Environmental Stress Prediction entry screen's
/// 2x2 action grid (e.g. "Check Current Environment"). Styled to match the
/// app's other feature cards: white card, single-tone green badge — no
/// per-card accent colors.
class EnvironmentalActionCard extends StatelessWidget {
  const EnvironmentalActionCard({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String badge;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.featureIconBackground,
                  shape: BoxShape.circle,
                ),
                child: Text(badge, style: AppTextStyles.featureBadge),
              ),
              const SizedBox(height: 14),
              Text(title, style: AppTextStyles.featureCardTitle),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTextStyles.featureCardDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
