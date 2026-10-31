class TelemetryModel {
  final String deviceId;
  final String deviceType;
  final String sessionId;
  final int sequenceNumber;
  final Map<String, dynamic> vitals;
  final String timestamp;
  final bool pqcSignatureVerified;
  final bool tamperingDetected;

  TelemetryModel({
    required this.deviceId,
    required this.deviceType,
    required this.sessionId,
    required this.sequenceNumber,
    required this.vitals,
    required this.timestamp,
    required this.pqcSignatureVerified,
    required this.tamperingDetected,
  });

  int get heartRate {
    final val = vitals['heart_rate_bpm'] ?? vitals['heart_rate'] ?? 72;
    return (val is num) ? val.toInt() : int.tryParse(val.toString()) ?? 72;
  }

  int get spo2 {
    final val = vitals['spo2_percent'] ?? vitals['spo2'] ?? 98;
    return (val is num) ? val.toInt() : int.tryParse(val.toString()) ?? 98;
  }

  double get temperature {
    final val = vitals['temperature_c'] ?? vitals['temperature'] ?? 36.8;
    return (val is num) ? val.toDouble() : double.tryParse(val.toString()) ?? 36.8;
  }

  String get bloodPressure {
    return vitals['blood_pressure']?.toString() ?? '120/80 mmHg';
  }

  factory TelemetryModel.fromJson(Map<String, dynamic> json) {
    return TelemetryModel(
      deviceId: json['device_id'] as String? ?? 'UNKNOWN',
      deviceType: json['device_type'] as String? ?? 'Multi-parameter Monitor',
      sessionId: json['session_id'] as String? ?? 'SES-UNKNOWN',
      sequenceNumber: (json['sequence_number'] as num?)?.toInt() ?? 1,
      vitals: (json['vitals'] as Map<String, dynamic>?) ?? {},
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      pqcSignatureVerified: json['pqc_signature_verified'] as bool? ?? true,
      tamperingDetected: json['tampering_detected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_type': deviceType,
      'session_id': sessionId,
      'sequence_number': sequenceNumber,
      'vitals': vitals,
      'timestamp': timestamp,
      'pqc_signature_verified': pqcSignatureVerified,
      'tampering_detected': tamperingDetected,
    };
  }
}
