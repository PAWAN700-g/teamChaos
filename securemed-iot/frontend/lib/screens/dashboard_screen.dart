import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/device_model.dart';
import '../models/telemetry_model.dart';
import '../models/security_alert_model.dart';
import '../repositories/device_repository.dart';
import '../repositories/telemetry_repository.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/devices_tab.dart';
import 'tabs/security_center_tab.dart';
import 'tabs/attack_simulation_tab.dart';
import 'tabs/audit_logs_tab.dart';
import 'tabs/profile_tab.dart';

class DashboardScreen extends StatefulWidget {
  final int initialTabIndex;

  const DashboardScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DeviceRepository _deviceRepo = DeviceRepository();
  final TelemetryRepository _telemetryRepo = TelemetryRepository();

  late int _currentTabIndex;
  bool _isLoading = false;
  String _backendStatus = 'Ready (Syncing...)';
  String? _errorMessage;

  List<DeviceModel> _devices = [];
  List<TelemetryModel> _telemetryStream = [];
  List<SecurityAlertModel> _securityAlerts = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex;
    _refreshAllData();
    // Background polling every 12 seconds to keep live vitals updated
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _pollTelemetrySilently();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollTelemetrySilently() async {
    try {
      final snapshot = await _telemetryRepo.fetchLatestTelemetry();
      if (mounted) {
        setState(() {
          _telemetryStream = snapshot.telemetryStream;
          _securityAlerts = snapshot.securityAlerts;
          _backendStatus = 'Online (ML-KEM-768) | Packets: ${snapshot.totalPacketsIngested}';
        });
      }
    } catch (_) {
      // Background silent poll ignore
    }
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final devicesFuture = _deviceRepo.fetchDevices();
      final telemetryFuture = _telemetryRepo.fetchLatestTelemetry();

      final results = await Future.wait([
        devicesFuture,
        telemetryFuture,
      ]);

      final devices = results[0] as List<DeviceModel>;
      final snapshot = results[1] as TelemetrySnapshot;

      if (mounted) {
        setState(() {
          _isLoading = false;
          _devices = devices;
          _telemetryStream = snapshot.telemetryStream;
          _securityAlerts = snapshot.securityAlerts;
          _backendStatus = 'Online (ML-KEM-768) | Verified Packets: ${snapshot.totalPacketsIngested}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          _backendStatus = 'Gateway Disconnected (${e.toString()})';
          // Fallback pre-seeded mock devices if gateway is offline during initial load
          if (_devices.isEmpty) {
            _devices = [
              DeviceModel(
                deviceId: 'MED-DEV-ICU-701A',
                deviceType: 'Multi-parameter Vital Monitor',
                status: 'active',
                isPqcSecured: true,
                dsaPublicKeyB64: 'OC9MK6WkL+STLbefoc41kjbsUcAG2oDU1L34Gj65pzn+YLtFkCVeJCql+PoF8o5M...',
                registeredAt: '2026-10-31T19:20:18Z',
              ),
              DeviceModel(
                deviceId: 'MED-DEV-INF-412C',
                deviceType: 'Continuous Infusion Controller',
                status: 'active',
                isPqcSecured: true,
                dsaPublicKeyB64: 'UykzQUUgxiY79tVoyrPthwuB+z6iubWyMF9zQ0MM0pJ+nYe0vZGhg3lIC0804YYc...',
                registeredAt: '2026-10-31T19:20:18Z',
              ),
              DeviceModel(
                deviceId: 'MED-DEV-VENT-901B',
                deviceType: 'Autonomous Respiratory Assist',
                status: 'active',
                isPqcSecured: true,
                dsaPublicKeyB64: 'GMfY46phpcoy6SY+G47USyKF2ua+Ni5ktvrQIVJ4RfQwR1FwFhIqfEYKPTgHaaBL...',
                registeredAt: '2026-10-31T19:20:18Z',
              ),
            ];
          }
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
      // 1. Dashboard Screen (Total, Online, Offline, Alerts, Latest HR, SpO2, Recent events, Live sync)
      DashboardTab(
        user: user,
        isLoading: _isLoading,
        backendStatus: _backendStatus,
        onRefresh: _refreshAllData,
        devices: _devices,
        telemetryStream: _telemetryStream,
        securityAlerts: _securityAlerts,
        onSelectDevice: (dev) {
          setState(() => _currentTabIndex = 1);
        },
      ),

      // 2. Devices Screen (Device list, ID, type, online/offline, PQC status, last-seen, register/revoke)
      DevicesTab(
        user: user,
        devices: _devices,
        telemetryStream: _telemetryStream,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        onRefresh: _refreshAllData,
      ),

      // 3. Security Center Screen (Critical, High, Medium, Low alerts, alert details, history)
      SecurityCenterTab(
        securityAlerts: _securityAlerts,
        isLoading: _isLoading,
        onRefresh: _refreshAllData,
      ),

      // 4. Attack Simulation Screen (Replay, Tampering, Fake device, Unauthorized, Firmware, Rate-limit)
      AttackSimulationTab(
        onAttackCompleted: _refreshAllData,
      ),

      // 5. Audit Logs Screen (Event name, timestamp, user/device, result, hash-chain status)
      AuditLogsTab(
        onRefresh: _refreshAllData,
      ),

      // 6. Profile Screen (User info, role, logout)
      ProfileTab(
        user: user,
      ),
    ];

    final screenTitles = [
      'Clinical Dashboard',
      'Device Fleet',
      'Security Center',
      'Attack Simulator',
      'Audit Ledger Chain',
      'Profile & RBAC',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF00796B)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                screenTitles[_currentTabIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF0A192F),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Gateway Data',
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00796B)),
                  )
                : const Icon(Icons.sync, color: Color(0xFF00796B)),
            onPressed: _isLoading ? null : _refreshAllData,
          ),
          IconButton(
            tooltip: 'Sign Out (${user.email})',
            icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
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
        height: 65,
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: const Color(0xFF00796B).withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF00796B)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services, color: Color(0xFF00796B)),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: Color(0xFF00796B)),
            label: 'Security',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science, color: Color(0xFF00796B)),
            label: 'Simulation',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF00796B)),
            label: 'Audit Logs',
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
