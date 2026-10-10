import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';

/// One field's result card on the "Current Environmental Check" result
/// screen: badge + label, current value, suitable range, and a
/// color-coded status pill (High/Slightly High/Normal/Slightly Low/Low).
class EnvironmentStatusCard extends StatelessWidget {
  const EnvironmentStatusCard({
    super.key,
    required this.badge,
    required this.label,
    required this.currentValue,
    required this.suitableRange,
    required this.status,
    this.adjustmentDirection,
  });

  final String badge;
  final String label;
  final String currentValue;
  final String suitableRange;
  final String status;
  final String? adjustmentDirection;

  Color get _statusColor {
    switch (status) {
      case 'High':
      case 'Low':
        return const Color(0xFFEF6C00);
      case 'Slightly High':
      case 'Slightly Low':
        return const Color(0xFFF9A825);
      case 'Normal':
      default:
        return AppColors.primaryGreen;
    }
  }

  Color get _statusBackground => _statusColor.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.featureIconBackground,
                  shape: BoxShape.circle,
                ),
                child: Text(badge, style: AppTextStyles.featureBadge),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: AppTextStyles.featureCardTitle)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Current',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
          ),
          Text(
            currentValue,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _statusColor),
          ),
          const SizedBox(height: 6),
          const Text(
            'Suitable Range',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
          ),
          Text(
            suitableRange,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.titleDark),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Status',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor),
                ),
              ),
            ],
          ),
          if (adjustmentDirection != null) ...[
            const Divider(height: 18),
            Text(
              adjustmentDirection!,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.subtitleGrey),
            ),
          ],
        ],
      ),
    );
  }
}
