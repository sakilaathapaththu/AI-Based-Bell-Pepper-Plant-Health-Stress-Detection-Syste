import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bell_pepper_app/config/api_config.dart';

/// Thin wrapper around the unified backend's `/rgb/predict` endpoint
/// (unified-backend/app/routes/rgb.py), so screens depend on this instead
/// of the `http` package directly.
class RgbApiService {
  RgbApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> predict({
    required List<int> imageBytes,
    required String filename,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.rgbPredict}');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: filename),
      );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('RGB predict failed (${response.statusCode}): ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
