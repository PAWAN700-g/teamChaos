class DeviceModel {
  final String deviceId;
  final String deviceType;
  final String status;
  final bool isPqcSecured;
  final String dsaPublicKeyB64;
  final String registeredAt;
  final String? revokedAt;
  final String? lastSeen;

  DeviceModel({
    required this.deviceId,
    required this.deviceType,
    required this.status,
    required this.isPqcSecured,
    required this.dsaPublicKeyB64,
    required this.registeredAt,
    this.revokedAt,
    this.lastSeen,
  });

  bool get isOnline => status.toLowerCase() == 'active' && revokedAt == null;
  bool get isRevoked => status.toLowerCase() == 'revoked' || revokedAt != null;

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      deviceId: json['device_id'] as String? ?? 'UNKNOWN-DEV',
      deviceType: json['device_type'] as String? ?? 'Medical Device',
      status: json['status'] as String? ?? 'active',
      isPqcSecured: json['is_pqc_secured'] as bool? ?? true,
      dsaPublicKeyB64: json['dsa_public_key_b64'] as String? ?? '',
      registeredAt: json['registered_at'] as String? ?? '',
      revokedAt: json['revoked_at'] as String?,
      lastSeen: json['last_seen'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_type': deviceType,
      'status': status,
      'is_pqc_secured': isPqcSecured,
      'dsa_public_key_b64': dsaPublicKeyB64,
      'registered_at': registeredAt,
      'revoked_at': revokedAt,
      'last_seen': lastSeen,
    };
  }

  DeviceModel copyWith({
    String? deviceId,
    String? deviceType,
    String? status,
    bool? isPqcSecured,
    String? dsaPublicKeyB64,
    String? registeredAt,
    String? revokedAt,
    String? lastSeen,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      status: status ?? this.status,
      isPqcSecured: isPqcSecured ?? this.isPqcSecured,
      dsaPublicKeyB64: dsaPublicKeyB64 ?? this.dsaPublicKeyB64,
      registeredAt: registeredAt ?? this.registeredAt,
      revokedAt: revokedAt ?? this.revokedAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
