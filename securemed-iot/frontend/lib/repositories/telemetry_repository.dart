import '../models/telemetry_model.dart';
import '../models/security_alert_model.dart';
import '../services/api_service.dart';

class TelemetrySnapshot {
  final List<TelemetryModel> telemetryStream;
  final List<SecurityAlertModel> securityAlerts;
  final int totalPacketsIngested;
  final String auditHeadHash;

  TelemetrySnapshot({
    required this.telemetryStream,
    required this.securityAlerts,
    required this.totalPacketsIngested,
    required this.auditHeadHash,
  });
}

class TelemetryRepository {
  final ApiService _apiService;

  TelemetryRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  Future<TelemetrySnapshot> fetchLatestTelemetry() async {
    final data = await _apiService.getLatestTelemetry();

    final rawStream = (data['telemetry_stream'] as List<dynamic>?) ?? [];
    final rawAlerts = (data['security_alerts'] as List<dynamic>?) ?? [];

    final telemetryStream = rawStream
        .map((e) => TelemetryModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final securityAlerts = rawAlerts
        .map((e) => SecurityAlertModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return TelemetrySnapshot(
      telemetryStream: telemetryStream,
      securityAlerts: securityAlerts,
      totalPacketsIngested: (data['total_packets_ingested'] as num?)?.toInt() ?? telemetryStream.length,
      auditHeadHash: data['audit_head_hash'] as String? ?? 'GENESIS_SECUREMED_ROOT',
    );
  }
}
