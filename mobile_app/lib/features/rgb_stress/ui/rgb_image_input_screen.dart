import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/rgb_stress/ui/rgb_stress_result_screen.dart';
import 'package:bell_pepper_app/models/rgb_result.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/rgb_api_service.dart';
import 'package:bell_pepper_app/services/rgb_repository.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';
import 'package:bell_pepper_app/ui/widgets/secondary_button.dart';

/// Capture/upload + analyze screen for RGB Stress Detection. Embedded
/// inside the module's flow (in place, so the shared top bar and bottom nav
/// stay visible); [onBack] returns to the entry screen. "Analyze" calls the
/// backend's `/rgb/predict` endpoint and swaps in the result view; saving
/// to Firestore only happens once the user taps "Save Result" there.
class RgbImageInputScreen extends StatefulWidget {
  const RgbImageInputScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<RgbImageInputScreen> createState() => _RgbImageInputScreenState();
}

class _RgbImageInputScreenState extends State<RgbImageInputScreen> {
  final _apiService = RgbApiService();
  final _repository = RgbRepository();

  Uint8List? _imageBytes;
  String? _imageName;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _isSaved = false;
  RgbResult? _result;

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source, imageQuality: 85);
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
      _showError('Add an RGB image first.');
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final response = await _apiService.predict(imageBytes: imageBytes, filename: imageName);
      if (!mounted) return;
      setState(() {
        _result = RgbResult.fromApiResponse(response);
        _isSaved = false;
      });
    } catch (error) {
      _showError('Could not analyze image: $error');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _handleSaveResult() async {
    final result = _result;
    final uid = AuthService().currentUser?.uid;
    if (result == null || uid == null) return;

    setState(() => _isSaving = true);
    try {
      await _repository.saveResult(uid, result);
      if (!mounted) return;
      setState(() => _isSaved = true);
    } catch (error) {
      _showError('Could not save result: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleScanAgain() {
    setState(() {
      _result = null;
      _imageBytes = null;
      _imageName = null;
      _isSaved = false;
    });
  }

  void _handleSendToRecovery() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Send to Recovery System — coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final imageBytes = _imageBytes;
    if (result != null && imageBytes != null) {
      return RgbStressResultScreen(
        result: result,
        imageBytes: imageBytes,
        onBack: widget.onBack,
        onScanAgain: _handleScanAgain,
        onSaveResult: _handleSaveResult,
        onSendToRecovery: _handleSendToRecovery,
        isSaving: _isSaving,
        isSaved: _isSaved,
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
          'Capture a clear RGB image',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.titleDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Use your phone camera. No sensors are required.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 260,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF1B2E20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: imageBytes != null
              ? Image.memory(imageBytes, fit: BoxFit.cover)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: DottedGuideBox(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.eco_outlined, color: Color(0xFF8BC19B), size: 56),
                        const Spacer(),
                        const Text(
                          'Keep the plant inside the guide',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Image quality checklist', style: AppTextStyles.featureCardTitle),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: _ChecklistItem(label: 'Plant in focus')),
                  Expanded(child: _ChecklistItem(label: 'Good lighting')),
                ],
              ),
              const SizedBox(height: 8),
              const _ChecklistItem(label: 'Leaves clearly visible'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (imageBytes == null) ...[
          PrimaryButton(label: 'Take Photo', onPressed: () => _pickImage(ImageSource.camera)),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Upload from Gallery',
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
        ] else ...[
          PrimaryButton(label: 'Analyze', onPressed: _handleAnalyze, isLoading: _isAnalyzing),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Retake Photo',
            onPressed: _isAnalyzing ? null : () => setState(() => _imageBytes = null),
          ),
        ],
      ],
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check, size: 16, color: AppColors.primaryGreen),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.titleDark),
          ),
        ),
      ],
    );
  }
}

/// Dashed-border frame used as the capture guide before an image is picked.
class DottedGuideBox extends StatelessWidget {
  const DottedGuideBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      const dashWidth = 6.0;
      const dashGap = 5.0;
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
