import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';

/// Carousel position indicator: a filled dot for the active page, outlined
/// dots for the rest.
class OnboardingDotIndicator extends StatelessWidget {
  const OnboardingDotIndicator({
    super.key,
    required this.pageCount,
    required this.activeIndex,
  });

  final int pageCount;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final bool isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primaryGreen : Colors.transparent,
            border: isActive
                ? null
                : Border.all(color: AppColors.dotInactive, width: 1.5),
          ),
        );
      }),
    );
  }
}
