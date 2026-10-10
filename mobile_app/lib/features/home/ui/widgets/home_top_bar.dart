import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/ui/widgets/brand_header.dart';

/// Brand header + profile avatar shortcut, reused at the top of every tab
/// so the signed-in area reads as one consistent app shell.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return BrandHeader(
      trailing: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onProfileTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.featureIconBackground,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            color: AppColors.primaryGreen,
            size: 22,
          ),
        ),
      ),
    );
  }
}
