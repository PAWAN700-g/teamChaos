import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class FleetTab extends StatelessWidget {
  final UserProfile? user;
  final bool isConnecting;
  final String backendStatus;
  final VoidCallback onSyncBackend;
  final List<Map<String, dynamic>> liveTelemetry;
  final bool hasSynced;

  const FleetTab({
    super.key,
    this.user,
    required this.isConnecting,
    required this.backendStatus,
    required this.onSyncBackend,
    required this.liveTelemetry,
    required this.hasSynced,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hackathon Prototype Disclaimer Card
          Card(
            color: colorScheme.errorContainer.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'HACKATHON PROTOTYPE ONLY: Simulated medical devices & synthetic patient data. '
                      'Never connect to live clinical hardware or use for patient treatment.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Post-Quantum Cryptographic Architecture Card Summary
          Text(
            'Post-Quantum Cryptographic Architecture',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  _buildCryptoSummaryRow(
                    context,
                    title: 'Key Encapsulation Mechanism',
                    algo: 'ML-KEM-768 (Kyber)',
                    desc: 'Quantum-resistant key encapsulation for session secrets',
                    status: 'Active',
                  ),
                  const Divider(height: 18),
                  _buildCryptoSummaryRow(
                    context,
                    title: 'Digital Signature Algorithm',
                    algo: 'ML-DSA-65 (Dilithium)',
                    desc: 'Quantum-safe mutual device authentication & identity attestations',
                    status: 'Active',
                  ),
                  const Divider(height: 18),
                  _buildCryptoSummaryRow(
                    context,
                    title: 'Symmetric Cipher & KDF',
                    algo: 'AES-256-GCM + HKDF-SHA-256',
                    desc: 'Authenticated telemetry stream encryption & key derivation',
                    status: 'Active',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Connected Device Fleet Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Connected Device Fleet',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: isConnecting ? null : onSyncBackend,
                icon: isConnecting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 16),
                label: const Text('Sync Backend'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Backend Gateway Status: $backendStatus',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Live Ingested Packets if Synced, otherwise Default Simulated Fleet
          if (hasSynced && liveTelemetry.isNotEmpty) ...[
            for (final packet in liveTelemetry.reversed)
              _buildLiveTelemetryCard(context, packet: packet),
          ] else ...[
            _buildDeviceCard(
              context,
              name: 'ICU Patient Monitor #01',
              deviceId: 'MED-DEV-ICU-701A',
              deviceType: 'Multi-parameter Vital Monitor',
              status: 'Secured via ML-KEM-768',
              vitals: 'HR: 76 bpm | SpO2: 98% | BP: 120/80 mmHg',
              isSecure: true,
            ),
            const SizedBox(height: 10),
            _buildDeviceCard(
              context,
              name: 'Smart Infusion Pump #04',
              deviceId: 'MED-DEV-INF-412C',
              deviceType: 'Continuous Infusion Controller',
              status: 'Secured via ML-KEM-768',
              vitals: 'Flow Rate: 2.5 mL/h | Volume Infused: 48.0 mL',
              isSecure: true,
            ),
            const SizedBox(height: 10),
            _buildDeviceCard(
              context,
              name: 'Intelligent Ventilator #02',
              deviceId: 'MED-DEV-VENT-901B',
              deviceType: 'Autonomous Respiratory Assist',
              status: 'Secured via ML-KEM-768',
              vitals: 'FiO2: 40% | PEEP: 5 cmH2O | RR: 14 bpm',
              isSecure: true,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildCryptoSummaryRow(
    BuildContext context, {
    required String title,
    required String algo,
    required String desc,
    required String status,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_clock_outlined, size: 20, color: Color(0xFF00796B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                algo,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF00796B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(desc, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
          ),
        ),
      ],
    );
  }

  static Widget _buildLiveTelemetryCard(BuildContext context, {required Map<String, dynamic> packet}) {
    final theme = Theme.of(context);
    final vitals = packet["vitals"] as Map<String, dynamic>? ?? {};
    final deviceId = packet["device_id"] ?? "DEV-UNKNOWN";
    final isAnomaly = packet["tampering_detected"] == true;
    final seq = packet["sequence_number"] ?? 0;

    String vitalsSummary = vitals.entries
        .map((e) => '${e.key.replaceAll("_", " ")}: ${e.value}')
        .join(' | ');
    if (vitalsSummary.isEmpty) vitalsSummary = "Synthetic vitals stream active";

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isAnomaly ? const BorderSide(color: Colors.red, width: 1.2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAnomaly ? Icons.error_outline : Icons.verified_user_rounded,
                  color: isAnomaly ? Colors.red : Colors.teal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    packet["device_type"] ?? "Medical Telemetry Stream",
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    deviceId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                vitalsSummary,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seq #$seq | AES-256-GCM + ML-DSA-65',
                  style: TextStyle(
                    color: isAnomaly ? Colors.red : Colors.teal,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isAnomaly ? 'ANOMALY DETECTED' : 'PQC Verified',
                  style: TextStyle(
                    color: isAnomaly ? Colors.red : Colors.teal,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDeviceCard(
    BuildContext context, {
    required String name,
    required String deviceId,
    required String deviceType,
    required String status,
    required String vitals,
    required bool isSecure,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSecure ? Icons.verified_user_rounded : Icons.pending_outlined,
                  color: isSecure ? Colors.teal : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    deviceId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              deviceType,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                vitals,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                status,
                style: TextStyle(
                  color: isSecure ? Colors.teal : Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
