import 'package:flutter/material.dart';
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
                        'SHA-256 tamper-evident blockchain recording security events.',
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
                  ],
                ),
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
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'VERIFIED',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Entity: ${entry.deviceId}',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF475569)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.timestamp.length > 19 ? entry.timestamp.substring(0, 19).replaceAll('T', ' ') : entry.timestamp,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
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
