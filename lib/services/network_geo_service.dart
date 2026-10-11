import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'command_runner.dart';

class NetworkGeoInfo {
  final String publicIp;
  final String country;
  final String countryCode;
  final String countryFlag;
  final String city;
  final String region;
  final String isp;
  final String asn;
  final String localIp;
  final String? cellularIp;
  final String activeInterface;
  final String gateway;
  final List<String> dnsServers;
  final String ssid;
  final String bssid;
  final String wifiStandard;
  final int linkSpeedMbps;
  final int frequencyMhz;
  final int rssiDbm;
  final double? pingLatencyMs;
  final int rxTotalBytes;
  final int txTotalBytes;
  final bool isOnline;
  final DateTime timestamp;

  const NetworkGeoInfo({
    required this.publicIp,
    required this.country,
    required this.countryCode,
    required this.countryFlag,
    required this.city,
    required this.region,
    required this.isp,
    required this.asn,
    required this.localIp,
    this.cellularIp,
    required this.activeInterface,
    required this.gateway,
    required this.dnsServers,
    required this.ssid,
    required this.bssid,
    required this.wifiStandard,
    required this.linkSpeedMbps,
    required this.frequencyMhz,
    required this.rssiDbm,
    this.pingLatencyMs,
    required this.rxTotalBytes,
    required this.txTotalBytes,
    required this.isOnline,
    required this.timestamp,
  });

  factory NetworkGeoInfo.empty() {
    return NetworkGeoInfo(
      publicIp: 'Unavailable',
      country: 'Unknown',
      countryCode: '--',
      countryFlag: '🌐',
      city: 'Unknown',
      region: 'Unknown',
      isp: 'Unknown',
      asn: 'Unknown',
      localIp: '127.0.0.1',
      cellularIp: null,
      activeInterface: 'lo',
      gateway: 'Unavailable',
      dnsServers: const [],
      ssid: 'Disconnected',
      bssid: '--',
      wifiStandard: 'Unknown',
      linkSpeedMbps: 0,
      frequencyMhz: 0,
      rssiDbm: 0,
      pingLatencyMs: null,
      rxTotalBytes: 0,
      txTotalBytes: 0,
      isOnline: false,
      timestamp: DateTime.now(),
    );
  }
}

final networkGeoServiceProvider = Provider<NetworkGeoService>((ref) {
  final runner = ref.watch(commandRunnerProvider);
  return NetworkGeoService(runner);
});

final networkGeoInfoProvider = FutureProvider<NetworkGeoInfo>((ref) async {
  final service = ref.watch(networkGeoServiceProvider);
  return await service.fetchNetworkInfo();
});

class NetworkGeoService {
  final CommandRunner _runner;
  NetworkGeoInfo? _cachedInfo;
  DateTime? _lastFetch;

  NetworkGeoService(this._runner);

  Future<NetworkGeoInfo> fetchNetworkInfo({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && _cachedInfo != null && _lastFetch != null) {
      if (now.difference(_lastFetch!).inSeconds < 15) {
        return _cachedInfo!;
      }
    }

    String publicIp = 'Unavailable';
    String country = 'Unknown';
    String countryCode = '--';
    String countryFlag = '🌐';
    String city = 'Unknown';
    String region = 'Unknown';
    String isp = 'Unknown';
    String asn = 'Unknown';
    bool isOnline = false;

    // 1. Fetch Real Public IP & Geo Intelligence via HTTPS
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      // Try ipwho.is first
      try {
        final request = await client.getUrl(Uri.parse('https://ipwho.is/'));
        final response = await request.close().timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          if (data['success'] == true) {
            publicIp = data['ip']?.toString() ?? 'Unavailable';
            country = data['country']?.toString() ?? 'Unknown';
            countryCode = data['country_code']?.toString() ?? '--';
            city = data['city']?.toString() ?? 'Unknown';
            region = data['region']?.toString() ?? 'Unknown';
            
            final flagObj = data['flag'];
            if (flagObj is Map && flagObj['emoji'] != null) {
              countryFlag = flagObj['emoji'].toString();
            } else if (countryCode.length == 2 && countryCode != '--') {
              countryFlag = _countryCodeToEmoji(countryCode);
            }

            final conn = data['connection'];
            if (conn is Map) {
              isp = conn['isp']?.toString() ?? 'Unknown';
              asn = conn['asn'] != null ? 'AS${conn['asn']}' : 'Unknown';
            }
            isOnline = true;
          }
        }
      } catch (_) {}

