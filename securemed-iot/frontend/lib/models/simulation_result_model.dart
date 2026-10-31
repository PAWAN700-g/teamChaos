class SimulationResultModel {
  final String attackName;
  final String attackType;
  final Map<String, dynamic> simulatedInput;
  final String securityMechanism;
  final String expectedResult;
  final String actualResult;
  final String detectionStatus;
  final int statusCode;
  final String defenseTriggered;
  final String mitigationAction;
  final bool incidentLogged;
  final String? incidentId;
  final String timestamp;
  final Map<String, dynamic> payloadSent;

  SimulationResultModel({
    required this.attackName,
    required this.attackType,
    required this.simulatedInput,
    required this.securityMechanism,
    required this.expectedResult,
    required this.actualResult,
    required this.detectionStatus,
    required this.statusCode,
    required this.defenseTriggered,
    required this.mitigationAction,
    required this.incidentLogged,
    this.incidentId,
    required this.timestamp,
    Map<String, dynamic>? payloadSent,
  }) : payloadSent = payloadSent ?? simulatedInput;

  bool get isBlocked => detectionStatus == 'BLOCKED_BY_GATEWAY' || statusCode >= 400;

  factory SimulationResultModel.fromJson(Map<String, dynamic> json) {
    final input = (json['simulated_input'] as Map<String, dynamic>?) ??
        (json['payload_sent'] as Map<String, dynamic>?) ??
        {};
    final mechanism = json['security_mechanism'] as String? ??
        json['defense_triggered'] as String? ??
        'Cryptographic Gateway Defense';

    return SimulationResultModel(
      attackName: json['attack_name'] as String? ?? 'Security Simulation',
      attackType: json['attack_type'] as String? ?? 'ATTACK_SIMULATION',
      simulatedInput: input,
      payloadSent: input,
      securityMechanism: mechanism,
      expectedResult: json['expected_result'] as String? ??
          'Reject request and trigger cybersecurity alert',
      actualResult: json['actual_result'] as String? ??
          'Intercepted and blocked by FastAPI PQC gateway',
      detectionStatus: json['detection_status'] as String? ?? 'BLOCKED_BY_GATEWAY',
      statusCode: (json['status_code'] as num?)?.toInt() ?? 400,
      defenseTriggered: json['defense_triggered'] as String? ?? mechanism,
      mitigationAction: json['mitigation_action'] as String? ??
          'Packet dropped, threat isolated, SIEM alert published',
      incidentLogged: json['incident_logged'] as bool? ?? true,
      incidentId: json['incident_id'] as String?,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attack_name': attackName,
      'attack_type': attackType,
      'simulated_input': simulatedInput,
      'payload_sent': payloadSent,
      'security_mechanism': securityMechanism,
      'expected_result': expectedResult,
      'actual_result': actualResult,
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
