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

  Future<Map<String, dynamic>> getCryptoInfo() async {
    final uri = Uri.parse('$baseUrl/crypto/info');
    final response = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Crypto info returned HTTP ${response.statusCode}');
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

  Future<Map<String, dynamic>> revokeDevice(String deviceId, {String reason = "Admin revocation"}) async {
    final uri = Uri.parse('$baseUrl/devices/$deviceId/revoke');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reason': reason}),
    ).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Revocation returned HTTP ${response.statusCode}: ${response.body}');
  }

  Future<Map<String, dynamic>> getLatestTelemetry() async {
    final uri = Uri.parse('$baseUrl/telemetry/latest');
    final response = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Telemetry endpoint returned HTTP ${response.statusCode}');
  }

  Future<Map<String, dynamic>> verifyFirmware({
    required String firmwareName,
    required String version,
    required String firmwareImageB64,
    required String vendorSignatureB64,
    required String vendorDsaPubB64,
    String? expectedSha256,
  }) async {
    final uri = Uri.parse('$baseUrl/firmware/verify');
    final payload = <String, dynamic>{
      'firmware_name': firmwareName,
      'version': version,
      'firmware_image_b64': firmwareImageB64,
      'vendor_signature_b64': vendorSignatureB64,
      'vendor_dsa_pub_b64': vendorDsaPubB64,
    };
    if (expectedSha256 != null) {
      payload['expected_sha256'] = expectedSha256;
    }

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Firmware verification returned HTTP ${response.statusCode}: ${response.body}');
  }
}
