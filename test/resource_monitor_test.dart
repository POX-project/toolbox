import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toolbox/services/resource_monitor_service.dart';
import 'package:toolbox/widgets/charts/live_sparkline_chart.dart';
import 'package:toolbox/widgets/charts/live_ring_gauge.dart';
import 'package:toolbox/widgets/charts/resource_usage_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('ResourceTelemetrySnapshot Tests', () {
    test('initial factory produces valid non-null baseline snapshot', () {
      final snapshot = ResourceTelemetrySnapshot.initial();
      expect(snapshot.cpuUsagePercent, 0.0);
      expect(snapshot.ramUsagePercent, 0.0);
      expect(snapshot.ramTotalGb, 8.0);
      expect(snapshot.storageTotalGb, 128.0);
      expect(snapshot.batteryLevel, 100);
      expect(snapshot.isCharging, isFalse);
      expect(snapshot.networkRxSpeedKb, 0.0);
      expect(snapshot.networkTxSpeedKb, 0.0);
      expect(snapshot.timestamp, isNotNull);
    });

    test('custom snapshot holds exact values correctly', () {
      final now = DateTime.now();
      final snapshot = ResourceTelemetrySnapshot(
        cpuUsagePercent: 42.5,
        ramUsagePercent: 68.2,
        ramUsedGb: 5.4,
        ramTotalGb: 8.0,
        storageUsagePercent: 45.0,
        storageUsedGb: 57.6,
        storageTotalGb: 128.0,
        batteryLevel: 85,
        isCharging: true,
        batteryTemp: 31.4,
        networkRxSpeedKb: 254.8,
        networkTxSpeedKb: 48.2,
        totalRxBytes: 1048576,
        totalTxBytes: 524288,
        timestamp: now,
      );

      expect(snapshot.cpuUsagePercent, 42.5);
      expect(snapshot.ramUsagePercent, 68.2);
      expect(snapshot.ramUsedGb, 5.4);
      expect(snapshot.ramTotalGb, 8.0);
      expect(snapshot.storageUsagePercent, 45.0);
      expect(snapshot.batteryLevel, 85);
      expect(snapshot.isCharging, isTrue);
      expect(snapshot.batteryTemp, 31.4);
      expect(snapshot.networkRxSpeedKb, 254.8);
      expect(snapshot.networkTxSpeedKb, 48.2);
      expect(snapshot.timestamp, now);
    });
  });

  group('ResourceMonitorService Tests', () {
    test('Service starts with empty history and emits valid snapshots', () async {
      final service = ResourceMonitorService(autoStart: false);
      addTearDown(service.dispose);

      expect(service.history, isEmpty);

      // Trigger synthetic sample manually
      await service.sampleNow();

      expect(service.history.length, 1);
      final first = service.history.first;
      expect(first.cpuUsagePercent, greaterThanOrEqualTo(0.0));
      expect(first.ramTotalGb, greaterThan(0.0));
    });

    test('Service bounds history to maxHistorySize (60 points)', () async {
      final service = ResourceMonitorService(autoStart: false);
      addTearDown(service.dispose);

      for (int i = 0; i < 75; i++) {
        await service.sampleNow();
      }

      expect(service.history.length, ResourceMonitorService.maxHistorySize);
      expect(service.history.length, 60);
    });

    test('ProviderContainer exposes live resource providers correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final snapshot = container.read(latestResourceSnapshotProvider);
      expect(snapshot, isNotNull);
      expect(snapshot.cpuUsagePercent, greaterThanOrEqualTo(0.0));

      final history = container.read(resourceHistoryProvider);
      expect(history, isNotNull);
    });
  });

  group('Chart Widgets Rendering Tests', () {
    testWidgets('LiveSparklineChart renders with data points without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 100,
              child: LiveSparklineChart(
                dataPoints: [10, 25, 40, 15, 60, 80, 45, 90],
                minY: 0,
                maxY: 100,
                lineColor: Colors.blue,
                showGradient: true,
                showLiveDot: true,
                showGridLines: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LiveSparklineChart), findsOneWidget);
    });

    testWidgets('LiveSparklineChart renders empty data points gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 100,
              child: LiveSparklineChart(
                dataPoints: [],
                minY: 0,
                maxY: 100,
                lineColor: Colors.teal,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LiveSparklineChart), findsOneWidget);
    });

    testWidgets('LiveRingGauge renders arc and center text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 150,
              child: LiveRingGauge(
                value: 75.0,
                centerValue: '75%',
                label: 'CPU LOAD',
                activeColor: Colors.orange,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LiveRingGauge), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('CPU LOAD'), findsOneWidget);
    });

    testWidgets('ResourceUsageCard renders title, primary metric, and min/avg/peak stats', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ResourceUsageCard(
                title: 'CPU Workload',
                tag: 'PROCESSOR',
                icon: Icons.memory_rounded,
                accentColor: const Color(0xFF6366F1),
                primaryValue: '48.5%',
                secondaryValue: 'Dynamic Kernel Load',
                historyPoints: const [20, 35, 50, 40, 60, 48.5],
                minY: 0,
                maxY: 100,
                minLabel: '20%',
                avgLabel: '42%',
                maxLabel: '60%',
              ),
            ),
          ),
        ),
      );

      expect(find.text('CPU Workload'), findsOneWidget);
      expect(find.text('PROCESSOR'), findsOneWidget);
      expect(find.text('48.5%'), findsOneWidget);
      expect(find.text('Dynamic Kernel Load'), findsOneWidget);
      expect(find.text('MIN'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('AVG'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('PEAK'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });
  });
}
