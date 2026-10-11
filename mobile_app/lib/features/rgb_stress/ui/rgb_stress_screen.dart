import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/models/rgb_result.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/rgb_repository.dart';

/// Entry screen for RGB Stress Detection: hero intro, two actions (Scan
/// Plant / Recovery Tracking), the most recent saved scan (if any), and a
/// capture tip. Embedded inside the Home tab (keeping the shared top bar
/// and bottom nav visible); [onBack] returns to the dashboard, [onScanPlant]
/// advances to the capture screen.
class RgbStressScreen extends StatelessWidget {
  const RgbStressScreen({super.key, required this.onBack, required this.onScanPlant});

  final VoidCallback onBack;
  final VoidCallback onScanPlant;

  void _notifyComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature — coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI-Based RGB Bell Pepper\nPlant Stress Detection',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Detect visible abiotic stress and estimate severity using a normal smartphone photo.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text('What would you like to do?', style: AppTextStyles.featureCardTitle),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Scan Plant',
                  subtitle: 'Take or upload an RGB image',
                  onTap: onScanPlant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ActionCard(
                  icon: Icons.show_chart_rounded,
                  title: 'Recovery Tracking',
                  subtitle: 'Track stressed plants until healthy',
                  onTap: () => _notifyComingSoon(context, 'Recovery Tracking'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (user != null && !user.isAnonymous)
          FutureBuilder<RgbResult?>(
            future: RgbRepository().getLatestResult(user.uid),
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) return const SizedBox.shrink();
              return _RecentPlantCard(result: result);
            },
          ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8ECFB),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline, color: Color(0xFF3568C7), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tip for better results',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3568C7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Capture the whole upper canopy clearly and avoid strong shadows.',
                      style: AppTextStyles.featureCardDescription.copyWith(
                        color: const Color(0xFF3F5CA8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
                child: Icon(icon, color: AppColors.primaryGreen, size: 20),
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

class _RecentPlantCard extends StatelessWidget {
  const _RecentPlantCard({required this.result});

  final RgbResult result;

  @override
  Widget build(BuildContext context) {
    final statusLabel = result.isHealthy
        ? 'Healthy'
        : '${result.displayStressType ?? 'Stress'} • ${result.severity ?? '—'}';
    final scannedAt = result.createdAt;
    final scannedLabel = scannedAt == null
        ? 'Just now'
        : 'Last scan: ${TimeOfDay.fromDateTime(scannedAt).format(context)}';

    return Container(
      width: double.infinity,
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent plant', style: AppTextStyles.featureCardDescription),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.featureIconBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.isHealthy ? 'Healthy' : 'Monitoring',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Latest Scan', style: AppTextStyles.featureCardTitle),
          const SizedBox(height: 4),
          Text(
            statusLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
          ),
          const SizedBox(height: 4),
          Text(scannedLabel, style: AppTextStyles.featureCardDescription),
        ],
      ),
    );
  }
}
