import 'package:flutter/material.dart';

import '../../models/device_health_model.dart';
import '../../theme/app_theme.dart';
import 'partition_detail_sheet.dart';
import 'raw_descriptor_sheet.dart';

class ComponentHealthCard extends StatelessWidget {
  final ComponentHealth component;

  const ComponentHealthCard({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? const Color(0xFF161922) : Colors.white);
    final borderColor = Theme.of(context).colorScheme.outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon, Name, Category & Grade Badge
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: component.grade.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: component.grade.color.withValues(alpha: 0.3)),
                ),
                child: Icon(component.icon, color: component.grade.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      component.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Score & Grade Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: component.grade.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: component.grade.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      component.score != null
                          ? '${component.score!.toStringAsFixed(0)}%'
                          : 'N/A',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: component.grade.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '• ${component.grade.label}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: component.grade.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Wear gauge bar if applicable
          if (component.wearPercentage != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Endurance / Wear Level',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ),
                ),
                Text(
                  '${(100.0 - component.wearPercentage!).toStringAsFixed(0)}% Lifespan Remaining',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: component.grade.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ((100.0 - component.wearPercentage!) / 100.0).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: isDark ? const Color(0xFF222836) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(component.grade.color),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Summary text
          Text(
            component.summary,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),

          // Key Metrics Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1218) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: component.metrics.length,
              separatorBuilder: (context, index) => Divider(
                height: 16,
                thickness: 0.8,
                color: borderColor.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final metric = component.metrics[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              metric.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.getSecondaryText(context),
                              ),
                            ),
                          ),
                          if (metric.tooltip != null) ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message: metric.tooltip!,
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 12,
                                color: AppTheme.getSecondaryText(context).withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: Text(
                        metric.value,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Partition Detail Sheet Trigger
          if (component.partitions != null && component.partitions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => PartitionDetailSheet(partitions: component.partitions!),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Inspect All ${component.partitions!.length} Partition Volumes & Inodes',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Actionable technical inspector trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (component.isRootEnhanced)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open_rounded, size: 11, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'Root Enhanced',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 11, color: Colors.blueAccent),
                      SizedBox(width: 4),
                      Text(
                        'Universal Engine',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.code_rounded, size: 14),
                label: const Text(
                  'Raw Descriptors',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => RawDescriptorSheet(component: component),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
