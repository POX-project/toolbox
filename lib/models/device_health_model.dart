import 'package:flutter/material.dart';

enum HealthGrade {
  aPlus('A+', 'Optimal', 'Hardware is operating in peak factory condition with minimal wear.', Color(0xFF10B981)),
  a('A', 'Excellent', 'All subsystems are healthy with minor expected usage wear.', Color(0xFF34D399)),
  b('B', 'Good', 'Hardware is stable, moderate wear or thermal throttling detected.', Color(0xFFFBBF24)),
  c('C', 'Fair / Attention', 'Measurable degradation detected. Component may require optimization.', Color(0xFFF97316)),
  critical('F', 'Critical', 'Severe wear, high fault rate, or hardware degradation detected.', Color(0xFFEF4444)),
  undetermined('N/A', 'Undetermined', 'Diagnostic telemetry is insufficient to calculate authentic hardware health percentage.', Color(0xFF94A3B8));

  final String label;
  final String status;
  final String description;
  final Color color;

  const HealthGrade(this.label, this.status, this.description, this.color);

  static HealthGrade fromScore(double? score) {
    if (score == null) return HealthGrade.undetermined;
    if (score >= 95) return HealthGrade.aPlus;
    if (score >= 85) return HealthGrade.a;
    if (score >= 70) return HealthGrade.b;
    if (score >= 50) return HealthGrade.c;
    return HealthGrade.critical;
  }
}

enum MetricStatus {
  optimal,
  good,
  warning,
  critical,
  info,
}

class HealthMetricItem {
  final String label;
  final String value;
  final String? unit;
  final MetricStatus status;
  final String? tooltip;

  const HealthMetricItem({
    required this.label,
    required this.value,
    this.unit,
    this.status = MetricStatus.good,
    this.tooltip,
  });
}

class RawHardwareDescriptor {
  final String key;
  final String pathOrSource;
  final String rawValue;
  final String interpretation;

  const RawHardwareDescriptor({
    required this.key,
    required this.pathOrSource,
    required this.rawValue,
    required this.interpretation,
  });
}

class PartitionInfo {
  final String name;
  final String blockDevice;
  final String? mountPoint;
  final String? fsType;
  final String? mountFlags;
  final int? sizeBytes;
  final int? usedBytes;
  final int? availBytes;
  final double? usePercentage;
  final int? totalInodes;
  final int? usedInodes;
  final int? freeInodes;
  final double? inodeUsePct;
  final bool isReadOnly;
  final String category;

  const PartitionInfo({
    required this.name,
    required this.blockDevice,
    this.mountPoint,
    this.fsType,
    this.mountFlags,
    this.sizeBytes,
    this.usedBytes,
    this.availBytes,
    this.usePercentage,
    this.totalInodes,
    this.usedInodes,
    this.freeInodes,
    this.inodeUsePct,
    this.isReadOnly = false,
    this.category = 'System Core',
  });
}

class ComponentHealth {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final double? score; // 0 - 100, null if telemetry is insufficient
  final HealthGrade grade;
  final String summary;
  final bool isRootEnhanced;
  final bool hasSufficientData;
  final double? wearPercentage; // 0 - 100% wear consumed
  final List<HealthMetricItem> metrics;
  final List<RawHardwareDescriptor> rawDescriptors;
  final List<String> recommendations;
  final List<PartitionInfo>? partitions;

  const ComponentHealth({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    this.score,
    required this.grade,
    required this.summary,
    required this.isRootEnhanced,
    this.hasSufficientData = true,
    this.wearPercentage,
    required this.metrics,
    required this.rawDescriptors,
    this.recommendations = const [],
    this.partitions,
  });
}

class DeviceHealthReport {
  final double? overallScore; // null if telemetry is insufficient
  final HealthGrade overallGrade;
  final String summary;
  final String privilegeMode;
  final DateTime timestamp;
  final List<ComponentHealth> components;
  final bool hasSufficientData;
  final String? undeterminedReason;

  const DeviceHealthReport({
    this.overallScore,
    required this.overallGrade,
    required this.summary,
    required this.privilegeMode,
    required this.timestamp,
    required this.components,
    this.hasSufficientData = true,
    this.undeterminedReason,
  });

  ComponentHealth? getComponent(String id) {
    try {
      return components.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
