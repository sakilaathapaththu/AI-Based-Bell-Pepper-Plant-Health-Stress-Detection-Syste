import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_strings.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/auth/ui/login_screen.dart';
import 'package:bell_pepper_app/features/onboarding/models/onboarding_slides_data.dart';
import 'package:bell_pepper_app/features/onboarding/ui/widgets/onboarding_dot_indicator.dart';
import 'package:bell_pepper_app/features/onboarding/ui/widgets/onboarding_slide_view.dart';
import 'package:bell_pepper_app/ui/widgets/brand_header.dart';
import 'package:bell_pepper_app/ui/widgets/glow_circle.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// Post-splash carousel introducing the app's main capabilities before the
/// user signs in. Skip and Get Started both lead to [LoginScreen].
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;

  bool get _isLastSlide => _activeIndex == onboardingSlides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLastSlide() {
    _pageController.animateToPage(
      onboardingSlides.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onPrimaryButtonPressed() {
    if (_isLastSlide) {
      _goToLogin();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: GlowCircle(
              size: 240,
              colors: [
                AppColors.lightGreen.withValues(alpha: 0.45),
                AppColors.primaryGreen.withValues(alpha: 0.05),
              ],
            ),
          ),
          Positioned(
            bottom: -110,
            left: -90,
            child: GlowCircle(
              size: 260,
              colors: [
                AppColors.primaryGreen.withValues(alpha: 0.12),
                AppColors.lightGreen.withValues(alpha: 0.0),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  BrandHeader(
                    trailing: TextButton(
                      onPressed: _goToLastSlide,
                      child: const Text(
                        AppStrings.skip,
                        style: AppTextStyles.skipLabel,
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: onboardingSlides.length,
                      onPageChanged: (index) =>
                          setState(() => _activeIndex = index),
                      itemBuilder: (context, index) =>
                          OnboardingSlideView(slide: onboardingSlides[index]),
                    ),
                  ),
                  OnboardingDotIndicator(
                    pageCount: onboardingSlides.length,
                    activeIndex: _activeIndex,
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: AppStrings.getStarted,
                    onPressed: _onPrimaryButtonPressed,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        AppStrings.loginPrompt,
                        style: AppTextStyles.loginPrompt,
                      ),
                      GestureDetector(
                        onTap: _goToLogin,
                        child: const Text(
                          AppStrings.loginLink,
                          style: AppTextStyles.loginLink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
