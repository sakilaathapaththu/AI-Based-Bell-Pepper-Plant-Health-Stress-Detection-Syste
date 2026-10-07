import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_strings.dart';
import 'package:bell_pepper_app/constants/app_theme.dart';
import 'package:bell_pepper_app/ui/splash_screen.dart';

class PepperCareApp extends StatelessWidget {
  const PepperCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
