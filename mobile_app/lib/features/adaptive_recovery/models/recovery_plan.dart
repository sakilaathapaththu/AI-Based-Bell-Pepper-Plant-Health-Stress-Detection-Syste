/// Parsed response from the unified backend's
/// `POST /adaptive/generate-recovery-plan` (see
/// unified-backend/app/routes/adaptive.py and
/// unified-backend/app/services/adaptive_service.py for the ground-truth
/// Pydantic/response shape this mirrors).
class SupportingEvidenceItem {
  const SupportingEvidenceItem({
    required this.problem,
    required this.severity,
    required this.source,
    this.confidence,
  });

  final String problem;
  final String severity;
  final String source;
  final double? confidence;

  factory SupportingEvidenceItem.fromJson(Map<String, dynamic> json) {
    return SupportingEvidenceItem(
      problem: json['problem'] as String? ?? '—',
      severity: json['severity'] as String? ?? '—',
      source: json['source'] as String? ?? '—',
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'problem': problem,
    'severity': severity,
    'source': source,
    'confidence': confidence,
  };
}

class RecoveryPlanDetails {
  const RecoveryPlanDetails({
    required this.primaryProblem,
    required this.severity,
    required this.secondaryAction,
    required this.environmentalContext,
    required this.growthStage,
    required this.possibleEnvironmentalConfound,
    required this.agronomicEvidenceStatus,
    required this.inputsReceived,
  });

  final String primaryProblem;
  final String severity;
  final String secondaryAction;
  final String environmentalContext;
  final String growthStage;
  final bool possibleEnvironmentalConfound;
  final String agronomicEvidenceStatus;
  final Map<String, bool> inputsReceived;

  factory RecoveryPlanDetails.fromJson(Map<String, dynamic> json) {
    final inputs = (json['inputs_received'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RecoveryPlanDetails(
      primaryProblem: json['primary_problem'] as String? ?? 'Healthy',
      severity: json['severity'] as String? ?? 'None',
      secondaryAction: json['secondary_action'] as String? ?? '',
      environmentalContext: json['environmental_context'] as String? ?? '',
      growthStage: json['growth_stage'] as String? ?? '',
      possibleEnvironmentalConfound: json['possible_environmental_confound'] as bool? ?? false,
      agronomicEvidenceStatus: json['agronomic_evidence_status'] as String? ?? '',
      inputsReceived: inputs.map((key, value) => MapEntry(key, value == true)),
    );
  }

  Map<String, dynamic> toJson() => {
    'primary_problem': primaryProblem,
    'severity': severity,
    'secondary_action': secondaryAction,
    'environmental_context': environmentalContext,
    'growth_stage': growthStage,
    'possible_environmental_confound': possibleEnvironmentalConfound,
    'agronomic_evidence_status': agronomicEvidenceStatus,
    'inputs_received': inputsReceived,
  };
}

class RecoveryPlan {
  const RecoveryPlan({
    required this.plantId,
    required this.recommendedAction,
    required this.priority,
    required this.whyThisAction,
    required this.whyThisActionSource,
    required this.supportingEvidence,
    required this.details,
  });

  final String? plantId;
  final String recommendedAction;
  final String priority;
  final String whyThisAction;
  final String whyThisActionSource;
  final List<SupportingEvidenceItem> supportingEvidence;
  final RecoveryPlanDetails details;

  factory RecoveryPlan.fromJson(Map<String, dynamic> json) {
    final evidence = (json['supporting_evidence'] as List? ?? const [])
        .map((e) => SupportingEvidenceItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return RecoveryPlan(
      plantId: json['plant_id'] as String?,
      recommendedAction: json['recommended_action'] as String? ?? '—',
      priority: json['priority'] as String? ?? 'Low',
      whyThisAction: json['why_this_action'] as String? ?? '',
      whyThisActionSource: json['why_this_action_source'] as String? ?? '',
      supportingEvidence: evidence,
      details: RecoveryPlanDetails.fromJson(
        (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'plant_id': plantId,
    'recommended_action': recommendedAction,
    'priority': priority,
    'why_this_action': whyThisAction,
    'why_this_action_source': whyThisActionSource,
    'supporting_evidence': supportingEvidence.map((e) => e.toJson()).toList(),
    'details': details.toJson(),
  };
}
