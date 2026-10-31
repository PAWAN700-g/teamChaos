import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../models/user_profile.dart';
import '../models/telemetry_model.dart';
import '../widgets/vital_chart.dart';
import '../widgets/simulated_badge.dart';
import '../repositories/device_repository.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final DeviceModel device;
  final UserProfile? user;
  final List<TelemetryModel> telemetryHistory;
  final VoidCallback? onDeviceUpdated;

  const DeviceDetailsScreen({
    super.key,
    required this.device,
    this.user,
    this.telemetryHistory = const [],
    this.onDeviceUpdated,
  });

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final DeviceRepository _deviceRepo = DeviceRepository();
  late DeviceModel _device;
  bool _isRevoking = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  bool get _canManageDevice {
    final role = widget.user?.role;
    return role == UserRole.admin || role == UserRole.securityAnalyst;
  }

  void _confirmAndRevoke() async {
    final reasonController = TextEditingController(text: 'Security Operator Incident Response Revocation');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Revocation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revoking "${_device.deviceId}" will immediately invalidate its ML-DSA-65 public key identity and terminate all active AES-256-GCM sessions.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Revocation',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke Device'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isRevoking = true;
        _statusMessage = null;
      });

      try {
        final updated = await _deviceRepo.revokeDevice(_device.deviceId, reason: reasonController.text);
        if (mounted) {
          setState(() {
            _isRevoking = false;
            _device = updated;
            _statusMessage = 'Device credentials revoked successfully.';
          });
          widget.onDeviceUpdated?.call();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isRevoking = false;
            _statusMessage = 'Revocation failed: ${e.toString()}';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter telemetry for this specific device
    final deviceTelemetry = widget.telemetryHistory
        .where((t) => t.deviceId == _device.deviceId)
        .toList();

    final latest = deviceTelemetry.isNotEmpty ? deviceTelemetry.last : null;
    final hr = latest?.heartRate ?? 72;
    final spo2 = latest?.spo2 ?? 98;
    final hrTrend = deviceTelemetry.isNotEmpty
        ? deviceTelemetry.map((t) => t.heartRate.toDouble()).toList()
        : <double>[70, 72, 74, 73, 72, 75, 74, 72];
    final spo2Trend = deviceTelemetry.isNotEmpty
        ? deviceTelemetry.map((t) => t.spo2.toDouble()).toList()
        : <double>[98, 98, 97, 98, 99, 98, 98, 98];

    final fingerprint = _device.dsaPublicKeyB64.isNotEmpty
        ? '${_device.dsaPublicKeyB64.substring(0, 16)}...${_device.dsaPublicKeyB64.substring(_device.dsaPublicKeyB64.length - 16)}'
        : 'ML-DSA-65-GENESIS-KEY';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _device.deviceId,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _device.isOnline ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _device.isOnline ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _device.isOnline ? const Color(0xFF10B981) : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _device.isOnline ? 'ONLINE' : 'REVOKED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _device.isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Feedback Message
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage!.contains('failed') ? Colors.red.shade50 : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage!.contains('failed') ? Colors.redAccent : const Color(0xFF10B981),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage!.contains('failed') ? Icons.error_outline : Icons.check_circle_outline,
                      size: 18,
                      color: _statusMessage!.contains('failed') ? Colors.red : const Color(0xFF065F46),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusMessage!.contains('failed') ? Colors.red.shade900 : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 1. Device Profile Card
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _device.deviceType,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SimulatedBadge(isCompact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${_device.deviceId}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF475569)),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow('PQC Protection', _device.isPqcSecured ? 'ML-DSA-65 + ML-KEM-768' : 'Standard'),
                    _buildInfoRow('Registered At', _device.registeredAt.isNotEmpty ? _device.registeredAt : 'Default Seed'),
                    if (_device.revokedAt != null)
                      _buildInfoRow('Revoked At', _device.revokedAt!, isAlert: true),
                    _buildInfoRow('Last Telemetry', latest?.timestamp ?? 'Recent session active'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Vitals Monitoring Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Simulated Vitals Feed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SimulatedBadge(isCompact: true),
              ],
            ),
            const SizedBox(height: 10),
            HeartRateTrendChart(values: hrTrend, currentBpm: hr),
            const SizedBox(height: 10),
            SpO2TrendChart(values: spo2Trend, currentSpo2: spo2),
            const SizedBox(height: 10),
            EcgWaveformView(heartRate: hr),
            const SizedBox(height: 18),

            // 3. Post-Quantum Identity & Encryption Card
            Text(
              'Cryptographic Session & Identity',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCryptoDetailItem(
                      icon: Icons.fingerprint,
                      title: 'ML-DSA-65 Public Key (FIPS 204)',
                      subtitle: 'Size: 1,952 bytes | Category 3 Quantum Safe',
                      value: fingerprint,
                    ),
                    const Divider(height: 18),
                    _buildCryptoDetailItem(
                      icon: Icons.lock_clock,
                      title: 'Symmetric Cipher (SP 800-38D)',
                      subtitle: 'Key length: 256-bit | 128-bit MAC Auth Tag',
                      value: 'AES-256-GCM + Nonce Monotonic Window',
                    ),
                    const Divider(height: 18),
                    _buildCryptoDetailItem(
                      icon: Icons.vpn_key,
                      title: 'Shared Secret KEM (FIPS 203)',
                      subtitle: 'Encapsulated ciphertext: 1,088 bytes',
                      value: 'ML-KEM-768 Established Session',
                    ),
                    const Divider(height: 18),
                    _buildCryptoDetailItem(
                      icon: Icons.receipt_long,
                      title: 'Authenticated Associated Data (AAD)',
                      subtitle: 'Header binding prevents envelope substitution',
                      value: 'AAD: ${_device.deviceId}:SES-ACTIVE:Seq#${latest?.sequenceNumber ?? 1}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 4. Emergency Revocation Action
            if (_canManageDevice && !_device.isRevoked) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRevoking ? null : _confirmAndRevoke,
                  icon: _isRevoking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.block),
                  label: const Text('Revoke Device Credentials'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else if (!_canManageDevice) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only clinician mode: Device revocation requires Administrator or Security Analyst role.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.redAccent : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoDetailItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00796B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF0D9488)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
