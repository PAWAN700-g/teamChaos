import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin('admin', 'System Administrator'),
  doctor('doctor', 'Attending Physician / Clinician'),
  securityAnalyst('security_analyst', 'Cybersecurity Analyst');

  final String id;
  final String label;

  const UserRole(this.id, this.label);

  static UserRole fromString(String? roleStr) {
    switch (roleStr) {
      case 'admin':
        return UserRole.admin;
      case 'security_analyst':
        return UserRole.securityAnalyst;
      case 'doctor':
      default:
        return UserRole.doctor;
    }
  }
}

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isDoctor => role == UserRole.doctor;
  bool get isSecurityAnalyst => role == UserRole.securityAnalyst;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.id,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return UserProfile(
      uid: docId ?? map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Medical Staff',
      role: UserRole.fromString(map['role'] as String?),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return UserProfile.fromMap(data, docId: snapshot.id);
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
