import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// Entry screen for Thermal Stress Detection: a preview of the upload
/// action plus a CTA button. Embedded inside the Home tab (keeping the
/// shared top bar and bottom nav visible); [onBack] returns to the
/// dashboard, [onContinue] advances to the real capture/upload screen.
class ThermalStressScreen extends StatelessWidget {
  const ThermalStressScreen({super.key, required this.onBack, required this.onContinue});

  final VoidCallback onBack;
  final VoidCallback onContinue;

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
          'Thermal Stress Detection',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.titleDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Analyze a thermal image to identify physiological stress.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 22),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onContinue,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: AppColors.featureIconBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.cardBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.primaryGreen, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Upload Thermal Image',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.titleDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'JPG or PNG • clear plant view',
                  style: AppTextStyles.screenSubtitle,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Upload Thermal Image', onPressed: onContinue),
      ],
    );
  }
}
