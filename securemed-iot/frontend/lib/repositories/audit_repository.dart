import '../models/audit_entry_model.dart';
import '../services/api_service.dart';

class AuditLedgerReport {
  final String headHash;
  final int chainLength;
  final List<AuditEntryModel> events;
  final bool isChainIntact;

  AuditLedgerReport({
    required this.headHash,
    required this.chainLength,
    required this.events,
    required this.isChainIntact,
  });
}

class AuditRepository {
  final ApiService _apiService;

  AuditRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  Future<AuditLedgerReport> fetchAuditLedger() async {
    final data = await _apiService.getAuditLedger();
    final rawEvents = (data['events'] as List<dynamic>?) ?? [];

    final events = rawEvents
        .map((e) => AuditEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final headHash = data['audit_head_hash'] as String? ?? 'GENESIS_ROOT';
    final chainLength = (data['chain_length'] as num?)?.toInt() ?? events.length;

    // Verify hash integrity locally if events exist
    bool intact = true;
    if (events.isNotEmpty && headHash != 'GENESIS_SECUREMED_AUDIT_ROOT_00000000000000000000000000000000') {
      final lastBlock = events.last;
      if (lastBlock.blockHash != headHash && lastBlock.blockHash.isNotEmpty) {
        intact = false;
      }
    }

    return AuditLedgerReport(
      headHash: headHash,
      chainLength: chainLength,
      events: events,
      isChainIntact: intact,
    );
  }
}
