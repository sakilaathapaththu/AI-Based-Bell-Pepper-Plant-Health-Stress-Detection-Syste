import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';

/// Bottom sheet letting the user pick "Take Photo" or "Choose from Gallery"
/// for the thermal image, so both capture and upload are available from a
/// single tap target (matching the module's single upload box in the UI).
Future<XFile?> showThermalImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<XFile?>(
    context: context,
    backgroundColor: AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Thermal Image', style: AppTextStyles.featureCardTitle),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.photo_camera_outlined,
                label: 'Take Photo',
                onTap: () async {
                  final image = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop(image);
                },
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () async {
                  final image = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop(image);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.featureIconBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.titleDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
