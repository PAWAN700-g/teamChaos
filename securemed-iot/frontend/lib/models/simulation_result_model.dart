class SimulationResultModel {
  final String attackName;
  final String attackType;
  final Map<String, dynamic> payloadSent;
  final String detectionStatus;
  final int statusCode;
  final String defenseTriggered;
  final String mitigationAction;
  final bool incidentLogged;
  final String? incidentId;
  final String timestamp;

  SimulationResultModel({
    required this.attackName,
    required this.attackType,
    required this.payloadSent,
    required this.detectionStatus,
    required this.statusCode,
    required this.defenseTriggered,
    required this.mitigationAction,
    required this.incidentLogged,
    this.incidentId,
    required this.timestamp,
  });

  bool get isBlocked => detectionStatus == 'BLOCKED_BY_GATEWAY' || statusCode >= 400;

  factory SimulationResultModel.fromJson(Map<String, dynamic> json) {
    return SimulationResultModel(
      attackName: json['attack_name'] as String? ?? 'Security Simulation',
      attackType: json['attack_type'] as String? ?? 'ATTACK_SIMULATION',
      payloadSent: (json['payload_sent'] as Map<String, dynamic>?) ?? {},
      detectionStatus: json['detection_status'] as String? ?? 'BLOCKED_BY_GATEWAY',
      statusCode: (json['status_code'] as num?)?.toInt() ?? 400,
      defenseTriggered: json['defense_triggered'] as String? ?? 'Defense Mechanism Activated',
      mitigationAction: json['mitigation_action'] as String? ?? 'Packet dropped and incident logged',
      incidentLogged: json['incident_logged'] as bool? ?? true,
      incidentId: json['incident_id'] as String?,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attack_name': attackName,
      'attack_type': attackType,
      'payload_sent': payloadSent,
      'detection_status': detectionStatus,
      'status_code': statusCode,
      'defense_triggered': defenseTriggered,
      'mitigation_action': mitigationAction,
      'incident_logged': incidentLogged,
      'incident_id': incidentId,
      'timestamp': timestamp,
    };
  }
}
