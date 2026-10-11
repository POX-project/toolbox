import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../glass_container.dart';
import 'live_sparkline_chart.dart';

class ResourceUsageCard extends StatelessWidget {
  final String title;
  final String tag;
  final IconData icon;
  final Color accentColor;
  final String primaryValue;
  final String? secondaryValue;
  final List<double> historyPoints;
  final double minY;
  final double maxY;
  final String? minLabel;
  final String? avgLabel;
  final String? maxLabel;
  final VoidCallback? onTap;
  final double chartHeight;

  const ResourceUsageCard({
    super.key,
    required this.title,
    required this.tag,
    required this.icon,
    required this.accentColor,
    required this.primaryValue,
    this.secondaryValue,
    required this.historyPoints,
    this.minY = 0.0,
    this.maxY = 100.0,
    this.minLabel,
    this.avgLabel,
    this.maxLabel,
    this.onTap,
    this.chartHeight = 65.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate dynamic min/avg/max from history if not supplied
    double effectiveMin = 0.0;
    double effectiveAvg = 0.0;
    double effectiveMax = 0.0;

    if (historyPoints.isNotEmpty) {
      effectiveMin = historyPoints.reduce(min);
      effectiveMax = historyPoints.reduce(max);
      effectiveAvg = historyPoints.reduce((a, b) => a + b) / historyPoints.length;
    }

    final displayMin = minLabel ?? '${effectiveMin.toStringAsFixed(0)}%';
    final displayAvg = avgLabel ?? '${effectiveAvg.toStringAsFixed(0)}%';
    final displayMax = maxLabel ?? '${effectiveMax.toStringAsFixed(0)}%';

    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isBounded = constraints.hasBoundedHeight;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Header: Icon + Title + Status Pill
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 17),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : const Color(0xFFEBECEF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5.5,
                          height: 5.5,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4.5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 9),

              // Primary & Secondary Metric Values
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    primaryValue,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.7,
                    ),
                  ),
                  if (secondaryValue != null) ...[
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        secondaryValue!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getSecondaryText(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // Live Waveform Sparkline Chart
              if (isBounded)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LiveSparklineChart(
                      dataPoints: historyPoints,
                      minY: minY,
                      maxY: maxY,
                      lineColor: accentColor,
                      showGradient: true,
                      showLiveDot: true,
                      showGridLines: true,
                      strokeWidth: 2.0,
                      maxPoints: 30,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: chartHeight,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LiveSparklineChart(
                      dataPoints: historyPoints,
                      minY: minY,
                      maxY: maxY,
                      lineColor: accentColor,
                      showGradient: true,
                      showLiveDot: true,
                      showGridLines: true,
                      strokeWidth: 2.0,
                      maxPoints: 30,
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Footer: Min / Avg / Peak Micro Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMicroMetric(context, 'MIN', displayMin),
                  _buildMicroMetric(context, 'AVG', displayAvg),
                  _buildMicroMetric(context, 'PEAK', displayMax),
                  if (onTap != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Inspect',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 15, color: accentColor),
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMicroMetric(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppTheme.getSecondaryText(context),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