      // Fallback to ip-api.com if needed
      if (!isOnline) {
        try {
          final request = await client.getUrl(Uri.parse('http://ip-api.com/json/'));
          final response = await request.close().timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final data = jsonDecode(body) as Map<String, dynamic>;
            if (data['status'] == 'success') {
              publicIp = data['query']?.toString() ?? 'Unavailable';
              country = data['country']?.toString() ?? 'Unknown';
              countryCode = data['countryCode']?.toString() ?? '--';
              countryFlag = _countryCodeToEmoji(countryCode);
              city = data['city']?.toString() ?? 'Unknown';
              region = data['regionName']?.toString() ?? 'Unknown';
              isp = data['isp']?.toString() ?? 'Unknown';
              asn = data['as']?.toString() ?? 'Unknown';
              isOnline = true;
            }
          }
        } catch (_) {}
      }
      client.close();
    } catch (_) {}

    // 2. Fetch Local Network Telemetry from Android OS / Linux Kernel
    String localIp = '127.0.0.1';
    String? cellularIp;
    String activeInterface = 'lo';
    String gateway = 'Unavailable';
    final List<String> dnsServers = [];
    String ssid = 'Disconnected';
    String bssid = '--';
    String wifiStandard = 'Unknown';
    int linkSpeedMbps = 0;
    int frequencyMhz = 0;
    int rssiDbm = 0;

    try {
      final connOut = await _runner.runCommand('dumpsys connectivity 2>/dev/null');
      if (connOut.isNotEmpty) {
        // Extract Wi-Fi details from dumpsys connectivity TransportInfo / WifiNetworkAgentSpecifier
        final matchSsid = RegExp(r'SSID:\s*"([^"]+)"').firstMatch(connOut) ??
            RegExp(r'SSID="([^"]+)"').firstMatch(connOut);
        if (matchSsid != null) {
          ssid = matchSsid.group(1) ?? 'Disconnected';
        }

        final matchBssid = RegExp(r'BSSID[=:]\s*([0-9a-fA-F:]{17})').firstMatch(connOut);
        if (matchBssid != null) {
          bssid = matchBssid.group(1) ?? '--';
        }

        final matchRssi = RegExp(r'RSSI:\s*(-?\d+)').firstMatch(connOut) ??
            RegExp(r'SignalStrength:\s*(-?\d+)').firstMatch(connOut);
        if (matchRssi != null) {
          rssiDbm = int.tryParse(matchRssi.group(1) ?? '0') ?? 0;
        }

        final matchLinkSpeed = RegExp(r'Link speed:\s*(\d+)Mbps').firstMatch(connOut);
        if (matchLinkSpeed != null) {
          linkSpeedMbps = int.tryParse(matchLinkSpeed.group(1) ?? '0') ?? 0;
        }

        final matchFreq = RegExp(r'Frequency:\s*(\d+)MHz').firstMatch(connOut);
        if (matchFreq != null) {
          frequencyMhz = int.tryParse(matchFreq.group(1) ?? '0') ?? 0;
        }

        final matchStd = RegExp(r'Wi-Fi standard:\s*([a-zA-Z0-9]+)').firstMatch(connOut);
        if (matchStd != null) {
          wifiStandard = '802.${matchStd.group(1)}';
        }

        // Extract Gateway & DNS from Routes: [ ... ]
        final matchRoutes = RegExp(r'0\.0\.0\.0/0\s*->\s*([0-9.]+)\s+([a-zA-Z0-9_]+)').allMatches(connOut);
        for (final m in matchRoutes) {
          final gw = m.group(1) ?? '';
          final iface = m.group(2) ?? '';
          if (gw.isNotEmpty && gw != '0.0.0.0') {
            gateway = gw;
            activeInterface = iface;
            break;
          }
        }

        final matchDns = RegExp(r'DnsAddresses:\s*\[\s*([^\]]+)\s*\]').allMatches(connOut);
        for (final m in matchDns) {
          final rawList = m.group(1) ?? '';
          for (final item in rawList.split(',')) {
            final clean = item.replaceAll('/', '').trim();
            if (clean.isNotEmpty && !dnsServers.contains(clean)) {
              dnsServers.add(clean);
            }
          }
        }
      }
    } catch (_) {}

    // 3. Fallback/Supplement from ip addr show
    try {
      final ipOut = await _runner.runCommand('ip addr show 2>/dev/null');
      if (ipOut.isNotEmpty) {
        final lines = ipOut.split('\n');
        String currentIface = '';
        for (final line in lines) {
          final ifaceMatch = RegExp(r'^\s*\d+:\s+([a-zA-Z0-9_\-]+):').firstMatch(line);
          if (ifaceMatch != null) {
            currentIface = ifaceMatch.group(1) ?? '';
          }
          final inetMatch = RegExp(r'inet\s+([0-9.]+)/\d+').firstMatch(line);
          if (inetMatch != null && currentIface != 'lo') {
            final ip = inetMatch.group(1) ?? '';
            if (currentIface.startsWith('wlan') || currentIface.startsWith('eth')) {
              localIp = ip;
              if (activeInterface == 'lo' || activeInterface.isEmpty) {
                activeInterface = currentIface;
              }
            } else if (currentIface.startsWith('rmnet') || currentIface.startsWith('ccmni') || currentIface.startsWith('pdp')) {
              cellularIp = ip;
              if (localIp == '127.0.0.1') {
                localIp = ip;
                activeInterface = currentIface;
              }
            }
          }
        }
      }
    } catch (_) {}

    // 4. Measure Real Ping Latency
    double? pingLatency;
    try {
      final target = gateway != 'Unavailable' ? gateway : '8.8.8.8';
      final pingOut = await _runner.runCommand('ping -c 1 -W 2 $target 2>/dev/null');
      final matchTime = RegExp(r'time=([\d.]+)\s*ms').firstMatch(pingOut);
      if (matchTime != null) {
        pingLatency = double.tryParse(matchTime.group(1) ?? '');
      }
    } catch (_) {}

    // 5. Read Kernel Total Transferred Bytes from /proc/net/dev
    int rxTotal = 0;
    int txTotal = 0;
    try {
      final netDev = await _runner.runCommand('cat /proc/net/dev 2>/dev/null');
      if (netDev.isNotEmpty) {
        for (final line in netDev.split('\n')) {
          if (!line.contains(':') || line.contains('lo:')) continue;
          final parts = line.split(':')[1].trim().split(RegExp(r'\s+'));
          if (parts.length >= 9) {
            rxTotal += int.tryParse(parts[0]) ?? 0;
            txTotal += int.tryParse(parts[8]) ?? 0;
          }
        }
      }
    } catch (_) {}

    final result = NetworkGeoInfo(
      publicIp: publicIp,
      country: country,
      countryCode: countryCode,
      countryFlag: countryFlag,
      city: city,
      region: region,
      isp: isp,
      asn: asn,
      localIp: localIp,
      cellularIp: cellularIp,
      activeInterface: activeInterface,
      gateway: gateway,
      dnsServers: dnsServers,
      ssid: ssid,
      bssid: bssid,
      wifiStandard: wifiStandard,
      linkSpeedMbps: linkSpeedMbps,
      frequencyMhz: frequencyMhz,
      rssiDbm: rssiDbm,
      pingLatencyMs: pingLatency,
      rxTotalBytes: rxTotal,
      txTotalBytes: txTotal,
      isOnline: isOnline,
      timestamp: now,
    );

    _cachedInfo = result;
    _lastFetch = now;
    return result;
  }

  static String countryCodeToEmoji(String countryCode) {
    if (countryCode.length != 2 || countryCode == '--') return '🌐';
    final upper = countryCode.toUpperCase();
    final first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  static String _countryCodeToEmoji(String countryCode) => countryCodeToEmoji(countryCode);
}
