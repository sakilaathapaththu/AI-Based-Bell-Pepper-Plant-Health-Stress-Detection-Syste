import 'package:bell_pepper_app/features/onboarding/models/onboarding_slide.dart';

/// Static copy for the onboarding carousel, one slide per app capability
/// group (environmental + prediction, visual/thermal detection, recovery).
const List<OnboardingSlide> onboardingSlides = [
  OnboardingSlide(
    title: 'Grow smarter\nwith PepperCare AI',
    subtitle:
        'AI-powered insights to help protect your peppers and make '
        'better greenhouse decisions.',
    features: [
      OnboardingFeature(
        badge: 'CE',
        title: 'Check Current Environment',
        description: 'See which environmental factors are high, low, or normal.',
      ),
      OnboardingFeature(
        badge: 'AI',
        title: 'Predict Future Stress',
        description: 'Estimate plant stress risk for the next 30 and 60 minutes.',
      ),
      OnboardingFeature(
        badge: '?',
        title: 'Get Clear Insights',
        description: 'Understand the main factors behind each prediction.',
      ),
    ],
  ),
  OnboardingSlide(
    title: 'Spot stress\nbefore it spreads',
    subtitle:
        'Scan leaf and canopy images to catch early signs of stress '
        'across your plants.',
    features: [
      OnboardingFeature(
        badge: 'RGB',
        title: 'Visual Stress Detection',
        description: 'Analyze leaf color and texture for early stress signs.',
      ),
      OnboardingFeature(
        badge: 'TH',
        title: 'Thermal Evidence',
        description: 'Capture heat patterns that reveal hidden plant stress.',
      ),
      OnboardingFeature(
        badge: 'GC',
        title: 'Grad-CAM Explanations',
        description: 'See exactly which regions influenced each result.',
      ),
    ],
  ),
  OnboardingSlide(
    title: 'Act with\nconfidence',
    subtitle:
        'Get tailored recovery plans and track how your greenhouse '
        'responds over time.',
    features: [
      OnboardingFeature(
        badge: 'RP',
        title: 'Recovery Plans',
        description: 'Step-by-step actions tailored to the detected stress.',
      ),
      OnboardingFeature(
        badge: 'FU',
        title: 'Fused Diagnosis',
        description: 'Combine RGB, thermal, and environmental signals.',
      ),
      OnboardingFeature(
        badge: 'TR',
        title: 'Track Outcomes',
        description: 'Monitor recovery progress after each action.',
      ),
    ],
  ),
];
