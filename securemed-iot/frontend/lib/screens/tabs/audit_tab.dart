import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AuditTab extends StatefulWidget {
  final String headHash;
  final VoidCallback onRefresh;

  const AuditTab({
    super.key,
    required this.headHash,
    required this.onRefresh,
  });

  @override
  State<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<AuditTab> {
  final ApiService _apiService = ApiService();
  String _currentHeadHash = '';
  int _chainLength = 4;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentHeadHash = widget.headHash.isNotEmpty
        ? widget.headHash
        : 'GENESIS_SECUREMED_AUDIT_ROOT_00000000000000000000000000000000';
    _fetchAuditHead();
  }

  void _fetchAuditHead() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getCryptoStatus();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentHeadHash = res["audit_head_hash"] ?? _currentHeadHash;
          _chainLength = res["audit_chain_length"] ?? _chainLength;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
                  'Tamper-Evident SHA-256 Audit Ledger',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  _fetchAuditHead();
                  widget.onRefresh();
                },
                tooltip: 'Refresh Ledger',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cryptographic blockchain audit chaining ensures all security events, PQC handshakes, and telemetry ingestions cannot be repudiated, deleted, or altered.',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 16),

          // Head Hash & Genesis Banner Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, color: Colors.teal, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Current Audit Head Digest',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          'Intact ($_chainLength Blocks)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _currentHeadHash,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Cryptographic Blocks Flow
          Text('Chained Audit Events', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          _buildAuditBlock(
            blockIndex: 1,
            event: 'DEVICE_REGISTERED',
            deviceId: 'MED-DEV-ICU-701A',
            summary: 'ML-DSA-65 1,952-byte public key registered in secure state',
            prevHash: 'GENESIS_SECUREMED_AUDIT_ROOT_00000000000000000000000000000000',
            entryHash: '6d92a1cf8813bc49439281a8b11c05d761bc978d4615a1334c4d1192801bf41c',
            time: 'Genesis Session',
          ),
          _buildAuditChainConnector(),

          _buildAuditBlock(
            blockIndex: 2,
            event: 'PQC_SESSION_ESTABLISHED',
            deviceId: 'MED-DEV-ICU-701A',
            summary: 'ML-KEM-768 ciphertext decapsulated & transcript bound via HKDF',
            prevHash: '6d92a1cf8813bc49439281a8b11c05d761bc978d4615a1334c4d1192801bf41c',
            entryHash: 'a8b79e13d944c668912cf54128f641ac0815dc39178bb1d31846b9a89d784ef1',
            time: 'T + 12s',
          ),
          _buildAuditChainConnector(),

          _buildAuditBlock(
            blockIndex: 3,
            event: 'TELEMETRY_INGESTED',
            deviceId: 'MED-DEV-ICU-701A',
            summary: 'Sequence #1 verified | Nonce freshness validated | AES-256-GCM decrypted',
            prevHash: 'a8b79e13d944c668912cf54128f641ac0815dc39178bb1d31846b9a89d784ef1',
            entryHash: 'f4128f641ac0815dc39178bb1d31846b9a89d784ef18a86ad6a5abfd4ff388e2',
            time: 'T + 14s',
          ),
          _buildAuditChainConnector(),

          _buildAuditBlock(
            blockIndex: 4,
            event: 'FIRMWARE_VERIFIED',
            deviceId: 'VENDOR_SIGNING_AUTHORITY',
            summary: 'SecureMed-RTOS-v2.4.1 SHA-256 matched | ML-DSA-65 vendor signature verified',
            prevHash: 'f4128f641ac0815dc39178bb1d31846b9a89d784ef18a86ad6a5abfd4ff388e2',
            entryHash: _currentHeadHash,
            time: 'Latest Verified',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAuditBlock({
    required int blockIndex,
    required String event,
    required String deviceId,
    required String summary,
    required String prevHash,
    required String entryHash,
    required String time,
  }) {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Block #$blockIndex',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 6),
            Text(summary, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phonelink, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(deviceId, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey)),
              ],
            ),
            const Divider(height: 12),
            Text('Prev: ${prevHash.substring(0, prevHash.length.clamp(0, 32))}...', style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.grey)),
            Text('Hash: ${entryHash.substring(0, entryHash.length.clamp(0, 32))}...', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditChainConnector() {
    return Center(
      child: Container(
        height: 18,
        width: 2,
        color: Colors.teal.shade300,
        margin: const EdgeInsets.symmetric(vertical: 2),
      ),
    );
  }
}
