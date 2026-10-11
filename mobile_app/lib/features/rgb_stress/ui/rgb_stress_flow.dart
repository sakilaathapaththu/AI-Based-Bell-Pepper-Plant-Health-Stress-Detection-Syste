import 'package:flutter/material.dart';
import 'package:bell_pepper_app/features/rgb_stress/ui/rgb_image_input_screen.dart';
import 'package:bell_pepper_app/features/rgb_stress/ui/rgb_stress_screen.dart';

/// Owns navigation between the RGB Stress Detection entry screen and the
/// capture/upload screen, swapping content in place (keeping the shared
/// top bar and bottom nav visible) rather than pushing routes. [onBack]
/// returns the tab to the dashboard.
class RgbStressFlow extends StatefulWidget {
  const RgbStressFlow({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<RgbStressFlow> createState() => _RgbStressFlowState();
}

class _RgbStressFlowState extends State<RgbStressFlow> {
  bool _showInput = false;

  @override
  Widget build(BuildContext context) {
    if (_showInput) {
      return RgbImageInputScreen(onBack: () => setState(() => _showInput = false));
    }
    return RgbStressScreen(
      onBack: widget.onBack,
      onScanPlant: () => setState(() => _showInput = true),
    );
  }
}
