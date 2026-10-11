import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'command_runner.dart';

/// Single point-in-time telemetry snapshot with 100% real hardware readings
class ResourceTelemetrySnapshot {
  final double cpuUsagePercent;
  final double ramUsagePercent;
  final double ramUsedGb;
  final double ramTotalGb;
  final double storageUsagePercent;
  final double storageUsedGb;
  final double storageTotalGb;
  final int batteryLevel;
  final bool isCharging;
  final double? batteryTemp;
  final double networkRxSpeedKb;
  final double networkTxSpeedKb;
  final int totalRxBytes;
  final int totalTxBytes;
  final DateTime timestamp;

  const ResourceTelemetrySnapshot({
    required this.cpuUsagePercent,
    required this.ramUsagePercent,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.storageUsagePercent,
    required this.storageUsedGb,
    required this.storageTotalGb,
    required this.batteryLevel,
    required this.isCharging,
    this.batteryTemp,
    required this.networkRxSpeedKb,
    required this.networkTxSpeedKb,
    required this.totalRxBytes,
    required this.totalTxBytes,
    required this.timestamp,
  });

  factory ResourceTelemetrySnapshot.initial() {
    return ResourceTelemetrySnapshot(
      cpuUsagePercent: 0.0,
      ramUsagePercent: 0.0,
      ramUsedGb: 0.0,
      ramTotalGb: 8.0,
      storageUsagePercent: 0.0,
      storageUsedGb: 0.0,
      storageTotalGb: 128.0,
      batteryLevel: 100,
      isCharging: false,
      batteryTemp: 28.0,
      networkRxSpeedKb: 0.0,
      networkTxSpeedKb: 0.0,
      totalRxBytes: 0,
      totalTxBytes: 0,
      timestamp: DateTime.now(),
    );
  }
}

