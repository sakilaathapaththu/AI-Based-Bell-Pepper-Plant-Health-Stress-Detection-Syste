import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bell_pepper_app/config/api_config.dart';

/// Thin wrapper around the unified backend's `/thermal/predict` endpoint
/// (unified-backend/app/routes/thermal.py), so screens depend on this
/// instead of the `http` package directly.
class ThermalApiService {
  ThermalApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> predict({
    required List<int> imageBytes,
    required String filename,
    String? plantId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.thermalPredict}');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('thermal_image', imageBytes, filename: filename),
      );
    if (plantId != null) {
      request.fields['plant_id'] = plantId;
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Thermal predict failed (${response.statusCode}): ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
