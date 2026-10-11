import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/thermal_stress/ui/thermal_stress_result_screen.dart';
import 'package:bell_pepper_app/features/thermal_stress/ui/widgets/thermal_image_source_sheet.dart';
import 'package:bell_pepper_app/models/thermal_result.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/thermal_api_service.dart';
import 'package:bell_pepper_app/services/thermal_repository.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// Capture/upload + analyze screen for Thermal Stress Detection. Embedded
/// inside the module's flow (in place, so the shared top bar and bottom nav
/// stay visible); [onBack] returns to the entry screen. "Analyze" calls the
/// backend's `/thermal/predict` endpoint, saves the result to Firestore
/// (mobile-app side - the backend never persists anything itself), then
/// swaps in the result view.
class ThermalImageInputScreen extends StatefulWidget {
  const ThermalImageInputScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ThermalImageInputScreen> createState() => _ThermalImageInputScreenState();
}

class _ThermalImageInputScreenState extends State<ThermalImageInputScreen> {
  final _apiService = ThermalApiService();
  final _repository = ThermalRepository();

  Uint8List? _imageBytes;
  String? _imageName;
  bool _isAnalyzing = false;
  ThermalResult? _result;

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final image = await showThermalImageSourceSheet(context);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = image.name;
    });
  }

  Future<void> _handleAnalyze() async {
    final imageBytes = _imageBytes;
    final imageName = _imageName;
    if (imageBytes == null || imageName == null) {
      _showError('Add a thermal image first.');
      return;
    }

    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      _showError('You need to be signed in to analyze an image.');
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final response = await _apiService.predict(
        imageBytes: imageBytes,
        filename: imageName,
      );

      // Image upload to Firebase Storage is disabled for now (storage.rules
      // not deployed yet - see ImageStorageService) - save the prediction
      // without an image URL until that's wired back in.
      final result = ThermalResult.fromApiResponse(response);
      await _repository.saveResult(uid, result);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      _showError('Could not analyze thermal image: $error');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return ThermalStressResultScreen(
        result: result,
        onBack: () => setState(() => _result = null),
      );
    }

    final imageBytes = _imageBytes;

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
          'Thermal Image Input',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.titleDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Capture or upload the latest thermal image.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 22),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 240,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.featureIconBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: imageBytes != null
                ? Image.memory(imageBytes, fit: BoxFit.cover)
                : const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 72,
                      color: AppColors.subtitleGrey,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Analyze',
          onPressed: _handleAnalyze,
          isLoading: _isAnalyzing,
        ),
        const SizedBox(height: 14),
        const Text(
          'Tip: keep the plant within the thermal camera frame.',
          style: AppTextStyles.screenSubtitle,
        ),
      ],
    );
  }
}
