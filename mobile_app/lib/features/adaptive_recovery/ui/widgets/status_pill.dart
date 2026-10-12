import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';

/// Small colored pill used on the Recovery Assessment screen to show each
/// component's stress status (e.g. MODERATE, HIGH, HIGH RISK) or a neutral
/// "no data" state when today's result is missing.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.isNeutral = false, this.showDot = false});

  final String label;
  final bool isNeutral;

  /// When true, prefixes the label with a colored "● " dot, matching the
  /// "● HIGH PRIORITY" style used for Recovery Plan action items.
  final bool showDot;

  Color get _color {
    if (isNeutral) return AppColors.loadingGrey;
    final upper = label.toUpperCase();
    if (upper.contains('HIGH')) return const Color(0xFFD32F2F);
    if (upper.contains('MODERATE') || upper.contains('MEDIUM')) return const Color(0xFFEF6C00);
    if (upper.contains('LOW') || upper.contains('HEALTHY')) return AppColors.primaryGreen;
    return AppColors.subtitleGrey;
  }

  /// Maps a recovery plan `priority` string ("High"/"Medium"/"Low") to the
  /// pill color used across Adaptive Recovery screens.
  static Color colorForPriority(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFFD32F2F);
      case 'MEDIUM':
        return const Color(0xFFEF6C00);
      default:
        return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final text = showDot ? '●  ${label.toUpperCase()}' : label.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
