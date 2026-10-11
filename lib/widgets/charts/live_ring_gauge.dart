import 'dart:math';
import 'package:flutter/material.dart';

class LiveRingGauge extends StatelessWidget {
  final double value; // 0.0 to 100.0
  final Color activeColor;
  final double strokeWidth;
  final double size;
  final String? centerValue;
  final String? label;
  final IconData? icon;

  const LiveRingGauge({
    super.key,
    required this.value,
    required this.activeColor,
    this.strokeWidth = 8.0,
    this.size = 84.0,
    this.centerValue,
    this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final trackColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : const Color(0xFFEBECEF);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: (value / 100.0).clamp(0.0, 1.0),
              activeColor: activeColor,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: size * 0.22, color: activeColor),
                const SizedBox(height: 2),
              ],
              Text(
                centerValue ?? '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: size * 0.19,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: size * 0.11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc starting from top (-pi / 2)
    if (progress > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}
