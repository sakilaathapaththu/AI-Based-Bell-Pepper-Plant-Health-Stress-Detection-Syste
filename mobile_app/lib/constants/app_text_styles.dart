import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';

/// Shared text styles. Screens should reuse these instead of inlining
/// TextStyle(...) so typography stays consistent across the app.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle appTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.titleDark,
    letterSpacing: 0.2,
  );

  static const TextStyle appSubtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleGrey,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryGreen,
  );

  static const TextStyle loadingLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.loadingGrey,
  );

  static const TextStyle brandWordmark = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    color: AppColors.titleDark,
  );

  static const TextStyle brandWordmarkAccent = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryGreen,
  );

  static const TextStyle brandSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleGrey,
  );

  static const TextStyle skipLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.subtitleGrey,
  );

  static const TextStyle onboardingTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.titleDark,
    height: 1.25,
  );

  static const TextStyle onboardingSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleGrey,
    height: 1.4,
  );

  static const TextStyle featureCardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.titleDark,
  );

  static const TextStyle featureCardDescription = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleGrey,
    height: 1.35,
  );

  static const TextStyle featureBadge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryGreen,
  );

  static const TextStyle primaryButtonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle loginPrompt = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleGrey,
  );

  static const TextStyle loginLink = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryGreen,
  );

  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.titleDark,
  );

  static const TextStyle screenSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleGrey,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.titleDark,
  );

  static const TextStyle fieldInput = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.titleDark,
  );

  static const TextStyle fieldHint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.loadingGrey,
  );

  static const TextStyle linkLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryGreen,
  );

  static const TextStyle secondaryButtonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryGreen,
  );

  static const TextStyle dividerLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleGrey,
  );
}
