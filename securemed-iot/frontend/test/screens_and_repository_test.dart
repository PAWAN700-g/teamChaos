import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securemed_iot/models/device_model.dart';
import 'package:securemed_iot/models/security_alert_model.dart';
import 'package:securemed_iot/models/simulation_result_model.dart';
import 'package:securemed_iot/models/telemetry_model.dart';
import 'package:securemed_iot/models/user_profile.dart';
import 'package:securemed_iot/screens/device_details_screen.dart';
import 'package:securemed_iot/screens/tabs/attack_simulation_tab.dart';
import 'package:securemed_iot/screens/tabs/audit_logs_tab.dart';
import 'package:securemed_iot/screens/tabs/security_center_tab.dart';

void main() {
  group('SecureMed IoT - Models, Repositories & Specialized Screens Tests', () {
    test('DeviceModel parses JSON correctly and computes online/revocation status', () {
      final active = DeviceModel.fromJson({
        'device_id': 'MED-DEV-ICU-701A',
        'device_type': 'Multi-parameter Vital Monitor',
        'status': 'active',
        'is_pqc_secured': true,
        'dsa_public_key_b64': 'KEY_DATA_SAMPLE',
        'registered_at': '2026-10-31T19:20:18Z',
      });
      expect(active.isOnline, isTrue);
      expect(active.isRevoked, isFalse);

      final revoked = active.copyWith(status: 'revoked', revokedAt: '2026-10-31T20:00:00Z');
      expect(revoked.isOnline, isFalse);
      expect(revoked.isRevoked, isTrue);
    });

    test('TelemetryModel parses synthetic vitals with default fallbacks and SIMULATED bounds', () {
      final t = TelemetryModel.fromJson({
        'device_id': 'MED-DEV-ICU-701A',
        'device_type': 'Multi-parameter Vital Monitor',
        'session_id': 'SES-TEST-001',
        'sequence_number': 42,
        'vitals': {
          'heart_rate_bpm': 82,
          'spo2_percent': 99,
          'temperature_c': 37.1,
          'blood_pressure': '118/76',
        },
        'timestamp': '2026-10-31T19:25:00Z',
        'pqc_signature_verified': true,
        'tampering_detected': false,
      });

      expect(t.heartRate, 82);
      expect(t.spo2, 99);
      expect(t.temperature, 37.1);
      expect(t.bloodPressure, '118/76');
      expect(t.sequenceNumber, 42);
      expect(t.pqcSignatureVerified, isTrue);
    });

    test('SecurityAlertModel filters severity levels accurately', () {
      final crit = SecurityAlertModel(
        alertId: 'ALT-1',
        deviceId: 'MED-1',
        severity: 'critical',
        attackType: 'REPLAY_ATTACK',
        description: 'Duplicate sequence detected',
        timestamp: '2026-10-31T19:30:00Z',
      );
      expect(crit.isCritical, isTrue);
      expect(crit.isHigh, isFalse);

      final high = SecurityAlertModel(
        alertId: 'ALT-2',
        deviceId: 'MED-2',
        severity: 'high',
        attackType: 'SPOOFING',
        description: 'Unregistered device',
        timestamp: '2026-10-31T19:30:00Z',
      );
      expect(high.isHigh, isTrue);
    });

    test('SimulationResultModel parses detection result correctly', () {
      final result = SimulationResultModel.fromJson({
        'attack_name': 'Monotonic Sequence Replay Attack',
        'attack_type': 'REPLAY_ATTACK_DETECTED',
        'payload_sent': {'seq': 1},
        'detection_status': 'BLOCKED_BY_GATEWAY',
        'status_code': 400,
        'defense_triggered': 'Monotonic Sequence Verification',
        'mitigation_action': 'Packet dropped immediately',
        'incident_logged': true,
        'incident_id': 'ALT-REPLAY-12345',
        'timestamp': '2026-10-31T19:35:00Z',
      });

      expect(result.isBlocked, isTrue);
      expect(result.statusCode, 400);
      expect(result.incidentId, 'ALT-REPLAY-12345');
    });

    testWidgets('DeviceDetailsScreen renders charts and cryptographic identity cards',
        (WidgetTester tester) async {
      final testDevice = DeviceModel(
        deviceId: 'MED-DEV-ICU-701A',
        deviceType: 'Multi-parameter Vital Monitor',
        status: 'active',
        isPqcSecured: true,
        dsaPublicKeyB64: 'OC9MK6WkL+STLbefoc41kjbsUcAG2oDU1L34Gj65pzn+YLtFkCVeJCql+PoF8o5M',
        registeredAt: '2026-10-31T19:20:18Z',
      );

      final user = UserProfile(
        uid: 'DOC-123',
        email: 'doc@hospital.local',
        displayName: 'Dr. Gregory House',
        role: UserRole.doctor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceDetailsScreen(
            device: testDevice,
            user: user,
            telemetryHistory: [
              TelemetryModel(
                deviceId: testDevice.deviceId,
                deviceType: testDevice.deviceType,
                sessionId: 'SES-001',
                sequenceNumber: 1,
                vitals: {'heart_rate_bpm': 76, 'spo2_percent': 98},
                timestamp: '2026-10-31T19:25:00Z',
                pqcSignatureVerified: true,
                tamperingDetected: false,
              ),
            ],
          ),
        ),
      );

      expect(find.text('MED-DEV-ICU-701A'), findsWidgets);
      expect(find.text('Simulated Vitals Feed'), findsOneWidget);
      expect(find.text('Heart Rate Trend'), findsOneWidget);
      expect(find.text('Pulse Oximetry (SpO2)'), findsOneWidget);
      expect(find.text('LEAD II ECG TRACE'), findsOneWidget);
      expect(find.text('Cryptographic Session & Identity'), findsOneWidget);
      expect(find.text('ML-DSA-65 Public Key (FIPS 204)'), findsOneWidget);
      expect(find.text('AES-256-GCM + Nonce Monotonic Window'), findsOneWidget);
    });

    testWidgets('SecurityCenterTab renders severity counts and filter chips', (WidgetTester tester) async {
      final alerts = [
        SecurityAlertModel(
          alertId: 'ALT-1',
          deviceId: 'MED-DEV-ICU-701A',
          severity: 'critical',
          attackType: 'REPLAY_ATTACK_DETECTED',
          description: 'Sequence retransmitted',
          timestamp: '2026-10-31T19:30:00Z',
        ),
        SecurityAlertModel(
          alertId: 'ALT-2',
          deviceId: 'ROGUE-01',
          severity: 'high',
          attackType: 'UNREGISTERED_DEVICE_SPOOFING',
          description: 'Rogue certificate',
          timestamp: '2026-10-31T19:31:00Z',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecurityCenterTab(
              securityAlerts: alerts,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      expect(find.text('Security Operations Center (SIEM)'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('All Incidents (2)'), findsOneWidget);
      expect(find.text('REPLAY_ATTACK_DETECTED'), findsOneWidget);
      expect(find.text('UNREGISTERED_DEVICE_SPOOFING'), findsOneWidget);
    });

    testWidgets('AttackSimulationTab renders all 6 simulation attack buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttackSimulationTab(),
          ),
        ),
      );

      expect(find.text('Cybersecurity Attack Simulator'), findsOneWidget);
      expect(find.text('1. Replay Attack'), findsOneWidget);
      expect(find.text('2. Telemetry Tampering'), findsOneWidget);
      expect(find.text('3. Fake Device'), findsOneWidget);
      expect(find.text('4. Unauthorized Command'), findsOneWidget);
      expect(find.text('5. Firmware Tampering'), findsOneWidget);
      expect(find.text('6. Rate-Limit Test'), findsOneWidget);
    });

    testWidgets('AuditLogsTab renders hash-chain ledger view', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditLogsTab(onRefresh: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audit Ledger Chain'), findsOneWidget);
      expect(find.text('Hash-Chain Integrity Status'), findsOneWidget);
    });
  });
}
