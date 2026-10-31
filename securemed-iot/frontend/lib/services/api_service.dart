import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  /// Global provider for Firebase ID tokens across all API requests.
  static Future<String?> Function()? globalTokenProvider;

  final Dio _dio;
  final Future<String?> Function()? _tokenProvider;

  ApiService({Dio? dio, Future<String?> Function()? tokenProvider})
      : _dio = dio ?? Dio(),
        _tokenProvider = tokenProvider ?? globalTokenProvider {
    _initDio();
  }

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

  void _initDio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 5);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_tokenProvider != null) {
            try {
              final token = await _tokenProvider();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              debugPrint('[ApiService] Notice: could not retrieve auth token: $e');
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          debugPrint('[ApiService] Request error [${error.response?.statusCode}]: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getCryptoInfo() async {
    try {
      final response = await _dio.get('/crypto/info');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getCryptoStatus() async {
    try {
      final response = await _dio.get('/crypto/status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<dynamic>> getDevices() async {
    try {
      final response = await _dio.get('/devices/');
      return response.data is List ? response.data as List<dynamic> : [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getDevice(String deviceId) async {
    try {
      final response = await _dio.get('/devices/$deviceId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String deviceType,
    required String dsaPublicKeyB64,
  }) async {
    try {
      final response = await _dio.post(
        '/devices/register',
        data: {
          'device_id': deviceId,
          'device_type': deviceType,
          'dsa_public_key_b64': dsaPublicKeyB64,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> revokeDevice(String deviceId, {String reason = "Admin revocation"}) async {
    try {
      final response = await _dio.post(
        '/devices/$deviceId/revoke',
        data: {'reason': reason},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getLatestTelemetry() async {
    try {
      final response = await _dio.get('/telemetry/latest');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getAuditLedger() async {
    try {
      final response = await _dio.get('/telemetry/audit');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // --- ATTACK SIMULATION ENDPOINTS ---

  Future<Map<String, dynamic>> simulateDeviceImpersonation() async {
    try {
      final response = await _dio.post('/simulation/device-impersonation');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> simulateReplay() async {
    try {
      final response = await _dio.post('/simulation/replay');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> simulateTampering() async {
    try {
      final response = await _dio.post('/simulation/tampering');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> simulateFakeDevice() => simulateDeviceImpersonation();

  Future<Map<String, dynamic>> simulateUnauthorizedAccess() async {
    try {
      final response = await _dio.post('/simulation/unauthorized-access');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> simulateUnauthorizedCommand() => simulateUnauthorizedAccess();

  Future<Map<String, dynamic>> simulateFirmwareTampering() async {
    try {
      final response = await _dio.post('/simulation/firmware-tampering');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> simulateRateLimit() async {
    try {
      final response = await _dio.post('/simulation/rate-limit');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> simulateDeviceRevocation() async {
    try {
      final response = await _dio.post('/simulation/device-revocation');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> simulateAuditModification() async {
    try {
      final response = await _dio.post('/simulation/audit-modification');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> verifyFirmware({
    required String firmwareName,
    required String version,
    required String firmwareImageB64,
    required String vendorSignatureB64,
    required String vendorDsaPubB64,
    String? expectedSha256,
  }) async {
    try {
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
      final response = await _dio.post('/firmware/verify', data: payload);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return Exception('SecureMed Gateway unreachable. Check backend connection at $baseUrl.');
    }
    final resp = error.response;
    if (resp != null) {
      final detail = resp.data is Map ? resp.data['detail'] : resp.statusMessage;
      return Exception('HTTP ${resp.statusCode}: ${detail ?? error.message}');
    }
    return Exception(error.message ?? 'Unknown network error');
  }
}
