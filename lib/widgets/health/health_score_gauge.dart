import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/device_health_model.dart';
import '../../theme/app_theme.dart';

class HealthScoreGauge extends StatelessWidget {
  final double? score;
  final HealthGrade grade;
  final String privilegeMode;
  final bool hasSufficientData;
  final String? undeterminedReason;
  final VoidCallback onRefresh;
  final VoidCallback? onPrivilegeTap;
  final bool isLoading;

  const HealthScoreGauge({
    super.key,
    this.score,
    required this.grade,
    required this.privilegeMode,
    this.hasSufficientData = true,
    this.undeterminedReason,
    required this.onRefresh,
    this.onPrivilegeTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? const Color(0xFF161922) : Colors.white);
    final borderColor = Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: grade.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: grade.color.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasSufficientData ? Icons.verified_user_rounded : Icons.help_outline_rounded,
                          color: grade.color,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'GRADE ${grade.label} • ${grade.status.toUpperCase()}',
                          style: TextStyle(
                            color: grade.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.refresh_rounded, size: 20, color: AppTheme.getSecondaryText(context)),
                onPressed: isLoading ? null : onRefresh,
                tooltip: 'Re-analyze hardware health',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Circular Score Visualizer wrapped in RepaintBoundary
          RepaintBoundary(
            child: SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: _ScoreArcPainter(
                  score: hasSufficientData && score != null ? score! : null,
                  arcColor: grade.color,
                  bgColor: isDark ? const Color(0xFF222836) : const Color(0xFFE5E7EB),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasSufficientData && score != null
                            ? score!.toStringAsFixed(0)
                            : '--',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          color: hasSufficientData
                              ? Theme.of(context).colorScheme.onSurface
                              : AppTheme.getSecondaryText(context),
                        ),
                      ),
                      Text(
                        hasSufficientData ? 'OF 100 HEALTH' : 'INSUFFICIENT DATA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: hasSufficientData
                              ? AppTheme.getSecondaryText(context)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Insufficient Telemetry Explanatory Warning Card
          if (!hasSufficientData) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF261E14) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "We can't determine the health of your phone based on those data",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    undeterminedReason ??
                        "Key hardware wear telemetry (battery cycle degradation and flash storage NAND lifespan) requires elevated privileges (Root/Shizuku) or is not exposed by this device's firmware.",
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                    ),
                  ),
                  if (onPrivilegeTap != null &&
                      !privilegeMode.contains('Root') &&
                      !privilegeMode.contains('Shizuku')) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFF59E0B)),
                        label: const Text(
                          'Unlock Telemetry with Shizuku / Root',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        onPressed: onPrivilegeTap,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Privilege & Mode Status
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPrivilegeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1218) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    privilegeMode.contains('Root') ? Icons.security_rounded : Icons.info_outline_rounded,
                    size: 14,
                    color: privilegeMode.contains('Root')
                        ? const Color(0xFF10B981)
                        : AppTheme.getSecondaryText(context),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Diagnostic Level: $privilegeMode',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (onPrivilegeTap != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.tune_rounded,
                      size: 13,
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  final double? score;
  final Color arcColor;
  final Color bgColor;

  const _ScoreArcPainter({
    required this.score,
    required this.arcColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 12.0;

    // Background track (260 degree arc)
    const startAngle = 140 * (pi / 180);
    const sweepTotal = 260 * (pi / 180);

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Active score arc (only painted when score is available)
    if (score != null) {
      final sweepScore = sweepTotal * (score! / 100.0).clamp(0.0, 1.0);
      final activePaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepScore,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.bgColor != bgColor;
  }
}
