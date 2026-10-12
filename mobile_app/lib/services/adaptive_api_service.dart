import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bell_pepper_app/config/api_config.dart';
import 'package:bell_pepper_app/features/adaptive_recovery/models/recovery_plan.dart';

/// Thin wrapper around the unified backend's `/adaptive/generate-recovery-plan`
/// endpoint (unified-backend/app/routes/adaptive.py), so screens depend on
/// this instead of the `http` package directly.
class AdaptiveApiService {
  AdaptiveApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RecoveryPlan> generateRecoveryPlan({
    String? plantId,
    Map<String, dynamic>? rgbResult,
    Map<String, dynamic>? thermalResult,
    Map<String, dynamic>? environmentalResult,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adaptiveRecoveryPlan}');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'plant_id': plantId,
        'rgb_result': rgbResult,
        'thermal_result': thermalResult,
        'environmental_result': environmentalResult,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Generate recovery plan failed (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return RecoveryPlan.fromJson(body);
  }
}
