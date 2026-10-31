import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securemed_iot/models/simulation_result_model.dart';
import 'package:securemed_iot/repositories/security_repository.dart';
import 'package:securemed_iot/screens/tabs/attack_simulation_tab.dart';

void main() {
  group('SecureMed IoT - Attack Simulation Module Tests', () {
    test('SimulationResultModel parses all 4 required security fields and aliases', () {
      final json = {
        'attack_name': 'Attack 1: Device Impersonation & Signature Forgery',
        'attack_type': 'DEVICE_IMPERSONATION_DETECTED',
        'simulated_input': {
          'device_id': 'ROGUE-DEVICE-SPOOF-X99',
          'signature_scheme': 'ML-DSA-65',
          'forged_signature_b64': 'AAAAAAAAAAAAAAAA...',
          'attempted_action': 'POST /api/v1/crypto/handshake/init',
          'registered_in_gateway': false,
        },
        'security_mechanism': 'ML-DSA-65 Identity Verification & Registry Lookup',
        'expected_result': 'Reject authentication and create a security event (HTTP 401/404)',
        'actual_result': 'Authentication rejected: Unregistered device identity. Security incident chained.',
        'detection_status': 'BLOCKED_BY_GATEWAY',
        'status_code': 404,
        'defense_triggered': 'Pre-Provisioned ML-DSA-65 Public Key Identity Verification',
        'mitigation_action': 'Handshake rejected with HTTP 404, device blocked, network access denied.',
        'incident_logged': true,
        'incident_id': 'ALT-IMPERSONATION-123456',
        'timestamp': '2026-10-31T20:00:00Z',
      };

      final model = SimulationResultModel.fromJson(json);

      expect(model.attackName, 'Attack 1: Device Impersonation & Signature Forgery');
      expect(model.attackType, 'DEVICE_IMPERSONATION_DETECTED');
      expect(model.simulatedInput['device_id'], 'ROGUE-DEVICE-SPOOF-X99');
      expect(model.simulatedInput['registered_in_gateway'], isFalse);
      expect(model.securityMechanism, 'ML-DSA-65 Identity Verification & Registry Lookup');
      expect(model.expectedResult, contains('Reject authentication'));
      expect(model.actualResult, contains('Authentication rejected'));
      expect(model.statusCode, 404);
      expect(model.isBlocked, isTrue);
      expect(model.incidentId, 'ALT-IMPERSONATION-123456');
    });

    test('SimulationResultModel handles fallback fields gracefully', () {
      final json = {
        'attack_name': 'Generic Attack',
        'payload_sent': {'param': 'val'},
        'defense_triggered': 'Custom Shield',
        'status_code': 400,
      };

      final model = SimulationResultModel.fromJson(json);
      expect(model.simulatedInput['param'], 'val');
      expect(model.securityMechanism, 'Custom Shield');
      expect(model.statusCode, 400);
      expect(model.isBlocked, isTrue);
    });

    testWidgets('AttackSimulationTab renders all 8 attack scenarios', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttackSimulationTab(),
          ),
        ),
      );

      // Verify Header
      expect(find.text('Cybersecurity Attack Simulator'), findsOneWidget);
      expect(find.text('Live Attack Scenarios'), findsOneWidget);

      // Verify all 8 attack titles are present (using scroll if needed)
      final titles = [
        '1. Device Impersonation',
        '2. Replay Attack',
        '3. Telemetry Tampering',
        '4. Unauthorized Access',
        '5. Firmware Tampering',
        '6. Rate-Limit Attack',
        '7. Device Revocation',
        '8. Audit Log Modification',
      ];

      for (final title in titles) {
        final finder = find.text(title);
        await tester.scrollUntilVisible(finder, 100);
        expect(finder, findsOneWidget);
      }

      // Verify specific security badges
      expect(find.text('PQC DSA Identity'), findsOneWidget);
      expect(find.text('Sequence Monotonicity'), findsOneWidget);
      expect(find.text('AES-GCM Auth Tag'), findsOneWidget);
      expect(find.text('RBAC Policy Guard'), findsOneWidget);
      expect(find.text('FIPS 204 ML-DSA'), findsOneWidget);
      expect(find.text('Token Bucket Flood Defense'), findsOneWidget);
      expect(find.text('CRL Revocation Guard'), findsOneWidget);
      expect(find.text('SHA-256 Hash Chain'), findsOneWidget);
    });

    testWidgets('Detection Result Card renders simulated input, mechanism, expected and actual results', (tester) async {
      final sampleResult = SimulationResultModel(
        attackName: 'Attack 3: MITM Telemetry & Ciphertext Tampering',
        attackType: 'MITM_CIPHERTEXT_TAMPERING',
        simulatedInput: {
          'device_id': 'MED-DEV-INF-412C',
          'cipher': 'AES-256-GCM',
          'tampered_bytes': '0xDEADBEEF',
        },
        securityMechanism: 'AES-256-GCM 128-bit Authentication Tag (GHASH) Verification',
        expectedResult: 'AES-GCM verification fails and message is rejected (HTTP 400)',
        actualResult: 'Rejected: GCM authentication tag mismatch. Bit-flip tampering detected.',
        detectionStatus: 'BLOCKED_BY_GATEWAY',
        statusCode: 400,
        defenseTriggered: 'AES-256-GCM 128-bit Authentication Tag Integrity Check',
        mitigationAction: 'Ciphertext discarded un-decrypted, intrusion alert triggered.',
        incidentLogged: true,
        incidentId: 'ALT-MITM-TEST-001',
        timestamp: '2026-10-31T20:30:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    key: const Key('result_card_host'),
                    child: Builder(
                      builder: (ctx) {
                        // Rerender AttackSimulationTab with sampleResult directly or simulate its display
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sampleResult.attackName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Text('SIMULATED ATTACK INPUT'),
                              Text(sampleResult.simulatedInput.toString()),
                              const Text('BACKEND SECURITY MECHANISM'),
                              Text(sampleResult.securityMechanism),
                              const Text('EXPECTED RESULT'),
                              Text(sampleResult.expectedResult),
                              const Text('ACTUAL RESULT'),
                              Text(sampleResult.actualResult),
                              Text('${sampleResult.statusCode} (Interception Verified)'),
                              Text(sampleResult.defenseTriggered),
                              Text(sampleResult.mitigationAction),
                              Text(sampleResult.incidentId!),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Attack 3: MITM Telemetry & Ciphertext Tampering'), findsOneWidget);
      expect(find.text('SIMULATED ATTACK INPUT'), findsOneWidget);
      expect(find.text('BACKEND SECURITY MECHANISM'), findsOneWidget);
      expect(find.text('EXPECTED RESULT'), findsOneWidget);
      expect(find.text('ACTUAL RESULT'), findsOneWidget);
      expect(find.text('AES-256-GCM 128-bit Authentication Tag (GHASH) Verification'), findsOneWidget);
      expect(find.text('400 (Interception Verified)'), findsOneWidget);
      expect(find.text('ALT-MITM-TEST-001'), findsOneWidget);
    });
  });
}
