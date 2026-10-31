import 'package:flutter/material.dart';
import '../../models/security_alert_model.dart';
import '../../widgets/summary_metric_card.dart';

class SecurityCenterTab extends StatefulWidget {
  final List<SecurityAlertModel> securityAlerts;
  final bool isLoading;
  final VoidCallback onRefresh;

  const SecurityCenterTab({
    super.key,
    required this.securityAlerts,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<SecurityCenterTab> createState() => _SecurityCenterTabState();
}

class _SecurityCenterTabState extends State<SecurityCenterTab> {
  String _selectedSeverityFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate severity metrics
    final criticalCount = widget.securityAlerts.where((a) => a.isCritical).length;
    final highCount = widget.securityAlerts.where((a) => a.isHigh).length;
    final mediumCount = widget.securityAlerts.where((a) => a.isMedium).length;
    final lowCount = widget.securityAlerts.where((a) => a.isLow).length;

    // Filter alerts based on selection
    final filteredAlerts = widget.securityAlerts.where((a) {
      if (_selectedSeverityFilter == 'ALL') return true;
      if (_selectedSeverityFilter == 'CRITICAL') return a.isCritical;
      if (_selectedSeverityFilter == 'HIGH') return a.isHigh;
      if (_selectedSeverityFilter == 'MEDIUM') return a.isMedium;
      if (_selectedSeverityFilter == 'LOW') return a.isLow;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
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
                        'Security Operations Center (SIEM)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Real-time intrusion detection and cryptographic attack monitoring.',
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
                  tooltip: 'Refresh SIEM Alerts',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Severity Metrics Grid
            Row(
              children: [
                Expanded(
                  child: SummaryMetricCard(
                    title: 'Critical',
                    value: '$criticalCount',
                    subtitle: 'Immediate mitigation',
                    icon: Icons.dangerous_outlined,
                    iconColor: Colors.red.shade700,
                    onTap: () => setState(() => _selectedSeverityFilter = 'CRITICAL'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SummaryMetricCard(
                    title: 'High',
                    value: '$highCount',
                    subtitle: 'Unauthorized spoofing',
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.orange.shade800,
                    onTap: () => setState(() => _selectedSeverityFilter = 'HIGH'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SummaryMetricCard(
                    title: 'Medium',
                    value: '$mediumCount',
                    subtitle: 'RBAC escalation attempts',
                    icon: Icons.shield_outlined,
                    iconColor: Colors.amber.shade700,
                    onTap: () => setState(() => _selectedSeverityFilter = 'MEDIUM'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SummaryMetricCard(
                    title: 'Low / Info',
                    value: '$lowCount',
                    subtitle: 'Policy notifications',
                    icon: Icons.info_outline,
                    iconColor: const Color(0xFF0D9488),
                    onTap: () => setState(() => _selectedSeverityFilter = 'LOW'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Incidents (${widget.securityAlerts.length})'),
                  const SizedBox(width: 6),
                  _buildFilterChip('CRITICAL', 'Critical ($criticalCount)', color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  _buildFilterChip('HIGH', 'High ($highCount)', color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  _buildFilterChip('MEDIUM', 'Medium ($mediumCount)', color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  _buildFilterChip('LOW', 'Low ($lowCount)', color: const Color(0xFF0D9488)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Attack Detection History
            Text(
              'Attack Detection History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            if (filteredAlerts.isEmpty)
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
                        Icon(Icons.verified_user_outlined, size: 48, color: Colors.teal.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No Incidents In Selected Category',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All PQC authentication checks and AES-GCM envelopes passing nominal validation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAlerts.length,
                itemBuilder: (context, index) {
                  final alert = filteredAlerts.reversed.toList()[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _getSeverityBorderColor(alert.severity)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getSeverityColor(alert.severity).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getSeverityIcon(alert.severity),
                                  size: 18,
                                  color: _getSeverityColor(alert.severity),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alert.attackType,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Target: ${alert.deviceId}',
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getSeverityColor(alert.severity).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  alert.severity.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getSeverityColor(alert.severity),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            alert.description,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                          ),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Alert ID: ${alert.alertId}',
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                              ),
                              Text(
                                alert.timestamp.length > 19 ? alert.timestamp.substring(11, 19) : alert.timestamp,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
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

  Widget _buildFilterChip(String filterKey, String label, {Color? color}) {
    final isSelected = _selectedSeverityFilter == filterKey;
    final chipColor = color ?? const Color(0xFF00796B);

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      backgroundColor: Colors.white,
      selectedColor: chipColor,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? chipColor : const Color(0xFFE2E8F0)),
      ),
      onSelected: (_) => setState(() => _selectedSeverityFilter = filterKey),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade800;
      case 'medium':
      case 'warning':
        return Colors.amber.shade800;
      case 'low':
      case 'info':
      default:
        return const Color(0xFF0D9488);
    }
  }

  Color _getSeverityBorderColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade200;
      case 'high':
        return Colors.orange.shade200;
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.dangerous;
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
      case 'warning':
        return Icons.security_update_warning;
      case 'low':
      default:
        return Icons.info_outline;
    }
  }
}
