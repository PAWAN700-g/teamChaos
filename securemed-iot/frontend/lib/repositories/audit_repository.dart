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

class AuditVerificationReport {
  final bool isIntact;
  final int totalBlocksVerified;
  final String headHash;
  final String message;
  final Map<String, dynamic>? corruptedBlock;
  final String limitationDisclosure;

  AuditVerificationReport({
    required this.isIntact,
    required this.totalBlocksVerified,
    required this.headHash,
    required this.message,
    this.corruptedBlock,
    required this.limitationDisclosure,
  });

  factory AuditVerificationReport.fromJson(Map<String, dynamic> json) {
    return AuditVerificationReport(
      isIntact: json['is_intact'] as bool? ?? false,
      totalBlocksVerified: (json['total_blocks_verified'] as num?)?.toInt() ?? 0,
      headHash: json['head_hash'] as String? ?? '',
      message: json['message'] as String? ?? '',
      corruptedBlock: json['corrupted_block'] as Map<String, dynamic>?,
      limitationDisclosure: json['limitation_disclosure'] as String? ??
          'Local hash-chaining prevents retroactive modification of past records. External anchoring is required to detect complete ledger replacement.',
    );
  }
}

class AuditAnchoringReport {
  final String headHash;
  final int chainLength;
  final String latestEventId;
  final String latestTimestamp;
  final String anchoringDigest;
  final String limitationDisclosure;

  AuditAnchoringReport({
    required this.headHash,
    required this.chainLength,
    required this.latestEventId,
    required this.latestTimestamp,
    required this.anchoringDigest,
    required this.limitationDisclosure,
  });

  factory AuditAnchoringReport.fromJson(Map<String, dynamic> json) {
    return AuditAnchoringReport(
      headHash: json['audit_head_hash'] as String? ?? '',
      chainLength: (json['chain_length'] as num?)?.toInt() ?? 0,
      latestEventId: json['latest_event_id'] as String? ?? 'GENESIS',
      latestTimestamp: json['latest_timestamp'] as String? ?? '',
      anchoringDigest: json['anchoring_digest'] as String? ?? '',
      limitationDisclosure: json['limitation_disclosure'] as String? ??
          'External anchoring digest binds current ledger tip to an external authority to defend against whole-database recomputation.',
    );
  }
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

  Future<AuditVerificationReport> verifyAuditChain() async {
    final data = await _apiService.verifyAuditLedger();
    return AuditVerificationReport.fromJson(data);
  }

  Future<AuditAnchoringReport> exportAnchoringDigest() async {
    final data = await _apiService.exportAuditAnchor();
    return AuditAnchoringReport.fromJson(data);
  }
}