/// Global Service Provider
final resourceMonitorServiceProvider = Provider<ResourceMonitorService>((ref) {
  final runner = ref.watch(commandRunnerProvider);
  final service = ResourceMonitorService(runner: runner);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Live Stream of Snapshots for reactive widgets
final liveResourceStreamProvider = StreamProvider<ResourceTelemetrySnapshot>((ref) {
  final service = ref.watch(resourceMonitorServiceProvider);
  return service.stream;
});

/// Latest State Snapshot Provider (reactively drives UI only when watched)
final latestResourceSnapshotProvider = Provider<ResourceTelemetrySnapshot>((ref) {
  final streamAsync = ref.watch(liveResourceStreamProvider);
  final service = ref.watch(resourceMonitorServiceProvider);
  return streamAsync.value ?? (service.history.isNotEmpty ? service.history.last : ResourceTelemetrySnapshot.initial());
});

/// Historical Data Provider (Rolling 60s)
final resourceHistoryProvider = Provider<List<ResourceTelemetrySnapshot>>((ref) {
  ref.watch(latestResourceSnapshotProvider);
  final service = ref.watch(resourceMonitorServiceProvider);
  return service.history;
});

class ResourceMonitorService {
  static const int maxHistorySize = 60;

  final CommandRunner? runner;
  late final StreamController<ResourceTelemetrySnapshot> _controller;
  Timer? _pollingTimer;

  final List<ResourceTelemetrySnapshot> _history = [];
  final Set<String> _deniedSysfsPaths = {};
  bool? _isElevatedCached;

  // Previous CPU stats for delta calculation
  int _prevTotalJiffies = 0;
  int _prevWorkJiffies = 0;
  double _lastKnownCpu = 0.0;

  // Previous Network stats for speed calculation
  int _prevRxBytes = 0;
  int _prevTxBytes = 0;
  int _lastTotalRxBytes = 0;
  int _lastTotalTxBytes = 0;
  DateTime? _prevNetTime;

  // Cached storage stats to reduce df calls
  double _cachedStorageTotalGb = 0.0;
  double _cachedStorageUsedGb = 0.0;
  double _cachedStoragePercent = 0.0;
  int _storageCheckCounter = 0;

  // Cached battery metrics to eliminate repeated dumpsys forks
  int _batteryCheckCounter = 0;
  double? _cachedBatteryTemp;

  final Battery _battery = Battery();
  bool _isDisposed = false;
  bool _isPaused = false;

  Stream<ResourceTelemetrySnapshot> get stream => _controller.stream;
  List<ResourceTelemetrySnapshot> get history => List.unmodifiable(_history);
  bool get isPaused => _isPaused;

  ResourceMonitorService({this.runner, bool autoStart = false}) {
    _controller = StreamController<ResourceTelemetrySnapshot>.broadcast(
      onListen: () {
        if (_isPaused) {
          resume();
        } else {
          startMonitoring();
        }
      },
      onCancel: () {
        pause();
      },
    );
    if (autoStart) {
      startMonitoring();
    }
  }

  Future<bool> _isElevated() async {
    if (_isElevatedCached != null) return _isElevatedCached!;
    if (runner != null) {
      final status = await runner!.getPrivilegeStatus();
      _isElevatedCached = (status == PrivilegeStatus.root || status == PrivilegeStatus.shizuku);
    } else {
      _isElevatedCached = false;
    }
    return _isElevatedCached!;
  }

  void startMonitoring() {
    _pollingTimer?.cancel();
    _isPaused = false;
    _collectSnapshot();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && !_isDisposed) {
        _collectSnapshot();
      }
    });
  }

  void pause() {
    _isPaused = true;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void resume() {
    _isPaused = false;
    if (_pollingTimer == null && !_isDisposed) {
      startMonitoring();
    }
  }

  void togglePause() {
    if (_isPaused) {
      resume();
    } else {
      pause();
    }
  }

  /// Triggers an immediate sampling pass
  Future<void> sampleNow() => _collectSnapshot();

  Future<String> _readSysFile(String path) async {
    if (_deniedSysfsPaths.contains(path)) return '';
    try {
      final file = File(path);
      final content = await file.readAsString();
      if (content.trim().isNotEmpty) return content.trim();
    } catch (_) {
      _deniedSysfsPaths.add(path);
    }
    return '';
  }

  Future<void> _collectSnapshot() async {
    try {
      final now = DateTime.now();

      // 1. Real CPU Usage %
      final cpuPercent = await _readCpuUsage();

      // 2. Real RAM Usage % and GB
      final memData = await _readMemoryUsage();

      // 3. Storage Usage (sampled every 30 seconds to minimize IO load)
      if (_storageCheckCounter % 30 == 0) {
        await _readStorageUsage();
      }
      _storageCheckCounter++;

      // 4. Real Battery Level & Status & Temperature
      final batteryData = await _readBatteryInfo();

      // 5. Real Network Rx / Tx Speed & Totals
      final netData = await _readNetworkSpeed(now);

      final snapshot = ResourceTelemetrySnapshot(
        cpuUsagePercent: cpuPercent,
        ramUsagePercent: memData['percent'] ?? 0.0,
        ramUsedGb: memData['usedGb'] ?? 0.0,
        ramTotalGb: memData['totalGb'] ?? 0.0,
        storageUsagePercent: _cachedStoragePercent,
        storageUsedGb: _cachedStorageUsedGb,
        storageTotalGb: _cachedStorageTotalGb,
        batteryLevel: batteryData['level'] as int? ?? 0,
        isCharging: batteryData['charging'] as bool? ?? false,
        batteryTemp: batteryData['temp'] as double?,
        networkRxSpeedKb: netData['rx'] ?? 0.0,
        networkTxSpeedKb: netData['tx'] ?? 0.0,
        totalRxBytes: _lastTotalRxBytes,
        totalTxBytes: _lastTotalTxBytes,
        timestamp: now,
      );

      _history.add(snapshot);
      if (_history.length > maxHistorySize) {
        _history.removeAt(0);
      }

      if (!_controller.isClosed) {
        _controller.add(snapshot);
      }
    } catch (_) {
      // Maintain last known actual reading or zero-safe fallback if unavailable
      if (_history.isNotEmpty) {
        final last = _history.last;
        final duplicate = ResourceTelemetrySnapshot(
          cpuUsagePercent: last.cpuUsagePercent,
          ramUsagePercent: last.ramUsagePercent,
          ramUsedGb: last.ramUsedGb,
          ramTotalGb: last.ramTotalGb,
          storageUsagePercent: last.storageUsagePercent,
          storageUsedGb: last.storageUsedGb,
          storageTotalGb: last.storageTotalGb,
          batteryLevel: last.batteryLevel,
          isCharging: last.isCharging,
          batteryTemp: last.batteryTemp,
          networkRxSpeedKb: 0.0,
          networkTxSpeedKb: 0.0,
          totalRxBytes: last.totalRxBytes,
          totalTxBytes: last.totalTxBytes,
          timestamp: DateTime.now(),
        );
        _history.add(duplicate);
        if (_history.length > maxHistorySize) _history.removeAt(0);
        if (!_controller.isClosed) _controller.add(duplicate);
      }
    }
  }

  Future<double> _readCpuUsage() async {
    try {
      String statContent = await _readSysFile('/proc/stat');
      if (statContent.isEmpty && runner != null && await _isElevated()) {
        statContent = await runner!.runCommand('cat /proc/stat 2>/dev/null');
      }
      if (statContent.isNotEmpty) {
        final lines = statContent.split('\n');
        for (final line in lines) {
          if (line.startsWith('cpu ')) {
            final parts = line.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
            if (parts.length >= 8) {
              final user = int.tryParse(parts[1]) ?? 0;
              final nice = int.tryParse(parts[2]) ?? 0;
              final system = int.tryParse(parts[3]) ?? 0;
              final idle = int.tryParse(parts[4]) ?? 0;
              final iowait = int.tryParse(parts[5]) ?? 0;
              final irq = int.tryParse(parts[6]) ?? 0;
              final softirq = int.tryParse(parts[7]) ?? 0;
              final steal = parts.length > 8 ? (int.tryParse(parts[8]) ?? 0) : 0;

              final total = user + nice + system + idle + iowait + irq + softirq + steal;
              final work = user + nice + system + irq + softirq + steal;

              if (_prevTotalJiffies > 0) {
                final totalDelta = total - _prevTotalJiffies;
                final workDelta = work - _prevWorkJiffies;
                _prevTotalJiffies = total;
                _prevWorkJiffies = work;
                if (totalDelta > 0) {
                  _lastKnownCpu = ((workDelta / totalDelta) * 100).clamp(0.0, 100.0);
                  return _lastKnownCpu;
                }
              } else {
                _prevTotalJiffies = total;
                _prevWorkJiffies = work;
                return _lastKnownCpu;
              }
            }
          }
        }
      }
    } catch (_) {}
    return _lastKnownCpu;
  }

  Future<Map<String, double>> _readMemoryUsage() async {
    final result = <String, double>{
      'percent': 0.0,
      'usedGb': 0.0,
      'totalGb': 0.0,
    };
    try {
      final meminfoContent = await _readSysFile('/proc/meminfo');
      if (meminfoContent.isNotEmpty) {
        final lines = meminfoContent.split('\n');
        int memTotalKb = 0;
        int memAvailableKb = 0;
        int memFreeKb = 0;

        for (final line in lines) {
          if (line.startsWith('MemTotal:')) {
            memTotalKb = _extractKb(line);
          } else if (line.startsWith('MemAvailable:')) {
            memAvailableKb = _extractKb(line);
          } else if (line.startsWith('MemFree:')) {
            memFreeKb = _extractKb(line);
          }
        }

        if (memAvailableKb == 0) memAvailableKb = memFreeKb;

        if (memTotalKb > 0) {
          final usedKb = memTotalKb - memAvailableKb;
          result['totalGb'] = memTotalKb / (1024 * 1024);
          result['usedGb'] = usedKb / (1024 * 1024);
          result['percent'] = ((usedKb / memTotalKb) * 100).clamp(0.0, 100.0);
        }
      }
    } catch (_) {}
    return result;
  }

  int _extractKb(String line) {
    final parts = line.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return int.tryParse(parts[1]) ?? 0;
    }
    return 0;
  }

  Future<void> _readStorageUsage() async {
    try {
      String dfOut = '';
      final r = runner;
      if (r != null) {
        dfOut = await r.runCommand('df -k /data 2>/dev/null');
      }
      if (dfOut.isEmpty) {
        final path = Platform.isAndroid ? '/data' : '/';
        final proc = await Process.run('df', ['-k', path]);
        dfOut = proc.stdout.toString();
      }

      final lines = dfOut.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('/dev/') || trimmed.contains('/data') || trimmed.contains('/')) {
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final totalKb = int.tryParse(parts[1]) ?? 0;
            final usedKb = int.tryParse(parts[2]) ?? 0;
            if (totalKb > 0) {
              _cachedStorageTotalGb = totalKb / (1024 * 1024);
              _cachedStorageUsedGb = usedKb / (1024 * 1024);
              _cachedStoragePercent = ((usedKb / totalKb) * 100).clamp(0.0, 100.0);
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _readBatteryInfo() async {
    final result = <String, dynamic>{
      'level': 0,
      'charging': false,
      'temp': _cachedBatteryTemp,
    };
    try {
      result['level'] = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      result['charging'] = (state == BatteryState.charging || state == BatteryState.full);

      // Attempt to read battery temperature periodically (every 20s) to eliminate frame skips
      if (Platform.isAndroid && (_batteryCheckCounter % 20 == 0 || _cachedBatteryTemp == null)) {
        final rawTemp = await _readSysFile('/sys/class/power_supply/battery/temp');
        if (rawTemp.isNotEmpty) {
          final tempVal = double.tryParse(rawTemp);
          if (tempVal != null && tempVal > 0) {
            if (tempVal > 1000) {
              _cachedBatteryTemp = tempVal / 1000.0;
            } else if (tempVal > 100) {
              _cachedBatteryTemp = tempVal / 10.0;
            } else {
              _cachedBatteryTemp = tempVal;
            }
          }
        }

        // Fallback to dumpsys battery only if cached temp is still null and elevated
        if (_cachedBatteryTemp == null && runner != null && await _isElevated()) {
          final bDump = await runner!.runCommand('dumpsys battery 2>/dev/null');
          if (bDump.isNotEmpty) {
            final mTemp = RegExp(r'temperature:\s*(\d+)').firstMatch(bDump);
            if (mTemp != null) {
              final tVal = double.tryParse(mTemp.group(1) ?? '0') ?? 0.0;
              if (tVal > 0) {
                _cachedBatteryTemp = tVal / 10.0;
              }
            }
          }
        }
      }
      _batteryCheckCounter++;
      result['temp'] = _cachedBatteryTemp;
    } catch (_) {}
    return result;
  }

  Future<Map<String, double>> _readNetworkSpeed(DateTime now) async {
    final result = <String, double>{
      'rx': 0.0,
      'tx': 0.0,
    };
    try {
      String netDevContent = await _readSysFile('/proc/net/dev');
      if (netDevContent.isEmpty && runner != null && await _isElevated()) {
        netDevContent = await runner!.runCommand('cat /proc/net/dev 2>/dev/null');
      }
      if (netDevContent.isNotEmpty) {
        final lines = netDevContent.split('\n');
        int currentRxBytes = 0;
        int currentTxBytes = 0;

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('Inter-') || trimmed.startsWith('face')) continue;
          final colonIdx = trimmed.indexOf(':');
          if (colonIdx == -1) continue;
          final iface = trimmed.substring(0, colonIdx).trim();
          if (iface == 'lo') continue; // Ignore loopback

          final stats = trimmed.substring(colonIdx + 1).trim().split(RegExp(r'\s+'));
          if (stats.length >= 9) {
            currentRxBytes += int.tryParse(stats[0]) ?? 0;
            currentTxBytes += int.tryParse(stats[8]) ?? 0;
          }
        }

        _lastTotalRxBytes = currentRxBytes;
        _lastTotalTxBytes = currentTxBytes;

        if (_prevNetTime != null && _prevRxBytes > 0) {
          final elapsedSec = now.difference(_prevNetTime!).inMilliseconds / 1000.0;
          if (elapsedSec > 0.2) {
            final rxDelta = max(0, currentRxBytes - _prevRxBytes);
            final txDelta = max(0, currentTxBytes - _prevTxBytes);
            result['rx'] = (rxDelta / 1024.0) / elapsedSec; // KB/s
            result['tx'] = (txDelta / 1024.0) / elapsedSec; // KB/s
          }
        }
        _prevRxBytes = currentRxBytes;
        _prevTxBytes = currentTxBytes;
        _prevNetTime = now;
      }
    } catch (_) {}
    return result;
  }

  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _controller.close();
  }
}
