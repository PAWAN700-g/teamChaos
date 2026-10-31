import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CryptoTab extends StatefulWidget {
  const CryptoTab({super.key});

  @override
  State<CryptoTab> createState() => _CryptoTabState();
}

class _CryptoTabState extends State<CryptoTab> {
  final ApiService _apiService = ApiService();
  bool _isRunningTest = false;
  Map<String, dynamic>? _selfTestResult;
  String? _testError;

  void _runCryptoSelfTest() async {
    setState(() {
      _isRunningTest = true;
      _testError = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final res = await _apiService.getCryptoStatus();
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _isRunningTest = false;
          _selfTestResult = {
            ...res,
            'latency_ms': stopwatch.elapsedMilliseconds,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunningTest = false;
          _testError = e.toString();
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
          Text(
            'Quantum-Resistant Cryptographic Engine',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Standardized NIST Post-Quantum Cryptography implementations protecting clinical IoT devices from Harvest-Now-Decrypt-Later threats.',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 16),

          // Algorithm 1: ML-KEM-768
          _buildAlgorithmCard(
            context,
            standard: 'NIST FIPS 203',
            name: 'ML-KEM-768 (Module-Lattice KEM)',
            role: 'Post-Quantum Key Establishment',
            securityLevel: 'Category 3 (AES-192 equivalent)',
            details: [
              'Public Key Size: 1,184 bytes',
              'Ciphertext Size: 1,088 bytes',
              'Established Secret: 32 bytes (256-bit)',
              'Protects session secret encapsulation against future quantum cryptanalysis',
            ],
            color: const Color(0xFF00796B),
            icon: Icons.vpn_key_rounded,
          ),
          const SizedBox(height: 12),

          // Algorithm 2: ML-DSA-65
          _buildAlgorithmCard(
            context,
            standard: 'NIST FIPS 204',
            name: 'ML-DSA-65 (Module-Lattice DSA)',
            role: 'Device Identity & Firmware Attestation',
            securityLevel: 'Category 3 (AES-192 equivalent)',
            details: [
              'Public Key Size: 1,952 bytes',
              'Digital Signature Size: 3,309 bytes',
              'Mutual authentication during challenge-response handshake',
              'Vendor firmware integrity verification preventing unauthorized updates',
            ],
            color: const Color(0xFF00695C),
            icon: Icons.draw_rounded,
          ),
          const SizedBox(height: 12),

          // Algorithm 3: AES-256-GCM & HKDF
          _buildAlgorithmCard(
            context,
            standard: 'NIST SP 800-38D & RFC 5869',
            name: 'AES-256-GCM + HKDF-SHA-256',
            role: 'Authenticated Telemetry Encryption',
            securityLevel: '256-bit Symmetric & Key Derivation',
            details: [
              'Authenticated Associated Data (AAD) binding device ID, session ID, sequence & timestamp',
              '96-bit unique nonces with strict reuse prevention',
              '128-bit authentication tag validating ciphertext integrity',
              'Dual independent keys: telemetry_enc_key and telemetry_mac_key',
            ],
            color: const Color(0xFF004D40),
            icon: Icons.enhanced_encryption_rounded,
          ),
          const SizedBox(height: 20),

          // Live Engine Verification Action Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.teal, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Live PQC Cryptographic Self-Test',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Directly triggers backend ML-KEM-768 encapsulation/decapsulation and ML-DSA-65 signature self-tests on the gateway.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 14),

                  if (_selfTestResult != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.teal, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Engine Operational: PQC Ready',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal.shade900),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_selfTestResult!["latency_ms"]} ms',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Active Sessions: ${_selfTestResult!["active_pqc_sessions"]} | Devices: ${_selfTestResult!["registered_devices"]} | Audit Blocks: ${_selfTestResult!["audit_chain_length"]}',
                            style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Head Hash: ${_selfTestResult!["audit_head_hash"]?.substring(0, 24)}...',
                            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.teal.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_testError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Self-Test Error: $_testError',
                        style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isRunningTest ? null : _runCryptoSelfTest,
                      icon: _isRunningTest
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(_isRunningTest ? 'Running Self-Test...' : 'Run Engine Self-Test'),
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

  Widget _buildAlgorithmCard(
    BuildContext context, {
    required String standard,
    required String name,
    required String role,
    required String securityLevel,
    required List<String> details,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    standard,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$role • $securityLevel',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 14),
            for (final detail in details)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
