import 'dart:math';
import 'package:flutter/material.dart';

class LiveSparklineChart extends StatelessWidget {
  final List<double> dataPoints;
  final double minY;
  final double maxY;
  final Color lineColor;
  final bool showGradient;
  final bool showLiveDot;
  final bool showGridLines;
  final double strokeWidth;
  final int maxPoints;

  const LiveSparklineChart({
    super.key,
    required this.dataPoints,
    this.minY = 0.0,
    this.maxY = 100.0,
    required this.lineColor,
    this.showGradient = true,
    this.showLiveDot = true,
    this.showGridLines = true,
    this.strokeWidth = 2.4,
    this.maxPoints = 30,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    return CustomPaint(
      painter: _SparklinePainter(
        dataPoints: dataPoints,
        minY: minY,
        maxY: maxY,
        lineColor: lineColor,
        showGradient: showGradient,
        showLiveDot: showLiveDot,
        showGridLines: showGridLines,
        strokeWidth: strokeWidth,
        gridColor: gridColor,
        maxPoints: maxPoints,
      ),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> dataPoints;
  final double minY;
  final double maxY;
  final Color lineColor;
  final bool showGradient;
  final bool showLiveDot;
  final bool showGridLines;
  final double strokeWidth;
  final Color gridColor;
  final int maxPoints;

  _SparklinePainter({
    required this.dataPoints,
    required this.minY,
    required this.maxY,
    required this.lineColor,
    required this.showGradient,
    required this.showLiveDot,
    required this.showGridLines,
    required this.strokeWidth,
    required this.gridColor,
    required this.maxPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Grid Guidelines (25%, 50%, 75%)
    if (showGridLines) {
      final gridPaint = Paint()
        ..color = gridColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      for (int i = 1; i <= 3; i++) {
        final y = size.height * (i / 4.0);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    if (dataPoints.isEmpty) return;

    // Determine actual effective min/max
    final effectiveMin = minY;
    final effectiveMax = max(maxY, effectiveMin + 1.0);
    final range = effectiveMax - effectiveMin;

    final points = <Offset>[];
    final count = dataPoints.length;
    final int capacity = max(maxPoints, count);

    for (int i = 0; i < count; i++) {
      // Align points so latest point is on right edge
      final double x = (capacity <= 1)
          ? size.width
          : size.width - ((count - 1 - i) * (size.width / (capacity - 1)));
      final val = dataPoints[i].clamp(effectiveMin, effectiveMax);
      final double y = size.height - ((val - effectiveMin) / range) * size.height;
      points.add(Offset(x.clamp(0.0, size.width), y.clamp(0.0, size.height)));
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points.first, 4, dotPaint);
      return;
    }

    // 2. Build Smooth Cubic Bézier Curve Path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // 3. Draw Gradient Area Fill Beneath Curve
    if (showGradient) {
      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.lineTo(points.first.dx, size.height);
      fillPath.close();

      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.32),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, gradientPaint);
    }

    // 4. Draw Main Sparkline Stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // 5. Draw Live Terminal Pulsing Indicator Dot
    if (showLiveDot && points.isNotEmpty) {
      final latest = points.last;

      // Outer soft aura
      final auraPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(latest, 7.0, auraPaint);

      // Inner crisp dot
      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(latest, 3.5, dotPaint);

      // Center white core
      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(latest, 1.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.maxY != maxY;
  }
}
