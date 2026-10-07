import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';

/// Indeterminate loading bar used on the splash screen.
///
/// Extracted as its own widget (rather than inlined in [SplashScreen]) so it
/// can be reused anywhere else a branded loading bar is needed. Uses
/// Flutter's built-in indeterminate animation (no `value` set) so it loops
/// continuously without any custom AnimationController to manage.
class SplashProgressBar extends StatelessWidget {
  const SplashProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: const LinearProgressIndicator(
        minHeight: 6,
        backgroundColor: AppColors.progressTrack,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
      ),
    );
  }
}
