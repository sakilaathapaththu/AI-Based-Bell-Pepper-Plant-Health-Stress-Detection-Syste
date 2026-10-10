import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/home/models/dashboard_module.dart';

/// Dashboard tile for one [DashboardModule]. All cards share the same
/// resting look — only an actual tap (the InkWell ripple) highlights a
/// card, so nothing reads as pre-selected.
class ModuleCard extends StatelessWidget {
  const ModuleCard({super.key, required this.module, this.onTap});

  final DashboardModule module;
  final VoidCallback? onTap;

  bool get _isImplemented => module.status == ModuleStatus.implemented;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                module.accentColor.withValues(alpha: 0.06),
                AppColors.cardBackground,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: module.accentColor.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ModuleAvatar(module: module),
                  if (_isImplemented)
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: module.accentColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        color: module.accentColor,
                        size: 15,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(module.title, style: AppTextStyles.featureCardTitle),
              const SizedBox(height: 6),
              Text(
                module.description,
                style: AppTextStyles.featureCardDescription,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _StatusBadge(accentColor: module.accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Module icon: a photo thumbnail when [DashboardModule.imageAsset] is set
/// (e.g. RGB/thermal/recovery), otherwise a colored glyph chip.
class _ModuleAvatar extends StatelessWidget {
  const _ModuleAvatar({required this.module});

  final DashboardModule module;

  @override
  Widget build(BuildContext context) {
    final imageAsset = module.imageAsset;
    if (imageAsset != null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: module.accentColor.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          image: DecorationImage(image: AssetImage(imageAsset), fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            module.accentColor,
            module.accentColor.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: module.accentColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(module.icon, color: Colors.white, size: 22),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const Text(
            'Start',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
