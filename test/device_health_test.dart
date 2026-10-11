import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toolbox/models/device_health_model.dart';
import 'package:toolbox/services/command_runner.dart';
import 'package:toolbox/widgets/health/component_health_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('HealthGrade Evaluation Tests', () {
    test('HealthGrade.fromScore assigns correct grades and thresholds', () {
      expect(HealthGrade.fromScore(100), HealthGrade.aPlus);
      expect(HealthGrade.fromScore(95), HealthGrade.aPlus);
      expect(HealthGrade.fromScore(94.9), HealthGrade.a);
      expect(HealthGrade.fromScore(85), HealthGrade.a);
      expect(HealthGrade.fromScore(84.9), HealthGrade.b);
      expect(HealthGrade.fromScore(70), HealthGrade.b);
      expect(HealthGrade.fromScore(69.9), HealthGrade.c);
      expect(HealthGrade.fromScore(50), HealthGrade.c);
      expect(HealthGrade.fromScore(49.9), HealthGrade.critical);
      expect(HealthGrade.fromScore(0), HealthGrade.critical);
      expect(HealthGrade.fromScore(null), HealthGrade.undetermined);
    });

    test('HealthGrade attributes and labels are consistent', () {
      expect(HealthGrade.aPlus.label, 'A+');
      expect(HealthGrade.aPlus.status, 'Optimal');
      expect(HealthGrade.aPlus.color, const Color(0xFF10B981));

      expect(HealthGrade.a.label, 'A');
      expect(HealthGrade.a.status, 'Excellent');

      expect(HealthGrade.b.label, 'B');
      expect(HealthGrade.b.status, 'Good');

      expect(HealthGrade.c.label, 'C');
      expect(HealthGrade.c.status, 'Fair / Attention');

      expect(HealthGrade.critical.label, 'F');
      expect(HealthGrade.critical.status, 'Critical');
      expect(HealthGrade.critical.color, const Color(0xFFEF4444));

      expect(HealthGrade.undetermined.label, 'N/A');
      expect(HealthGrade.undetermined.status, 'Undetermined');
      expect(HealthGrade.undetermined.color, const Color(0xFF94A3B8));
    });
  });

  group('MetricStatus Evaluation Tests', () {
    test('MetricStatus values are well-defined', () {
      expect(MetricStatus.values, contains(MetricStatus.optimal));
      expect(MetricStatus.values, contains(MetricStatus.good));
      expect(MetricStatus.values, contains(MetricStatus.warning));
      expect(MetricStatus.values, contains(MetricStatus.critical));
      expect(MetricStatus.values, contains(MetricStatus.info));
    });
  });

  group('RawHardwareDescriptor and Data Structure Tests', () {
    test('RawHardwareDescriptor holds key, source, rawValue and interpretation', () {
      const desc = RawHardwareDescriptor(
        key: 'bPreEOLInfo',
        pathOrSource: '/sys/devices/platform/soc/1d84000.ufshc/health/bPreEOLInfo',
        rawValue: '0x01 (Normal)',
        interpretation: 'Overall flash wear is below 80% consumed. Normal device lifetime remaining.',
      );

      expect(desc.key, 'bPreEOLInfo');
      expect(desc.pathOrSource, contains('1d84000.ufshc'));
      expect(desc.rawValue, contains('0x01'));
      expect(desc.interpretation, contains('80%'));
    });

    test('ComponentHealth computes and exposes properties correctly', () {
      const comp = ComponentHealth(
        id: 'ufs',
        name: 'UFS / Flash Storage',
        category: 'Non-Volatile NAND Memory',
        icon: Icons.storage_rounded,
        score: 92.0,
        grade: HealthGrade.a,
        summary: 'Excellent flash endurance with minimal block wear.',
        isRootEnhanced: true,
        wearPercentage: 8.0,
        metrics: [
          HealthMetricItem(
            label: 'NAND Wear Used',
            value: '8.0%',
            status: MetricStatus.optimal,
          ),
          HealthMetricItem(
            label: 'EOL Indicator',
            value: 'Normal (bPreEOLInfo: 0x01)',
            status: MetricStatus.optimal,
          ),
        ],
        rawDescriptors: [
          RawHardwareDescriptor(
            key: 'bDeviceLifeTimeEstA',
            pathOrSource: '/sys/class/ufs/bDeviceLifeTimeEstA',
            rawValue: '0x01 (0%-10% consumed)',
            interpretation: 'Type A SLC/TLC wear estimation.',
          ),
        ],
        recommendations: [
          'Maintain at least 15% free partition space.',
        ],
      );

      expect(comp.id, 'ufs');
      expect(comp.name, 'UFS / Flash Storage');
      expect(comp.score, 92.0);
      expect(comp.wearPercentage, 8.0);
      expect(comp.grade, HealthGrade.a);
      expect(comp.metrics.length, 2);
      expect(comp.rawDescriptors.length, 1);
      expect(comp.recommendations.length, 1);
      expect(comp.isRootEnhanced, isTrue);
    });

    test('DeviceHealthReport aggregates composite score and recommendations', () {
      final report = DeviceHealthReport(
        overallScore: 88.5,
        overallGrade: HealthGrade.a,
        summary: 'Device is running at optimal health.',
        privilegeMode: 'Root Accelerated (Direct sysfs)',
        timestamp: DateTime.now(),
        components: const [
          ComponentHealth(
            id: 'storage',
            name: 'Storage Subsystem',
            category: 'UFS / Flash',
            icon: Icons.storage_rounded,
            score: 92.0,
            grade: HealthGrade.a,
            summary: 'Storage running optimal.',
            isRootEnhanced: true,
            metrics: [],
            rawDescriptors: [],
          ),
          ComponentHealth(
            id: 'cpu',
            name: 'CPU & Silicon Subsystem',
            category: 'Processor & Cores',
            icon: Icons.memory_rounded,
            score: 85.0,
            grade: HealthGrade.a,
            summary: 'CPU cores stable.',
            isRootEnhanced: false,
            metrics: [],
            rawDescriptors: [],
          ),
          ComponentHealth(
            id: 'memory',
            name: 'Memory Subsystem',
            category: 'RAM & Swap',
            icon: Icons.memory_outlined,
            score: 90.0,
            grade: HealthGrade.a,
            summary: 'Ample RAM available.',
            isRootEnhanced: false,
            metrics: [],
            rawDescriptors: [],
          ),
          ComponentHealth(
            id: 'battery',
            name: 'Battery Subsystem',
            category: 'Cell & Fuel Gauge',
            icon: Icons.battery_charging_full_rounded,
            score: 95.0,
            grade: HealthGrade.aPlus,
            summary: 'Cell voltage stable.',
            isRootEnhanced: false,
            metrics: [],
            rawDescriptors: [],
          ),
          ComponentHealth(
            id: 'thermal',
            name: 'Thermal Subsystem',
            category: 'SoC Sensors',
            icon: Icons.thermostat_rounded,
            score: 98.0,
            grade: HealthGrade.aPlus,
            summary: 'Cooling optimal.',
            isRootEnhanced: false,
            metrics: [],
            rawDescriptors: [],
          ),
          ComponentHealth(
            id: 'network',
            name: 'Network Subsystem',
            category: 'Interface & Link',
            icon: Icons.wifi_tethering_rounded,
            score: 100.0,
            grade: HealthGrade.aPlus,
            summary: 'Zero dropped packets.',
            isRootEnhanced: false,
            metrics: [],
            rawDescriptors: [],
          ),
          ComponentHealth(
            id: 'partitions',
            name: 'Partitions Subsystem',
            category: 'Flash Geometry & Inodes',
            icon: Icons.pie_chart_outline_rounded,
            score: 95.0,
            grade: HealthGrade.aPlus,
            summary: 'Partitions mounted with ample free inodes.',
            isRootEnhanced: false,
            metrics: [],
            rawDescriptors: [],
          ),
          ComponentHealth(
            id: 'system',
            name: 'System Subsystem',
            category: 'Kernel & Stability',
            icon: Icons.security_rounded,
            score: 94.0,
            grade: HealthGrade.a,
            summary: 'SELinux enforcing.',
            isRootEnhanced: false,
            metrics: [],
            rawDescriptors: [],
          ),
        ],
      );

      expect(report.overallScore, 88.5);
      expect(report.overallGrade, HealthGrade.a);
      expect(report.summary, contains('optimal'));
      expect(report.privilegeMode, contains('Root Accelerated'));
      expect(report.components.length, 8);
      expect(report.getComponent('storage')?.score, 92.0);
      expect(report.getComponent('partitions')?.score, 95.0);
      expect(report.getComponent('cpu')?.isRootEnhanced, isFalse);
      expect(report.getComponent('memory')?.score, 90.0);
      expect(report.getComponent('battery')?.score, 95.0);
      expect(report.getComponent('thermal')?.score, 98.0);
      expect(report.getComponent('network')?.score, 100.0);
      expect(report.getComponent('system')?.score, 94.0);
      expect(report.getComponent('nonexistent'), isNull);
    });

    test('DeviceHealthReport correctly handles insufficient telemetry state', () {
      final report = DeviceHealthReport(
        overallScore: null,
        overallGrade: HealthGrade.undetermined,
        summary: "We can't determine the health of your phone based on those data.",
        privilegeMode: 'Standard Unprivileged',
        timestamp: DateTime.now(),
        hasSufficientData: false,
        undeterminedReason: "Key hardware degradation telemetry (battery charge cycle wear and flash storage NAND lifespan) requires elevated privileges (Root or Shizuku) or is not exposed by this device's firmware.",
        components: const [
          ComponentHealth(
            id: 'storage',
            name: 'Storage Subsystem',
            category: 'UFS / Flash',
            icon: Icons.storage_rounded,
            score: null,
            grade: HealthGrade.undetermined,
            summary: 'NAND wear registers restricted by SELinux.',
            isRootEnhanced: false,
            hasSufficientData: false,
            metrics: [],
            rawDescriptors: [],
          ),
          ComponentHealth(
            id: 'battery',
            name: 'Battery Subsystem',
            category: 'Cell & Fuel Gauge',
            icon: Icons.battery_charging_full_rounded,
            score: null,
            grade: HealthGrade.undetermined,
            summary: 'Battery wear registers not exposed in unprivileged mode.',
            isRootEnhanced: false,
            hasSufficientData: false,
            metrics: [],
            rawDescriptors: [],
          ),
        ],
      );

      expect(report.hasSufficientData, isFalse);
      expect(report.overallScore, isNull);
      expect(report.overallGrade, HealthGrade.undetermined);
      expect(report.summary, contains("We can't determine the health of your phone based on those data."));
      expect(report.undeterminedReason, contains('Root or Shizuku'));
      expect(report.getComponent('storage')?.hasSufficientData, isFalse);
      expect(report.getComponent('storage')?.score, isNull);
      expect(report.getComponent('battery')?.hasSufficientData, isFalse);
      expect(report.getComponent('battery')?.score, isNull);
    });

    test('PartitionInfo correctly models block device and inode attributes', () {
      const p = PartitionInfo(
        name: 'USERDATA',
        blockDevice: '/dev/block/by-name/USERDATA',
        mountPoint: '/data',
        fsType: 'f2fs',
        mountFlags: 'rw,seclabel,nosuid,nodev,noatime',
        sizeBytes: 26978808 * 1024,
        usedBytes: 8847360 * 1024,
        availBytes: 18131448 * 1024,
        usePercentage: 32.8,
        totalInodes: 6209536,
        usedInodes: 1930000,
        freeInodes: 4279536,
        inodeUsePct: 31.1,
        isReadOnly: false,
        category: 'User Data & Cache',
      );

      expect(p.name, 'USERDATA');
      expect(p.blockDevice, contains('/dev/block/by-name'));
      expect(p.mountPoint, '/data');
      expect(p.fsType, 'f2fs');
      expect(p.isReadOnly, isFalse);
      expect(p.category, 'User Data & Cache');
      expect(p.totalInodes, 6209536);
      expect(p.inodeUsePct, 31.1);
      expect(p.sizeBytes, greaterThan(0));
    });
  });

  group('JEDEC JESD220 & Storage Diagnostic Algorithms', () {
    test('JEDEC bPreEOLInfo decodes correctly', () {
      String decodePreEol(int code) {
        switch (code) {
          case 0x01:
            return 'Normal (0% - 80% lifespan consumed)';
          case 0x02:
            return 'Warning (80% - 90% lifespan consumed)';
          case 0x03:
            return 'Urgent (Exceeded 90% lifespan, replace soon)';
          default:
            return 'Not Defined / Reserved ($code)';
        }
      }

      expect(decodePreEol(0x01), contains('Normal'));
      expect(decodePreEol(0x02), contains('Warning'));
      expect(decodePreEol(0x03), contains('Urgent'));
      expect(decodePreEol(0x00), contains('Not Defined'));
    });

    test('JEDEC bDeviceLifeTimeEst decodes wear percentage band', () {
      double estWearPercent(int hexCode) {
        if (hexCode >= 0x01 && hexCode <= 0x0A) {
          return (hexCode - 1) * 10.0 + 5.0; // midpoint of range
        } else if (hexCode == 0x0B) {
          return 100.0;
        }
        return 0.0;
      }

      expect(estWearPercent(0x01), 5.0); // 0% - 10%
      expect(estWearPercent(0x02), 15.0); // 10% - 20%
      expect(estWearPercent(0x05), 45.0); // 40% - 50%
      expect(estWearPercent(0x0A), 95.0); // 90% - 100%
      expect(estWearPercent(0x0B), 100.0); // Exceeded
    });

    test('Battery Coulomb counter estimation yields accurate capacity & SoH', () {
      // Scenario: battery is at 50% level, charge_counter is 2,400,000 uAh (2400 mAh)
      // Design capacity is 5000 mAh
      const chargeCounterUah = 2400000;
      const level = 50;
      const designCapacity = 5000.0;

      final currentMah = chargeCounterUah / 1000.0; // 2400 mAh
      final estTotalCapacityMah = currentMah / (level / 100.0); // 4800 mAh
      final soh = (estTotalCapacityMah / designCapacity) * 100.0; // 96.0%

      expect(estTotalCapacityMah, 4800.0);
      expect(soh, 96.0);
      expect(HealthGrade.fromScore(soh), HealthGrade.aPlus);
    });

    test('ZRAM compression ratio calculation handles division and sizing', () {
      const origDataBytes = 1048576000; // 1000 MB
      const comprDataBytes = 349525333; // ~333 MB

      final ratio = origDataBytes / comprDataBytes;
      expect(ratio, closeTo(3.0, 0.05));
    });
  });

  group('Root Telemetry Parsing & Privilege Mode Tests', () {
    test('dumpsys cpuinfo top process regex formats cleanly', () {
      const rawDumpLine = '  7.1% 8265/com.txorav.andbox: 4.8% user + 2.3% kernel / faults: 871 minor';
      final match = RegExp(r'([\d\.]+%)\s+\d+/([^:]+)').firstMatch(rawDumpLine.trim());
      expect(match, isNotNull);
      expect(match!.group(1), '7.1%');
      expect(match.group(2), 'com.txorav.andbox');

      final formattedVal = '${match.group(1)} (${match.group(2)})';
      expect(formattedVal, '7.1% (com.txorav.andbox)');
    });

    test('dumpsys mount fstrim maintenance regex extracts clean timestamp', () {
      const rawMountDump = 'Last maintenance: 2026-10-08 07:05:13\nOther info';
      final match = RegExp(r'Last maintenance:\s*([^\r\n]+)', caseSensitive: false).firstMatch(rawMountDump);
      expect(match, isNotNull);
      expect(match!.group(1)?.trim(), '2026-10-08 07:05:13');
    });

    test('PrivilegeModePreference values and descriptions are complete', () {
      expect(PrivilegeModePreference.values, contains(PrivilegeModePreference.auto));
      expect(PrivilegeModePreference.values, contains(PrivilegeModePreference.root));
      expect(PrivilegeModePreference.values, contains(PrivilegeModePreference.shizuku));
      expect(PrivilegeModePreference.values, contains(PrivilegeModePreference.standard));
      expect(PrivilegeModePreference.auto.label, contains('Automatic'));
    });

    testWidgets('ComponentHealthCard renders long root metric values without squishing or throwing', (tester) async {
      const comp = ComponentHealth(
        id: 'cpu',
        name: 'CPU & Silicon Processing',
        category: 'Processor & Clusters',
        icon: Icons.memory_rounded,
        score: 95.0,
        grade: HealthGrade.aPlus,
        summary: 'Nominal execution with optimal thermal headroom.',
        isRootEnhanced: true,
        metrics: [
          HealthMetricItem(
            label: 'Active Process Workload',
            value: '7.1% (com.txorav.andbox)',
            status: MetricStatus.good,
            tooltip: '7.1% 8265/com.txorav.andbox: 4.8% user + 2.3% kernel / faults: 871 minor',
          ),
          HealthMetricItem(
            label: 'Flash TRIM Maintenance',
            value: '2026-10-08 07:05:13',
            status: MetricStatus.optimal,
            tooltip: 'Last automated StorageManager fstrim cycle recycling unused NAND flash blocks: 2026-10-08 07:05:13',
          ),
          HealthMetricItem(
            label: 'Installed Apps Footprint',
            value: '512.4M apps • 1200.5M data • 340.2M cache',
            status: MetricStatus.good,
          ),
        ],
        rawDescriptors: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ComponentHealthCard(component: comp),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CPU & Silicon Processing'), findsOneWidget);
      expect(find.text('Active Process Workload'), findsOneWidget);
      expect(find.text('7.1% (com.txorav.andbox)'), findsOneWidget);
      expect(find.text('Flash TRIM Maintenance'), findsOneWidget);
      expect(find.text('2026-10-08 07:05:13'), findsOneWidget);
      expect(find.text('512.4M apps • 1200.5M data • 340.2M cache'), findsOneWidget);
    });
  });
}
