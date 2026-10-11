import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shizuku_api/shizuku_api.dart';

enum PrivilegeStatus {
  root('Root Access', 'Full system privilege active', true),
  shizuku('Shizuku Service', 'ADB shell privilege active', true),
  standard('Standard Mode', 'Running with sandboxed permissions', false);

  final String label;
  final String description;
  final bool hasPrivilege;
  const PrivilegeStatus(this.label, this.description, this.hasPrivilege);
}

enum PrivilegeModePreference {
  auto('Automatic (Recommended)', 'Auto-detect highest available privilege (Root > Shizuku > Standard)'),
  root('Root Access', 'Force execution using SU root binary'),
  shizuku('Shizuku Service', 'Force execution via Shizuku ADB binder IPC'),
  standard('Standard Sandboxed', 'Simulate standard unprivileged shell execution');

  final String label;
  final String description;
  const PrivilegeModePreference(this.label, this.description);
}

final privilegeModePreferenceProvider = StateProvider<PrivilegeModePreference>((ref) => PrivilegeModePreference.auto);

final commandRunnerProvider = Provider((ref) => CommandRunner());

final privilegeStatusProvider = FutureProvider<PrivilegeStatus>((ref) async {
  final runner = ref.watch(commandRunnerProvider);
  final pref = ref.watch(privilegeModePreferenceProvider);
  return await runner.getPrivilegeStatus(preference: pref);
});

class CommandRunner {
  final _shizuku = ShizukuApi();
  PrivilegeModePreference activePreference = PrivilegeModePreference.auto;

  Future<bool> isShizukuAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      final isRunning = await _shizuku.pingBinder();
      if (isRunning != true) return false;

      final hasPermission = await _shizuku.checkPermission();
      if (hasPermission == true) return true;

      final granted = await _shizuku.requestPermission();
      return granted ?? false;
    } catch (e) {
      return false;
    }
  }

  String? _resolvedSuPath;

  Future<String?> _findSuBinary() async {
    if (_resolvedSuPath != null) return _resolvedSuPath;
    final candidates = [
      'su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/adb/ap/bin/su',
      '/data/adb/ksu/bin/su',
      '/data/adb/magisk/su',
    ];
    for (final candidate in candidates) {
      try {
        final result = await Process.run(candidate, ['-c', 'id']);
        final out = result.stdout.toString();
        if (out.contains('uid=0') || out.contains('root')) {
          _resolvedSuPath = candidate;
          return candidate;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> isRootAvailable() async {
    if (!Platform.isAndroid && !Platform.isLinux) return false;
    final su = await _findSuBinary();
    return su != null;
  }

  Future<PrivilegeStatus> getPrivilegeStatus({PrivilegeModePreference? preference}) async {
    final pref = preference ?? activePreference;
    activePreference = pref;

    switch (pref) {
      case PrivilegeModePreference.standard:
        return PrivilegeStatus.standard;
      case PrivilegeModePreference.shizuku:
        if (await isShizukuAvailable()) return PrivilegeStatus.shizuku;
        return PrivilegeStatus.standard;
      case PrivilegeModePreference.root:
        if (await isRootAvailable()) return PrivilegeStatus.root;
        // If user explicitly chose root, attempt root execution so superuser manager can prompt
        return PrivilegeStatus.root;
      case PrivilegeModePreference.auto:
        if (await isRootAvailable()) {
          return PrivilegeStatus.root;
        }
        if (await isShizukuAvailable()) {
          return PrivilegeStatus.shizuku;
        }
        return PrivilegeStatus.standard;
    }
  }

  Future<String> runCommand(String command, {PrivilegeModePreference? preference}) async {
    final status = await getPrivilegeStatus(preference: preference);
    if (status == PrivilegeStatus.root) {
      try {
        final suBin = _resolvedSuPath ?? 'su';
        final result = await Process.run(suBin, ['-c', command]);
        final out = '${result.stdout}${result.stderr}'.trim();
        return out;
      } catch (e) {
        return 'Root Execution Error: $e';
      }
    } else if (status == PrivilegeStatus.shizuku) {
      try {
        // Execute via privileged Shizuku binder IPC
        final shizukuOut = await _shizuku.runCommand(command);
        if (shizukuOut != null && shizukuOut.trim().isNotEmpty) {
          return shizukuOut.trim();
        }
        // Fallback to local shell process if Shizuku binder returns null
        final result = await Process.run('sh', ['-c', command]);
        final out = '${result.stdout}${result.stderr}'.trim();
        return out;
      } catch (e) {
        return 'Shizuku Execution Error: $e';
      }
    } else {
      // Run as standard shell user
      try {
        final result = await Process.run('sh', ['-c', command]);
        final out = '${result.stdout}${result.stderr}'.trim();
        return out;
      } catch (e) {
        return 'Standard Shell Error: $e';
      }
    }
  }
}
