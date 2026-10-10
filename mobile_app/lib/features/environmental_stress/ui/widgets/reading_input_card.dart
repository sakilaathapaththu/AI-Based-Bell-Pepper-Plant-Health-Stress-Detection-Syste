import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';

/// One greenhouse-reading row on the "Check Current Environment" form:
/// a badge + label on the left, a value input (with unit suffix) on the
/// right. White rounded card matching the rest of the module's styling.
class ReadingInputCard extends StatelessWidget {
  const ReadingInputCard({
    super.key,
    required this.badge,
    required this.label,
    required this.controller,
    required this.unit,
  });

  final String badge;
  final String label;
  final TextEditingController controller;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.featureIconBackground,
              shape: BoxShape.circle,
            ),
            child: Text(badge, style: AppTextStyles.featureBadge),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.featureCardTitle),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.left,
              style: AppTextStyles.fieldInput,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Enter value',
                hintStyle: AppTextStyles.fieldHint.copyWith(fontSize: 12.5),
                suffixText: unit,
                suffixStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.titleDark,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same row layout as [ReadingInputCard] but with a dropdown instead of a
/// free-text value (e.g. Growth Stage).
class ReadingDropdownCard extends StatelessWidget {
  const ReadingDropdownCard({
    super.key,
    required this.badge,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String badge;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.featureIconBackground,
              shape: BoxShape.circle,
            ),
            child: Text(badge, style: AppTextStyles.featureBadge),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.featureCardTitle),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                icon: const Icon(Icons.expand_more, size: 18, color: AppColors.subtitleGrey),
                style: AppTextStyles.fieldInput,
                items: [
                  for (final option in options)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
