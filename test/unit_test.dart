import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toolbox/providers/theme_provider.dart';
import 'package:toolbox/services/command_runner.dart';
import 'package:toolbox/services/info_service.dart';
import 'package:toolbox/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('ThemeNotifier and ThemeState Unit Tests', () {
    test('ThemeState default has isDarkMode false', () {
      const state = ThemeState();
      expect(state.isDarkMode, isFalse);
    });

    test('ThemeState copyWith updates isDarkMode', () {
      const state = ThemeState();
      final updated = state.copyWith(isDarkMode: true);
      expect(updated.isDarkMode, isTrue);

      final unchanged = updated.copyWith();
      expect(unchanged.isDarkMode, isTrue);
    });

    test('ThemeNotifier toggles dark mode correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeProvider).isDarkMode, isFalse);

      container.read(themeProvider.notifier).toggleDarkMode(true);
      expect(container.read(themeProvider).isDarkMode, isTrue);

      container.read(themeProvider.notifier).toggleDarkMode(false);
      expect(container.read(themeProvider).isDarkMode, isFalse);
    });
  });

  group('PrivilegeStatus Metadata Tests', () {
    test('PrivilegeStatus enum attributes are well-formed', () {
      expect(PrivilegeStatus.root.hasPrivilege, isTrue);
      expect(PrivilegeStatus.root.label, 'Root Access');
      expect(PrivilegeStatus.root.description, contains('Full system privilege'));

      expect(PrivilegeStatus.shizuku.hasPrivilege, isTrue);
      expect(PrivilegeStatus.shizuku.label, 'Shizuku Service');
      expect(PrivilegeStatus.shizuku.description, contains('ADB shell privilege'));

      expect(PrivilegeStatus.standard.hasPrivilege, isFalse);
      expect(PrivilegeStatus.standard.label, 'Standard Mode');
      expect(PrivilegeStatus.standard.description, contains('sandboxed'));
    });
  });

  group('CommandRunner Resilience Tests', () {
    test('isShizukuAvailable returns boolean without throwing', () async {
      final runner = CommandRunner();
      final result = await runner.isShizukuAvailable();
      expect(result, isA<bool>());
    });

    test('isRootAvailable returns boolean without throwing', () async {
      final runner = CommandRunner();
      final result = await runner.isRootAvailable();
      expect(result, isA<bool>());
    });

    test('getPrivilegeStatus returns valid PrivilegeStatus without throwing', () async {
      final runner = CommandRunner();
      final status = await runner.getPrivilegeStatus();
      expect(PrivilegeStatus.values, contains(status));
    });

    test('runCommand executes safely with fallback', () async {
      final runner = CommandRunner();
      final output = await runner.runCommand('echo "test_runner"');
      expect(output, isA<String>());
      expect(output.isNotEmpty, isTrue);
    });
  });

  group('InfoService Platform Safety Tests', () {
    test('getCpuInfo returns valid map with cores or platform info', () async {
      final infoService = InfoService();
      final cpuInfo = await infoService.getCpuInfo();
      expect(cpuInfo, isA<Map<String, String>>());
      expect(cpuInfo.isNotEmpty, isTrue);
    });

    test('getMemInfo returns valid memory telemetry or platform note', () async {
      final infoService = InfoService();
      final memInfo = await infoService.getMemInfo();
      expect(memInfo, isA<Map<String, String>>());
      expect(memInfo.isNotEmpty, isTrue);
    });

    test('getGpuInfo returns renderer and vendor information', () async {
      final infoService = InfoService();
      final gpuInfo = await infoService.getGpuInfo();
      expect(gpuInfo, isA<Map<String, String>>());
      expect(gpuInfo.containsKey('Renderer'), isTrue);
      expect(gpuInfo.containsKey('Vendor'), isTrue);
    });

    test('getStorageInfo returns storage telemetry or fallback', () async {
      final infoService = InfoService();
      final storageInfo = await infoService.getStorageInfo();
      expect(storageInfo, isA<Map<String, String>>());
      expect(storageInfo.isNotEmpty, isTrue);
    });

    test('getNetworkInfo returns telemetry and handles network_info_plus gracefully', () async {
      final mockRunner = CommandRunner();
      final infoService = InfoService(mockRunner);
      final networkInfo = await infoService.getNetworkInfo();
      expect(networkInfo, isA<Map<String, String>>());
      expect(networkInfo.containsKey('Active Interface'), isTrue);
    });
  });

  group('AppTheme Theming Configuration Tests', () {
    test('lightTheme has Light Brightness and expected colors', () {
      final theme = AppTheme.lightTheme();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppTheme.background);
      expect(theme.colorScheme.surface, AppTheme.surface);
    });

    test('darkTheme has Dark Brightness and obsidian colors', () {
      final theme = AppTheme.darkTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppTheme.darkBackground);
      expect(theme.colorScheme.surface, AppTheme.darkSurface);
      expect(theme.cardTheme.color, AppTheme.darkSurface);
    });

    test('monoStyle creates typography with JetBrainsMono', () {
      final style = AppTheme.monoStyle(fontSize: 14, fontWeight: FontWeight.bold);
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('secondaryText and darkSecondaryText meet high-contrast palette values', () {
      expect(AppTheme.secondaryText, const Color(0xFF4B5563));
      expect(AppTheme.darkSecondaryText, const Color(0xFF9CA3AF));
    });
  });
}
