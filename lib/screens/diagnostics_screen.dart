import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/command_runner.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'command_result_screen.dart';
import 'device_health_screen.dart';
import 'tests/interactive_tests.dart';
import 'tests/live_resource_monitor_screen.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commandRunner = ref.watch(commandRunnerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HEALTH & SENSORS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Diagnostics Hub',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Search input
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppTheme.getSecondaryText(context), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim().toLowerCase();
                                });
                              },
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: 'Search diagnostics, thermal, battery...',
                                hintStyle: TextStyle(color: AppTheme.getSecondaryText(context), fontSize: 13.5),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: AppTheme.getSecondaryText(context), size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Interactive Tests Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'INTERACTIVE TESTS',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildListDelegate([
                  _buildInteractiveTestCard(
                    context,
                    icon: Icons.health_and_safety_rounded,
                    title: 'Hardware Health',
                    description: 'Lifespan & diagnostics',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceHealthScreen()));
                    },
                  ),
                  _buildInteractiveTestCard(
                    context,
                    icon: Icons.show_chart_rounded,
                    title: 'Resource Telemetry',
                    description: 'Live CPU, RAM & I/O',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveResourceMonitorScreen()));
                    },
                  ),
                  _buildInteractiveTestCard(
                    context,
                    icon: Icons.tv_rounded,
                    title: 'Display & OLED',
                    description: 'RGBW uniformity test',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenTesterScreen()));
                    },
                  ),
                  _buildInteractiveTestCard(
                    context,
                    icon: Icons.touch_app_rounded,
                    title: 'Multi-Touch Tester',
                    description: 'Track multi-finger touches',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiTouchTesterScreen()));
                    },
                  ),
                  _buildInteractiveTestCard(
                    context,
                    icon: Icons.vibration_rounded,
                    title: 'Haptic & Vibration',
                    description: 'Test vibration motors',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HapticTesterScreen()));
                    },
                  ),
                  _buildInteractiveTestCard(
                    context,
                    icon: Icons.volume_up_rounded,
                    title: 'Stereo Audio Test',
                    description: 'Left & right channels',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioChannelTesterScreen()));
                    },
                  ),
                  _buildInteractiveTestCard(
                    context,
                    icon: Icons.speed_rounded,
                    title: 'Motion & Vectors',
                    description: 'Live 3-axis G-Force',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccelerometerMonitorScreen()));
                    },
                  ),
                  _buildInteractiveTestCard(
                    context,
                    icon: Icons.storage_rounded,
                    title: 'Storage Benchmark',
                    description: 'Real I/O speed & latency',
                    onTap: () {
                      _executeUserFriendlyDiagnostic(
                        context,
                        commandRunner,
                        _DiagReport(
                          icon: Icons.storage_rounded,
                          title: 'Storage Benchmark',
                          category: 'I/O Speed & Latency',
                          command: 'dumpsys diskstats',
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),

            // Diagnostics & Telemetry Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                child: Text(
                  'TELEMETRY & LOGS',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ),
            ),

            // Diagnostic Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildListDelegate(
                  _buildFilteredDiagnostics(context, commandRunner),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilteredDiagnostics(BuildContext context, CommandRunner commandRunner) {
    final diagnostics = [
      _DiagReport(
        icon: Icons.health_and_safety_rounded,
        title: 'Hardware Health Engine',
        category: 'Component Lifespan & Wear',
        command: 'device_health',
      ),
      _DiagReport(
        icon: Icons.storage_rounded,
        title: 'Storage Health & EOL',
        category: 'UFS & Flash Wear',
        command: 'dumpsys storaged',
      ),
      _DiagReport(
        icon: Icons.battery_charging_full_rounded,
        title: 'Deep Battery Health',
        category: 'Power & Cycles',
        command: 'dumpsys battery',
      ),
      _DiagReport(
        icon: Icons.memory_rounded,
        title: 'RAM & Heap Analysis',
        category: 'Active Memory Load',
        command: 'dumpsys meminfo',
      ),
      _DiagReport(
        icon: Icons.thermostat_rounded,
        title: 'Thermal & Zones',
        category: 'CPU Temperatures',
        command: 'dumpsys thermalservice',
      ),
      _DiagReport(
        icon: Icons.speed_rounded,
        title: 'Battery Drain History',
        category: 'App Power Draw',
        command: 'dumpsys batterystats',
      ),
      _DiagReport(
        icon: Icons.aspect_ratio_rounded,
        title: 'Window & Display',
        category: 'Refresh Rate Pipeline',
        command: 'dumpsys window',
      ),
      _DiagReport(
        icon: Icons.apps_rounded,
        title: 'App Package List',
        category: 'Installed Packages',
        command: 'pm list packages -f',
      ),
      _DiagReport(
        icon: Icons.sensors_rounded,
        title: 'Sensors Registry',
        category: 'Gyro, Accel & Proximity',
        command: 'dumpsys sensorservice',
      ),
      _DiagReport(
        icon: Icons.wifi_tethering_rounded,
        title: 'Wi-Fi Telemetry',
        category: 'Link & RSSI Quality',
        command: 'dumpsys wifi',
      ),
      _DiagReport(
        icon: Icons.account_tree_rounded,
        title: 'Process Activity',
        category: 'Background Tasks',
        command: 'dumpsys activity',
      ),
      _DiagReport(
        icon: Icons.bug_report_rounded,
        title: 'System Event Logs',
        category: 'Live System Logs',
        command: 'logcat -d',
      ),
      _DiagReport(
        icon: Icons.code_rounded,
        title: 'Kernel Messages',
        category: 'OS Boot Log',
        command: 'dmesg',
      ),
      _DiagReport(
        icon: Icons.settings_ethernet_rounded,
        title: 'Network Adapters',
        category: 'IP & Interfaces',
        command: 'ip a',
      ),
    ];

    final filtered = diagnostics.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.title.toLowerCase().contains(_searchQuery) ||
          d.category.toLowerCase().contains(_searchQuery) ||
          d.command.toLowerCase().contains(_searchQuery);
    }).toList();

    return filtered.map((item) {
      return GlassContainer(
        borderRadius: 22,
        padding: const EdgeInsets.all(14),
        onTap: () => _executeUserFriendlyDiagnostic(context, commandRunner, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item.category,
              style: TextStyle(
                fontSize: 10.5,
                color: AppTheme.getSecondaryText(context),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildInteractiveTestCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? theme.colorScheme.onSurface : Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: theme.colorScheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(fontSize: 10.5, color: AppTheme.getSecondaryText(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _executeUserFriendlyDiagnostic(
    BuildContext context,
    CommandRunner commandRunner,
    _DiagReport diag,
  ) async {
    HapticFeedback.mediumImpact();
    if (diag.command == 'device_health') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceHealthScreen()));
      return;
    }
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: theme.colorScheme.primary,
                strokeWidth: 3.5,
              ),
              const SizedBox(height: 18),
              Text(
                'Analyzing ${diag.title}...',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Extracting subsystem telemetry report',
                style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context)),
              ),
            ],
          ),
        ),
      ),
    );

    final rawResult = await commandRunner.runCommand(diag.command);

    if (context.mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommandResultScreen(
            title: diag.title,
            commandOutput: rawResult,
          ),
        ),
      );
    }
  }
}

class _DiagReport {
  final IconData icon;
  final String title;
  final String category;
  final String command;

  const _DiagReport({
    required this.icon,
    required this.title,
    required this.category,
    required this.command,
  });
}
