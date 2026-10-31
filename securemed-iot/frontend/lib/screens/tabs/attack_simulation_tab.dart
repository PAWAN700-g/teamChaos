import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/simulation_result_model.dart';
import '../../repositories/security_repository.dart';

class AttackSimulationTab extends StatefulWidget {
  final VoidCallback? onAttackCompleted;

  const AttackSimulationTab({super.key, this.onAttackCompleted});

  @override
  State<AttackSimulationTab> createState() => _AttackSimulationTabState();
}

class _AttackSimulationTabState extends State<AttackSimulationTab> {
  final SecurityRepository _securityRepo = SecurityRepository();

  bool _isSimulating = false;
  String? _currentRunningAttack;
  SimulationResultModel? _lastResult;
  String? _simulationError;

  void _runSimulation(String attackType, Future<SimulationResultModel> Function() runner) async {
    setState(() {
      _isSimulating = true;
      _currentRunningAttack = attackType;
      _simulationError = null;
    });

    try {
      final res = await runner();
      if (mounted) {
        setState(() {
          _isSimulating = false;
          _currentRunningAttack = null;
          _lastResult = res;
        });
        widget.onAttackCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSimulating = false;
          _currentRunningAttack = null;
          _simulationError = 'Simulation failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Cybersecurity Attack Simulator',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Simulate real-world hostile threat vectors against the Post-Quantum Gateway to verify defense defenses.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // Simulation Error (if any)
          if (_simulationError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _simulationError!,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Returned Detection Result Card (if any)
          if (_lastResult != null) ...[
            _buildDetectionResultCard(_lastResult!),
            const SizedBox(height: 20),
          ],

          // Attack Simulation Buttons List
          Text(
            'Live Attack Scenarios',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          _buildAttackCard(
            title: '1. Device Impersonation',
            badge: 'PQC DSA Identity',
            badgeColor: Colors.deepOrange,
            description: 'Unregistered device with invalid signature attempts authentication and telemetry transmission.',
            endpoint: 'POST /api/v1/simulation/device-impersonation',
            attackKey: 'DEVICE_IMPERSONATION',
            onTap: () => _runSimulation('DEVICE_IMPERSONATION', _securityRepo.runDeviceImpersonationSimulation),
          ),
          const SizedBox(height: 10),

          _buildAttackCard(
            title: '2. Replay Attack',
            badge: 'Sequence Monotonicity',
            badgeColor: Colors.purple,
            description: 'Captures and replays valid telemetry with identical session and sequence number.',
            endpoint: 'POST /api/v1/simulation/replay',
            attackKey: 'REPLAY',
            onTap: () => _runSimulation('REPLAY', _securityRepo.runReplayAttackSimulation),
          ),
          const SizedBox(height: 10),

          _buildAttackCard(
            title: '3. Telemetry Tampering',
            badge: 'AES-GCM Auth Tag',
            badgeColor: Colors.red.shade700,
            description: 'Flips ciphertext bytes in transit to test 128-bit GHASH authentication tag verification failure.',
            endpoint: 'POST /api/v1/simulation/tampering',
            attackKey: 'TAMPERING',
            onTap: () => _runSimulation('TAMPERING', _securityRepo.runTamperingSimulation),
          ),
          const SizedBox(height: 10),

          _buildAttackCard(
            title: '4. Unauthorized Access',
            badge: 'RBAC Policy Guard',
            badgeColor: Colors.amber.shade900,
            description: 'Authenticated Doctor role attempts an Admin-only operation (HTTP 403 Forbidden).',
            endpoint: 'POST /api/v1/simulation/unauthorized-access',
            attackKey: 'UNAUTHORIZED_ACCESS',
            onTap: () => _runSimulation('UNAUTHORIZED_ACCESS', _securityRepo.runUnauthorizedAccessSimulation),
          ),
          const SizedBox(height: 10),

          _buildAttackCard(
            title: '5. Firmware Tampering',
            badge: 'FIPS 204 ML-DSA',
            badgeColor: Colors.blueGrey.shade800,
            description: 'Firmware package payload altered after signing, causing post-quantum signature verification failure.',
            endpoint: 'POST /api/v1/simulation/firmware-tampering',
            attackKey: 'FIRMWARE',
            onTap: () => _runSimulation('FIRMWARE', _securityRepo.runFirmwareTamperingSimulation),
          ),
          const SizedBox(height: 10),

          _buildAttackCard(
            title: '6. Rate-Limit Attack',
            badge: 'Token Bucket Flood Defense',
            badgeColor: Colors.teal.shade800,
            description: 'Controlled burst of requests exceeding threshold, triggering HTTP 429 Too Many Requests.',
            endpoint: 'POST /api/v1/simulation/rate-limit',
            attackKey: 'RATE_LIMIT',
            onTap: () => _runSimulation('RATE_LIMIT', _securityRepo.runRateLimitSimulation),
          ),
          const SizedBox(height: 10),

          _buildAttackCard(
            title: '7. Device Revocation',
            badge: 'CRL Revocation Guard',
            badgeColor: Colors.indigo.shade800,
            description: 'Revoked test device attempts re-authentication and is rejected by the gateway.',
            endpoint: 'POST /api/v1/simulation/device-revocation',
            attackKey: 'DEVICE_REVOCATION',
            onTap: () => _runSimulation('DEVICE_REVOCATION', _securityRepo.runDeviceRevocationSimulation),
          ),
          const SizedBox(height: 10),

          _buildAttackCard(
            title: '8. Audit Log Modification',
            badge: 'SHA-256 Hash Chain',
            badgeColor: Colors.brown.shade800,
            description: 'Modifies an audit ledger record, triggering hash-chain integrity verification failure.',
            endpoint: 'POST /api/v1/simulation/audit-modification',
            attackKey: 'AUDIT_MODIFICATION',
            onTap: () => _runSimulation('AUDIT_MODIFICATION', _securityRepo.runAuditModificationSimulation),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAttackCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required String description,
    required String endpoint,
    required String attackKey,
    required VoidCallback onTap,
  }) {
    final isRunning = _isSimulating && _currentRunningAttack == attackKey;

    return Card(
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Text(
              endpoint,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSimulating ? null : onTap,
                icon: isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(isRunning ? 'Simulating Threat...' : 'Execute Simulation Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionResultCard(SimulationResultModel result) {
    final simulatedInputJson = result.simulatedInput.isNotEmpty
        ? const JsonEncoder.withIndent('  ').convert(result.simulatedInput)
        : '{}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A192F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'SECURITY VERIFICATION RESULT',
                style: TextStyle(
                  color: Color(0xFF2DD4BF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                ),
                child: Text(
                  result.detectionStatus,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.attackName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),

          // Required 4 Core Parameters
          _buildResultSection(
            title: 'SIMULATED ATTACK INPUT',
            content: simulatedInputJson,
            isMonospace: true,
            bgColor: const Color(0xFF0F172A),
          ),
          const SizedBox(height: 8),

          _buildResultSection(
            title: 'BACKEND SECURITY MECHANISM',
            content: result.securityMechanism,
            textColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 8),

          _buildResultSection(
            title: 'EXPECTED RESULT',
            content: result.expectedResult,
            textColor: const Color(0xFFFDE047),
          ),
          const SizedBox(height: 8),

          _buildResultSection(
            title: 'ACTUAL RESULT',
            content: result.actualResult,
            textColor: const Color(0xFF4ADE80),
          ),
          const SizedBox(height: 12),

          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 6),

          // Additional Telemetry & Audit Meta
          _buildResultItem('HTTP Status Code', '${result.statusCode} (Interception Verified)'),
          _buildResultItem('Defense Triggered', result.defenseTriggered),
          _buildResultItem('Mitigation Action', result.mitigationAction),
          if (result.incidentId != null)
            _buildResultItem('SIEM Incident ID', result.incidentId!),
          _buildResultItem('Alert Generated', 'Logged to SIEM & Published to Firestore'),
          _buildResultItem('Audit Ledger Chained', result.incidentLogged ? 'Logged to SHA-256 chain' : 'Pending'),
          _buildResultItem('Timestamp', result.timestamp),
        ],
      ),
    );
  }

  Widget _buildResultSection({
    required String title,
    required String content,
    bool isMonospace = false,
    Color? textColor,
    Color? bgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor ?? const Color(0xFF132238),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 11,
              fontFamily: isMonospace ? 'monospace' : null,
              color: textColor ?? const Color(0xFFE2E8F0),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
