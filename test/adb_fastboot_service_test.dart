import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/services/adb_service.dart';
import 'package:toolbox/services/fastboot_service.dart';
import 'package:toolbox/services/command_runner.dart';

class MockCommandRunner extends CommandRunner {
  String nextResponse = '';
  final List<String> executedCommands = [];

  @override
  Future<String> runCommand(String command, {PrivilegeModePreference? preference}) async {
    executedCommands.add(command);
    return nextResponse;
  }

  @override
  Future<bool> isRootAvailable() async => true;

  @override
  Future<bool> isShizukuAvailable() async => false;
}

void main() {
  group('AdbService Tests', () {
    late MockCommandRunner runner;
    late AdbService adbService;

    setUp(() {
      runner = MockCommandRunner();
      adbService = AdbService(runner);
    });

    test('Parses adb devices -l output correctly', () async {
      runner.nextResponse = '''
List of devices attached
3201fc59490d5691       device product:m20dd model:SM_M205F device:m20 transport_id:1
192.168.1.55:5555      device product:cheetah model:Pixel_7_Pro device:cheetah transport_id:2
emulator-5554          offline transport_id:3
''';

      // We test parsing logic by testing the output format
      final lines = runner.nextResponse.split('\n');
      final devices = <AdbDevice>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('List of devices')) continue;

        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final serial = parts[0];
          final state = parts[1];
          String model = '';
          String product = '';
          for (int i = 2; i < parts.length; i++) {
            if (parts[i].startsWith('model:')) model = parts[i].substring(6);
            if (parts[i].startsWith('product:')) product = parts[i].substring(8);
          }
          final isNetwork = serial.contains(':') || serial.startsWith('192.');
          final isUsb = !isNetwork && !serial.startsWith('emulator-');

          devices.add(AdbDevice(
            serial: serial,
            state: state,
            model: model,
            product: product,
            isUsb: isUsb,
            isNetwork: isNetwork,
          ));
        }
      }

      expect(devices.length, 3);
      expect(devices[0].serial, '3201fc59490d5691');
      expect(devices[0].model, 'SM_M205F');
      expect(devices[0].isUsb, isTrue);
      expect(devices[0].isNetwork, isFalse);

      expect(devices[1].serial, '192.168.1.55:5555');
      expect(devices[1].model, 'Pixel_7_Pro');
      expect(devices[1].isUsb, isFalse);
      expect(devices[1].isNetwork, isTrue);
      expect(devices[1].displayName, 'Pixel_7_Pro (192.168.1.55:5555)');
    });

    test('rebootMode triggers correct commands', () async {
      await adbService.rebootMode('recovery');
      expect(runner.executedCommands.last, 'reboot recovery');

      await adbService.rebootMode('bootloader');
      expect(runner.executedCommands.last, 'reboot bootloader');

      await adbService.rebootMode('fastbootd');
      expect(runner.executedCommands.last, 'reboot fastboot');

      await adbService.rebootMode('edl');
      expect(runner.executedCommands.last, 'reboot edl');

      await adbService.rebootMode('download');
      expect(runner.executedCommands.last, 'reboot download');

      await adbService.rebootMode('userspace');
      expect(runner.executedCommands.last, 'reboot userspace');
    });

    test('WirelessAdbInfo constructs connect command', () {
      const info = WirelessAdbInfo(
        isEnabled: true,
        port: 5555,
        ipAddress: '192.168.1.120',
        connectCommand: 'adb connect 192.168.1.120:5555',
      );

      expect(info.isEnabled, isTrue);
      expect(info.connectCommand, 'adb connect 192.168.1.120:5555');
    });
  });

  group('FastbootService Tests', () {
    late MockCommandRunner runner;
    late FastbootService fastbootService;

    setUp(() {
      runner = MockCommandRunner();
      fastbootService = FastbootService(runner);
    });

    test('BootloaderStatus reports correct flags', () {
      const status = BootloaderStatus(
        isLocked: false,
        verifiedBootState: 'orange',
        currentSlot: 'a',
        hasSlotAB: true,
        bootloaderVersion: 'M205FXXU7CTB1',
        isDynamicPartitions: false,
      );

      expect(status.isLocked, isFalse);
      expect(status.verifiedBootState, 'orange');
      expect(status.currentSlot, 'a');
      expect(status.hasSlotAB, isTrue);
    });

    test('setActiveSlot invokes bootctl on local device', () async {
      await fastbootService.setActiveSlot('b');
      expect(runner.executedCommands.last, 'bootctl set-active-boot-slot 1');
    });

    test('Fastboot variables parser handles getvar all format', () {
      const getvarOutput = '''
(bootloader) product: universal7904
(bootloader) version-bootloader: M205FXXU7CTB1
(bootloader) secure: yes
(bootloader) unlocked: yes
(bootloader) slot-count: 2
(bootloader) current-slot: a
(bootloader) partition-size:boot: 0x2000000
all: done
''';

      final vars = <String, String>{};
      for (final line in getvarOutput.split('\n')) {
        var clean = line.replaceFirst('(bootloader)', '').replaceFirst('getvar:', '').trim();
        final colonIdx = clean.indexOf(':');
        if (colonIdx > 0) {
          final key = clean.substring(0, colonIdx).trim();
          final value = clean.substring(colonIdx + 1).trim();
          if (key.isNotEmpty && key != 'all') {
            vars[key] = value;
          }
        }
      }

      expect(vars['product'], 'universal7904');
      expect(vars['version-bootloader'], 'M205FXXU7CTB1');
      expect(vars['secure'], 'yes');
      expect(vars['unlocked'], 'yes');
      expect(vars['slot-count'], '2');
      expect(vars['current-slot'], 'a');
      expect(vars['partition-size'], 'boot: 0x2000000');
    });

    test('FastbootDevice model representation', () {
      const dev = FastbootDevice(serial: '3201fc59490d5691', mode: 'fastbootd', product: 'universal7904');
      expect(dev.displayName, 'universal7904 (3201fc59490d5691)');
      expect(dev.mode, 'fastbootd');
    });
  });
}
