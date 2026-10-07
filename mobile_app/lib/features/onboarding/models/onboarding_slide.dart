/// One highlighted capability shown inside an [OnboardingSlide] card.
class OnboardingFeature {
  const OnboardingFeature({
    required this.badge,
    required this.title,
    required this.description,
  });

  /// Short 1-2 letter label shown inside the icon circle (e.g. "AI", "RGB").
  final String badge;
  final String title;
  final String description;
}

/// Content for a single page of the onboarding carousel.
class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.features,
  });

  final String title;
  final String subtitle;
  final List<OnboardingFeature> features;
}
