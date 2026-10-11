import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/adb_service.dart';
import '../../services/command_runner.dart';
import '../../theme/app_theme.dart';

class AdbToolsScreen extends ConsumerStatefulWidget {
  const AdbToolsScreen({super.key});

  @override
  ConsumerState<AdbToolsScreen> createState() => _AdbToolsScreenState();
}

class _AdbToolsScreenState extends ConsumerState<AdbToolsScreen> {
  bool _isLoading = true;
  AdbBinaryInfo? _binaryInfo;
  WirelessAdbInfo? _wirelessInfo;
  List<AdbDevice> _connectedDevices = [];
  String? _selectedDeviceSerial; // null means local device

  // Terminal state
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _terminalScrollController = ScrollController();
  String _terminalOutput = '';
  bool _isExecutingCmd = false;
  final List<String> _cmdHistory = [];

  // Tweakers state
  int? _currentDensity;
  double _selectedDensity = 420;
  double _mockBatteryLevel = 80;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _cmdController.dispose();
    _terminalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final adb = ref.read(adbServiceProvider);

    final binary = await adb.ensureAdbBinary();
    final wireless = await adb.getWirelessAdbInfo();
    final devices = await adb.getConnectedDevices();
    final density = await adb.getDisplayDensity();

    if (mounted) {
      setState(() {
        _binaryInfo = binary;
        _wirelessInfo = wireless;
        _connectedDevices = devices;
        _currentDensity = density;
        if (density != null) _selectedDensity = density.toDouble();
        _isLoading = false;
      });
    }
  }

  Future<void> _executeCommand(String command) async {
    if (command.trim().isEmpty) return;
    setState(() {
      _isExecutingCmd = true;
      _terminalOutput += '\n\$ $command\n';
      _cmdHistory.add(command);
    });

    final adb = ref.read(adbServiceProvider);
    final result = await adb.runAdbCommand(command, targetDevice: _selectedDeviceSerial);

    if (mounted) {
      setState(() {
        _terminalOutput += '$result\n';
        _isExecutingCmd = false;
      });
      // Scroll terminal to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_terminalScrollController.hasClients) {
          _terminalScrollController.animateTo(
            _terminalScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _toggleWireless(bool enable) async {
    setState(() => _isLoading = true);
    final adb = ref.read(adbServiceProvider);
    await adb.toggleWirelessAdb(enable: enable);
    await Future.delayed(const Duration(milliseconds: 800));
    final wireless = await adb.getWirelessAdbInfo();
    if (mounted) {
      setState(() {
        _wirelessInfo = wireless;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable ? 'Wireless ADB enabled on port 5555' : 'Wireless ADB disabled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmReboot(String mode, String title, String warning) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(warning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reboot Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final adb = ref.read(adbServiceProvider);
      final res = await adb.rebootMode(mode, targetDevice: _selectedDeviceSerial);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reboot requested: $res'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPairingDialog() {
    final hostController = TextEditingController(text: '${_wirelessInfo?.ipAddress ?? "192.168.1."}:');
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Wireless Debugging Pairing', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pair with Android 11+ Developer Options Wireless Debugging pairing code.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'IP & Pairing Port (e.g. 192.168.1.5:37891)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '6-digit Pairing Code',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final adb = ref.read(adbServiceProvider);
              final res = await adb.pairTarget(hostController.text.trim(), codeController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res), behavior: SnackBarBehavior.floating),
                );
                _loadAll();
              }
            },
            child: const Text('Pair Device'),
          ),
        ],
      ),
    );
  }

  void _showConnectDialog() {
    final hostController = TextEditingController(
      text: '${_wirelessInfo?.ipAddress ?? "127.0.0.1"}:${_wirelessInfo?.port ?? 5555}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Connect ADB Target', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Connect to localhost or any network device with ADB over TCP enabled.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'Host:Port',
                hintText: '192.168.1.10:5555',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final target = hostController.text.trim();
              final parts = target.split(':');
              final host = parts[0];
              final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 5555 : 5555;

              final adb = ref.read(adbServiceProvider);
              final res = await adb.connectTarget(host, port);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res), behavior: SnackBarBehavior.floating),
                );
                _loadAll();
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final privAsync = ref.watch(privilegeStatusProvider);
    final borderColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('ADB Toolkit', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status & Devices',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Status Banner & Privilege Card
                  _buildStatusCard(context, isDark, borderColor, privAsync),
                  const SizedBox(height: 14),

                  // 2. Wireless ADB Hub Card
                  _buildWirelessAdbCard(context, isDark, borderColor),
                  const SizedBox(height: 14),

                  // 3. Connected Devices & USB OTG Selector
                  _buildDeviceSelectorCard(context, isDark, borderColor),
                  const SizedBox(height: 14),

                  // 4. Power & Advanced Reboot Grid
                  _buildRebootGridCard(context, isDark, borderColor),
                  const SizedBox(height: 14),

                  // 5. Interactive ADB Terminal
                  _buildTerminalCard(context, isDark, borderColor),
                  const SizedBox(height: 14),

                  // 6. Display & Battery Quick Tweaker
                  _buildTweakersCard(isDark, borderColor),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    bool isDark,
    Color borderColor,
    AsyncValue<PrivilegeStatus> privAsync,
  ) {
    final adb = ref.watch(adbServiceProvider);
    final isReady = _binaryInfo?.isReady == true;
    final priv = privAsync.valueOrNull ?? PrivilegeStatus.standard;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isReady ? Colors.green : Colors.redAccent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isReady ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: isReady ? Colors.green : Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReady ? 'ADB Native Engine Active' : 'ADB Binary Initializing',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      _binaryInfo?.version ?? 'Platform Tools v35.0.2',
                      style: TextStyle(fontSize: 11, color: AppTheme.getSecondaryText(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Exec Mode Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242A38) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<AdbExecMode>(
                  value: adb.execMode,
                  underline: const SizedBox(),
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  items: AdbExecMode.values.map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(mode.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (newMode) {
                    if (newMode != null) {
                      setState(() => adb.execMode = newMode);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(
                context,
                icon: Icons.security_rounded,
                label: priv.label,
                color: priv.hasPrivilege ? Colors.teal : Colors.blueGrey,
              ),
              _buildBadge(
                context,
                icon: Icons.usb_rounded,
                label: 'USB OTG Host Enabled',
                color: Colors.blueAccent,
              ),
              _buildBadge(
                context,
                icon: Icons.folder_zip_rounded,
                label: _binaryInfo?.path.contains('/files/bin') == true ? 'Local Sandboxed' : 'System',
                color: Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWirelessAdbCard(BuildContext context, bool isDark, Color borderColor) {
    final info = _wirelessInfo;
    final isEnabled = info?.isEnabled == true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isEnabled ? Colors.teal : Colors.blueGrey).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: isEnabled ? Colors.teal : Colors.blueGrey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wireless ADB & Network Debugging', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(
                      isEnabled
                          ? '${info?.ipAddress}:${info?.port} (Listening)'
                          : '${info?.ipAddress} (Service inactive)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: isEnabled ? Colors.teal : AppTheme.getSecondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (val) => _toggleWireless(val),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF11141B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    info?.connectCommand ?? 'adb connect 127.0.0.1:5555',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: info?.connectCommand ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connect command copied to clipboard'), behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('Connect Target', style: TextStyle(fontSize: 12)),
                  onPressed: _showConnectDialog,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_rounded, size: 16),
                  label: const Text('Pair Device', style: TextStyle(fontSize: 12)),
                  onPressed: _showPairingDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelectorCard(BuildContext context, bool isDark, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('Target Device / USB OTG', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              Text(
                '${_connectedDevices.length} Connected',
                style: TextStyle(fontSize: 11, color: AppTheme.getSecondaryText(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Local Device (Self)'),
                selected: _selectedDeviceSerial == null,
                onSelected: (val) {
                  if (val) setState(() => _selectedDeviceSerial = null);
                },
              ),
              ..._connectedDevices.map((d) {
                final isSel = _selectedDeviceSerial == d.serial;
                return ChoiceChip(
                  avatar: Icon(d.isUsb ? Icons.usb_rounded : Icons.wifi_rounded, size: 14),
                  label: Text('${d.displayName} [${d.state}]'),
                  selected: isSel,
                  onSelected: (val) {
                    setState(() => _selectedDeviceSerial = val ? d.serial : null);
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRebootGridCard(BuildContext context, bool isDark, Color borderColor) {
    final targetLabel = _selectedDeviceSerial ?? 'Local Device';

    final rebootModes = [
      {'mode': 'recovery', 'title': 'Recovery Mode', 'sub': 'TWRP / Stock Recovery', 'icon': Icons.healing_rounded, 'color': Colors.orange},
      {'mode': 'bootloader', 'title': 'Bootloader', 'sub': 'Fastboot flashing mode', 'icon': Icons.terminal_rounded, 'color': Colors.cyan},
      {'mode': 'fastbootd', 'title': 'FastbootD', 'sub': 'Userspace dynamic partitions', 'icon': Icons.developer_mode_rounded, 'color': Colors.indigo},
      {'mode': 'edl', 'title': 'EDL Mode', 'sub': 'Qualcomm 9008 unbrick', 'icon': Icons.warning_amber_rounded, 'color': Colors.deepOrange},
      {'mode': 'download', 'title': 'Download Mode', 'sub': 'Samsung Odin / Loke', 'icon': Icons.download_rounded, 'color': Colors.blue},
      {'mode': 'userspace', 'title': 'Soft Reboot', 'sub': 'Fast framework restart', 'icon': Icons.speed_rounded, 'color': Colors.purple},
      {'mode': 'safemode', 'title': 'Safe Mode', 'sub': 'Disable 3rd-party apps', 'icon': Icons.security_rounded, 'color': Colors.green},
      {'mode': 'poweroff', 'title': 'Power Off', 'sub': 'Complete shutdown', 'icon': Icons.power_settings_new_rounded, 'color': Colors.redAccent},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restart_alt_rounded, size: 18),
              const SizedBox(width: 8),
              Text('Power & Advanced Reboot ($targetLabel)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: rebootModes.length,
            itemBuilder: (ctx, i) {
              final item = rebootModes[i];
              final color = item['color'] as MaterialColor;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _confirmReboot(
                  item['mode'] as String,
                  item['title'] as String,
                  'Are you sure you want to reboot $targetLabel into ${item['title']}?',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(item['icon'] as IconData, size: 20, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color[700]),
                              maxLines: 1,
                            ),
                            Text(
                              item['sub'] as String,
                              style: TextStyle(fontSize: 9.5, color: AppTheme.getSecondaryText(context)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalCard(BuildContext context, bool isDark, Color borderColor) {
    final presets = [
      'devices -l',
      'shell pm list packages -3',
      'shell wm density',
      'shell wm size',
      'shell dumpsys battery',
      'shell getprop ro.build.version.release',
      'shell df -h',
      'shell top -n 1 -m 5',
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('Interactive ADB Console', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                tooltip: 'Clear Output',
                onPressed: () => setState(() => _terminalOutput = ''),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: 'Copy Output',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _terminalOutput));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Console output copied'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Presets chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    label: Text(p, style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace')),
                    onPressed: () {
                      _cmdController.text = p;
                      _executeCommand(p);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Console Output Box
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0D14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              controller: _terminalScrollController,
              child: Text(
                _terminalOutput.isEmpty ? 'Type an ADB command or tap a preset above to begin...' : _terminalOutput,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: Color(0xFF4AF626), // Classic terminal green
                  height: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Command Input Field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cmdController,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'e.g. shell pm list packages, reboot, etc.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: _executeCommand,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _isExecutingCmd ? null : () => _executeCommand(_cmdController.text),
                child: _isExecutingCmd
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTweakersCard(bool isDark, Color borderColor) {
    final adb = ref.read(adbServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 18),
              SizedBox(width: 8),
              Text('Display & Battery Simulator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Display Density (DPI)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentDensity != null ? 'Screen Density (Current: $_currentDensity DPI)' : 'Screen Density (DPI)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              Text('${_selectedDensity.round()} DPI', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _selectedDensity,
            min: 240,
            max: 600,
            divisions: 36,
            label: '${_selectedDensity.round()} DPI',
            onChanged: (val) => setState(() => _selectedDensity = val),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final res = await adb.setDisplayDensity(_selectedDensity.round(), targetDevice: _selectedDeviceSerial);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DPI applied: $res'), behavior: SnackBarBehavior.floating));
                    _loadAll();
                  },
                  child: const Text('Apply Density', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final res = await adb.resetDisplayDensity(targetDevice: _selectedDeviceSerial);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DPI reset: $res'), behavior: SnackBarBehavior.floating));
                  _loadAll();
                },
                child: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          const Divider(height: 24),

          // 2. Battery Simulator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mock Battery Simulation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              Text('${_mockBatteryLevel.round()}%', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _mockBatteryLevel,
            min: 1,
            max: 100,
            divisions: 99,
            label: '${_mockBatteryLevel.round()}%',
            onChanged: (val) => setState(() => _mockBatteryLevel = val),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final res = await adb.mockBatteryLevel(_mockBatteryLevel.round(), targetDevice: _selectedDeviceSerial);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Battery mocked: $res'), behavior: SnackBarBehavior.floating));
                  },
                  child: const Text('Set Level', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final res = await adb.mockBatteryUnplug(targetDevice: _selectedDeviceSerial);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unplugged: $res'), behavior: SnackBarBehavior.floating));
                  },
                  child: const Text('Simulate Unplug', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final res = await adb.resetBattery(targetDevice: _selectedDeviceSerial);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Battery reset: $res'), behavior: SnackBarBehavior.floating));
                },
                child: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
