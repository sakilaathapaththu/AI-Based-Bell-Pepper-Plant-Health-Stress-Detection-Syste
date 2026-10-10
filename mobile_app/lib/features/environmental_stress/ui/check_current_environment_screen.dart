import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/environmental_stress/ui/environment_check_result_screen.dart';
import 'package:bell_pepper_app/features/environmental_stress/ui/future_stress_prediction_screen.dart';
import 'package:bell_pepper_app/features/environmental_stress/ui/widgets/reading_input_card.dart';
import 'package:bell_pepper_app/models/environmental_reading.dart';
import 'package:bell_pepper_app/models/stress_prediction.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/environmental_api_service.dart';
import 'package:bell_pepper_app/services/environmental_repository.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// Manual-entry form for the current greenhouse readings. Embedded inside
/// the Environmental Stress Prediction view, so [onBack] just returns to
/// that screen rather than popping a route. "Analyze" calls the backend's
/// rule-based /environmental/check-environment endpoint, saves the reading
/// + result to Firestore (mobile-app side - the backend never persists
/// anything itself), then swaps in the result view in place (keeping the
/// shared top bar and bottom nav visible) rather than pushing a route.
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
  bool _isLoading = false;
  Map<String, dynamic>? _resultStatus;

  bool _isPredicting = false;
  StressPrediction? _prediction;
  bool _isSavingPrediction = false;
  bool _predictionSaved = false;

  final _apiService = EnvironmentalApiService();
  final _repository = EnvironmentalRepository();

  @override
  void dispose() {
    _airTempController.dispose();
    _humidityController.dispose();
    _lightController.dispose();
    _soilTempController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleAnalyze() async {
    final airTemp = double.tryParse(_airTempController.text);
    final humidity = double.tryParse(_humidityController.text);
    final light = double.tryParse(_lightController.text);
    final soilTemp = double.tryParse(_soilTempController.text);

    if (airTemp == null || humidity == null || light == null || soilTemp == null) {
      _showError('Please enter a valid number for every reading.');
      return;
    }

    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      _showError('You need to be signed in to analyze readings.');
      return;
    }

    setState(() => _isLoading = true);

    final timestamp = DateTime.now().toIso8601String();

    try {
      final result = await _apiService.checkEnvironment(
        timestamp: timestamp,
        growthStage: _growthStage,
        airTemperatureC: airTemp,
        relativeHumidityPct: humidity,
        lightIntensityLux: light,
        soilTemperatureC: soilTemp,
      );

      final environmentStatus = Map<String, dynamic>.from(
        result['environment_status'] as Map,
      );

      await _repository.saveReading(
        uid,
        EnvironmentalReading(
          timestamp: timestamp,
          growthStage: _growthStage,
          airTemperatureC: airTemp,
          relativeHumidityPct: humidity,
          lightIntensityLux: light,
          soilTemperatureC: soilTemp,
          environmentStatus: environmentStatus,
        ),
      );

      if (!mounted) return;
      setState(() => _resultStatus = environmentStatus);
    } catch (error) {
      _showError('Could not analyze environment: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePredictFutureStress() async {
    final airTemp = double.tryParse(_airTempController.text);
    final humidity = double.tryParse(_humidityController.text);
    final light = double.tryParse(_lightController.text);
    final soilTemp = double.tryParse(_soilTempController.text);

    if (airTemp == null || humidity == null || light == null || soilTemp == null) {
      _showError('Please enter a valid number for every reading.');
      return;
    }

    setState(() => _isPredicting = true);

    try {
      final response = await _apiService.predict(
        timestamp: DateTime.now().toIso8601String(),
        growthStage: _growthStage,
        airTemperatureC: airTemp,
        relativeHumidityPct: humidity,
        lightIntensityLux: light,
        soilTemperatureC: soilTemp,
      );

      if (!mounted) return;
      setState(() {
        _prediction = StressPrediction.fromApiResponse(response);
        _predictionSaved = false;
      });
    } catch (error) {
      _showError('Could not predict future stress: $error');
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  Future<void> _handleSavePrediction() async {
    final prediction = _prediction;
    final uid = AuthService().currentUser?.uid;
    if (prediction == null || uid == null) return;

    setState(() => _isSavingPrediction = true);
    try {
      await _repository.savePrediction(uid, prediction);
      if (!mounted) return;
      setState(() => _predictionSaved = true);
    } catch (error) {
      _showError('Could not save prediction: $error');
    } finally {
      if (mounted) setState(() => _isSavingPrediction = false);
    }
  }

  void _handleSendToRecovery() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Send to Recovery — coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final prediction = _prediction;
    if (prediction != null) {
      return FutureStressPredictionScreen(
        growthStage: prediction.growthStage,
        stressType: prediction.stressType,
        risk30m: prediction.risk30m,
        risk60m: prediction.risk60m,
        explanation: prediction.explanation,
        mainContributingFactors: prediction.mainContributingFactors,
        onBack: () => setState(() => _prediction = null),
        onSaveResult: _handleSavePrediction,
        onSendToRecovery: _handleSendToRecovery,
        isSaving: _isSavingPrediction,
        isSaved: _predictionSaved,
      );
    }

    final resultStatus = _resultStatus;
    if (resultStatus != null) {
      return EnvironmentCheckResultScreen(
        growthStage: _growthStage,
        environmentStatus: resultStatus,
        onBack: () => setState(() => _resultStatus = null),
        onPredictFutureStress: _handlePredictFutureStress,
        isPredicting: _isPredicting,
      );
    }

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
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
