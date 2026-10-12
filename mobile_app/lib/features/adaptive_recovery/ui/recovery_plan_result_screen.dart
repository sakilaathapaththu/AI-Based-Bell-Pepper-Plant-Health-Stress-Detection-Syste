import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/models/recovery_plan.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/ui/widgets/status_pill.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

/// "Recovery Plan" screen: shows a prioritized action list built from the
/// backend's recovery plan response, plus an expandable "Why this plan?"
/// explanation section (why_this_action / supporting_evidence / agronomic
/// evidence status).
///
/// The backend (unified-backend/app/services/adaptive_service.py) only ever
/// returns ONE `recommended_action` and ONE `details.secondary_action` - it
/// has no code path that returns a list of multiple actions. To match the
/// 3-item mockup, item 3 is derived (not fabricated data from the backend,
/// just worded) from `details.environmental_context` + `details.growth_stage`
/// as a generic monitoring follow-up.
class RecoveryPlanResultScreen extends StatefulWidget {
  const RecoveryPlanResultScreen({
    super.key,
    required this.plan,
    required this.onBack,
    this.autoExpandExplanation = false,
  });

  final RecoveryPlan plan;
  final VoidCallback onBack;

  /// When true (e.g. arriving from the "Why this plan?" card on the summary
  /// screen), the explanation section starts expanded.
  final bool autoExpandExplanation;

  @override
  State<RecoveryPlanResultScreen> createState() => _RecoveryPlanResultScreenState();
}

class _RecoveryPlanResultScreenState extends State<RecoveryPlanResultScreen> {
  late bool _explanationExpanded;

  @override
  void initState() {
    super.initState();
    _explanationExpanded = widget.autoExpandExplanation;
  }

  /// One priority level below [priority] ("High" -> "Medium" -> "Low"),
  /// used for the secondary action when the backend doesn't give it an
  /// explicit priority of its own.
  static String _oneLevelDown(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return 'Medium';
      case 'MEDIUM':
        return 'Low';
      default:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final details = plan.details;

    final items = <_ActionItem>[
      _ActionItem(title: plan.recommendedAction, priority: plan.priority),
      if (details.secondaryAction.isNotEmpty)
        _ActionItem(title: details.secondaryAction, priority: _oneLevelDown(plan.priority)),
      _ActionItem(
        title: 'Monitor ${details.environmentalContext} conditions during the '
            '${details.growthStage} stage.',
        priority: 'Low',
      ),
    ];

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
        const Text('Recovery Plan', style: AppTextStyles.screenTitle),
        const SizedBox(height: 4),
        const Text('Prioritized actions for the greenhouse', style: AppTextStyles.screenSubtitle),
        const SizedBox(height: 18),
        Column(
          children: [
            for (var i = 0; i < items.length; i++)
              _TimelineStep(
                index: i + 1,
                item: items[i],
                isLast: i == items.length - 1,
              ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'View Explanation',
          onPressed: () => setState(() => _explanationExpanded = !_explanationExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _explanationExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _ExplanationSection(plan: plan),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ActionItem {
  const _ActionItem({required this.title, required this.priority});

  final String title;
  final String priority;
}

/// One node + content block in the vertical timeline. The node is colored
/// per the item's priority (reusing [StatusPill.colorForPriority]) and is
/// connected to the next node by a vertical line segment.
class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.index, required this.item, required this.isLast});

  final int index;
  final _ActionItem item;
  final bool isLast;

  static const double _nodeSize = 30;

  @override
  Widget build(BuildContext context) {
    final nodeColor = StatusPill.colorForPriority(item.priority);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: _nodeSize,
                height: _nodeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: nodeColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: AppColors.progressTrack,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.fieldBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(label: '${item.priority} priority', showDot: true),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.titleDark,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({required this.plan});

  final RecoveryPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Why this plan?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.titleDark),
          ),
          const SizedBox(height: 6),
          Text(
            plan.whyThisAction,
            style: const TextStyle(fontSize: 12.5, color: AppColors.subtitleGrey, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Source: ${plan.whyThisActionSource == 'gemini' ? 'AI-generated explanation' : 'Rule-based explanation'}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.subtitleGrey),
          ),
          if (plan.supportingEvidence.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Supporting evidence',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.titleDark),
            ),
            const SizedBox(height: 8),
            for (final evidence in plan.supportingEvidence)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${evidence.problem.replaceAll('_', ' ')} · ${evidence.source}'
                        '${evidence.confidence != null ? ' · ${(evidence.confidence! * 100).round()}%' : ''}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.titleDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(label: evidence.severity),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Text(
            plan.details.agronomicEvidenceStatus,
            style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.subtitleGrey),
          ),
        ],
      ),
    );
  }
}
