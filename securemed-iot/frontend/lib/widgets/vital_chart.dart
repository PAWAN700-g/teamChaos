import 'package:flutter/material.dart';
import 'simulated_badge.dart';

class HeartRateTrendChart extends StatelessWidget {
  final List<double> values;
  final int currentBpm;

  const HeartRateTrendChart({
    super.key,
    required this.values,
    required this.currentBpm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Heart Rate Trend',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const SimulatedBadge(isCompact: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$currentBpm',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 4),
              const Text(
                'BPM',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentBpm >= 60 && currentBpm <= 100 ? 'Normal Sinus' : 'Abnormal Rate',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: currentBpm >= 60 && currentBpm <= 100 ? const Color(0xFF0D9488) : Colors.orange.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                data: values.isNotEmpty ? values : [72, 75, 74, 76, 73, 75, 78, 74, 75, 72],
                lineColor: Colors.redAccent,
                minY: 50,
                maxY: 120,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpO2TrendChart extends StatelessWidget {
  final List<double> values;
  final int currentSpo2;

  const SpO2TrendChart({
    super.key,
    required this.values,
    required this.currentSpo2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_outlined, color: Color(0xFF0D9488), size: 14),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Pulse Oximetry (SpO2)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const SimulatedBadge(isCompact: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$currentSpo2%',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentSpo2 >= 95 ? 'Adequate Saturation' : 'Hypoxia Warning',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: currentSpo2 >= 95 ? const Color(0xFF0D9488) : Colors.red.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                data: values.isNotEmpty ? values : [98, 98, 97, 98, 99, 98, 98, 97, 98, 98],
                lineColor: const Color(0xFF0D9488),
                minY: 90,
                maxY: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EcgWaveformView extends StatelessWidget {
  final int heartRate;

  const EcgWaveformView({super.key, this.heartRate = 75});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A192F), // Dark navy monitor screen
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF2DD4BF), size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'LEAD II ECG TRACE',
                  style: TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade400, width: 0.6),
                ),
                child: const Text(
                  'SYNTHETIC',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: _EcgWaveformPainter(heartRate: heartRate),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'HR: $heartRate bpm',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sweep: 25mm/s | AES-GCM Valid',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final double minY;
  final double maxY;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);
    final rangeY = (maxY - minY == 0) ? 1.0 : (maxY - minY);

    double normalizeY(double val) {
      final clamped = val.clamp(minY, maxY);
      return size.height - ((clamped - minY) / rangeY * size.height);
    }

    final startY = normalizeY(data.first);
    path.moveTo(0, startY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, startY);

    for (int i = 1; i < data.length; i++) {
      final x = i * stepX;
      final y = normalizeY(data[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final endX = size.width;
    final endY = normalizeY(data.last);
    final dotPaint = Paint()..color = lineColor;
    canvas.drawCircle(Offset(endX, endY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.lineColor != lineColor;
  }
}

class _EcgWaveformPainter extends CustomPainter {
  final int heartRate;

  _EcgWaveformPainter({required this.heartRate});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.7)
      ..strokeWidth = 0.5;

    const gridSize = 16.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final ecgPaint = Paint()
      ..color = const Color(0xFF2DD4BF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final midY = size.height * 0.58;

    final beatWidth = (size.width / 3.2).clamp(70.0, 140.0);
    double curX = 0;

    path.moveTo(0, midY);

    while (curX < size.width) {
      path.lineTo(curX + beatWidth * 0.12, midY);
      curX += beatWidth * 0.12;

      final pPeakX = curX + beatWidth * 0.08;
      path.quadraticBezierTo(pPeakX, midY - 9, curX + beatWidth * 0.16, midY);
      curX += beatWidth * 0.16;

      path.lineTo(curX + beatWidth * 0.06, midY);
      curX += beatWidth * 0.06;

      path.lineTo(curX + beatWidth * 0.04, midY + 7);
      curX += beatWidth * 0.04;

      final rPeakX = curX + beatWidth * 0.04;
      path.lineTo(rPeakX, midY - 48);
      curX += beatWidth * 0.04;

      final sDipX = curX + beatWidth * 0.04;
      path.lineTo(sDipX, midY + 16);
      curX += beatWidth * 0.04;

      path.lineTo(curX + beatWidth * 0.04, midY);
      curX += beatWidth * 0.04;

      path.lineTo(curX + beatWidth * 0.08, midY);
      curX += beatWidth * 0.08;

      final tPeakX = curX + beatWidth * 0.12;
      path.quadraticBezierTo(tPeakX, midY - 14, curX + beatWidth * 0.24, midY);
      curX += beatWidth * 0.24;

      path.lineTo((curX + beatWidth * 0.18).clamp(0, size.width), midY);
      curX += beatWidth * 0.18;
    }

    canvas.drawPath(path, ecgPaint);
  }

  @override
  bool shouldRepaint(covariant _EcgWaveformPainter oldDelegate) => oldDelegate.heartRate != heartRate;
}
