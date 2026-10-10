import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_assets.dart';
import 'package:bell_pepper_app/features/home/models/dashboard_module.dart';

/// Static copy for the "Your Modules" grid on the Home dashboard. Statuses
/// reflect which detection pipelines are wired up end-to-end today.
const List<DashboardModule> dashboardModules = [
  DashboardModule(
    title: 'RGB Stress Detection',
    description: 'Detect visible plant stress using RGB images.',
    icon: Icons.camera_alt_outlined,
    accentColor: Color(0xFF2F8F6B),
    status: ModuleStatus.comingSoon,
    imageAsset: AppAssets.rgbStressIcon,
  ),
  DashboardModule(
    title: 'Thermal Stress Detection',
    description: 'Identify physiological stress from thermal images.',
    icon: Icons.thermostat_outlined,
    accentColor: Color(0xFFE2762C),
    status: ModuleStatus.comingSoon,
    imageAsset: AppAssets.thermalStressIcon,
  ),
  DashboardModule(
    title: 'Environmental Stress Prediction',
    description: 'Check current conditions and predict future stress risk.',
    icon: Icons.insights_outlined,
    accentColor: Color(0xFF2E7D32),
    status: ModuleStatus.implemented,
  ),
  DashboardModule(
    title: 'Adaptive Recovery Plan',
    description: 'Generate recovery guidance from combined component outputs.',
    icon: Icons.healing_outlined,
    accentColor: Color(0xFF3568C7),
    status: ModuleStatus.comingSoon,
    imageAsset: AppAssets.recoveryPlanIcon,
  ),
];
