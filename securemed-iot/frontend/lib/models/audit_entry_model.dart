class AuditEntryModel {
  final String event;
  final String deviceId;
  final String timestamp;
  final Map<String, dynamic> details;
  final String parentHash;
  final String blockHash;

  AuditEntryModel({
    required this.event,
    required this.deviceId,
    required this.timestamp,
    required this.details,
    required this.parentHash,
    required this.blockHash,
  });

  factory AuditEntryModel.fromJson(Map<String, dynamic> json) {
    return AuditEntryModel(
      event: json['event'] as String? ?? 'SECURITY_AUDIT_EVENT',
      deviceId: json['device_id'] as String? ?? 'SYSTEM',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      parentHash: json['parent_hash'] as String? ?? 'GENESIS_SECUREMED_ROOT',
      blockHash: json['block_hash'] as String? ?? 'HASH_PENDING',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event': event,
      'device_id': deviceId,
      'timestamp': timestamp,
      'details': details,
      'parent_hash': parentHash,
      'block_hash': blockHash,
    };
  }
}
