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
          _pingResult = 'CONNECTED (${stopwatch.elapsedMilliseconds} ms)\nStatus: ${res["status"]} | Service: ${res["service"]}\nPQC: ${res["cryptography"]?["kem_algorithm"]} & ${res["cryptography"]?["dsa_algorithm"]}';
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
    final user = widget.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'User Profile & System Administration',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Role-based access permissions, Firebase authentication tokens, and gateway network routing.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // User Identity Card
          Card(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.12),
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.displayName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  RoleBadge(role: user.role, isDense: false),
                  const SizedBox(height: 12),
                  const Divider(height: 16),
                  _buildProfileRow('User UID', user.uid.isNotEmpty ? user.uid : 'FIREBASE-LOCAL-SESSION'),
                  _buildProfileRow('Account Created', user.createdAt.toIso8601String().substring(0, 10)),
                  _buildProfileRow('Session Status', 'Authenticated (RBAC Enforced)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // RBAC Permissions Matrix Card
          Text(
            'RBAC Security Permissions Matrix',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
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
                children: [
                  _buildPermissionRow('View Real-time Vitals & ECG', true),
                  const Divider(height: 14),
                  _buildPermissionRow('Register / Provision IoT Hardware', user.isAdmin || user.isSecurityAnalyst),
                  const Divider(height: 14),
                  _buildPermissionRow('Emergency Device Key Revocation', user.isAdmin || user.isSecurityAnalyst),
                  const Divider(height: 14),
                  _buildPermissionRow('Trigger Hostile Attack Simulations', true),
                  const Divider(height: 14),
                  _buildPermissionRow('OTA Firmware Signing & Verification', user.isAdmin),
                  const Divider(height: 14),
                  _buildPermissionRow('Export Cryptographic Audit Ledger', user.isAdmin || user.isSecurityAnalyst),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gateway Connectivity & Diagnostics
          Text(
            'Gateway Connectivity Diagnostics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
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
                      const Expanded(
                        child: Text(
                          'FastAPI Gateway Routing',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ApiService.baseUrl,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF00796B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isPinging ? null : _pingGateway,
                      icon: _isPinging
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00796B)),
                            )
                          : const Icon(Icons.network_ping, size: 16),
                      label: Text(_isPinging ? 'Pinging Gateway...' : 'Ping Gateway Diagnostics'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00796B),
                        side: const BorderSide(color: Color(0xFF00796B)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  if (_pingResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _pingResult!.contains('CONNECTED') ? const Color(0xFFECFDF5) : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _pingResult!.contains('CONNECTED') ? const Color(0xFF10B981) : Colors.redAccent,
                        ),
                      ),
                      child: Text(
                        _pingResult!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: _pingResult!.contains('CONNECTED') ? const Color(0xFF065F46) : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.read<AuthProvider>().signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('End Secure Session & Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String permission, bool granted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            permission,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: granted ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            granted ? 'PERMITTED' : 'RESTRICTED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: granted ? const Color(0xFF065F46) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}
