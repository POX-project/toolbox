import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../services/command_runner.dart';
import '../services/info_service.dart';
import '../services/resource_monitor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/resource_usage_card.dart';
import '../widgets/glass_container.dart';
import '../widgets/privilege_mode_modal.dart';
import 'category_detail_screen.dart';
import 'command_result_screen.dart';
import 'home_page.dart';
import 'tests/live_resource_monitor_screen.dart';

class PhoneInfoScreen extends ConsumerStatefulWidget {
  const PhoneInfoScreen({super.key});

  @override
  ConsumerState<PhoneInfoScreen> createState() => _PhoneInfoScreenState();
}

class _PhoneInfoScreenState extends ConsumerState<PhoneInfoScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All Specs';
  late AnimationController _pulseController;

  final List<String> _categoryTabs = const [
    'All Specs',
    'Hardware',
    'Battery & Power',
    'Memory & Storage',
    'Network',
    'Diagnostics',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final androidInfoAsync = ref.watch(androidInfoProvider);
    final cpuInfoAsync = ref.watch(cpuInfoProvider);
    final memInfoAsync = ref.watch(memInfoProvider);
    final gpuInfoAsync = ref.watch(gpuInfoProvider);
    final batteryInfoAsync = ref.watch(batteryInfoProvider);
    final networkInfoAsync = ref.watch(networkInfoProvider);
    final storageInfoAsync = ref.watch(storageInfoProvider);
    final privilegeAsync = ref.watch(privilegeStatusProvider);
    final commandRunner = ref.watch(commandRunnerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).cardColor,
          onRefresh: () async {
            ref.invalidate(androidInfoProvider);
            ref.invalidate(cpuInfoProvider);
            ref.invalidate(memInfoProvider);
            ref.invalidate(gpuInfoProvider);
            ref.invalidate(batteryInfoProvider);
            ref.invalidate(networkInfoProvider);
            ref.invalidate(storageInfoProvider);
            ref.invalidate(privilegeStatusProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top Header with Device Identity & Status
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                                        : const Color(0xFF111111),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1A000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.phone_android_rounded,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        androidInfoAsync.value?.model ?? 'Android Device',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          letterSpacing: -0.4,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          AnimatedBuilder(
                                            animation: _pulseController,
                                            builder: (context, child) {
                                              return Container(
                                                width: 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withValues(
                                                    alpha: 0.6 + (_pulseController.value * 0.4),
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${androidInfoAsync.value?.manufacturer.toUpperCase() ?? "DEVICE"} • ONLINE',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.8,
                                                color: AppTheme.getSecondaryText(context),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPrivilegePill(context, privilegeAsync.value),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Search bar with Black Action Filter Button
                      _buildSearchRow(),
                      const SizedBox(height: 16),

                      // Horizontal Category Filter Pills
                      _buildCategoryFilterPills(),
                    ],
                  ),
                ),
              ),

              // Animated Hero Feature Card
              if (_searchQuery.isEmpty && _selectedCategory == 'All Specs')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: _buildHeroCard(
                      context,
                      androidInfo: androidInfoAsync.value,
                      batteryInfo: batteryInfoAsync.value,
                      memInfo: memInfoAsync.value,
                      cpuInfo: cpuInfoAsync.value,
                      storageInfo: storageInfoAsync.value,
                    ),
                  ),
                ),

              // Live Resource Telemetry Section (All Specs Mode)
              if (_searchQuery.isEmpty && _selectedCategory == 'All Specs')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                    child: Consumer(
                      builder: (context, ref, _) {
                        final currentTab = ref.watch(homeTabIndexProvider);
                        final resourceSnapshot = currentTab == 0
                            ? ref.watch(latestResourceSnapshotProvider)
                            : ref.read(latestResourceSnapshotProvider);
                        final resourceHistory = currentTab == 0
                            ? ref.watch(resourceHistoryProvider)
                            : ref.read(resourceHistoryProvider);
                        return _buildLiveTelemetrySection(context, resourceSnapshot, resourceHistory);
                      },
                    ),
                  ),
                ),

              // Section Title: Hardware & Platform
              if (_selectedCategory != 'Diagnostics') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'HARDWARE & PLATFORM',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AppTheme.getSecondaryText(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            'Tap card to inspect',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.getSecondaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Category Bento List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      _buildFilteredCategories(
                        context,
                        androidInfo: androidInfoAsync.value,
                        cpuInfo: cpuInfoAsync.value,
                        gpuInfo: gpuInfoAsync.value,
                        batteryInfo: batteryInfoAsync.value,
                        networkInfo: networkInfoAsync.value,
                        memInfo: memInfoAsync.value,
                        storageInfo: storageInfoAsync.value,
                      ),
                    ),
                  ),
                ),
              ],

              // Section Title: Diagnostic Reports
              if (_selectedCategory == 'All Specs' || _selectedCategory == 'Diagnostics') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DIAGNOSTIC HEALTH REPORTS',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppTheme.getSecondaryText(context),
                          ),
                        ),
                        Text(
                          'Interactive telemetry',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.getSecondaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Diagnostic Command Tiles Grid
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
              ],

              // Bottom padding for floating dock
              const SliverToBoxAdapter(
                child: SizedBox(height: 130),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivilegePill(BuildContext context, PrivilegeStatus? status) {
    final s = status ?? PrivilegeStatus.standard;
    final isPrivileged = s.hasPrivilege;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => showPrivilegeModeModal(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrivileged
              ? (isDark ? theme.colorScheme.primary : const Color(0xFF111111))
              : (isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFEBECEF)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPrivileged ? Icons.verified_rounded : Icons.lock_outline_rounded,
              color: isPrivileged ? Colors.white : AppTheme.getSecondaryText(context),
              size: 13,
            ),
            const SizedBox(width: 6),
            Text(
              s.label,
              style: TextStyle(
                color: isPrivileged ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSearchRow() {
    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // Search Input Box
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: isDark ? const Color(0x30000000) : const Color(0x04000000),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: AppTheme.getSecondaryText(context), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search specs, battery, RAM...',
                      hintStyle: TextStyle(color: AppTheme.getSecondaryText(context), fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppTheme.getSecondaryText(context), size: 18),
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
        ),
        const SizedBox(width: 10),

        // Filter Action Button
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.tune_rounded, color: isDark ? theme.colorScheme.onSurface : Colors.white, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use category pills below to filter specifications.')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterPills() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeBg = isDark ? Colors.white : const Color(0xFF111111);
    final activeText = isDark ? const Color(0xFF111111) : Colors.white;
    final inactiveBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final inactiveBorder = theme.colorScheme.outline;
    final inactiveText = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categoryTabs.map((tab) {
          final isSelected = _selectedCategory == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCategory = tab;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? activeBg : inactiveBorder,
                  ),
                  boxShadow: [
                    if (isSelected)
                      const BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                  ],
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isSelected ? activeText : inactiveText,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    AndroidDeviceInfo? androidInfo,
    Map<String, String>? batteryInfo,
    Map<String, String>? memInfo,
    Map<String, String>? cpuInfo,
    Map<String, String>? storageInfo,
  }) {
    final batteryRaw = batteryInfo?['Level'] ?? '0%';
    final batteryVal = int.tryParse(batteryRaw.replaceAll('%', '')) ?? 0;
    final isCharging = batteryInfo?['Is Charging'] == 'Yes';
    final modelName = androidInfo?.model ?? 'Android Phone';
    final manufacturer = androidInfo?.manufacturer ?? 'Device';
    final androidVer = androidInfo?.version.release ?? '14';
    final ramUsed = memInfo?['Used RAM'] ?? 'Normal Load';
    final cpuName = cpuInfo?['SoC Model'] ?? (cpuInfo?['Hardware'] ?? cpuInfo?['Processor'] ?? 'Multi-Core SoC');

    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x30000000) : const Color(0x06000000),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Battery Arc Gauge
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: (batteryVal / 100.0).clamp(0.0, 1.0),
                      strokeWidth: 6.5,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        batteryVal > 20 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCharging)
                        const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 14),
                      Text(
                        '$batteryVal%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Title Specs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ANDROID $androidVer • API ${androidInfo?.version.sdkInt ?? ""}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      modelName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      manufacturer.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Circular Arrow Action Button
              GestureDetector(
                onTap: () {
                  if (androidInfo != null) {
                    _navigateToCategory(context, 'Device Details', _mapDeviceInfo(androidInfo));
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: isDark ? theme.colorScheme.onSurface : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 14),

          // Micro Stats Strip
          Row(
            children: [
              _buildHeroMicroStat(
                context,
                icon: Icons.memory_rounded,
                label: 'Memory Load',
                value: ramUsed,
              ),
              Container(
                height: 28,
                width: 1,
                color: borderColor,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              _buildHeroMicroStat(
                context,
                icon: Icons.speed_rounded,
                label: 'Processor SoC',
                value: cpuName.length > 16 ? '${cpuName.substring(0, 16)}...' : cpuName,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMicroStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.onSurface, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.getSecondaryText(context), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTelemetrySection(
    BuildContext context,
    ResourceTelemetrySnapshot snapshot,
    List<ResourceTelemetrySnapshot> history,
  ) {
    final theme = Theme.of(context);

    final cpuPoints = history.map((e) => e.cpuUsagePercent).toList();
    final ramPoints = history.map((e) => e.ramUsagePercent).toList();
    final storagePoints = history.map((e) => e.storageUsagePercent).toList();
    final batteryPoints = history.map((e) => e.batteryLevel.toDouble()).toList();
    final netPoints = history.map((e) => (e.networkRxSpeedKb + e.networkTxSpeedKb)).toList();
    final maxNet = netPoints.fold(0.0, max);
    final minBattery = history.isEmpty ? snapshot.batteryLevel : history.map((e) => e.batteryLevel).reduce(min);
    final maxBattery = history.isEmpty ? snapshot.batteryLevel : history.map((e) => e.batteryLevel).reduce(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'LIVE RESOURCE TELEMETRY',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.getSecondaryText(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LiveResourceMonitorScreen(initialMode: 'ALL'),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'Full Monitor',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 242,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              SizedBox(
                width: 255,
                child: ResourceUsageCard(
                  title: 'CPU Workload',
                  tag: 'PROCESSOR',
                  icon: Icons.memory_rounded,
                  accentColor: const Color(0xFF6366F1),
                  primaryValue: '${snapshot.cpuUsagePercent.toStringAsFixed(1)}%',
                  secondaryValue: 'Dynamic Load',
                  historyPoints: cpuPoints,
                  minY: 0,
                  maxY: 100,
                  chartHeight: 52,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveResourceMonitorScreen(initialMode: 'CPU'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 255,
                child: ResourceUsageCard(
                  title: 'RAM Usage',
                  tag: 'MEMORY',
                  icon: Icons.pie_chart_rounded,
                  accentColor: const Color(0xFF10B981),
                  primaryValue: '${snapshot.ramUsagePercent.toStringAsFixed(1)}%',
                  secondaryValue: '${snapshot.ramUsedGb.toStringAsFixed(1)} / ${snapshot.ramTotalGb.toStringAsFixed(1)} GB',
                  historyPoints: ramPoints,
                  minY: 0,
                  maxY: 100,
                  chartHeight: 52,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveResourceMonitorScreen(initialMode: 'RAM'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 255,
                child: ResourceUsageCard(
                  title: 'Storage Capacity',
                  tag: 'INTERNAL',
                  icon: Icons.sd_storage_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  primaryValue: '${snapshot.storageUsagePercent.toStringAsFixed(1)}%',
                  secondaryValue: '${snapshot.storageUsedGb.toStringAsFixed(1)} / ${snapshot.storageTotalGb.toStringAsFixed(1)} GB',
                  historyPoints: storagePoints,
                  minY: 0,
                  maxY: 100,
                  chartHeight: 52,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveResourceMonitorScreen(initialMode: 'STORAGE'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 255,
                child: ResourceUsageCard(
                  title: 'Battery Health',
                  tag: 'POWER',
                  icon: Icons.battery_charging_full_rounded,
                  accentColor: const Color(0xFF14B8A6),
                  primaryValue: '${snapshot.batteryLevel}%',
                  secondaryValue: '${snapshot.isCharging ? "Charging" : "Discharging"}${snapshot.batteryTemp != null ? " • ${snapshot.batteryTemp!.toStringAsFixed(1)}°C" : ""}',
                  historyPoints: batteryPoints,
                  minY: 0,
                  maxY: 100,
                  minLabel: '$minBattery%',
                  maxLabel: '$maxBattery%',
                  chartHeight: 52,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveResourceMonitorScreen(initialMode: 'BATTERY'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 255,
                child: ResourceUsageCard(
                  title: 'Network Traffic',
                  tag: 'BANDWIDTH',
                  icon: Icons.wifi_rounded,
                  accentColor: const Color(0xFFEC4899),
                  primaryValue: '${(snapshot.networkRxSpeedKb + snapshot.networkTxSpeedKb).toStringAsFixed(1)} KB/s',
                  secondaryValue: '↓ ${snapshot.networkRxSpeedKb.toStringAsFixed(1)} • ↑ ${snapshot.networkTxSpeedKb.toStringAsFixed(1)}',
                  historyPoints: netPoints,
                  minY: 0,
                  maxY: max(100.0, maxNet * 1.2),
                  minLabel: '0 KB/s',
                  avgLabel: '${netPoints.isEmpty ? 0 : (netPoints.reduce((a, b) => a + b) / netPoints.length).toStringAsFixed(1)} KB/s',
                  maxLabel: '${maxNet.toStringAsFixed(1)} KB/s',
                  chartHeight: 52,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveResourceMonitorScreen(initialMode: 'NETWORK'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFilteredCategories(
    BuildContext context, {
    AndroidDeviceInfo? androidInfo,
    Map<String, String>? cpuInfo,
    Map<String, String>? gpuInfo,
    Map<String, String>? batteryInfo,
    Map<String, String>? networkInfo,
    Map<String, String>? memInfo,
    Map<String, String>? storageInfo,
  }) {
    final List<Widget> cards = [];
    final showAll = _selectedCategory == 'All Specs';

    // Live Resource Cards prepended per Category Filter Mode (wrapped in Consumer for isolated rebuilds)
    if (_selectedCategory == 'Hardware') {
      cards.add(
        Consumer(
          builder: (context, ref, _) {
            final resourceSnapshot = ref.watch(latestResourceSnapshotProvider);
            final history = ref.watch(resourceHistoryProvider);
            return ResourceUsageCard(
              title: 'Live CPU Workload',
              tag: 'REAL-TIME FREQUENCY & LOAD',
              icon: Icons.memory_rounded,
              accentColor: const Color(0xFF6366F1),
              primaryValue: '${resourceSnapshot.cpuUsagePercent.toStringAsFixed(1)}%',
              secondaryValue: 'Dynamic Processor Load',
              historyPoints: history.map((e) => e.cpuUsagePercent).toList(),
              minY: 0,
              maxY: 100,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LiveResourceMonitorScreen(initialMode: 'CPU'),
                ),
              ),
            );
          },
        ),
      );
    }

    if (_selectedCategory == 'Memory & Storage') {
      cards.add(
        Consumer(
          builder: (context, ref, _) {
            final resourceSnapshot = ref.watch(latestResourceSnapshotProvider);
            final history = ref.watch(resourceHistoryProvider);
            return Column(
              children: [
                ResourceUsageCard(
                  title: 'Live RAM Allocation',
                  tag: 'ACTIVE VOLATILE MEMORY',
                  icon: Icons.pie_chart_rounded,
                  accentColor: const Color(0xFF10B981),
                  primaryValue: '${resourceSnapshot.ramUsagePercent.toStringAsFixed(1)}%',
                  secondaryValue: '${resourceSnapshot.ramUsedGb.toStringAsFixed(2)} / ${resourceSnapshot.ramTotalGb.toStringAsFixed(1)} GB',
                  historyPoints: history.map((e) => e.ramUsagePercent).toList(),
                  minY: 0,
                  maxY: 100,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveResourceMonitorScreen(initialMode: 'RAM'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ResourceUsageCard(
                  title: 'Storage Usage & Partition',
                  tag: 'PERSISTENT FILE SYSTEM',
                  icon: Icons.sd_storage_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  primaryValue: '${resourceSnapshot.storageUsagePercent.toStringAsFixed(1)}%',
                  secondaryValue: '${resourceSnapshot.storageUsedGb.toStringAsFixed(1)} / ${resourceSnapshot.storageTotalGb.toStringAsFixed(1)} GB',
                  historyPoints: history.map((e) => e.storageUsagePercent).toList(),
                  minY: 0,
                  maxY: 100,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveResourceMonitorScreen(initialMode: 'STORAGE'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    if (_selectedCategory == 'Battery & Power') {
      cards.add(
        Consumer(
          builder: (context, ref, _) {
            final resourceSnapshot = ref.watch(latestResourceSnapshotProvider);
            final history = ref.watch(resourceHistoryProvider);
            final effectiveMin = history.isEmpty ? resourceSnapshot.batteryLevel : history.map((e) => e.batteryLevel).reduce(min);
            final effectiveMax = history.isEmpty ? resourceSnapshot.batteryLevel : history.map((e) => e.batteryLevel).reduce(max);
            return ResourceUsageCard(
              title: 'Live Battery & Power Telemetry',
              tag: 'POWER & CHARGING CYCLE',
              icon: Icons.battery_charging_full_rounded,
              accentColor: const Color(0xFF14B8A6),
              primaryValue: '${resourceSnapshot.batteryLevel}%',
              secondaryValue: '${resourceSnapshot.isCharging ? "Charging" : "Discharging"}${resourceSnapshot.batteryTemp != null ? " • ${resourceSnapshot.batteryTemp!.toStringAsFixed(1)}°C" : ""}',
              historyPoints: history.map((e) => e.batteryLevel.toDouble()).toList(),
              minY: 0,
              maxY: 100,
              minLabel: '$effectiveMin%',
              maxLabel: '$effectiveMax%',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LiveResourceMonitorScreen(initialMode: 'BATTERY'),
                ),
              ),
            );
          },
        ),
      );
    }

    if (_selectedCategory == 'Network') {
      cards.add(
        Consumer(
          builder: (context, ref, _) {
            final resourceSnapshot = ref.watch(latestResourceSnapshotProvider);
            final history = ref.watch(resourceHistoryProvider);
            final netPoints = history.map((e) => (e.networkRxSpeedKb + e.networkTxSpeedKb)).toList();
            final maxNet = netPoints.fold(0.0, max);
            return ResourceUsageCard(
              title: 'Live Network Throughput',
              tag: 'DYNAMIC BANDWIDTH',
              icon: Icons.wifi_rounded,
              accentColor: const Color(0xFFEC4899),
              primaryValue: '${(resourceSnapshot.networkRxSpeedKb + resourceSnapshot.networkTxSpeedKb).toStringAsFixed(1)} KB/s',
              secondaryValue: 'Rx: ${resourceSnapshot.networkRxSpeedKb.toStringAsFixed(1)} KB/s • Tx: ${resourceSnapshot.networkTxSpeedKb.toStringAsFixed(1)} KB/s',
              historyPoints: netPoints,
              minY: 0,
              maxY: max(100.0, maxNet * 1.2),
              minLabel: '0 KB/s',
              avgLabel: '${netPoints.isEmpty ? 0 : (netPoints.reduce((a, b) => a + b) / netPoints.length).toStringAsFixed(1)} KB/s',
              maxLabel: '${maxNet.toStringAsFixed(1)} KB/s',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LiveResourceMonitorScreen(initialMode: 'NETWORK'),
                ),
              ),
            );
          },
        ),
      );
    }

    // 1. Device Hardware
    if ((showAll || _selectedCategory == 'Hardware') &&
        _matchesSearch(['Device Details', 'Model', 'Manufacturer', 'Brand', 'Board', 'Hardware', androidInfo?.model ?? ''])) {
      cards.add(
        _buildEditorialCategoryCard(
          context,
          icon: Icons.phone_android_rounded,
          title: 'Device & Identity',
          tag: 'HARDWARE',
          keyInfo: {
            'Model': androidInfo?.model ?? 'Unknown',
            'Brand': androidInfo?.brand ?? 'Unknown',
            'Board': androidInfo?.board ?? 'Unknown',
          },
          onTap: () {
            if (androidInfo != null) {
              _navigateToCategory(context, 'Device Identity', _mapDeviceInfo(androidInfo));
            }
          },
        ),
      );
    }

    // 2. OS & Platform
    if ((showAll || _selectedCategory == 'Hardware') &&
        _matchesSearch(['OS & System', 'Android', 'Version', 'SDK', 'Security Patch', 'Build', androidInfo?.version.release ?? ''])) {
      cards.add(
        _buildEditorialCategoryCard(
          context,
          icon: Icons.layers_rounded,
          title: 'OS & System Platform',
          tag: 'ANDROID',
          keyInfo: {
            'Release': 'Android ${androidInfo?.version.release ?? "Unknown"}',
            'SDK API': 'Level ${androidInfo?.version.sdkInt ?? "Unknown"}',
            'Security Patch': androidInfo?.version.securityPatch ?? 'Unknown',
          },
          onTap: () {
            if (androidInfo != null) {
              _navigateToCategory(context, 'OS & Platform', _mapOsInfo(androidInfo));
            }
          },
        ),
      );
    }

    // 3. CPU Architecture
    if ((showAll || _selectedCategory == 'Hardware') &&
        _matchesSearch(['CPU Details', 'Processor', 'Cores', 'Architecture', 'Hardware', cpuInfo?['Hardware'] ?? '', cpuInfo?['SoC Model'] ?? ''])) {
      cards.add(
        _buildEditorialCategoryCard(
          context,
          icon: Icons.memory_rounded,
          title: 'CPU & Core Architecture',
          tag: 'CHIPSET',
          keyInfo: {
            'SoC / Platform': cpuInfo?['SoC Model'] ?? cpuInfo?['Hardware'] ?? 'Unknown',
            'Cores': cpuInfo?['CPU Cores'] ?? 'Multi-Core',
            'Topology': cpuInfo?['Cluster Topology'] ?? androidInfo?.supportedAbis.firstOrNull ?? 'ARM64-v8a',
          },
          onTap: () {
            if (cpuInfo != null) {
              _navigateToCategory(context, 'CPU & Architecture', cpuInfo);
            }
          },
        ),
      );
    }

    // 4. Memory & Storage
    if ((showAll || _selectedCategory == 'Memory & Storage') &&
        _matchesSearch(['Memory', 'RAM', 'Storage', 'Internal', memInfo?['Total RAM'] ?? '', storageInfo?['Internal Total'] ?? ''])) {
      cards.add(
        _buildEditorialCategoryCard(
          context,
          icon: Icons.pie_chart_rounded,
          title: 'Memory & Storage Capacity',
          tag: 'CAPACITY',
          keyInfo: {
            'Total RAM': memInfo?['Total RAM'] ?? 'Analyzing...',
            'Available RAM': memInfo?['Free RAM'] ?? 'Analyzing...',
            'Internal Storage': storageInfo?['Internal Total'] ?? 'Storage Available',
          },
          onTap: () {
            final combined = <String, String>{};
            if (memInfo != null) combined.addAll(memInfo);
            if (storageInfo != null) combined.addAll(storageInfo);
            _navigateToCategory(context, 'Memory & Storage', combined);
          },
        ),
      );
    }

    // 5. GPU & Graphics
    if ((showAll || _selectedCategory == 'Hardware') &&
        _matchesSearch(['GPU Details', 'Renderer', 'Vendor', 'Graphics', 'Vulkan', gpuInfo?['Renderer'] ?? ''])) {
      cards.add(
        _buildEditorialCategoryCard(
          context,
          icon: Icons.sports_esports_rounded,
          title: 'GPU & Graphics Render',
          tag: 'GRAPHICS',
          keyInfo: {
            'Renderer': gpuInfo?['Renderer'] ?? 'Graphics Subsystem',
            'Vendor': gpuInfo?['Vendor'] ?? 'Hardware Vendor',
          },
          onTap: () {
            if (gpuInfo != null) {
              _navigateToCategory(context, 'GPU & Graphics', gpuInfo);
            }
          },
        ),
      );
    }

    // 6. Battery & Power
    if ((showAll || _selectedCategory == 'Battery & Power') &&
        _matchesSearch(['Battery Status', 'Power', 'Health', 'Level', 'State', batteryInfo?['Level'] ?? ''])) {
      cards.add(
        _buildEditorialCategoryCard(
          context,
          icon: Icons.battery_charging_full_rounded,
          title: 'Battery & Power Health',
          tag: 'ENERGY',
          keyInfo: {
            'Level': batteryInfo?['Level'] ?? 'Unknown',
            'State': batteryInfo?['State'] ?? 'Unknown',
            'Charging?': batteryInfo?['Is Charging'] ?? 'No',
          },
          onTap: () {
            if (batteryInfo != null) {
              _navigateToCategory(context, 'Battery & Power', batteryInfo);
            }
          },
        ),
      );
    }

    // 7. Network & Wi-Fi
    if ((showAll || _selectedCategory == 'Network') &&
        _matchesSearch(['Network', 'Connectivity', 'Wi-Fi', 'IP', 'SSID', networkInfo?['Wi-Fi IP'] ?? '', networkInfo?['Country'] ?? '', networkInfo?['Public IP'] ?? ''])) {
      cards.add(
        _buildEditorialCategoryCard(
          context,
          icon: Icons.wifi_rounded,
          title: 'Network & Wi-Fi Link',
          tag: 'WIRELESS',
          keyInfo: {
            'Country / IP': networkInfo?['Country'] != null ? '${networkInfo!['Country']} • ${networkInfo['Public IP'] ?? ""}' : (networkInfo?['Wi-Fi IP'] ?? 'Unknown'),
            'Network / SSID': networkInfo?['Wi-Fi SSID'] ?? (networkInfo?['Wi-Fi SSID / BSSID'] ?? 'Unknown'),
            if (networkInfo?['ISP'] != null) 'ISP Provider': networkInfo!['ISP']!,
            if (networkInfo?['Gateway'] != null) 'Default Gateway': networkInfo!['Gateway']!,
          },
          onTap: () {
            if (networkInfo != null) {
              _navigateToCategory(context, 'Network & Connectivity', networkInfo);
            }
          },
        ),
      );
    }

    if (cards.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No specifications found matching search.',
              style: TextStyle(color: AppTheme.getSecondaryText(context)),
            ),
          ),
        ),
      ];
    }

    return cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12.0), child: c)).toList();
  }

  bool _matchesSearch(List<String> terms) {
    if (_searchQuery.isEmpty) return true;
    return terms.any((t) => t.toLowerCase().contains(_searchQuery));
  }

  Widget _buildEditorialCategoryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String tag,
    required Map<String, String> keyInfo,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: theme.colorScheme.onSurface, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: keyInfo.entries.map((entry) {
                    return Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${entry.key}: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getSecondaryText(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: AppTheme.getSecondaryText(context), size: 20),
        ],
      ),
    );
  }

  List<Widget> _buildFilteredDiagnostics(BuildContext context, CommandRunner commandRunner) {
    final diagnostics = [
      _DiagReport(
        icon: Icons.battery_charging_full_rounded,
        title: 'Deep Battery Health',
        category: 'Power & Charge Cycles',
        command: 'dumpsys battery',
      ),
      _DiagReport(
        icon: Icons.memory_rounded,
        title: 'RAM & Heap Analysis',
        category: 'Active Memory Distribution',
        command: 'dumpsys meminfo',
      ),
      _DiagReport(
        icon: Icons.thermostat_rounded,
        title: 'Thermal & Cooling Status',
        category: 'CPU Temperature Zones',
        command: 'dumpsys thermalservice',
      ),
      _DiagReport(
        icon: Icons.speed_rounded,
        title: 'Battery Drain History',
        category: 'App Discharge Rates',
        command: 'dumpsys batterystats',
      ),
      _DiagReport(
        icon: Icons.aspect_ratio_rounded,
        title: 'Display & Surface Pipeline',
        category: 'Refresh Rate & Windows',
        command: 'dumpsys window',
      ),
      _DiagReport(
        icon: Icons.apps_rounded,
        title: 'Installed App Inventory',
        category: 'Package Manifests',
        command: 'pm list packages -f',
      ),
      _DiagReport(
        icon: Icons.sensors_rounded,
        title: 'Hardware Sensor Registry',
        category: 'Gyro, Accel & Proximity',
        command: 'dumpsys sensorservice',
      ),
      _DiagReport(
        icon: Icons.wifi_tethering_rounded,
        title: 'Wi-Fi Signal & Telemetry',
        category: 'Channel & RSSI Health',
        command: 'dumpsys wifi',
      ),
      _DiagReport(
        icon: Icons.account_tree_rounded,
        title: 'Process Tree & Tasks',
        category: 'Active Background Tasks',
        command: 'dumpsys activity',
      ),
      _DiagReport(
        icon: Icons.bug_report_rounded,
        title: 'System Event Logs',
        category: 'Real-time Event Records',
        command: 'logcat -d',
      ),
      _DiagReport(
        icon: Icons.code_rounded,
        title: 'Kernel System Messages',
        category: 'OS Boot & Hardware Log',
        command: 'dmesg',
      ),
      _DiagReport(
        icon: Icons.settings_ethernet_rounded,
        title: 'Network Interface Config',
        category: 'IP Routes & Adapters',
        command: 'ip a',
      ),
    ];

    final filtered = diagnostics.where((d) => _matchesSearch([d.title, d.category, d.command])).toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return filtered.map((item) {
      return GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(14),
        onTap: () => _executeUserFriendlyDiagnostic(context, commandRunner, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: isDark ? theme.colorScheme.onSurface : Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
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

  Map<String, String> _mapDeviceInfo(AndroidDeviceInfo info) {
    return {
      'Brand': info.brand,
      'Manufacturer': info.manufacturer,
      'Model': info.model,
      'Product': info.product,
      'Device': info.device,
      'Board': info.board,
      'Hardware': info.hardware,
      'Physical Device?': info.isPhysicalDevice ? 'Yes' : 'No',
      'Supported ABIs': info.supportedAbis.join(', '),
      'Supported 32-bit ABIs': info.supported32BitAbis.join(', '),
      'Supported 64-bit ABIs': info.supported64BitAbis.join(', '),
      'Display': info.display,
      'Host': info.host,
      'ID': info.id,
    };
  }

  Map<String, String> _mapOsInfo(AndroidDeviceInfo info) {
    return {
      'Android Version': info.version.release,
      'SDK Int': info.version.sdkInt.toString(),
      'Security Patch': info.version.securityPatch ?? 'Unknown',
      'Codename': info.version.codename,
      'Base OS': info.version.baseOS ?? 'Stock / Generic',
      'Incremental': info.version.incremental,
      'Fingerprint': info.fingerprint,
      'Bootloader': info.bootloader,
      'Host': info.host,
      'Tags': info.tags,
      'Type': info.type,
      'Build ID': info.id,
    };
  }

  void _navigateToCategory(BuildContext context, String title, Map<String, String> data) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          title: title,
          data: data,
        ),
      ),
    );
  }

  void _executeUserFriendlyDiagnostic(
    BuildContext context,
    CommandRunner commandRunner,
    _DiagReport diag,
  ) async {
    HapticFeedback.mediumImpact();
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
                'Gathering ${diag.title}...',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Analyzing system telemetry metrics',
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
