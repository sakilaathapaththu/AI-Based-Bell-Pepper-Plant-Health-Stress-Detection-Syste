import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_assets.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_strings.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/onboarding/ui/onboarding_screen.dart';
import 'package:bell_pepper_app/ui/widgets/splash_progress_bar.dart';

/// Minimum time the splash branding stays on screen before the app moves on
/// to onboarding. Startup work (auth/session check, Firebase init, cached
/// data warm-up) will run concurrently with this delay as those features land.
const Duration _splashMinDuration = Duration(seconds: 3);

/// App entry screen: shows branding for [_splashMinDuration], then hands off
/// to onboarding.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(_splashMinDuration, _goToOnboarding);
  }

  void _goToOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _SplashBranding(),
              const Spacer(flex: 5),
              const SplashProgressBar(),
              const SizedBox(height: 12),
              const Text(AppStrings.loading, style: AppTextStyles.loadingLabel),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBranding extends StatelessWidget {
  const _SplashBranding();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(AppStrings.appName, style: AppTextStyles.appTitle),
        const SizedBox(height: 8),
        const Text(AppStrings.appTagline, style: AppTextStyles.appSubtitle),
        const SizedBox(height: 32),
        Image.asset(
          AppAssets.pepperLogo,
          width: 180,
          height: 180,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 32),
        const Text(AppStrings.splashCaption, style: AppTextStyles.caption),
      ],
    );
  }
}
