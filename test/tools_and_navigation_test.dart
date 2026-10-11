import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toolbox/screens/command_result_screen.dart';
import 'package:toolbox/screens/settings_screen.dart';
import 'package:toolbox/screens/tools_screen.dart';
import 'package:toolbox/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('ToolsScreen Widget Tests', () {
    testWidgets('ToolsScreen renders header and all 5 utility cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const ProviderScope(
            child: Scaffold(
              body: ToolsScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DAILY UTILITIES'), findsOneWidget);
      expect(find.text('Interactive Toolkit'), findsOneWidget);
      expect(find.text('ADB Toolkit'), findsOneWidget);
      expect(find.text('Fastboot Toolkit'), findsOneWidget);
      expect(find.text('HANDY TOOLS'), findsOneWidget);

      expect(find.text('Spirit Bubble Level'), findsOneWidget);
      expect(find.text('Screen Ruler'), findsOneWidget);
      expect(find.text('Screen Flashlight'), findsOneWidget);
      expect(find.text('Precision Stopwatch'), findsOneWidget);
      expect(find.text('Whiteboard Canvas'), findsOneWidget);
    });
  });

  group('SettingsScreen and Dark Mode Toggle Tests', () {
    testWidgets('SettingsScreen renders appearance section and toggles switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PREFERENCES & SYSTEM'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('APPEARANCE & DISPLAY'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Verify initial switch state
      final Switch initialSwitch = tester.widget(switchFinder);
      expect(initialSwitch.value, isFalse);

      // Toggle switch
      await tester.tap(switchFinder);
      await tester.pump(const Duration(milliseconds: 300));

      final Switch toggledSwitch = tester.widget(switchFinder);
      expect(toggledSwitch.value, isTrue);
    });
  });

  group('CommandResultScreen Telemetry & Tabs Tests', () {
    testWidgets('CommandResultScreen renders metrics and navigates across tabs', (WidgetTester tester) async {
      const mockCommandOutput = '''
Hardware: Qualcomm Snapdragon 8 Gen 2
Cores: 8 Cores
Architecture: ARMv8-A
Governor: schedutil
Frequency: 3.2 GHz
''';

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const CommandResultScreen(
              title: 'SoC Architecture Report',
              commandOutput: mockCommandOutput,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify header and initial Overview tab
      expect(find.text('SoC Architecture Report'), findsWidgets);
      expect(find.text('OPTIMAL HEALTH STATUS'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Detailed Metrics'), findsOneWidget);
      expect(find.text('System Health'), findsOneWidget);
      expect(find.text('KEY TELEMETRY SUMMARY'), findsOneWidget);

      // Tap 'Detailed Metrics' tab
      await tester.tap(find.text('Detailed Metrics'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('GRANULAR PARAMETERS'), findsOneWidget);
      expect(find.text('SUBSYSTEM TELEMETRY DUMP'), findsOneWidget);

      // Tap 'System Health' tab
      await tester.tap(find.text('System Health'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hardware Integrity Score'), findsOneWidget);
      expect(find.text('98%'), findsOneWidget);
      expect(find.text('HEALTH CHECKS & VERIFICATIONS'), findsOneWidget);
      expect(find.text('Thermal Throttling Protection'), findsOneWidget);
    });
  });
}
