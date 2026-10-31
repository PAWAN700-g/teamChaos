import 'package:flutter/material.dart';

class SimulatedBadge extends StatelessWidget {
  final bool isCompact;

  const SimulatedBadge({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.amber.shade700, width: 0.8),
        ),
        child: Text(
          'SIMULATED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade900,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 13, color: Color(0xFFB45309)),
          SizedBox(width: 4),
          Text(
            'SIMULATED CLINICAL DATA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB45309),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
