import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool isDense;

  const RoleBadge({
    super.key,
    required this.role,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (role) {
      case UserRole.admin:
        badgeColor = const Color(0xFFC62828); // Crimson
        badgeIcon = Icons.admin_panel_settings;
        badgeText = isDense ? 'ADMIN' : 'ADMINISTRATOR';
        break;
      case UserRole.securityAnalyst:
        badgeColor = const Color(0xFFE65100); // Amber Orange
        badgeIcon = Icons.shield;
        badgeText = isDense ? 'ANALYST' : 'SECURITY ANALYST';
        break;
      case UserRole.doctor:
        badgeColor = const Color(0xFF00796B); // Medical Teal
        badgeIcon = Icons.medical_services_outlined;
        badgeText = isDense ? 'DOCTOR' : 'CLINICIAN / DOCTOR';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 7 : 12,
        vertical: isDense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: isDense ? 13 : 16, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: isDense ? 10 : 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
