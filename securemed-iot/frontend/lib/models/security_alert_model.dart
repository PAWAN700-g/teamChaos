class SecurityAlertModel {
  final String alertId;
  final String deviceId;
  final String severity; // critical, high, medium, low, warning
  final String attackType;
  final String description;
  final String timestamp;

  SecurityAlertModel({
    required this.alertId,
    required this.deviceId,
    required this.severity,
    required this.attackType,
    required this.description,
    required this.timestamp,
  });

  bool get isCritical => severity.toLowerCase() == 'critical';
  bool get isHigh => severity.toLowerCase() == 'high';
  bool get isMedium => severity.toLowerCase() == 'medium' || severity.toLowerCase() == 'warning';
  bool get isLow => severity.toLowerCase() == 'low' || severity.toLowerCase() == 'info';

  factory SecurityAlertModel.fromJson(Map<String, dynamic> json) {
    return SecurityAlertModel(
      alertId: json['alert_id'] as String? ?? 'ALT-${DateTime.now().millisecondsSinceEpoch}',
      deviceId: json['device_id'] as String? ?? 'SYSTEM',
      severity: json['severity'] as String? ?? 'warning',
      attackType: json['attack_type'] as String? ?? 'INTRUSION_DETECTED',
      description: json['description'] as String? ?? 'Security event triggered',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alert_id': alertId,
      'device_id': deviceId,
      'severity': severity,
      'attack_type': attackType,
      'description': description,
      'timestamp': timestamp,
    };
  }
}
