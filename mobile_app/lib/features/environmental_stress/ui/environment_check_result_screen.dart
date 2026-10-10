import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/environmental_stress/ui/widgets/environment_status_card.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// Shows the backend's `/environmental/check-environment` result: an
/// overall status banner plus one [EnvironmentStatusCard] per field. The
/// reading itself was already saved to Firestore before this screen opens.
/// Embedded inside the Check Current Environment form (in place, so the
/// shared top bar and bottom nav stay visible) rather than pushed as a
/// separate route; [onBack] returns to the form.
class EnvironmentCheckResultScreen extends StatelessWidget {
  const EnvironmentCheckResultScreen({
    super.key,
    required this.growthStage,
    required this.environmentStatus,
    required this.onBack,
    required this.onPredictFutureStress,
    this.isPredicting = false,
  });

  final String growthStage;
  final Map<String, dynamic> environmentStatus;
  final VoidCallback onBack;
  final VoidCallback onPredictFutureStress;
  final bool isPredicting;

  static const _fieldOrder = [
    ('air_temperature_c', 'T', 'Air Temperature', '°C'),
    ('relative_humidity_pct', 'RH', 'Humidity', '%'),
    ('light_intensity_lux', 'L', 'Light Intensity', ''),
    ('soil_temperature_c', 'ST', 'Soil Temperature', '°C'),
  ];

  int get _factorsOutsideRange {
    return environmentStatus.values.where((info) {
      final status = (info as Map)['status'] as String?;
      return status != null && status != 'Normal';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final outsideCount = _factorsOutsideRange;
    final needsAttention = outsideCount > 0;
    final cards = [
      for (final (key, badge, label, unit) in _fieldOrder) _buildCard(key, badge, label, unit),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onBack,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.featureIconBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.primaryGreen),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Current Environmental\nCheck',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.titleDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Current values compared with suitable ranges for $growthStage stage.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: needsAttention ? const Color(0xFFFFF3E0) : AppColors.featureIconBackground,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overall Status',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    needsAttention ? Icons.error : Icons.check_circle,
                    color: needsAttention ? const Color(0xFFEF6C00) : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    needsAttention ? 'Needs Attention' : 'Good',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: needsAttention ? const Color(0xFFEF6C00) : AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                needsAttention
                    ? '$outsideCount factor${outsideCount == 1 ? '' : 's'} outside the suitable range.'
                    : 'All factors are within the suitable range.',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.subtitleGrey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 14),
                Expanded(
                  child: i + 1 < cards.length ? cards[i + 1] : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Predict Future Stress',
          onPressed: onPredictFutureStress,
          isLoading: isPredicting,
        ),
      ],
    );
  }

  Widget _buildCard(String key, String badge, String label, String unit) {
    final info = environmentStatus[key] as Map<String, dynamic>?;
    if (info == null) {
      return EnvironmentStatusCard(
        badge: badge,
        label: label,
        currentValue: '—',
        suitableRange: '—',
        status: 'Normal',
      );
    }

    final value = info['value'];
    final range = info['suitable_range'] as List?;
    final status = info['status'] as String? ?? 'Normal';
    final direction = info['adjustment_direction'] as String?;

    final rangeText = range != null && range.length == 2
        ? '${_formatNumber(range[0])}–${_formatNumber(range[1])}$unit'
        : 'Normal at night';

    return EnvironmentStatusCard(
      badge: badge,
      label: label,
      currentValue: '${_formatNumber(value)}$unit',
      suitableRange: rangeText,
      status: status,
      adjustmentDirection: direction,
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '—';
    final number = value is num ? value : num.tryParse(value.toString());
    if (number == null) return value.toString();
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }
}
