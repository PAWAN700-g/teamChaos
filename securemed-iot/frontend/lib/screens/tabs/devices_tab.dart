import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/device_model.dart';
import '../../models/telemetry_model.dart';
import '../../repositories/device_repository.dart';
import '../device_details_screen.dart';

class DevicesTab extends StatefulWidget {
  final UserProfile? user;
  final List<DeviceModel> devices;
  final List<TelemetryModel> telemetryStream;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;

  const DevicesTab({
    super.key,
    this.user,
    required this.devices,
    required this.telemetryStream,
    required this.isLoading,
    this.errorMessage,
    required this.onRefresh,
  });

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  final DeviceRepository _deviceRepo = DeviceRepository();
  bool _isActionInProgress = false;

  bool get _canManageDevices {
    final role = widget.user?.role;
    return role == UserRole.admin || role == UserRole.securityAnalyst;
  }

  void _showRegisterDeviceDialog() {
    final idController = TextEditingController(text: 'MED-DEV-${Random().nextInt(900) + 100}X');
    final typeController = TextEditingController(text: 'Pulse Oximeter & Capnograph');
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF00796B)),
                SizedBox(width: 8),
                Text('Provision New Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registers a new medical device node. The gateway pre-provisions an ML-DSA-65 cryptographic identity key pair (NIST FIPS 204).',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(dialogError!, style: TextStyle(fontSize: 11, color: Colors.red.shade900)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'Device Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final devId = idController.text.trim();
                  final devType = typeController.text.trim();
                  if (devId.isEmpty || devType.isEmpty) {
                    setDialogState(() => dialogError = 'Please fill out all fields.');
                    return;
                  }

                  // Generate a valid 1,952-byte base64 synthetic ML-DSA-65 public key for registration
                  final mockKeyBytes = List<int>.generate(1952, (i) => (i * 37 + devId.hashCode) % 256);
                  final dsaPubB64 = base64Encode(mockKeyBytes);

                  try {
                    await _deviceRepo.registerDevice(
                      deviceId: devId,
                      deviceType: devType,
                      dsaPublicKeyB64: dsaPubB64,
                    );
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    widget.onRefresh();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Device "$devId" registered successfully with ML-DSA-65 identity!'),
                        backgroundColor: const Color(0xFF00796B),
                      ),
                    );
                  } catch (e) {
                    setDialogState(() => dialogError = e.toString());
                  }
                },
                child: const Text('Register Node'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _revokeDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Revocation'),
        content: Text(
          'Are you sure you want to revoke credentials for "${device.deviceId}"? It will no longer be able to establish PQC sessions or submit telemetry.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionInProgress = true);
      try {
        await _deviceRepo.revokeDevice(device.deviceId);
        widget.onRefresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device "${device.deviceId}" revoked successfully.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Revocation failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _canManageDevices
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Provision Device'),
              onPressed: _showRegisterDeviceDialog,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected Device Fleet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Hardware nodes with pre-provisioned ML-DSA-65 keys.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: widget.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00796B)),
                          )
                        : const Icon(Icons.refresh, color: Color(0xFF00796B)),
                    onPressed: widget.isLoading ? null : widget.onRefresh,
                    tooltip: 'Refresh Device Fleet',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Error State Banner
              if (widget.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.errorMessage!,
                          style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Empty State
              if (widget.devices.isEmpty && !widget.isLoading) ...[
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.devices_other, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Registered Devices Found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Provision a device or connect the simulator to populate fleet inventory.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (_canManageDevices) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showRegisterDeviceDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Provision First Device'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00796B),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Device List Cards
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.devices.length,
                  itemBuilder: (context, index) {
                    final dev = widget.devices[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: dev.isRevoked ? Colors.red.shade200 : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DeviceDetailsScreen(
                                device: dev,
                                user: widget.user,
                                telemetryHistory: widget.telemetryStream,
                                onDeviceUpdated: widget.onRefresh,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: dev.isRevoked
                                          ? Colors.red.shade50
                                          : const Color(0xFF00796B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.medical_services_outlined,
                                      size: 22,
                                      color: dev.isRevoked ? Colors.redAccent : const Color(0xFF00796B),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dev.deviceId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dev.deviceType,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: dev.isOnline ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      dev.isOnline ? 'ONLINE' : 'REVOKED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: dev.isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                children: [
                                  const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF00796B)),
                                  const SizedBox(width: 4),
                                  const Expanded(
                                    child: Text(
                                      'ML-DSA-65 Valid',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00796B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    dev.registeredAt.length > 10 ? dev.registeredAt.substring(0, 10) : "Active",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              if (_canManageDevices && !dev.isRevoked) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.block, size: 14),
                                    label: const Text('Revoke Node', style: TextStyle(fontSize: 12)),
                                    onPressed: _isActionInProgress ? null : () => _revokeDevice(dev),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 60), // Spacing for floating action button
            ],
          ),
        ),
      ),
    );
  }
}
