import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/device_model.dart';
import '../../models/telemetry_model.dart';
import '../../models/security_alert_model.dart';
import '../../widgets/summary_metric_card.dart';
import '../../widgets/vital_chart.dart';
import '../../widgets/simulated_badge.dart';

class DashboardTab extends StatelessWidget {
  final UserProfile? user;
  final bool isLoading;
  final String backendStatus;
  final VoidCallback onRefresh;
  final List<DeviceModel> devices;
  final List<TelemetryModel> telemetryStream;
  final List<SecurityAlertModel> securityAlerts;
  final Function(DeviceModel)? onSelectDevice;

  const DashboardTab({
    super.key,
    this.user,
    required this.isLoading,
    required this.backendStatus,
    required this.onRefresh,
    required this.devices,
    required this.telemetryStream,
    required this.securityAlerts,
    this.onSelectDevice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Compute device fleet metrics
    final totalDevices = devices.length;
    final onlineDevices = devices.where((d) => d.isOnline).length;
    final offlineDevices = totalDevices - onlineDevices;
    final activeAlerts = securityAlerts.length;

    // Latest vitals
    final latestTelemetry = telemetryStream.isNotEmpty ? telemetryStream.last : null;
    final heartRate = latestTelemetry?.heartRate ?? 74;
    final spo2 = latestTelemetry?.spo2 ?? 98;

    // Synthetic trend history for sparklines
    final hrHistory = telemetryStream.isNotEmpty
        ? telemetryStream.map((t) => t.heartRate.toDouble()).toList()
        : <double>[72, 75, 73, 76, 74, 75, 78, 74, 72, 74];
    final spo2History = telemetryStream.isNotEmpty
        ? telemetryStream.map((t) => t.spo2.toDouble()).toList()
        : <double>[98, 98, 97, 98, 99, 98, 97, 98, 98, 98];

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Simulation Notice Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'HOSPITAL CYBERSECURITY SANDBOX: All clinical patient data and waveforms are SYNTHETIC & SIMULATED.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Gateway Connection Status Bar
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: backendStatus.contains('Online') ? const Color(0xFF10B981) : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    backendStatus,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00796B)),
                        )
                      : const Icon(Icons.sync, size: 18, color: Color(0xFF00796B)),
                  tooltip: 'Sync Gateway Telemetry',
                  onPressed: isLoading ? null : onRefresh,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 1. Summary Metrics Grid (Total, Online, Offline, Alerts)
            Text(
              'Fleet Overview & Security State',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SummaryMetricCard(
                    title: 'Total Devices',
                    value: '$totalDevices',
                    subtitle: 'Provisioned PQC nodes',
                    icon: Icons.devices,
                    iconColor: const Color(0xFF00796B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryMetricCard(
                    title: 'Online Active',
                    value: '$onlineDevices',
                    subtitle: 'Authenticated & live',
                    icon: Icons.wifi,
                    iconColor: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SummaryMetricCard(
                    title: 'Offline / Revoked',
                    value: '$offlineDevices',
                    subtitle: 'Decommissioned',
                    icon: Icons.wifi_off,
                    iconColor: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryMetricCard(
                    title: 'Security Alerts',
                    value: '$activeAlerts',
                    subtitle: activeAlerts > 0 ? 'Review SIEM alerts' : 'Normal status',
                    icon: Icons.warning_amber_rounded,
                    iconColor: activeAlerts > 0 ? Colors.redAccent : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Post-Quantum Cryptographic Architecture Summary Card
            Text(
              'Post-Quantum Cryptographic Architecture',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
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
                    const Divider(height: 16),
                    _buildCryptoSummaryRow(
                      context,
                      title: 'Digital Signature Algorithm',
                      algo: 'ML-DSA-65 (Dilithium)',
                      desc: 'Quantum-safe mutual device authentication & firmware verification',
                      status: 'Active',
                    ),
                    const Divider(height: 16),
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

            // 3. Connected Device Fleet Summary Section
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Connected Device Fleet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$onlineDevices/$totalDevices online',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.isNotEmpty ? (devices.length > 3 ? 3 : devices.length) : 1,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (devices.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text('No devices currently registered', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ),
                    );
                  }
                  final dev = devices[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: dev.isRevoked ? Colors.red.shade50 : const Color(0xFF00796B).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.medical_services_outlined,
                        size: 16,
                        color: dev.isRevoked ? Colors.redAccent : const Color(0xFF00796B),
                      ),
                    ),
                    title: Text(
                      dev.deviceId,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${dev.deviceType} | ML-DSA-65 Authenticated',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: dev.isOnline ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dev.isOnline ? 'ONLINE' : 'REVOKED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: dev.isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // 4. Latest Patient Vitals Monitor (Heart Rate & SpO2)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Latest Telemetry Vitals',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const SimulatedBadge(isCompact: true),
              ],
            ),
            const SizedBox(height: 8),
            HeartRateTrendChart(
              values: hrHistory,
              currentBpm: heartRate,
            ),
            const SizedBox(height: 12),
            SpO2TrendChart(
              values: spo2History,
              currentSpo2: spo2,
            ),
            const SizedBox(height: 12),
            EcgWaveformView(heartRate: heartRate),
            const SizedBox(height: 20),

            // 5. Recent Security & Telemetry Events Feed
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Gateway Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${telemetryStream.length} packets',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (telemetryStream.isEmpty)
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF94A3B8)),
                        SizedBox(height: 8),
                        Text(
                          'No telemetry received yet',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap Sync or start the medical device simulator to stream packets.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: telemetryStream.length > 5 ? 5 : telemetryStream.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = telemetryStream.reversed.toList()[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock, size: 16, color: Color(0xFF00796B)),
                      ),
                      title: Text(
                        '${item.deviceId} (Seq #${item.sequenceNumber})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'HR: ${item.heartRate} bpm | SpO2: ${item.spo2}% | AES-256-GCM Verified',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      trailing: const Text(
                        'PQC Valid',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoSummaryRow(
    BuildContext context, {
    required String title,
    required String algo,
    required String desc,
    required String status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified, size: 16, color: Color(0xFF00796B)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              Text(
                algo,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
          ),
        ),
      ],
    );
  }
}
