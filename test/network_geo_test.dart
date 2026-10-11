import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/services/command_runner.dart';
import 'package:toolbox/services/network_geo_service.dart';

class MockCommandRunner extends CommandRunner {
  final Map<String, String> responses;

  MockCommandRunner(this.responses);

  @override
  Future<String> runCommand(String command, {PrivilegeModePreference? preference}) async {
    for (final entry in responses.entries) {
      if (command.contains(entry.key)) {
        return entry.value;
      }
    }
    return '';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkGeoInfo & Service Tests', () {
    test('NetworkGeoInfo.empty creates valid fallback model', () {
      final info = NetworkGeoInfo.empty();
      expect(info.isOnline, isFalse);
      expect(info.publicIp, 'Unavailable');
      expect(info.country, 'Unknown');
      expect(info.countryCode, '--');
      expect(info.countryFlag, '🌐');
      expect(info.localIp, '127.0.0.1');
      expect(info.activeInterface, 'lo');
      expect(info.gateway, 'Unavailable');
      expect(info.ssid, 'Disconnected');
    });

    test('NetworkGeoService parses dumpsys connectivity and proc net dev', () async {
      final mockRunner = MockCommandRunner({
        'dumpsys connectivity': '''
          NetworkAgentInfo{ ... }
          TransportInfo: <SSID: "Test_Fiber_5G", BSSID: 00:11:22:33:44:55, RSSI: -54, Link speed: 866Mbps, Frequency: 5180MHz, Wi-Fi standard: 11ac>
          Routes: [ 0.0.0.0/0 -> 192.168.1.1 wlan0, 192.168.1.0/24 -> 0.0.0.0 wlan0 ]
          DnsAddresses: [ /192.168.1.1, /1.1.1.1 ]
        ''',
        'ip addr show': '''
          1: lo: <LOOPBACK>
              inet 127.0.0.1/8 scope host lo
          2: wlan0: <BROADCAST,MULTICAST,UP>
              inet 192.168.1.45/24 brd 192.168.1.255 scope global wlan0
        ''',
        'ping': '64 bytes from 192.168.1.1: icmp_seq=1 ttl=64 time=4.32 ms',
        '/proc/net/dev': '''
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
  lo:  1000       10    0    0    0     0          0         0     1000       10    0    0    0     0       0          0
wlan0: 5000000    3500    0    0    0     0          0         0  2000000    2100    0    0    0     0       0          0
        ''',
      });

      final service = NetworkGeoService(mockRunner);
      final info = await service.fetchNetworkInfo(forceRefresh: true);

      expect(info.ssid, 'Test_Fiber_5G');
      expect(info.bssid, '00:11:22:33:44:55');
      expect(info.rssiDbm, -54);
      expect(info.linkSpeedMbps, 866);
      expect(info.frequencyMhz, 5180);
      expect(info.wifiStandard, '802.11ac');
      expect(info.gateway, '192.168.1.1');
      expect(info.activeInterface, 'wlan0');
      expect(info.dnsServers, contains('192.168.1.1'));
      expect(info.dnsServers, contains('1.1.1.1'));
      expect(info.localIp, '192.168.1.45');
      expect(info.pingLatencyMs, 4.32);
      expect(info.rxTotalBytes, 5000000);
      expect(info.txTotalBytes, 2000000);
    });

    test('Country code flag conversion', () {
      expect(NetworkGeoService.countryCodeToEmoji('DZ'), '🇩🇿');
      expect(NetworkGeoService.countryCodeToEmoji('US'), '🇺🇸');
      expect(NetworkGeoService.countryCodeToEmoji('GB'), '🇬🇧');
      expect(NetworkGeoService.countryCodeToEmoji('--'), '🌐');
      expect(NetworkGeoService.countryCodeToEmoji(''), '🌐');
    });
  });
}
