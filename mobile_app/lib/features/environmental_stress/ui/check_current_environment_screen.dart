import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/environmental_stress/ui/widgets/reading_input_card.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// Manual-entry form for the current greenhouse readings. Embedded inside
/// the Environmental Stress Prediction view, so [onBack] just returns to
/// that screen rather than popping a route. Not wired to any backend or
/// model yet — "Analyze" currently just acknowledges the tap.
class CheckCurrentEnvironmentScreen extends StatefulWidget {
  const CheckCurrentEnvironmentScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<CheckCurrentEnvironmentScreen> createState() =>
      _CheckCurrentEnvironmentScreenState();
}

class _CheckCurrentEnvironmentScreenState
    extends State<CheckCurrentEnvironmentScreen> {
  static const _growthStages = ['Seedling', 'Vegetative', 'Flowering', 'Fruiting'];

  final _airTempController = TextEditingController();
  final _humidityController = TextEditingController();
  final _lightController = TextEditingController();
  final _soilTempController = TextEditingController();
  String _growthStage = _growthStages[2];

  @override
  void dispose() {
    _airTempController.dispose();
    _humidityController.dispose();
    _lightController.dispose();
    _soilTempController.dispose();
    super.dispose();
  }

  void _handleAnalyze() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Environment analysis — coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onBack,
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
          'Check Current\nEnvironment',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.titleDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Enter the latest greenhouse readings from your existing measuring tools.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 22),
        ReadingInputCard(
          badge: 'T',
          label: 'Air Temperature (°C)',
          controller: _airTempController,
          unit: '°C',
        ),
        const SizedBox(height: 14),
        ReadingInputCard(
          badge: 'RH',
          label: 'Humidity (%)',
          controller: _humidityController,
          unit: '%',
        ),
        const SizedBox(height: 14),
        ReadingInputCard(
          badge: 'L',
          label: 'Light Intensity',
          controller: _lightController,
          unit: 'lux',
        ),
        const SizedBox(height: 14),
        ReadingInputCard(
          badge: 'ST',
          label: 'Soil Temperature (°C)',
          controller: _soilTempController,
          unit: '°C',
        ),
        const SizedBox(height: 14),
        ReadingDropdownCard(
          badge: 'GS',
          label: 'Growth Stage',
          value: _growthStage,
          options: _growthStages,
          onChanged: (value) {
            if (value != null) setState(() => _growthStage = value);
          },
        ),
        const SizedBox(height: 18),
        const Text(
          'Use scientifically validated ranges for the selected growth stage.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Analyze Current Environment',
          onPressed: _handleAnalyze,
        ),
      ],
    );
  }
}
