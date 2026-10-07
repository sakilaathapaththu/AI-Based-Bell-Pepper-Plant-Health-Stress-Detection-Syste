import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/onboarding/models/onboarding_slide.dart';
import 'package:bell_pepper_app/features/onboarding/ui/widgets/onboarding_feature_card.dart';

/// Content (headline, subtitle, feature cards) for one onboarding page.
///
/// Centered vertically within the available height so leftover space on
/// tall screens is split evenly above/below the content instead of
/// collecting as one large gap below the cards. Still scrolls if the
/// content is taller than the viewport (e.g. small devices with wrapped text).
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({super.key, required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slide.title, style: AppTextStyles.onboardingTitle),
                  const SizedBox(height: 12),
                  Text(slide.subtitle, style: AppTextStyles.onboardingSubtitle),
                  const SizedBox(height: 28),
                  for (final feature in slide.features) ...[
                    OnboardingFeatureCard(feature: feature),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
