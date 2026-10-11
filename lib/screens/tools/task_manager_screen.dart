import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/command_runner.dart';
import '../../services/network_geo_service.dart';
import '../../services/resource_monitor_service.dart';
import '../../theme/app_theme.dart';

class TaskItem {
  final int pid;
  final String user;
  final String pr;
  final String ni;
  final String virt;
  final String res;
  final String shr;
  final String state;
  final double cpuPct;
  final double memPct;
  final String time;
  final String args;
  final String category; // 'User App', 'System Service', 'Kernel Thread'
  final String speed; // CPU execution / core frequency
  final String ioSpeed; // Process I/O throughput
  final int ioBytes;
  final int? sockets;

  const TaskItem({
    required this.pid,
    required this.user,
    required this.pr,
    required this.ni,
    required this.virt,
    required this.res,
    required this.shr,
    required this.state,
    required this.cpuPct,
    required this.memPct,
    required this.time,
    required this.args,
    required this.category,
    required this.speed,
    required this.ioSpeed,
    required this.ioBytes,
    this.sockets,
  });
}

class TaskManagerScreen extends ConsumerStatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  ConsumerState<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends ConsumerState<TaskManagerScreen> {
  bool _isLoading = true;
  bool _autoRefresh = true;
  Timer? _timer;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'CPU'; // 'CPU', 'RAM', 'Speed', 'I/O & Net', 'PID', 'Name'

  final TextEditingController _searchController = TextEditingController();

  List<TaskItem> _tasks = [];
  double _totalCpuLoad = 0.0;
  String _curCpuFreq = 'Live DVFS';

