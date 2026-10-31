import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Determine base URL dynamically based on operating platform.
  /// Android Emulator loops back to host machine via 10.0.2.2.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api/v1';
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      default:
        return 'http://127.0.0.1:8000/api/v1';
    }
  }

  Future<Map<String, dynamic>> getHealth() async {
    final uri = Uri.parse('$baseUrl/health');
    final response = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Gateway returned HTTP ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getCryptoStatus() async {
    final uri = Uri.parse('$baseUrl/crypto/status');
    final response = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Crypto status returned HTTP ${response.statusCode}');
  }

  Future<List<dynamic>> getDevices() async {
    final uri = Uri.parse('$baseUrl/devices/');
    final response = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Devices endpoint returned HTTP ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getLatestTelemetry() async {
    final uri = Uri.parse('$baseUrl/telemetry/latest');
    final response = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Telemetry endpoint returned HTTP ${response.statusCode}');
  }
}
