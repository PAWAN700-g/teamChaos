import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/role_badge.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isConnecting = false;
  String _backendStatus = 'Ready (Tap Sync to connect)';
  List<Map<String, dynamic>> _liveTelemetry = [];
  List<Map<String, dynamic>> _securityAlerts = [];
  bool _hasSynced = false;

  void _checkBackendConnection() async {
    setState(() {
      _isConnecting = true;
      _backendStatus = 'Connecting to Gateway...';
    });

    try {
      final health = await _apiService.getHealth();
      final telemetry = await _apiService.getLatestTelemetry();

      final stream = (telemetry["telemetry_stream"] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      final alerts = (telemetry["security_alerts"] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _hasSynced = true;
          _liveTelemetry = stream;
          _securityAlerts = alerts;
          final kem = health["cryptography"]?["kem_algorithm"] ?? "ML-KEM-768";
          final totalPackets = telemetry["total_packets_ingested"] ?? stream.length;
          _backendStatus = 'Online ($kem) | Verified Packets: $totalPackets';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _backendStatus = 'Gateway Offline (${e.toString()})';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userProfile;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Unauthenticated Session')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            Icon(Icons.security, size: 22, color: Color(0xFF00796B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'SecureMed IoT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout (${user.email})',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Session Profile Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.15),
                          child: Text(
                            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => context.read<AuthProvider>().signOut(),
                          icon: const Icon(Icons.logout, size: 14),
                          label: const Text('Log Out', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Flexible(child: RoleBadge(role: user.role, isDense: false)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(Icons.verified, size: 14, color: Colors.green),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Authenticated via Firebase & Firestore',
                            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

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

            // Post-Quantum Cryptographic Architecture Section
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
                    _buildCryptoRow(
                      context,
                      title: 'Key Encapsulation Mechanism',
                      algo: 'ML-KEM-768 (Kyber)',
                      desc: 'Quantum-resistant key encapsulation for session secrets',
                      status: 'Active',
                    ),
                    const Divider(height: 18),
                    _buildCryptoRow(
                      context,
                      title: 'Digital Signature Algorithm',
                      algo: 'ML-DSA-65 (Dilithium)',
                      desc: 'Quantum-safe mutual device authentication & identity attestations',
                      status: 'Active',
                    ),
                    const Divider(height: 18),
                    _buildCryptoRow(
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

            // Connected Medical Device Fleet Header
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
                  onPressed: _isConnecting ? null : _checkBackendConnection,
                  icon: _isConnecting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Sync Backend'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Backend Gateway Status: $_backendStatus',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Live Ingested Packets if Synced, otherwise Default Simulated Fleet
            if (_hasSynced && _liveTelemetry.isNotEmpty) ...[
              for (final packet in _liveTelemetry.reversed)
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
            ],

            // Security Alerts Section
            if (_securityAlerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Active Security & Anomaly Incidents (${_securityAlerts.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 8),
              for (final alert in _securityAlerts.reversed.take(3))
                Card(
                  color: Colors.red.shade50,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${alert["attack_type"] ?? "ANOMALY"} [${alert["device_id"] ?? "UNKNOWN"}]',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alert["description"] ?? "Security incident recorded",
                                style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoRow(
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

  Widget _buildLiveTelemetryCard(BuildContext context, {required Map<String, dynamic> packet}) {
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

  Widget _buildDeviceCard(
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
