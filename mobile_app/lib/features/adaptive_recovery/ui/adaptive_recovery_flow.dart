import 'package:flutter/material.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/models/recovery_plan.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/ui/adaptive_recovery_home_screen.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/ui/recovery_assessment_screen.dart';

/// Owns navigation across the Adaptive Recovery module, swapping content in
/// place (keeping the shared top bar and bottom nav visible, same pattern as
/// [RgbStressFlow]/[ThermalStressFlow]) rather than pushing routes.
///
/// Flow: tapping the dashboard tile lands straight on
/// [RecoveryAssessmentScreen] (skipping the Adaptive Recovery summary).
/// Generating a plan there swaps to [AdaptiveRecoveryHomeScreen] showing the
/// newly generated plan. From there, "Start Recovery Assessment" (empty
/// state) swaps back to the assessment screen, and [onBack] returns the tab
/// to the dashboard.
class AdaptiveRecoveryFlow extends StatefulWidget {
  const AdaptiveRecoveryFlow({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdaptiveRecoveryFlow> createState() => _AdaptiveRecoveryFlowState();
}

class _AdaptiveRecoveryFlowState extends State<AdaptiveRecoveryFlow> {
  bool _showSummary = false;
  RecoveryPlan? _plan;

  @override
  Widget build(BuildContext context) {
    if (_showSummary) {
      return AdaptiveRecoveryHomeScreen(
        onBack: () => setState(() => _showSummary = false),
        initialPlan: _plan,
        onStartAssessment: () => setState(() => _showSummary = false),
      );
    }

    return RecoveryAssessmentScreen(
      onBack: widget.onBack,
      onPlanGenerated: (plan) => setState(() {
        _plan = plan;
        _showSummary = true;
      }),
    );
  }
}
