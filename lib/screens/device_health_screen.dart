import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_health_model.dart';
import '../services/command_runner.dart';
import '../services/device_health_service.dart';
import '../theme/app_theme.dart';
import '../widgets/health/component_health_card.dart';
import '../widgets/health/health_score_gauge.dart';
import '../widgets/privilege_mode_modal.dart';

class DeviceHealthScreen extends ConsumerStatefulWidget {
  const DeviceHealthScreen({super.key});

  @override
  ConsumerState<DeviceHealthScreen> createState() => _DeviceHealthScreenState();
}

class _DeviceHealthScreenState extends ConsumerState<DeviceHealthScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Storage',
    'Partitions',
    'CPU',
    'Memory',
    'Battery',
    'Thermal',
    'Network',
    'System',
  ];

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(deviceHealthReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Health & Lifespan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Copy Health Report',
            onPressed: () {
              healthAsync.whenData((report) {
                final buffer = StringBuffer();
                buffer.writeln('=== TOOLBOX HARDWARE HEALTH REPORT ===');
                if (report.hasSufficientData && report.overallScore != null) {
                  buffer.writeln('Overall Score: ${report.overallScore!.toStringAsFixed(0)}/100 (Grade ${report.overallGrade.label})');
                } else {
                  buffer.writeln('Overall Score: N/A - Insufficient data to determine health percentage (Grade ${report.overallGrade.label})');
                  buffer.writeln('Notice: We can\'t determine the health of your phone based on those data.');
                }
                buffer.writeln('Status: ${report.overallGrade.status}');
                buffer.writeln('Privilege: ${report.privilegeMode}');
                buffer.writeln('Timestamp: ${report.timestamp}');
                buffer.writeln('');
                for (final c in report.components) {
                  buffer.writeln('--- ${c.name} ---');
                  buffer.writeln('Score: ${c.score != null ? "${c.score!.toStringAsFixed(0)}%" : "N/A (Undetermined)"} (Grade ${c.grade.label})');
                  buffer.writeln('Summary: ${c.summary}');
                  for (final m in c.metrics) {
                    buffer.writeln('  • ${m.label}: ${m.value}');
                  }
                  buffer.writeln('');
                }
                Clipboard.setData(ClipboardData(text: buffer.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hardware health report copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: healthAsync.when(
        data: (report) => _buildContent(context, report),
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Analyzing kernel health descriptors & telemetry...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  'Failed to analyze device health',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  onPressed: () => ref.refresh(deviceHealthReportProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DeviceHealthReport report) {
    final filteredComponents = report.components.where((c) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Storage') return c.id == 'storage';
      if (_selectedFilter == 'Partitions') return c.id == 'partitions';
      if (_selectedFilter == 'CPU') return c.id == 'cpu';
      if (_selectedFilter == 'Memory') return c.id == 'memory';
      if (_selectedFilter == 'Battery') return c.id == 'battery';
      if (_selectedFilter == 'Thermal') return c.id == 'thermal';
      if (_selectedFilter == 'Network') return c.id == 'network';
      if (_selectedFilter == 'System') return c.id == 'system';
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(privilegeStatusProvider);
        return ref.refresh(deviceHealthReportProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Overall Score Gauge
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: HealthScoreGauge(
                score: report.overallScore,
                grade: report.overallGrade,
                privilegeMode: report.privilegeMode,
                hasSufficientData: report.hasSufficientData,
                undeterminedReason: report.undeterminedReason,
                onRefresh: () {
                  ref.invalidate(privilegeStatusProvider);
                  ref.invalidate(deviceHealthReportProvider);
                },
                onPrivilegeTap: () => showPrivilegeModeModal(context, ref),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;
                  return ChoiceChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Component Cards List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final comp = filteredComponents[index];
                  return ComponentHealthCard(component: comp);
                },
                childCount: filteredComponents.length,
              ),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
