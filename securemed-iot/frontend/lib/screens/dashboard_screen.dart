import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'tabs/fleet_tab.dart';
import 'tabs/crypto_tab.dart';
import 'tabs/threats_tab.dart';
import 'tabs/audit_tab.dart';
import 'tabs/profile_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  int _currentTabIndex = 0;

  bool _isConnecting = false;
  String _backendStatus = 'Ready (Tap Sync to connect)';
  List<Map<String, dynamic>> _liveTelemetry = [];
  List<Map<String, dynamic>> _securityAlerts = [];
  String _auditHeadHash = 'GENESIS_SECUREMED_AUDIT_ROOT_00000000000000000000000000000000';
  bool _hasSynced = false;

  @override
  void initState() {
    super.initState();
    _silentAutoConnect();
  }

  void _silentAutoConnect() async {
    try {
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
          _liveTelemetry = stream;
          _securityAlerts = alerts;
          _auditHeadHash = telemetry["audit_head_hash"] ?? _auditHeadHash;
          if (stream.isNotEmpty) {
            _hasSynced = true;
            _backendStatus = 'Online | Ingested Packets: ${telemetry["total_packets_ingested"] ?? stream.length}';
          }
        });
      }
    } catch (_) {
      // Offline fallback is expected for prototype demo mode
    }
  }

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
          _auditHeadHash = telemetry["audit_head_hash"] ?? _auditHeadHash;
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
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userProfile;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Unauthenticated Session')),
      );
    }

    final pages = [
      FleetTab(
        user: user,
        isConnecting: _isConnecting,
        backendStatus: _backendStatus,
        onSyncBackend: _checkBackendConnection,
        liveTelemetry: _liveTelemetry,
        hasSynced: _hasSynced,
      ),
      const CryptoTab(),
      ThreatsTab(
        securityAlerts: _securityAlerts,
        onRefresh: _checkBackendConnection,
      ),
      AuditTab(
        headHash: _auditHeadHash,
        onRefresh: _checkBackendConnection,
      ),
      ProfileTab(user: user),
    ];

    final titles = [
      'SecureMed IoT',
      'PQC Security Engine',
      'Threat Defense SIEM',
      'Audit Ledger Chain',
      'System & Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.security, size: 22, color: Color(0xFF00796B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titles[_currentTabIndex],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
      body: IndexedStack(
        index: _currentTabIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() => _currentTabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services, color: Color(0xFF00796B)),
            label: 'Fleet',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_clock_outlined),
            selectedIcon: Icon(Icons.lock, color: Color(0xFF00796B)),
            label: 'PQC Crypto',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: Color(0xFF00796B)),
            label: 'Threats',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF00796B)),
            label: 'Audit Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF00796B)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
