import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bell_pepper_app/config/api_config.dart';

/// Thin wrapper around the unified backend's `/environmental/*` endpoints,
/// so screens depend on this instead of the `http` package directly.
class EnvironmentalApiService {
  EnvironmentalApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> checkEnvironment({
    required String timestamp,
    required String growthStage,
    required double airTemperatureC,
    required double relativeHumidityPct,
    required double lightIntensityLux,
    required double soilTemperatureC,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.environmentalCheck}');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'timestamp': timestamp,
        'growth_stage': growthStage,
        'air_temperature_c': airTemperatureC,
        'relative_humidity_pct': relativeHumidityPct,
        'light_intensity_lux': lightIntensityLux,
        'soil_temperature_c': soilTemperatureC,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Check environment failed (${response.statusCode}): ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> predict({
    required String timestamp,
    required String growthStage,
    required double airTemperatureC,
    required double relativeHumidityPct,
    required double lightIntensityLux,
    required double soilTemperatureC,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.environmentalPredict}');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'timestamp': timestamp,
        'growth_stage': growthStage,
        'air_temperature_c': airTemperatureC,
        'relative_humidity_pct': relativeHumidityPct,
        'light_intensity_lux': lightIntensityLux,
        'soil_temperature_c': soilTemperatureC,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Predict future stress failed (${response.statusCode}): ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
