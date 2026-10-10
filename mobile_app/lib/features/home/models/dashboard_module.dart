import 'package:flutter/material.dart';

/// Whether a module card on the dashboard is usable yet.
enum ModuleStatus { implemented, comingSoon }

/// One capability tile on the Home dashboard (e.g. "RGB Stress Detection").
class DashboardModule {
  const DashboardModule({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.status,
    this.imageAsset,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final ModuleStatus status;

  /// Photo thumbnail shown instead of [icon] when set (e.g. a real leaf or
  /// thermal capture rather than a generic glyph).
  final String? imageAsset;
}
