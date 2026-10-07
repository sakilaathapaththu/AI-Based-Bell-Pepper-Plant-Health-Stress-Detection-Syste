import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_assets.dart';
import 'package:bell_pepper_app/constants/app_strings.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';

/// Logo + "PepperCare AI" wordmark + tagline, used at the top of onboarding,
/// login, and other top-level screens. [trailing] holds a screen-specific
/// action (e.g. a Skip button) and defaults to empty space.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            AppAssets.pepperLogo,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: AppStrings.brandWordmarkPepper,
                      style: AppTextStyles.brandWordmark,
                    ),
                    TextSpan(
                      text: AppStrings.brandWordmarkCare,
                      style: AppTextStyles.brandWordmarkAccent,
                    ),
                    TextSpan(
                      text: AppStrings.brandWordmarkSuffix,
                      style: AppTextStyles.brandWordmark,
                    ),
                  ],
                ),
              ),
              const Text(
                AppStrings.appTagline,
                style: AppTextStyles.brandSubtitle,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
