import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/audit_entry_model.dart';
import '../../repositories/audit_repository.dart';

class AuditLogsTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const AuditLogsTab({super.key, required this.onRefresh});

  @override
  State<AuditLogsTab> createState() => _AuditLogsTabState();
}

class _AuditLogsTabState extends State<AuditLogsTab> {
  final AuditRepository _auditRepo = AuditRepository();
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _errorMessage;
  String _headHash = 'GENESIS_ROOT';
  int _chainLength = 0;
  bool _isChainIntact = true;
  List<AuditEntryModel> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchAuditLedger();
  }

  void _fetchAuditLedger() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await _auditRepo.fetchAuditLedger();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _headHash = report.headHash;
          _chainLength = report.chainLength;
          _isChainIntact = report.isChainIntact;
          _events = report.events;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _runChainVerification() async {
    setState(() => _isVerifying = true);
    try {
      final res = await _auditRepo.verifyAuditChain();
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isChainIntact = res.isIntact;
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Icon(
                  res.isIntact ? Icons.verified : Icons.dangerous,
                  color: res.isIntact ? const Color(0xFF0D9488) : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  res.isIntact ? 'Audit Chain Verified' : 'Integrity Compromise',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(res.message, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                  const SizedBox(height: 10),
                  Text('Total Blocks Verified: ${res.totalBlocksVerified}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Head Hash:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: Text(res.headHash, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                  ),
                  if (res.corruptedBlock != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.redAccent)),
                      child: Text('Corrupted Block: ${res.corruptedBlock.toString()}', style: TextStyle(fontSize: 11, color: Colors.red.shade900)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  const Text(
                    'SECURITY LIMITATION DISCLOSURE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    res.limitationDisclosure,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.3),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chain verification error: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  void _exportAnchoringDigest() async {
    try {
      final anchor = await _auditRepo.exportAnchoringDigest();
      if (mounted) {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.anchor, color: Color(0xFF00796B), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'External Anchoring Digest',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Color(0xFF00796B)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: anchor.anchoringDigest));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Anchoring digest copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Exported SHA-256 anchoring digest for external ledger publication (e.g. public blockchain or RFC 3161 TSA):',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A192F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      anchor.anchoringDigest,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF2DD4BF)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Chain Blocks: ${anchor.chainLength}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                      Text('Latest Event: ${anchor.latestEventId}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SECURITY NOTICE: WHOLE-DATABASE RECOMPUTATION LIMITATION',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          anchor.limitationDisclosure,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF78350F), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export anchoring digest: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        _fetchAuditLedger();
        widget.onRefresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Ledger Chain',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'SHA-256 tamper-evident blockchain recording all security events.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00796B)),
                        )
                      : const Icon(Icons.refresh, color: Color(0xFF00796B)),
                  onPressed: _isLoading ? null : _fetchAuditLedger,
                  tooltip: 'Refresh Audit Ledger',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Hash-Chain Verification Status Card
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
                      children: [
                        const Icon(Icons.link, color: Color(0xFF00796B), size: 18),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Hash-Chain Integrity Status',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isChainIntact ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _isChainIntact ? 'INTACT' : 'COMPROMISED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isChainIntact ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text.rich(
                      TextSpan(
                        text: 'Total Chained Blocks: ',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        children: [
                          TextSpan(
                            text: '$_chainLength blocks',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Current Head Hash (Tip of Chain):', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _headHash,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF00796B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Chain Verification & External Anchoring Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isVerifying ? null : _runChainVerification,
                            icon: _isVerifying
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.security, size: 16),
                            label: const Text('Verify Chain', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00796B),
                              side: const BorderSide(color: Color(0xFF00796B)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exportAnchoringDigest,
                            icon: const Icon(Icons.anchor, size: 16),
                            label: const Text('Export Anchor', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Permanent Security Limitation Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Security Notice: Local hash chaining prevents modification of past records. '
                      'To protect against full-database recomputation attacks, use "Export Anchor" to commit '
                      'the head hash to an external immutable ledger.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error Message (if any)
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Text(_errorMessage!, style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
              ),
              const SizedBox(height: 14),
            ],

            // Chronological Ledger Events
            Text(
              'Chronological Ledger Events',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            if (_events.isEmpty && !_isLoading)
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                        SizedBox(height: 10),
                        Text('No ledger entries recorded yet', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        SizedBox(height: 4),
                        Text('Cryptographic device events and telemetry ingestion will append blocks here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  // Show newest blocks first
                  final entry = _events.reversed.toList()[index];
                  final blockNum = _events.length - index;

                  Color resultColor;
                  Color resultBg;
                  if (entry.isSuccess) {
                    resultColor = const Color(0xFF065F46);
                    resultBg = const Color(0xFFD1FAE5);
                  } else if (entry.isRejected) {
                    resultColor = const Color(0xFF991B1B);
                    resultBg = const Color(0xFFFEE2E2);
                  } else {
                    resultColor = const Color(0xFF92400E);
                    resultBg = const Color(0xFFFEF3C7);
                  }

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
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
                                  color: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#$blockNum',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entry.event,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: resultBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.result,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: resultColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Event: ${entry.eventId}',
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B)),
                              ),
                              Text(
                                entry.timestamp.length > 19 ? entry.timestamp.substring(0, 19).replaceAll('T', ' ') : entry.timestamp,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Actor: ${entry.actor}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                          ),
                          const Divider(height: 12),
                          Text(
                            'Parent: ${entry.parentHash.length > 20 ? "${entry.parentHash.substring(0, 10)}...${entry.parentHash.substring(entry.parentHash.length - 8)}" : entry.parentHash}',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hash:   ${entry.blockHash.length > 20 ? "${entry.blockHash.substring(0, 10)}...${entry.blockHash.substring(entry.blockHash.length - 8)}" : entry.blockHash}',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
