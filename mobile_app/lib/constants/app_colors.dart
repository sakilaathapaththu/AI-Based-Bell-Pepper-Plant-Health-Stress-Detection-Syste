import 'package:flutter/material.dart';

/// Centralized color palette for the app. Keeping colors here (instead of
/// hardcoding hex values in widgets) keeps the UI consistent and makes
/// re-theming a one-file change.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF2F5F2);
  static const Color surface = Color(0xFFF7F9F7);

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFA5D6A7);
  static const Color progressTrack = Color(0xFFD9E8D9);

  static const Color titleDark = Color(0xFF1B2430);
  static const Color subtitleGrey = Color(0xFF8A9199);
  static const Color loadingGrey = Color(0xFFA0A6AC);

  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x14000000);
  static const Color featureIconBackground = Color(0xFFE6F4E6);
  static const Color dotInactive = Color(0xFFD9E8D9);

  static const Color fieldBorder = Color(0xFFE0E5E0);
  static const Color error = Color(0xFFC62828);

  static const Color navInactive = Color(0xFF9AA39C);
}
