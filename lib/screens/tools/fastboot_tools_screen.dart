import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/fastboot_service.dart';
import '../../services/command_runner.dart';
import '../../theme/app_theme.dart';

class FastbootToolsScreen extends ConsumerStatefulWidget {
  const FastbootToolsScreen({super.key});

  @override
  ConsumerState<FastbootToolsScreen> createState() => _FastbootToolsScreenState();
}

class _FastbootToolsScreenState extends ConsumerState<FastbootToolsScreen> {
  bool _isLoading = true;
  FastbootBinaryInfo? _binaryInfo;
  BootloaderStatus? _bootloaderStatus;
  List<FastbootDevice> _connectedDevices = [];
  String? _selectedDeviceSerial;

  // Flasher & Dumper State
  String _selectedPartition = 'boot';
  final TextEditingController _imagePathController = TextEditingController();
  bool _disableVerity = false;
  bool _disableVerification = false;
  bool _isFlashing = false;

  // Fastboot Variables State
  Map<String, String> _fastbootVars = {};
  bool _isLoadingVars = false;
  String _varFilter = '';

  // Terminal State
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _terminalScrollController = ScrollController();
  String _terminalOutput = '';
  bool _isExecutingCmd = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _imagePathController.dispose();
    _cmdController.dispose();
    _terminalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final fastboot = ref.read(fastbootServiceProvider);

    final binary = await fastboot.ensureFastbootBinary();
    final blStatus = await fastboot.getLocalBootloaderStatus();
    final devices = await fastboot.getConnectedFastbootDevices();