  @override
  void initState() {
    super.initState();
    _fetchProcesses();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_autoRefresh) {
      _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        if (mounted && _autoRefresh && !_isLoading) {
          _fetchProcesses(silent: true);
        }
      });
    }
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
      if (_autoRefresh) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _fetchProcesses({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final runner = ref.read(commandRunnerProvider);

    try {
      // 1. Read live CPU frequency across clusters (big.LITTLE)
      int fKhz = 0;
      for (final core in [0, 4, 7]) {
        final fOut = await runner.runCommand('cat /sys/devices/system/cpu/cpu$core/cpufreq/scaling_cur_freq 2>/dev/null');
        final parsed = int.tryParse(fOut.trim()) ?? 0;
        if (parsed > fKhz) {
          fKhz = parsed;
        }
      }
      if (fKhz > 0) {
        _curCpuFreq = '${(fKhz / 1000000.0).toStringAsFixed(2)} GHz';
      }

      // 2. Fetch processes via top
      final topOut = await runner.runCommand('top -b -n 1 -m 80 2>/dev/null');
      if (topOut.isNotEmpty) {
        final List<TaskItem> list = [];
        double cpuUser = 0;
        double cpuSys = 0;

        for (final line in topOut.split('\n')) {
          final tLine = line.trim();
          if (tLine.contains('%cpu')) {
            final mTotal = RegExp(r'(\d+)%cpu').firstMatch(tLine);
            final mUser = RegExp(r'(\d+)%user').firstMatch(tLine);
            final mSys = RegExp(r'(\d+)%sys').firstMatch(tLine);
            final mIdle = RegExp(r'(\d+)%idle').firstMatch(tLine);

            final totalPool = double.tryParse(mTotal?.group(1) ?? '100') ?? 100.0;
            if (mIdle != null && totalPool > 0) {
              final idle = double.tryParse(mIdle.group(1) ?? '0') ?? 0.0;
              _totalCpuLoad = (((totalPool - idle) / totalPool) * 100.0).clamp(0.0, 100.0);
            } else {
              if (mUser != null) cpuUser = double.tryParse(mUser.group(1) ?? '0') ?? 0;
              if (mSys != null) cpuSys = double.tryParse(mSys.group(1) ?? '0') ?? 0;
              final divisor = totalPool > 100 ? (totalPool / 100.0) : 1.0;
              _totalCpuLoad = ((cpuUser + cpuSys) / divisor).clamp(0.0, 100.0);
            }
          } else if (!tLine.startsWith('PID') && !tLine.startsWith('Tasks:') && !tLine.startsWith('Mem:') && tLine.isNotEmpty) {
            final parts = tLine.split(RegExp(r'\s+'));
            if (parts.length >= 12) {
              final pid = int.tryParse(parts[0]);
              if (pid != null) {
                final user = parts[1];
                final pr = parts[2];
                final ni = parts[3];
                final virt = parts[4];
                final res = parts[5];
                final shr = parts[6];
                final state = parts[7];
                final cpuPct = double.tryParse(parts[8]) ?? 0.0;
                final memPct = double.tryParse(parts[9]) ?? 0.0;
                final time = parts[10];
                final args = parts.sublist(11).join(' ');

                String category = 'System Service';
                if (args.startsWith('[') && args.endsWith(']')) {
                  category = 'Kernel Thread';
                } else if (user.startsWith('u0_a') || user.startsWith('u1_a')) {
                  category = 'User App';
                }

                // Calculate speed and I/O heuristics
                final speedStr = cpuPct > 0 ? '${cpuPct.toStringAsFixed(1)}% @ $_curCpuFreq' : _curCpuFreq;
                final resBytes = _parseResBytes(res);

                list.add(TaskItem(
                  pid: pid,
                  user: user,
                  pr: pr,
                  ni: ni,
                  virt: virt,
                  res: res,
                  shr: shr,
                  state: state,
                  cpuPct: cpuPct,
                  memPct: memPct,
                  time: time,
                  args: args,
                  category: category,
                  speed: speedStr,
                  ioSpeed: resBytes > 50 * 1024 * 1024 ? '${(resBytes / (1024 * 1024)).toStringAsFixed(0)}M RSS' : '${(resBytes / 1024).toStringAsFixed(0)}K RSS',
                  ioBytes: resBytes,
                ));
              }
            }
          }
        }

        if (list.isNotEmpty && mounted) {
          setState(() {
            _tasks = list;
            _isLoading = false;
          });
          return;
        }
      }

      // Fallback: ps -A if top returned empty
      final psOut = await runner.runCommand('ps -A -o PID,USER,PR,NI,VSZ,RSS,S,CMD 2>/dev/null');
      if (psOut.isNotEmpty) {
        final List<TaskItem> list = [];
        final lines = psOut.split('\n');
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 8) {
            final pid = int.tryParse(parts[0]);
            if (pid != null) {
              final user = parts[1];
              final pr = parts[2];
              final ni = parts[3];
              final vsz = '${parts[4]}K';
              final rss = '${parts[5]}K';
              final state = parts[6];
              final cmd = parts.sublist(7).join(' ');

              String category = 'System Service';
              if (cmd.startsWith('[') && cmd.endsWith(']')) {
                category = 'Kernel Thread';
              } else if (user.startsWith('u0_a') || user.startsWith('u1_a')) {
                category = 'User App';
              }

              final resBytes = (int.tryParse(parts[5]) ?? 0) * 1024;
              list.add(TaskItem(
                pid: pid,
                user: user,
                pr: pr,
                ni: ni,
                virt: vsz,
                res: rss,
                shr: '0',
                state: state,
                cpuPct: 0.0,
                memPct: 0.0,
                time: '0:00',
                args: cmd,
                category: category,
                speed: _curCpuFreq,
                ioSpeed: '${(resBytes / 1024).toStringAsFixed(0)}K RSS',
                ioBytes: resBytes,
              ));
            }
          }
        }
        if (mounted) {
          setState(() {
            _tasks = list;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _killProcess(TaskItem task) async {
    final runner = ref.read(commandRunnerProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Terminate PID ${task.pid}?'),
        content: Text('Are you sure you want to kill "${task.args}"?\n\nThis will send SIGKILL (-9) or am force-stop to the application process.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kill Task', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (task.category == 'User App') {
      final pkg = task.args.split(':').first.trim();
      await runner.runCommand('am force-stop $pkg 2>/dev/null || kill -9 ${task.pid} 2>/dev/null');
    } else {
      await runner.runCommand('kill -9 ${task.pid} 2>/dev/null');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Killed task ${task.pid} (${task.args})'), duration: const Duration(seconds: 2)),
    );
    _fetchProcesses();
  }

  Future<void> _trimMemory() async {
    final runner = ref.read(commandRunnerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Triggering system memory trim & page cache reclaim...'), duration: Duration(milliseconds: 1500)),
    );
    final out = await runner.runCommand('am send-trim-memory RUNNING_CRITICAL 2>/dev/null; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Memory trim completed. ${out.trim().isNotEmpty ? out.trim() : ""}'), duration: const Duration(seconds: 2)),
    );
    _fetchProcesses();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).colorScheme.outline;

    // Watch real-time network and GeoIP telemetry
    final resSnapshot = ref.watch(latestResourceSnapshotProvider);
    final geoAsync = ref.watch(networkGeoInfoProvider);
    final geo = geoAsync.value;

    final categories = ['All', 'User App', 'System Service', 'Kernel Thread'];

    final filtered = _tasks.where((t) {
      final matchesCat = _selectedCategory == 'All' || t.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesQuery = q.isEmpty ||
          t.args.toLowerCase().contains(q) ||
          t.pid.toString().contains(q) ||
          t.user.toLowerCase().contains(q);
      return matchesCat && matchesQuery;
    }).toList();

    // Sort tasks
    filtered.sort((a, b) {
      if (_sortBy == 'CPU') {
        return b.cpuPct.compareTo(a.cpuPct);
      } else if (_sortBy == 'RAM') {
        return _parseResBytes(b.res).compareTo(_parseResBytes(a.res));
      } else if (_sortBy == 'Speed') {
        final cmp = b.cpuPct.compareTo(a.cpuPct);
        if (cmp != 0) return cmp;
        return b.speed.compareTo(a.speed);
      } else if (_sortBy == 'I/O & Net') {
        return b.ioBytes.compareTo(a.ioBytes);
      } else if (_sortBy == 'PID') {
        return a.pid.compareTo(b.pid);
      } else {
        return a.args.toLowerCase().compareTo(b.args.toLowerCase());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(_autoRefresh ? Icons.pause_circle_rounded : Icons.play_circle_rounded, size: 20),
            tooltip: _autoRefresh ? 'Pause Auto-Refresh' : 'Resume Auto-Refresh',
            color: _autoRefresh ? const Color(0xFF10B981) : Colors.grey,
            onPressed: _toggleAutoRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded, size: 20),
            tooltip: 'Trim Memory',
            onPressed: _trimMemory,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: () => _fetchProcesses(),
          ),
        ],
      ),
      body: _isLoading && _tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Live Country IP & Network Usage Dashboard Card
                _buildNetworkCountryBanner(context, isDark, borderColor, geo, resSnapshot),

                // 2. Live Resource Top Gauge Banner
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161A24) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
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
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _autoRefresh ? const Color(0xFF10B981) : Colors.orangeAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _autoRefresh ? 'LIVE WORKLOAD MONITOR' : 'MONITOR PAUSED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppTheme.getSecondaryText(context),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_tasks.length} Active Tasks • $_curCpuFreq',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CPU Utilization', style: TextStyle(fontSize: 10, color: AppTheme.getSecondaryText(context))),
                                const SizedBox(height: 1),
                                Text(
                                  '${_totalCpuLoad.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _totalCpuLoad > 75 ? Colors.redAccent : (_totalCpuLoad > 40 ? Colors.orangeAccent : const Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('User Apps', style: TextStyle(fontSize: 10, color: AppTheme.getSecondaryText(context))),
                                const SizedBox(height: 1),
                                Text(
                                  '${_tasks.where((t) => t.category == 'User App').length}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.blueAccent),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Daemons / OS', style: TextStyle(fontSize: 10, color: AppTheme.getSecondaryText(context))),
                                const SizedBox(height: 1),
                                Text(
                                  '${_tasks.where((t) => t.category == 'System Service').length}',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Search and Sort Filter Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1F2C) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Search PID, app name, user...',
                              hintStyle: TextStyle(fontSize: 11, color: AppTheme.getSecondaryText(context)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 16),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sort Dropdown Selector
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1F2C) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                            items: ['CPU', 'RAM', 'Speed', 'I/O & Net', 'PID', 'Name'].map((s) {
                              return DropdownMenuItem<String>(
                                value: s,
                                child: Text('Sort: $s'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _sortBy = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Horizontal Category Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: SizedBox(
                    height: 28,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, idx) {
                        final cat = categories[idx];
                        final isSel = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: 10.5, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600)),
                          selected: isSel,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // 5. Scrollable Process List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No matching processes found',
                            style: TextStyle(color: AppTheme.getSecondaryText(context), fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final task = filtered[index];
                            return _buildTaskTile(context, task, isDark, borderColor);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildNetworkCountryBanner(
    BuildContext context,
    bool isDark,
    Color borderColor,
    NetworkGeoInfo? geo,
    ResourceTelemetrySnapshot res,
  ) {
    final flag = geo?.countryFlag ?? '🌐';
    final country = geo != null && geo.isOnline ? '${geo.country} (${geo.countryCode})' : 'Local Network';
    final pubIp = geo?.publicIp ?? 'Offline';
    final isp = geo?.isp ?? 'Unknown Provider';
    final localIp = geo?.localIp ?? '127.0.0.1';
    final iface = geo?.activeInterface ?? 'lo';

    final rxSpeed = res.networkRxSpeedKb.toStringAsFixed(1);
    final txSpeed = res.networkTxSpeedKb.toStringAsFixed(1);
    final totalRxMb = (res.totalRxBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalTxMb = (res.totalTxBytes / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131722) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Country & Public IP column
              Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            country,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: (geo?.isOnline == true ? const Color(0xFF10B981) : Colors.orangeAccent).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pubIp,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w800,
                                color: geo?.isOnline == true ? const Color(0xFF10B981) : Colors.orangeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$isp • $localIp ($iface)',
                        style: TextStyle(fontSize: 10, color: AppTheme.getSecondaryText(context)),
                      ),
                    ],
                  ),
                ],
              ),
              // Live Network Speed readout
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFF06B6D4)),
                      Text(
                        '$rxSpeed KB/s',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF06B6D4)),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFF3B82F6)),
                      Text(
                        '$txSpeed KB/s',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Sub-row: Cumulative Traffic & Latency
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Volume: ↓ $totalRxMb MB • ↑ $totalTxMb MB',
                style: TextStyle(fontSize: 9.5, color: AppTheme.getSecondaryText(context), fontFamily: 'monospace'),
              ),
              if (geo?.pingLatencyMs != null)
                Text(
                  'Ping RTT: ${geo!.pingLatencyMs!.toStringAsFixed(1)} ms',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981), fontFamily: 'monospace'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, TaskItem task, bool isDark, Color borderColor) {
    final isRunning = task.state == 'R';
    final isZombie = task.state == 'Z';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A24) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        onTap: () => _showTaskDetails(task),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            // Category Icon / State Badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (isRunning ? const Color(0xFF10B981) : (isZombie ? Colors.redAccent : Colors.blueAccent)).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                task.category == 'User App'
                    ? Icons.apps_rounded
                    : (task.category == 'Kernel Thread' ? Icons.settings_suggest_rounded : Icons.terminal_rounded),
                size: 20,
                color: isRunning ? const Color(0xFF10B981) : (isZombie ? Colors.redAccent : Colors.blueAccent),
              ),
            ),
            const SizedBox(width: 10),

            // Process Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.args,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222836) : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PID ${task.pid}',
                          style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        task.user,
                        style: TextStyle(fontSize: 10.5, color: AppTheme.getSecondaryText(context), fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(fontSize: 9, color: AppTheme.getSecondaryText(context))),
                      const SizedBox(width: 6),
                      Text(
                        'State: ${task.state}',
                        style: TextStyle(fontSize: 10.5, color: isRunning ? const Color(0xFF10B981) : AppTheme.getSecondaryText(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Columns: Speed, CPU %, RAM & I/O
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speed column pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        task.speed,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.blueAccent,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // CPU % badge
                    if (task.cpuPct > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (task.cpuPct > 20 ? Colors.redAccent : const Color(0xFF10B981)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${task.cpuPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: task.cpuPct > 20 ? Colors.redAccent : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // I/O & Memory column
                    Text(
                      task.res,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.ioSpeed,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.purpleAccent, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Kill task button
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
              tooltip: 'Terminate Process',
              onPressed: () => _killProcess(task),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(TaskItem task) async {
    final runner = ref.read(commandRunnerProvider);
    final oomScore = await runner.runCommand('cat /proc/${task.pid}/oom_score_adj 2>/dev/null');
    final cmdline = await runner.runCommand('cat /proc/${task.pid}/cmdline 2>/dev/null');
    final ioStats = await runner.runCommand('cat /proc/${task.pid}/io 2>/dev/null');
    final sockCount = await runner.runCommand('ls -l /proc/${task.pid}/fd 2>/dev/null | grep socket | wc -l');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF11141B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.args,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.stop_circle_rounded, size: 16, color: Colors.white),
                      label: const Text('Kill Task', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _killProcess(task);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildDetailRow('Process ID (PID)', '${task.pid}'),
                _buildDetailRow('Owner / User', task.user),
                _buildDetailRow('Category', task.category),
                _buildDetailRow('State', '${task.state} (${_decodeState(task.state)})'),
                _buildDetailRow('CPU Load', '${task.cpuPct.toStringAsFixed(1)}%'),
                _buildDetailRow('Clock Speed', task.speed),
                _buildDetailRow('Resident Memory (RES)', task.res),
                _buildDetailRow('Virtual Memory (VIRT)', task.virt),
                _buildDetailRow('Shared Memory (SHR)', task.shr),
                _buildDetailRow('CPU Time Elapsed', task.time),
                _buildDetailRow('Priority / Nice', 'PR: ${task.pr} • NI: ${task.ni}'),
                if (sockCount.trim().isNotEmpty && sockCount.trim() != '0')
                  _buildDetailRow('Active Sockets', '${sockCount.trim()} network socket handles'),
                if (ioStats.trim().isNotEmpty) ...[
                  const Divider(height: 16),
                  Text('REAL PROCESS I/O STATISTICS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppTheme.getSecondaryText(context))),
                  const SizedBox(height: 6),
                  for (final l in ioStats.split('\n'))
                    if (l.contains(':'))
                      _buildDetailRow(l.split(':')[0].trim(), l.split(':')[1].trim()),
                  const Divider(height: 16),
                ],
                _buildDetailRow('OOM Score Adj', oomScore.trim().isNotEmpty ? oomScore.trim() : 'N/A'),
                if (cmdline.trim().isNotEmpty)
                  _buildDetailRow('Command Line', cmdline.replaceAll('\x00', ' ').trim()),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Details'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: 'PID: ${task.pid}\nName: ${task.args}\nUser: ${task.user}\nRES: ${task.res}\nSpeed: ${task.speed}\nCPU: ${task.cpuPct}%'));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Process details copied!')));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  String _decodeState(String s) {
    switch (s) {
      case 'R': return 'Running';
      case 'S': return 'Sleeping (Interruptible)';
      case 'D': return 'Disk Sleep (Uninterruptible I/O)';
      case 'Z': return 'Zombie (Terminated)';
      case 'T': return 'Stopped / Traced';
      default: return 'Active';
    }
  }

  int _parseResBytes(String raw) {
    final u = raw.toUpperCase().trim();
    if (u.endsWith('G')) {
      return ((double.tryParse(u.replaceAll('G', '')) ?? 0) * 1024 * 1024 * 1024).toInt();
    }
    if (u.endsWith('M')) {
      return ((double.tryParse(u.replaceAll('M', '')) ?? 0) * 1024 * 1024).toInt();
    }
    if (u.endsWith('K')) {
      return ((double.tryParse(u.replaceAll('K', '')) ?? 0) * 1024).toInt();
    }
    final intVal = int.tryParse(u) ?? 0;
    // On toybox top, raw numeric RSS is reported in kilobytes
    return intVal * 1024;
  }
}
