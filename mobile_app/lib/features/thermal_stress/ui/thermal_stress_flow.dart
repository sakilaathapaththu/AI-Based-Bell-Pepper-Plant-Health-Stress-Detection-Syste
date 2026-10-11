import 'package:flutter/material.dart';
import 'package:bell_pepper_app/features/thermal_stress/ui/thermal_image_input_screen.dart';
import 'package:bell_pepper_app/features/thermal_stress/ui/thermal_stress_screen.dart';

/// Owns navigation between the Thermal Stress Detection entry screen and
/// the capture/upload screen, swapping content in place (keeping the
/// shared top bar and bottom nav visible) rather than pushing routes.
/// [onBack] returns the tab to the dashboard.
class ThermalStressFlow extends StatefulWidget {
  const ThermalStressFlow({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ThermalStressFlow> createState() => _ThermalStressFlowState();
}

class _ThermalStressFlowState extends State<ThermalStressFlow> {
  bool _showInput = false;

  @override
  Widget build(BuildContext context) {
    if (_showInput) {
      return ThermalImageInputScreen(onBack: () => setState(() => _showInput = false));
    }
    return ThermalStressScreen(
      onBack: widget.onBack,
      onContinue: () => setState(() => _showInput = true),
    );
  }
}