    if (mounted) {
      setState(() {
        _binaryInfo = binary;
        _bootloaderStatus = blStatus;
        _connectedDevices = devices;
        if (devices.isNotEmpty && _selectedDeviceSerial == null) {
          _selectedDeviceSerial = devices.first.serial;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _executeFastbootCommand(String command) async {
    if (command.trim().isEmpty) return;
    setState(() {
      _isExecutingCmd = true;
      _terminalOutput += '\n\$ fastboot $command\n';
    });

    final fastboot = ref.read(fastbootServiceProvider);
    final result = await fastboot.runFastbootCommand(command, targetDevice: _selectedDeviceSerial);

    if (mounted) {
      setState(() {
        _terminalOutput += '$result\n';
        _isExecutingCmd = false;
      });
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

  Future<void> _fetchVariables() async {
    setState(() => _isLoadingVars = true);
    final fastboot = ref.read(fastbootServiceProvider);
    final vars = await fastboot.getFastbootVariables(targetDevice: _selectedDeviceSerial);
    if (mounted) {
      setState(() {
        _fastbootVars = vars;
        _isLoadingVars = false;
      });
    }
  }

  Future<void> _dumpPartition(String partition) async {
    final defaultPath = '/sdcard/Download/${partition}_backup.img';
    final pathController = TextEditingController(text: defaultPath);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Dump $partition Partition', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Direct-extract raw block data for $partition to storage. This raw image can be used for Magisk/KernelSU patching or safekeeping.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Destination File Path',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Extraction'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dumping $partition... please wait'), behavior: SnackBarBehavior.floating),
      );

      final fastboot = ref.read(fastbootServiceProvider);
      final res = await fastboot.dumpPartitionToStorage(
        partition: partition,
        outputPath: pathController.text.trim(),
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Extraction Result'),
            content: Text(res),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _flashImage({bool temporaryBootOnly = false}) async {
    final imagePath = _imagePathController.text.trim();
    if (imagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify image file path (.img)'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final targetName = temporaryBootOnly
        ? 'Temporary Boot image via Fastboot'
        : 'Flash $_selectedPartition with $imagePath';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(temporaryBootOnly ? 'Test Temporary Boot' : 'Confirm Partition Flash', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          temporaryBootOnly
              ? 'Tethered boot will run "$imagePath" in memory without overwriting flash storage.'
              : 'WARNING: Flashing an incorrect image to "$_selectedPartition" can brick your device or cause a bootloop!\nAction: $targetName\nAre you sure you wish to continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: temporaryBootOnly ? Colors.teal : Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(temporaryBootOnly ? 'Proceed' : 'Flash Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isFlashing = true);
      final fastboot = ref.read(fastbootServiceProvider);

      String res;
      if (temporaryBootOnly) {
        res = await fastboot.temporaryBoot(imagePath, targetDevice: _selectedDeviceSerial);
      } else {
        res = await fastboot.flashPartition(
          partition: _selectedPartition,
          imagePath: imagePath,
          disableVerity: _disableVerity,
          disableVerification: _disableVerification,
          targetDevice: _selectedDeviceSerial,
        );
      }

      if (mounted) {
        setState(() => _isFlashing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(temporaryBootOnly ? 'Boot Output' : 'Flash Output'),
            content: SingleChildScrollView(child: Text(res, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
          ),
        );
      }
    }
  }

  Future<void> _switchSlot() async {
    final current = _bootloaderStatus?.currentSlot ?? 'a';
    final target = current == 'a' ? 'b' : 'a';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Switch Active Slot', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Switch active boot slot from Slot $current to Slot $target?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Switch to Slot $target'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final fastboot = ref.read(fastbootServiceProvider);
      final res = await fastboot.setActiveSlot(target, targetDevice: _selectedDeviceSerial);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Slot change result: $res'), behavior: SnackBarBehavior.floating),
        );
        _loadAll();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final privAsync = ref.watch(privilegeStatusProvider);
    final borderColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Fastboot Toolkit', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
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
                  // 1. Status Banner & Binary Info
                  _buildStatusCard(context, isDark, borderColor, privAsync),
                  const SizedBox(height: 14),

                  // 2. Bootloader & AVB Status Card
                  _buildBootloaderStatusCard(context, isDark, borderColor),
                  const SizedBox(height: 14),

                  // 3. Fastboot USB OTG Devices Scanner
                  _buildOtgScannerCard(context, isDark, borderColor),
                  const SizedBox(height: 14),

                  // 4. Kernel / Partition Dumper & Flasher
                  _buildFlasherAndDumperCard(context, isDark, borderColor),
                  const SizedBox(height: 14),

                  // 5. Fastboot Variable Inspector
                  _buildVariablesCard(context, isDark, borderColor),
                  const SizedBox(height: 14),

                  // 6. Fastboot Command Console
                  _buildTerminalCard(context, isDark, borderColor),
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
                  color: (isReady ? Colors.teal : Colors.redAccent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isReady ? Icons.flash_on_rounded : Icons.warning_rounded,
                  color: isReady ? Colors.teal : Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReady ? 'Fastboot Flashing Engine Ready' : 'Fastboot Engine Initializing',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      _binaryInfo?.version ?? 'Platform Tools Fastboot v35.0.2',
                      style: TextStyle(fontSize: 11, color: AppTheme.getSecondaryText(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
                label: priv.hasPrivilege ? 'Root / Raw USB' : 'Standard USB Host',
                color: priv.hasPrivilege ? Colors.teal : Colors.blueGrey,
              ),
              _buildBadge(
                context,
                icon: Icons.usb_rounded,
                label: 'USB OTG Protocol Active',
                color: Colors.blueAccent,
              ),
              _buildBadge(
                context,
                icon: Icons.layers_rounded,
                label: 'Fastboot & FastbootD',
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBootloaderStatusCard(BuildContext context, bool isDark, Color borderColor) {
    final bl = _bootloaderStatus;
    final isLocked = bl?.isLocked ?? true;
    final vbState = bl?.verifiedBootState ?? 'unknown';
    final hasSlot = bl?.hasSlotAB ?? false;
    final currentSlot = bl?.currentSlot ?? 'none';

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
              const Icon(Icons.lock_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('Bootloader & AVB Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              if (hasSlot)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.sync_alt_rounded, size: 14),
                  label: Text('Slot $currentSlot (Switch)', style: const TextStyle(fontSize: 11)),
                  onPressed: _switchSlot,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'OEM Bootloader',
                  value: isLocked ? 'Locked' : 'Unlocked',
                  icon: isLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                  color: isLocked ? Colors.amber : Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'Verified Boot',
                  value: vbState.toUpperCase(),
                  icon: Icons.verified_user_rounded,
                  color: vbState == 'green' ? Colors.green : (vbState == 'orange' ? Colors.orange : Colors.blueGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'A/B Partitioning',
                  value: hasSlot ? 'Seamless A/B (Slot $currentSlot)' : 'Non-A/B (System-As-Root)',
                  icon: Icons.splitscreen_rounded,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'Dynamic Partitions',
                  value: bl?.isDynamicPartitions == true ? 'Supported (fastbootd)' : 'Standard Blocks',
                  icon: Icons.layers_rounded,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtgScannerCard(BuildContext context, bool isDark, Color borderColor) {
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
              const Icon(Icons.usb_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('USB OTG Fastboot Devices', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              Text(
                '${_connectedDevices.length} Detected',
                style: TextStyle(fontSize: 11, color: AppTheme.getSecondaryText(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_connectedDevices.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF11141B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No external devices connected via USB OTG in Fastboot or FastbootD mode. Connect another phone via USB cable to control it.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _connectedDevices.map((d) {
                final isSel = _selectedDeviceSerial == d.serial;
                return ChoiceChip(
                  avatar: const Icon(Icons.developer_board_rounded, size: 14),
                  label: Text('${d.displayName} [${d.mode}]'),
                  selected: isSel,
                  onSelected: (val) {
                    setState(() => _selectedDeviceSerial = val ? d.serial : null);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFlasherAndDumperCard(BuildContext context, bool isDark, Color borderColor) {
    final partitions = ['boot', 'init_boot', 'recovery', 'vbmeta', 'vendor_boot', 'dtbo', 'system'];

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
              Icon(Icons.system_update_alt_rounded, size: 18),
              SizedBox(width: 8),
              Text('Partition Flasher & Magisk Dumper', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),

          // 1. One-tap dump live kernel buttons
          const Text('Extract Live Image for Root / Patching:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDumpButton('boot', 'Extract boot.img (Kernel)'),
                const SizedBox(width: 8),
                _buildDumpButton('init_boot', 'Extract init_boot.img (Android 13+)'),
                const SizedBox(width: 8),
                _buildDumpButton('recovery', 'Extract recovery.img'),
                const SizedBox(width: 8),
                _buildDumpButton('vbmeta', 'Extract vbmeta.img'),
              ],
            ),
          ),

          const Divider(height: 24),

          // 2. Image Flasher Section
          const Text('Flash Partition Image (.img):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242A38) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedPartition,
                  underline: const SizedBox(),
                  isDense: true,
                  items: partitions.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPartition = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _imagePathController,
                  decoration: InputDecoration(
                    hintText: '/sdcard/Download/patched_boot.img',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _disableVerity,
                onChanged: (val) => setState(() => _disableVerity = val ?? false),
              ),
              const Text('Disable Verity', style: TextStyle(fontSize: 11.5)),
              const SizedBox(width: 12),
              Checkbox(
                value: _disableVerification,
                onChanged: (val) => setState(() => _disableVerification = val ?? false),
              ),
              const Text('Disable Verification', style: TextStyle(fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isFlashing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Flash Partition', style: TextStyle(fontSize: 12)),
                  onPressed: _isFlashing ? null : () => _flashImage(temporaryBootOnly: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.memory_rounded, size: 16),
                  label: const Text('Tethered Boot', style: TextStyle(fontSize: 12)),
                  onPressed: _isFlashing ? null : () => _flashImage(temporaryBootOnly: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDumpButton(String partition, String tooltip) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      icon: const Icon(Icons.download_rounded, size: 14),
      label: Text(partition, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11)),
      onPressed: () => _dumpPartition(partition),
    );
  }

  Widget _buildVariablesCard(BuildContext context, bool isDark, Color borderColor) {
    final filtered = _fastbootVars.entries.where((e) {
      if (_varFilter.isEmpty) return true;
      return e.key.toLowerCase().contains(_varFilter.toLowerCase()) ||
          e.value.toLowerCase().contains(_varFilter.toLowerCase());
    }).toList();

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
              const Icon(Icons.list_alt_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('Fastboot Variables (getvar all)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: _isLoadingVars
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded, size: 14),
                label: const Text('Read Variables', style: TextStyle(fontSize: 11)),
                onPressed: _isLoadingVars ? null : _fetchVariables,
              ),
            ],
          ),
          if (_fastbootVars.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: 'Filter variables...',
                prefixIcon: const Icon(Icons.search, size: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _varFilter = val),
            ),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF11141B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = filtered[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.key, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(item.value, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.blueAccent)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTerminalCard(BuildContext context, bool isDark, Color borderColor) {
    final presets = [
      'devices -l',
      'getvar all',
      'reboot',
      'reboot-bootloader',
      'reboot-recovery',
      'reboot fastboot',
      'flashing get_unlock_ability',
      'continue',
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
              const Text('Fastboot Console', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                onPressed: () => setState(() => _terminalOutput = ''),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _terminalOutput));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Output copied'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ],
          ),
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
                      _executeFastbootCommand(p);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 180,
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
                _terminalOutput.isEmpty ? 'Run Fastboot commands or tap presets above...' : _terminalOutput,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: Color(0xFF00E5FF), // Cyan fastboot terminal
                  height: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cmdController,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'e.g. getvar all, reboot, oem device-info',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: _executeFastbootCommand,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _isExecutingCmd ? null : () => _executeFastbootCommand(_cmdController.text),
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

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11141B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10, color: AppTheme.getSecondaryText(context))),
                Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
              ],
            ),
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
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
