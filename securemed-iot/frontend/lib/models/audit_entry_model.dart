class AuditEntryModel {
  final String eventId;
  final String event;
  final String actor;
  final String result;
  final String deviceId;
  final String timestamp;
  final Map<String, dynamic> details;
  final String parentHash;
  final String blockHash;

  AuditEntryModel({
    required this.eventId,
    required this.event,
    required this.actor,
    required this.result,
    required this.deviceId,
    required this.timestamp,
    required this.details,
    required this.parentHash,
    required this.blockHash,
  });

  bool get isSuccess => result == 'SUCCESS';
  bool get isRejected => result == 'REJECTED' || result.contains('FAILED');

  factory AuditEntryModel.fromJson(Map<String, dynamic> json) {
    final evt = json['event_type'] as String? ?? json['event'] as String? ?? 'SECURITY_AUDIT_EVENT';
    final act = json['actor'] as String? ?? json['device_id'] as String? ?? 'SYSTEM';
    final res = json['result'] as String? ?? 'SUCCESS';
    final prev = json['previous_hash'] as String? ?? json['parent_hash'] as String? ?? 'GENESIS_ROOT';
    final entry = json['entry_hash'] as String? ?? json['block_hash'] as String? ?? 'HASH_PENDING';
    final id = json['event_id'] as String? ?? 'EVT-${DateTime.now().millisecondsSinceEpoch}';

    return AuditEntryModel(
      eventId: id,
      event: evt,
      actor: act,
      result: res,
      deviceId: act,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      parentHash: prev,
      blockHash: entry,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'event_type': event,
      'event': event,
      'actor': actor,
      'result': result,
      'device_id': deviceId,
      'timestamp': timestamp,
      'details': details,
      'previous_hash': parentHash,
      'parent_hash': parentHash,
      'entry_hash': blockHash,
      'block_hash': blockHash,
    };
  }
}
