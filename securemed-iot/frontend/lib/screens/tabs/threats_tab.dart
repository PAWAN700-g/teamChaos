import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ThreatsTab extends StatefulWidget {
  final List<Map<String, dynamic>> securityAlerts;
  final VoidCallback onRefresh;

  const ThreatsTab({
    super.key,
    required this.securityAlerts,
    required this.onRefresh,
  });

  @override
  State<ThreatsTab> createState() => _ThreatsTabState();
}

class _ThreatsTabState extends State<ThreatsTab> {
  final ApiService _apiService = ApiService();
  final _revokeController = TextEditingController(text: 'MED-DEV-ICU-701A');
  bool _isRevoking = false;
  String? _revokeStatus;

  @override
  void dispose() {
    _revokeController.dispose();
    super.dispose();
  }

  void _executeRevocation() async {
    final deviceId = _revokeController.text.trim();
    if (deviceId.isEmpty) return;

    setState(() {
      _isRevoking = true;
      _revokeStatus = null;
    });

    try {
      final res = await _apiService.revokeDevice(deviceId, reason: "Security operator emergency revocation");
      if (mounted) {
        setState(() {
          _isRevoking = false;
          _revokeStatus = 'SUCCESS: Device $deviceId credentials revoked! Status: ${res["status"]}';
        });
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRevoking = false;
          _revokeStatus = 'REVOCATION FAILED: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cybersecurity Threat SIEM & Defense',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: widget.onRefresh,
                tooltip: 'Refresh Security Feed',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Real-time intrusion detection monitoring replay attacks, MITM ciphertext tampering, and physiological anomalies.',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 16),

          // Security Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'Incidents Logged',
                  value: '${widget.securityAlerts.length}',
                  color: widget.securityAlerts.isNotEmpty ? Colors.red : Colors.teal,
                  icon: Icons.security,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'Replay Protection',
                  value: 'ACTIVE',
                  color: Colors.teal,
                  icon: Icons.replay_circle_filled_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'Freshness Window',
                  value: '±60 sec',
                  color: Colors.teal,
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Defensive Posture Matrix
          Text(
            'Active Cryptographic Defenses',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: const [
                  _DefenseItem(
                    title: 'Monotonic Sequence Number Tracking',
                    desc: 'Every telemetry envelope must strictly increment sequence (Sn > SlastSeen). Duplicate or out-of-order packets are rejected.',
                    status: 'Enforced',
                  ),
                  Divider(height: 14),
                  _DefenseItem(
                    title: 'Temporal Freshness Clock Drift Window',
                    desc: 'Packets drifting beyond ±60 seconds from Gateway UTC time are rejected as stale or spoofed.',
                    status: 'Enforced',
                  ),
                  Divider(height: 14),
                  _DefenseItem(
                    title: 'Cryptographic Nonce-Reuse Prevention',
                    desc: 'Reusing a 96-bit AES-GCM nonce under the same active session key triggers immediate packet drop and alert.',
                    status: 'Enforced',
                  ),
                  Divider(height: 14),
                  _DefenseItem(
                    title: 'AAD Envelope Integrity Binding',
                    desc: 'Device ID, Session ID, Sequence Number, and Timestamp are bound as Authenticated Associated Data into the GCM auth tag.',
                    status: 'Enforced',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Emergency Device Revocation Tool
          Text(
            'Emergency Device Revocation',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instantly revoke a compromised medical device. Revocation invalidates its ML-DSA-65 credentials and closes all active sessions.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _revokeController,
                          decoration: const InputDecoration(
                            labelText: 'Device Identifier',
                            prefixIcon: Icon(Icons.phonelink_erase_rounded, size: 20),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: _isRevoking ? null : _executeRevocation,
                        child: _isRevoking
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Revoke'),
                      ),
                    ],
                  ),
                  if (_revokeStatus != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _revokeStatus!.startsWith('SUCCESS') ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _revokeStatus!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _revokeStatus!.startsWith('SUCCESS') ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Live Incident Feed
          Text(
            'Security Incident Log Feed (${widget.securityAlerts.length})',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (widget.securityAlerts.isEmpty)
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No security incidents detected. System operating normally under Post-Quantum Cryptographic protection.',
                    style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            for (final alert in widget.securityAlerts.reversed)
              Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.red.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    alert["attack_type"] ?? "SECURITY_ALERT",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    alert["severity"]?.toString().toUpperCase() ?? "CRITICAL",
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alert["description"] ?? "Suspicious activity blocked by gateway",
                              style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Device: ${alert["device_id"] ?? "N/A"} | Time: ${alert["timestamp"] ?? "Just now"}',
                              style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DefenseItem extends StatelessWidget {
  final String title;
  final String desc;
  final String status;

  const _DefenseItem({
    required this.title,
    required this.desc,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_rounded, size: 16, color: Colors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(status, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
        ),
      ],
    );
  }
}
