import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';

/// Single source of truth for MaterialApp-level theming.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        surface: AppColors.surface,
      ),
      fontFamily: 'Roboto',
    );
  }
}
