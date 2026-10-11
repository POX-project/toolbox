import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/resource_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/charts/live_ring_gauge.dart';
import '../../widgets/charts/live_sparkline_chart.dart';
import '../../widgets/charts/resource_usage_card.dart';
import '../../widgets/glass_container.dart';

class LiveResourceMonitorScreen extends ConsumerStatefulWidget {
  final String initialMode;

  const LiveResourceMonitorScreen({
    super.key,
    this.initialMode = 'ALL',
  });

  @override
  ConsumerState<LiveResourceMonitorScreen> createState() => _LiveResourceMonitorScreenState();
}

class _LiveResourceMonitorScreenState extends ConsumerState<LiveResourceMonitorScreen> {
  late String _selectedMode;
  int _timeWindow = 30; // 15s, 30s, 60s
  final List<String> _modes = const ['ALL', 'CPU', 'RAM', 'STORAGE', 'BATTERY', 'NETWORK'];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    final service = ref.watch(resourceMonitorServiceProvider);
    final history = ref.watch(resourceHistoryProvider);
    final snapshot = ref.watch(latestResourceSnapshotProvider);

    // Filter history based on time window
    final effectiveHistory = history.length > _timeWindow
        ? history.sublist(history.length - _timeWindow)
        : history;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Live Resource Monitor',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: theme.colorScheme.onSurface),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: service.isPaused
                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHighest,
              ),
              icon: Icon(
                service.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: service.isPaused ? const Color(0xFFEF4444) : theme.colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  service.togglePause();
                });
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Selector Tabs (ALL, CPU, RAM, STORAGE, BATTERY, NETWORK)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _modes.map((mode) {
                    final isSelected = _selectedMode == mode;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedMode = mode;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF111111))
                                : cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : borderColor,
                            ),
                          ),
                          child: Text(
                            mode,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF111111) : Colors.white)
                                  : theme.colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Time Window Selector Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: service.isPaused ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        service.isPaused ? 'TELEMETRY PAUSED' : 'STREAMING 1s SAMPLING',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppTheme.getSecondaryText(context),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [15, 30, 60].map((sec) {
                      final isSelected = _timeWindow == sec;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _timeWindow = sec;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              '${sec}s',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? theme.colorScheme.primary : AppTheme.getSecondaryText(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Main Content Area based on mode
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _buildModeContent(context, snapshot, effectiveHistory),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeContent(
    BuildContext context,
    ResourceTelemetrySnapshot snapshot,
    List<ResourceTelemetrySnapshot> history,
  ) {
    switch (_selectedMode) {
      case 'CPU':
        return _buildCpuDeepDive(context, snapshot, history);
      case 'RAM':
        return _buildRamDeepDive(context, snapshot, history);
      case 'STORAGE':
        return _buildStorageDeepDive(context, snapshot, history);
      case 'BATTERY':
        return _buildBatteryDeepDive(context, snapshot, history);
      case 'NETWORK':
        return _buildNetworkDeepDive(context, snapshot, history);
      case 'ALL':
      default:
        return _buildAllOverview(context, snapshot, history);
    }
  }

  /// ==========================================
  /// 1. ALL RESOURCES OVERVIEW
  /// ==========================================
  Widget _buildAllOverview(
    BuildContext context,
    ResourceTelemetrySnapshot snapshot,
    List<ResourceTelemetrySnapshot> history,
  ) {
    final cpuPoints = history.map((e) => e.cpuUsagePercent).toList();
    final ramPoints = history.map((e) => e.ramUsagePercent).toList();
    final storagePoints = history.map((e) => e.storageUsagePercent).toList();
    final batteryPoints = history.map((e) => e.batteryLevel.toDouble()).toList();
    final rxPoints = history.map((e) => e.networkRxSpeedKb).toList();

    return Column(
      children: [
        ResourceUsageCard(
          title: 'Processor Load',
          tag: 'CPU',
          icon: Icons.speed_rounded,
          accentColor: const Color(0xFF3B82F6),
          primaryValue: '${snapshot.cpuUsagePercent.toStringAsFixed(1)}%',
          secondaryValue: 'Hardware Threads Active',
          historyPoints: cpuPoints,
          onTap: () => setState(() => _selectedMode = 'CPU'),
        ),
        const SizedBox(height: 12),
        ResourceUsageCard(
          title: 'Memory Utilization',
          tag: 'RAM',
          icon: Icons.memory_rounded,
          accentColor: const Color(0xFF10B981),
          primaryValue: '${snapshot.ramUsagePercent.toStringAsFixed(1)}%',
          secondaryValue: '${snapshot.ramUsedGb.toStringAsFixed(1)} / ${snapshot.ramTotalGb.toStringAsFixed(1)} GB',
          historyPoints: ramPoints,
          onTap: () => setState(() => _selectedMode = 'RAM'),
        ),
        const SizedBox(height: 12),
        ResourceUsageCard(
          title: 'Internal Storage Capacity',
          tag: 'STORAGE',
          icon: Icons.storage_rounded,
          accentColor: const Color(0xFF8B5CF6),
          primaryValue: '${snapshot.storageUsagePercent.toStringAsFixed(1)}%',
          secondaryValue: '${snapshot.storageUsedGb.toStringAsFixed(1)} / ${snapshot.storageTotalGb.toStringAsFixed(1)} GB',
          historyPoints: storagePoints,
          onTap: () => setState(() => _selectedMode = 'STORAGE'),
        ),
        const SizedBox(height: 12),
        ResourceUsageCard(
          title: 'Battery Reserve',
          tag: 'BATTERY',
          icon: Icons.battery_charging_full_rounded,
          accentColor: const Color(0xFFF59E0B),
          primaryValue: '${snapshot.batteryLevel}%',
          secondaryValue: snapshot.isCharging ? 'Fast Charging Connected' : 'Discharging Under Normal Load',
          historyPoints: batteryPoints,
          onTap: () => setState(() => _selectedMode = 'BATTERY'),
        ),
        const SizedBox(height: 12),
        ResourceUsageCard(
          title: 'Network Traffic Bandwidth',
          tag: 'NETWORK',
          icon: Icons.wifi_tethering_rounded,
          accentColor: const Color(0xFF06B6D4),
          primaryValue: '${snapshot.networkRxSpeedKb.toStringAsFixed(1)} KB/s',
          secondaryValue: 'Tx: ${snapshot.networkTxSpeedKb.toStringAsFixed(1)} KB/s',
          historyPoints: rxPoints,
          maxY: max(50.0, rxPoints.isEmpty ? 50.0 : rxPoints.reduce(max) * 1.2),
          minLabel: '0 KB/s',
          avgLabel: rxPoints.isEmpty ? '0 KB/s' : '${(rxPoints.reduce((a, b) => a + b) / rxPoints.length).toStringAsFixed(0)} KB/s',
          maxLabel: rxPoints.isEmpty ? '0 KB/s' : '${rxPoints.reduce(max).toStringAsFixed(0)} KB/s',
          onTap: () => setState(() => _selectedMode = 'NETWORK'),
        ),
      ],
    );
  }

  /// ==========================================
  /// 2. CPU DEEP DIVE
  /// ==========================================
  Widget _buildCpuDeepDive(
    BuildContext context,
    ResourceTelemetrySnapshot snapshot,
    List<ResourceTelemetrySnapshot> history,
  ) {
    final theme = Theme.of(context);
    final cpuPoints = history.map((e) => e.cpuUsagePercent).toList();

    return Column(
      children: [
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REAL-TIME CPU WORKLOAD',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: const Color(0xFF3B82F6)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${snapshot.cpuUsagePercent.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -1.0),
                      ),
                    ],
                  ),
                  LiveRingGauge(
                    value: snapshot.cpuUsagePercent,
                    activeColor: const Color(0xFF3B82F6),
                    icon: Icons.speed_rounded,
                    size: 80,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                width: double.infinity,
                child: LiveSparklineChart(
                  dataPoints: cpuPoints,
                  lineColor: const Color(0xFF3B82F6),
                  strokeWidth: 2.8,
                  maxPoints: _timeWindow,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildStatsBento(
          context,
          title: 'CPU Performance Metrics',
          items: {
            'Current Load': '${snapshot.cpuUsagePercent.toStringAsFixed(1)}%',
            'Sampling Window': '${_timeWindow}s Real-time',
            'Scheduler State': 'Dynamic Governor Active',
            'Core Status': 'Multi-Threaded Balanced',
          },
        ),
      ],
    );
  }

  /// ==========================================
  /// 3. RAM DEEP DIVE
  /// ==========================================
  Widget _buildRamDeepDive(
    BuildContext context,
    ResourceTelemetrySnapshot snapshot,
    List<ResourceTelemetrySnapshot> history,
  ) {
    final theme = Theme.of(context);
    final ramPoints = history.map((e) => e.ramUsagePercent).toList();
    final freeGb = max(0.0, snapshot.ramTotalGb - snapshot.ramUsedGb);

    return Column(
      children: [
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PHYSICAL MEMORY UTILIZATION',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: const Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${snapshot.ramUsagePercent.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -1.0),
                      ),
                      Text(
                        '${snapshot.ramUsedGb.toStringAsFixed(2)} GB used of ${snapshot.ramTotalGb.toStringAsFixed(1)} GB total',
                        style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  LiveRingGauge(
                    value: snapshot.ramUsagePercent,
                    activeColor: const Color(0xFF10B981),
                    icon: Icons.memory_rounded,
                    size: 80,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                width: double.infinity,
                child: LiveSparklineChart(
                  dataPoints: ramPoints,
                  lineColor: const Color(0xFF10B981),
                  strokeWidth: 2.8,
                  maxPoints: _timeWindow,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildStatsBento(
          context,
          title: 'RAM Subsystem Breakdown',
          items: {
            'Total Memory': '${snapshot.ramTotalGb.toStringAsFixed(2)} GB',
            'Used Memory': '${snapshot.ramUsedGb.toStringAsFixed(2)} GB',
            'Available Free': '${freeGb.toStringAsFixed(2)} GB',
            'Memory Health': snapshot.ramUsagePercent < 85 ? 'Optimal (Nominal)' : 'High Pressure',
          },
        ),
      ],
    );
  }

  /// ==========================================
  /// 4. STORAGE DEEP DIVE
  /// ==========================================
  Widget _buildStorageDeepDive(
    BuildContext context,
    ResourceTelemetrySnapshot snapshot,
    List<ResourceTelemetrySnapshot> history,
  ) {
    final theme = Theme.of(context);
    final storagePoints = history.map((e) => e.storageUsagePercent).toList();
    final freeGb = max(0.0, snapshot.storageTotalGb - snapshot.storageUsedGb);

    return Column(
      children: [
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STORAGE PARTITION ALLOCATION',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: const Color(0xFF8B5CF6)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${snapshot.storageUsagePercent.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -1.0),
                      ),
                      Text(
                        '${snapshot.storageUsedGb.toStringAsFixed(1)} GB used of ${snapshot.storageTotalGb.toStringAsFixed(0)} GB',
                        style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  LiveRingGauge(
                    value: snapshot.storageUsagePercent,
                    activeColor: const Color(0xFF8B5CF6),
                    icon: Icons.storage_rounded,
                    size: 80,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                width: double.infinity,
                child: LiveSparklineChart(
                  dataPoints: storagePoints,
                  lineColor: const Color(0xFF8B5CF6),
                  strokeWidth: 2.8,
                  maxPoints: _timeWindow,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildStatsBento(
          context,
          title: 'Disk Partition Allocation',
          items: {
            'Internal Total': '${snapshot.storageTotalGb.toStringAsFixed(1)} GB',
            'Internal Used': '${snapshot.storageUsedGb.toStringAsFixed(1)} GB',
            'Internal Available': '${freeGb.toStringAsFixed(1)} GB',
            'Target Filesystem': '/data partition',
          },
        ),
      ],
    );
  }

  /// ==========================================
  /// 5. BATTERY DEEP DIVE
  /// ==========================================
  Widget _buildBatteryDeepDive(
    BuildContext context,
    ResourceTelemetrySnapshot snapshot,
    List<ResourceTelemetrySnapshot> history,
  ) {
    final theme = Theme.of(context);
    final batteryPoints = history.map((e) => e.batteryLevel.toDouble()).toList();

    return Column(
      children: [
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BATTERY LEVEL & THERMALS',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: const Color(0xFFF59E0B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${snapshot.batteryLevel}%',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -1.0),
                      ),
                      Text(
                        snapshot.isCharging ? 'Charging Active (AC / Fast Charging)' : 'Discharging on Battery',
                        style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  LiveRingGauge(
                    value: snapshot.batteryLevel.toDouble(),
                    activeColor: snapshot.isCharging ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    icon: snapshot.isCharging ? Icons.bolt_rounded : Icons.battery_full_rounded,
                    size: 80,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                width: double.infinity,
                child: LiveSparklineChart(
                  dataPoints: batteryPoints,
                  lineColor: const Color(0xFFF59E0B),
                  strokeWidth: 2.8,
                  maxPoints: _timeWindow,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildStatsBento(
          context,
          title: 'Power & Thermal Status',
          items: {
            'Level': '${snapshot.batteryLevel}%',
            'Charging Status': snapshot.isCharging ? 'Connected' : 'Unplugged',
            'Temperature': snapshot.batteryTemp != null ? '${snapshot.batteryTemp!.toStringAsFixed(1)} °C' : 'Nominal',
            'Cell Health': 'Good',
          },
        ),
      ],
    );
  }

  /// ==========================================
  /// 6. NETWORK DEEP DIVE
  /// ==========================================
  Widget _buildNetworkDeepDive(
    BuildContext context,
    ResourceTelemetrySnapshot snapshot,
    List<ResourceTelemetrySnapshot> history,
  ) {
    final theme = Theme.of(context);
    final rxPoints = history.map((e) => e.networkRxSpeedKb).toList();
    final txPoints = history.map((e) => e.networkTxSpeedKb).toList();
    final maxSpeed = max(100.0, [...rxPoints, ...txPoints].isEmpty ? 100.0 : [...rxPoints, ...txPoints].reduce(max) * 1.2);

    return Column(
      children: [
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIVE NETWORK THROUGHPUT',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: const Color(0xFF06B6D4)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.download_rounded, color: const Color(0xFF06B6D4), size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${snapshot.networkRxSpeedKb.toStringAsFixed(1)} KB/s',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.upload_rounded, color: const Color(0xFF3B82F6), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${snapshot.networkTxSpeedKb.toStringAsFixed(1)} KB/s upload',
                            style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.wifi_tethering_rounded, color: const Color(0xFF06B6D4), size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Download Bandwidth (Rx)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF06B6D4)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 100,
                width: double.infinity,
                child: LiveSparklineChart(
                  dataPoints: rxPoints,
                  maxY: maxSpeed,
                  lineColor: const Color(0xFF06B6D4),
                  strokeWidth: 2.5,
                  maxPoints: _timeWindow,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Upload Bandwidth (Tx)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3B82F6)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 100,
                width: double.infinity,
                child: LiveSparklineChart(
                  dataPoints: txPoints,
                  maxY: maxSpeed,
                  lineColor: const Color(0xFF3B82F6),
                  strokeWidth: 2.5,
                  maxPoints: _timeWindow,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildStatsBento(
          context,
          title: 'I/O Telemetry Stats',
          items: {
            'Download (Rx)': '${snapshot.networkRxSpeedKb.toStringAsFixed(1)} KB/s',
            'Upload (Tx)': '${snapshot.networkTxSpeedKb.toStringAsFixed(1)} KB/s',
            'Subsystem Source': '/proc/net/dev',
            'Loopback Excluded': 'Active Interfaces Only',
          },
        ),
      ],
    );
  }

  Widget _buildStatsBento(
    BuildContext context, {
    required String title,
    required Map<String, String> items,
  }) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 12),
          ...items.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.getSecondaryText(context), fontWeight: FontWeight.w600),
                  ),
                  Text(
                    e.value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
