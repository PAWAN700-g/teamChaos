import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/role_badge.dart';
import '../../services/api_service.dart';

class ProfileTab extends StatefulWidget {
  final UserProfile user;

  const ProfileTab({super.key, required this.user});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ApiService _apiService = ApiService();
  bool _isPinging = false;
  String? _pingResult;

  void _pingGateway() async {
    setState(() {
      _isPinging = true;
      _pingResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final res = await _apiService.getHealth();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isPinging = false;
          _pingResult = 'CONNECTED (${stopwatch.elapsedMilliseconds} ms)\nStatus: ${res["status"]} | Service: ${res["service"]}\nPQC: ${res["cryptography"]?["kem_algorithm"]}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPinging = false;
          _pingResult = 'CONNECTION FAILED: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = widget.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'User Profile & System Administration',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Role-based access permissions, Firebase authentication tokens, and gateway network routing.',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 16),

          // User Identity Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.15),
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 10),
                  RoleBadge(role: user.role, isDense: false),
                  const SizedBox(height: 12),
                  const Divider(height: 16),
                  _buildProfileRow('Firebase User ID', user.uid),
                  _buildProfileRow('Account Created', user.createdAt.toIso8601String().substring(0, 10)),
                  _buildProfileRow('Role Security Level', user.role.name.toUpperCase()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Role-Based Access Control (RBAC) Permissions Matrix Card
          Text(
            'RBAC Security Permissions Matrix',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  _buildPermissionRow('Clinical Telemetry Reading', true, 'Doctors, Analysts, Admins'),
                  const Divider(height: 14),
                  _buildPermissionRow('Physiological Anomaly Alerts', true, 'Doctors, Analysts, Admins'),
                  const Divider(height: 14),
                  _buildPermissionRow('Cryptographic Key Handshake', true, 'Registered IoT Devices Only'),
                  const Divider(height: 14),
                  _buildPermissionRow(
                    'Device Credential Revocation',
                    user.role == UserRole.admin || user.role == UserRole.securityAnalyst,
                    'Security Analysts & Admins Only',
                  ),
                  const Divider(height: 14),
                  _buildPermissionRow(
                    'OTA Firmware Attestation & Signing',
                    user.role == UserRole.admin,
                    'Hospital Security Admins Only',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Gateway Network Connection Card
          Text(
            'FastAPI Backend Gateway Connection',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.router_outlined, size: 20, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Gateway API URL',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ApiService.baseUrl,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_pingResult != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _pingResult!.startsWith('CONNECTED') ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _pingResult!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: _pingResult!.startsWith('CONNECTED') ? Colors.green.shade900 : Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isPinging ? null : _pingGateway,
                      icon: _isPinging
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.network_check_rounded, size: 16),
                      label: Text(_isPinging ? 'Pinging Gateway...' : 'Ping Gateway & Test Health'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Log Out Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => context.read<AuthProvider>().signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out of SecureMed IoT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String title, bool isAllowed, String roles) {
    return Row(
      children: [
        Icon(
          isAllowed ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: isAllowed ? Colors.teal : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isAllowed ? Colors.black87 : Colors.grey)),
              Text(roles, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
