import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/models/recovery_plan.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/ui/recovery_plan_result_screen.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/ui/widgets/status_pill.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';
import 'package:bell_pepper_app/ui/widgets/secondary_button.dart';

/// Summary screen for the Adaptive Recovery module, reached after a recovery
/// plan has been generated on the Recovery Assessment screen (see
/// AdaptiveRecoveryFlow, which owns navigation between the two). Shows the
/// latest generated [RecoveryPlan] if one is available this session, or an
/// empty state that hands back to the assessment flow via
/// [onStartAssessment] otherwise.
///
/// Persistence note: the backend doesn't store recovery plans, and there is
/// no existing "latest plan" Firestore collection to read from, so the
/// latest plan is held in-memory for the lifetime of this screen (passed in
/// as [initialPlan] right after a successful generation, or null on a fresh
/// visit) rather than persisted - consistent with how this feature is
/// otherwise entirely session-driven (RecoveryAssessmentScreen itself keeps
/// its generated plan in local State, not Firestore).
class AdaptiveRecoveryHomeScreen extends StatefulWidget {
  const AdaptiveRecoveryHomeScreen({
    super.key,
    required this.onBack,
    required this.onStartAssessment,
    this.initialPlan,
  });

  final VoidCallback onBack;

  /// Hands navigation back to [AdaptiveRecoveryFlow] to show the assessment
  /// screen (empty-state "Start Recovery Assessment" action).
  final VoidCallback onStartAssessment;

  /// A just-generated plan to show immediately (e.g. after returning from
  /// the assessment flow), or null to show whatever this screen currently
  /// holds (nothing, on a fresh visit).
  final RecoveryPlan? initialPlan;

  @override
  State<AdaptiveRecoveryHomeScreen> createState() => _AdaptiveRecoveryHomeScreenState();
}

class _AdaptiveRecoveryHomeScreenState extends State<AdaptiveRecoveryHomeScreen> {
  RecoveryPlan? _plan;
  bool _showingDetail = false;
  bool _autoExpandExplanation = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    if (_showingDetail && plan != null) {
      return RecoveryPlanResultScreen(
        plan: plan,
        autoExpandExplanation: _autoExpandExplanation,
        onBack: () => setState(() => _showingDetail = false),
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
        const Text('Adaptive Recovery', style: AppTextStyles.screenTitle),
        const SizedBox(height: 4),
        const Text('AI-guided recovery decision support', style: AppTextStyles.screenSubtitle),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.featureIconBackground,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recovery Plan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.titleDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Combines stress severity, growth stage and conditions.',
                style: TextStyle(fontSize: 12.5, color: AppColors.subtitleGrey, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text('Latest assessment', style: AppTextStyles.featureCardTitle),
        const SizedBox(height: 12),
        if (plan == null) _EmptyState(onStartAssessment: widget.onStartAssessment) else _LatestPlanCard(plan: plan),
        if (plan != null) ...[
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'View Recovery Plan',
            onPressed: () => setState(() {
              _showingDetail = true;
              _autoExpandExplanation = false;
            }),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() {
              _showingDetail = true;
              _autoExpandExplanation = true;
            }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why this plan?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.titleDark),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Recommendations are ranked by urgency.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.subtitleGrey, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LatestPlanCard extends StatelessWidget {
  const _LatestPlanCard({required this.plan});

  final RecoveryPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
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
        children: [
          const Text(
            'Overall stress',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
          ),
          const SizedBox(height: 10),
          StatusPill(label: plan.priority),
          const SizedBox(height: 14),
          const Text(
            'Recovery plan ready',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.titleDark),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStartAssessment});

  final VoidCallback onStartAssessment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        children: [
          const Icon(Icons.eco_outlined, size: 36, color: AppColors.subtitleGrey),
          const SizedBox(height: 12),
          const Text(
            'No recovery plan yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.titleDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Run the recovery assessment to generate an AI-guided plan from your latest scans.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.subtitleGrey, height: 1.4),
          ),
          const SizedBox(height: 16),
          SecondaryButton(label: 'Start Recovery Assessment', onPressed: onStartAssessment),
        ],
      ),
    );
  }
}
