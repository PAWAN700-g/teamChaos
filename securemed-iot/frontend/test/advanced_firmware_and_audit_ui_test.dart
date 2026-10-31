import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securemed_iot/models/audit_entry_model.dart';
import 'package:securemed_iot/repositories/audit_repository.dart';
import 'package:securemed_iot/screens/tabs/audit_logs_tab.dart';
import 'package:securemed_iot/screens/tabs/security_center_tab.dart';

void main() {
  group('SecureMed IoT - Advanced Firmware Security & Audit Logging UI Tests', () {
    test('AuditEntryModel parses event_id, actor, and result fields', () {
      final json = {
        'event_id': 'EVT-A1B2C3D4E5F6',
        'event_type': 'FIRMWARE_VERIFIED',
        'actor': 'VENDOR-SECUREMED-PRIMARY',
        'result': 'SUCCESS',
        'device_id': 'VENDOR-SECUREMED-PRIMARY',
        'timestamp': '2026-11-01T03:30:00Z',
        'details': {'version': '2.5.0'},
        'previous_hash': 'PREV_HASH_123',
        'entry_hash': 'ENTRY_HASH_456',
      };

      final entry = AuditEntryModel.fromJson(json);

      expect(entry.eventId, 'EVT-A1B2C3D4E5F6');
      expect(entry.event, 'FIRMWARE_VERIFIED');
      expect(entry.actor, 'VENDOR-SECUREMED-PRIMARY');
      expect(entry.result, 'SUCCESS');
      expect(entry.isSuccess, isTrue);
      expect(entry.isRejected, isFalse);
      expect(entry.parentHash, 'PREV_HASH_123');
      expect(entry.blockHash, 'ENTRY_HASH_456');
    });

    test('AuditVerificationReport and AuditAnchoringReport parse limitation disclosure', () {
      final verifyJson = {
        'is_intact': true,
        'total_blocks_verified': 15,
        'head_hash': 'HEAD_HASH_999',
        'message': 'All blocks intact',
        'limitation_disclosure': 'Local hash chaining limitation notice: external anchoring required.',
      };

      final vReport = AuditVerificationReport.fromJson(verifyJson);
      expect(vReport.isIntact, isTrue);
      expect(vReport.totalBlocksVerified, 15);
      expect(vReport.limitationDisclosure, contains('external anchoring required'));

      final anchorJson = {
        'audit_head_hash': 'HEAD_HASH_999',
        'chain_length': 15,
        'latest_event_id': 'EVT-999',
        'latest_timestamp': '2026-11-01T03:35:00Z',
        'anchoring_digest': 'DIGEST_SHA256_HEX',
        'limitation_disclosure': 'External anchoring prevents full database replacement.',
      };

      final aReport = AuditAnchoringReport.fromJson(anchorJson);
      expect(aReport.chainLength, 15);
      expect(aReport.anchoringDigest, 'DIGEST_SHA256_HEX');
      expect(aReport.limitationDisclosure, contains('External anchoring'));
    });

    testWidgets('AuditLogsTab displays hash-chain verification, export anchor, and limitation notice', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditLogsTab(onRefresh: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Audit Ledger Chain Header
      expect(find.text('Audit Ledger Chain'), findsOneWidget);

      // Verify Hash-Chain Integrity Status Card
      expect(find.text('Hash-Chain Integrity Status'), findsOneWidget);
      expect(find.text('Verify Chain'), findsOneWidget);
      expect(find.text('Export Anchor'), findsOneWidget);

      // Verify Permanent Security Limitation Notice
      expect(
        find.textContaining('Security Notice: Local hash chaining prevents modification of past records.'),
        findsOneWidget,
      );
    });

    testWidgets('SecurityCenterTab displays Firmware Security & Anti-Rollback Attestation Card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecurityCenterTab(
              securityAlerts: const [],
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Firmware Security Card Title & Badges
      expect(find.text('Firmware Security & Anti-Rollback'), findsOneWidget);
      expect(find.text('ML-DSA-65 ATTESTED'), findsOneWidget);
      expect(find.textContaining('Baseline: v2.4.1'), findsOneWidget);
      expect(find.textContaining('Min Permitted: v2.0.0'), findsOneWidget);

      // Verify interactive action buttons
      expect(find.text('Verify Package'), findsOneWidget);
      expect(find.text('Test Rollback Block'), findsOneWidget);
    });
  });
}
