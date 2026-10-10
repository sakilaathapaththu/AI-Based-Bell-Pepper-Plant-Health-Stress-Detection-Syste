import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/environmental_stress/ui/widgets/environmental_action_card.dart';

/// Content for the Environmental Stress Prediction module: a status banner
/// plus a 2x2 grid of actions (check readings, predict risk, saved results,
/// help). Embedded inside the Home tab (keeping the shared top bar and
/// bottom nav visible) rather than pushed as a separate full-screen route;
/// [onBack] returns the tab to the dashboard view. Real data/prediction
/// wiring lands here incrementally — for now each action just acknowledges
/// the tap.
class EnvironmentalStressScreen extends StatelessWidget {
  const EnvironmentalStressScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onTap: onBack),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.titleDark,
              height: 1.2,
            ),
            children: [
              TextSpan(text: 'Environmental Stress\n'),
              TextSpan(
                text: 'Prediction',
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Check current greenhouse conditions and predict future plant stress risk.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 22),
        const _StatusBanner(),
        const SizedBox(height: 22),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: EnvironmentalActionCard(
                  badge: 'CE',
                  title: 'Check Current\nEnvironment',
                  subtitle: 'Compare readings with suitable ranges.',
                  onTap: () => _notifyComingSoon(context, 'Check Current Environment'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: EnvironmentalActionCard(
                  badge: 'AI',
                  title: 'Predict Future\nStress',
                  subtitle: 'Get 30- and 60-minute stress-risk levels.',
                  onTap: () => _notifyComingSoon(context, 'Predict Future Stress'),
                ),
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
                child: EnvironmentalActionCard(
                  badge: 'S',
                  title: 'Saved Results',
                  subtitle: 'View previous checks.',
                  onTap: () => _notifyComingSoon(context, 'Saved Results'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: EnvironmentalActionCard(
                  badge: '?',
                  title: 'Help & Guide',
                  subtitle: 'How this model works.',
                  onTap: () => _notifyComingSoon(context, 'Help & Guide'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _notifyComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature — coming soon.')));
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.featureIconBackground,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chevron_left, color: AppColors.primaryGreen),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.featureIconBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: const Text('GH', style: AppTextStyles.featureBadge),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Greenhouse Status', style: AppTextStyles.featureCardTitle),
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.primaryGreen),
                  SizedBox(width: 4),
                  Text(
                    'Ready for analysis',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
