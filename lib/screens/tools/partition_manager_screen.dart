import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device_health_model.dart';
import '../../services/command_runner.dart';
import '../../theme/app_theme.dart';

class PartitionCategoryGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<PartitionInfo> items;

  const PartitionCategoryGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class PartitionManagerScreen extends ConsumerStatefulWidget {
  const PartitionManagerScreen({super.key});

  @override
  ConsumerState<PartitionManagerScreen> createState() => _PartitionManagerScreenState();
}

class _PartitionManagerScreenState extends ConsumerState<PartitionManagerScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  List<PartitionInfo> _partitions = [];
  String _partitionScheme = 'Detecting...';
  int _totalMountedBytes = 0;
  int _totalUsedBytes = 0;
  int _totalInodes = 0;
  int _usedInodes = 0;

  @override
  void initState() {
    super.initState();
    _loadPartitionData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPartitionData() async {
    setState(() => _isLoading = true);
    final runner = ref.read(commandRunnerProvider);

    try {
      // 1. Block by-name map
      final Map<String, String> byNameMap = {};
      final lsOut = await runner.runCommand('ls -l /dev/block/by-name /dev/block/bootdevice/by-name /dev/block/platform/*/by-name 2>/dev/null');
      final matches = RegExp(r'(\S+)\s*->\s*(\S+)').allMatches(lsOut);
      for (final m in matches) {
        final name = m.group(1) ?? '';
        final target = m.group(2) ?? '';
        if (name.isNotEmpty && target.isNotEmpty) {
          byNameMap[name] = target;
        }
      }

      // 2. /proc/mounts
      final Map<String, Map<String, String>> mountMap = {};
      final Map<String, Map<String, String>> blockMountMap = {};
      final mountsOut = await runner.runCommand('cat /proc/mounts 2>/dev/null');

      for (final line in mountsOut.split('\n')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final dev = parts[0];
          final mnt = parts[1];
          final fs = parts[2];
          final opts = parts[3];
          mountMap[mnt] = {'device': dev, 'fsType': fs, 'options': opts};
          blockMountMap[dev] = {'mountPoint': mnt, 'fsType': fs, 'options': opts};
        }
      }

      // 3. df -k
      final Map<String, Map<String, dynamic>> dfData = {};
      final dfOut = await runner.runCommand('df -k 2>/dev/null');
      for (final line in dfOut.split('\n')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 6 && parts[1] != '1K-blocks') {
          final dev = parts[0];
          final sizeKb = int.tryParse(parts[1]) ?? 0;
          final usedKb = int.tryParse(parts[2]) ?? 0;
          final availKb = int.tryParse(parts[3]) ?? 0;
          final pctStr = parts[4].replaceAll('%', '');
          final usePct = double.tryParse(pctStr) ?? 0.0;
          final mnt = parts[5];
          dfData[mnt] = {
            'dev': dev,
            'sizeBytes': sizeKb * 1024,
            'usedBytes': usedKb * 1024,
            'availBytes': availKb * 1024,
            'usePct': usePct,
          };
        }
      }

      // 4. df -i
      final Map<String, Map<String, dynamic>> inodeData = {};
      final dfiOut = await runner.runCommand('df -i 2>/dev/null');
      for (final line in dfiOut.split('\n')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 6 && parts[1] != 'Inodes') {
          final totalInodes = int.tryParse(parts[1]) ?? 0;
          final usedInodes = int.tryParse(parts[2]) ?? 0;
          final freeInodes = int.tryParse(parts[3]) ?? 0;
          final pctStr = parts[4].replaceAll('%', '');
          final inodePct = double.tryParse(pctStr) ?? 0.0;
          final mnt = parts[5];
          inodeData[mnt] = {
            'totalInodes': totalInodes,
            'usedInodes': usedInodes,
            'freeInodes': freeInodes,
            'inodePct': inodePct,
          };
        }
      }

      // 5. System Properties for scheme
      final slotSuffix = (await runner.runCommand('getprop ro.boot.slot_suffix 2>/dev/null')).trim();
      final dynamicParts = (await runner.runCommand('getprop ro.boot.dynamic_partitions 2>/dev/null')).trim();
      final abUpdate = (await runner.runCommand('getprop ro.build.ab_update 2>/dev/null')).trim();

      String scheme = 'Legacy System-As-Root (Non-A/B)';
      if (dynamicParts == 'true') {
        scheme = 'Dynamic Partitions (Super Partition)';
      } else if (abUpdate == 'true' || slotSuffix.isNotEmpty) {
        scheme = 'A/B Seamless Update (Slot ${slotSuffix.replaceAll("_", "").toUpperCase()})';
      }

      String getCategory(String name, String? mountPoint) {
        final u = name.toUpperCase();
        final m = (mountPoint ?? '').toLowerCase();
        if (u.contains('SYSTEM') || u.contains('VENDOR') || u.contains('PRODUCT') || u.contains('ODM') || m == '/' || m == '/vendor' || m == '/system') {
          return 'System & OS';
        }
        if (u.contains('BOOT') || u.contains('RECOVERY') || u.contains('DTB') || u.contains('VBMETA')) {
          return 'Boot & Kernel';
        }
        if (u.contains('RADIO') || u.contains('MODEM') || u.contains('EFS') || u.contains('CP_') || u.contains('M9KEFS')) {
          return 'Radio & Modem';
        }
        if (u.contains('PARAM') || u.contains('PERSIST') || u.contains('STEADY') || u.contains('BOTA') || u.contains('MISC') || u.contains('NAD_')) {
          return 'Firmware & Security';
        }
        if (u.contains('USERDATA') || u.contains('DATA') || u.contains('CACHE') || u.contains('HIDDEN') || u.contains('OMR') || m.startsWith('/data') || m.startsWith('/storage') || m == '/cache') {
          return 'User Storage & Cache';
        }
        return 'Virtual Filesystems';
      }

      final List<PartitionInfo> loaded = [];
      final Set<String> processedMounts = {};

      byNameMap.forEach((name, blockDev) {
        String? mnt;
        String? fsType;
        String? mountOpts;

        if (blockMountMap.containsKey(blockDev)) {
          mnt = blockMountMap[blockDev]?['mountPoint'];
          fsType = blockMountMap[blockDev]?['fsType'];
          mountOpts = blockMountMap[blockDev]?['options'];
        } else {
          final uName = name.toUpperCase();
          if (uName == 'SYSTEM') {
            mnt = '/';
          } else if (uName == 'VENDOR') {
            mnt = '/vendor';
          } else if (uName == 'CACHE') {
            mnt = '/cache';
          } else if (uName == 'USERDATA') {
            mnt = '/data';
          }

          if (mnt != null && mountMap.containsKey(mnt)) {
            fsType = mountMap[mnt]?['fsType'];
            mountOpts = mountMap[mnt]?['options'];
          }
        }

        if (mnt != null) processedMounts.add(mnt);

        final dfInfo = mnt != null ? dfData[mnt] : null;
        final inoInfo = mnt != null ? inodeData[mnt] : null;
        final isRo = mountOpts != null && (mountOpts.startsWith('ro,') || mountOpts.contains(',ro,') || mountOpts.contains('ro'));

        loaded.add(PartitionInfo(
          name: name,
          blockDevice: blockDev,
          mountPoint: mnt,
          fsType: fsType,
          mountFlags: mountOpts,
          sizeBytes: dfInfo?['sizeBytes'],
          usedBytes: dfInfo?['usedBytes'],
          availBytes: dfInfo?['availBytes'],
          usePercentage: dfInfo?['usePct'],
          totalInodes: inoInfo?['totalInodes'],
          usedInodes: inoInfo?['usedInodes'],
          freeInodes: inoInfo?['freeInodes'],
          inodeUsePct: inoInfo?['inodePct'],
          isReadOnly: isRo,
          category: getCategory(name, mnt),
        ));
      });

      dfData.forEach((mnt, data) {
        if (!processedMounts.contains(mnt)) {
          final dev = data['dev'] as String? ?? '';
          final mntInfo = mountMap[mnt];
          final inoInfo = inodeData[mnt];
          final opts = mntInfo?['options'];
          final isRo = opts != null && (opts.startsWith('ro,') || opts.contains(',ro,'));

          String displayName = mnt.replaceAll('/', '').toUpperCase();
          if (displayName.isEmpty) displayName = 'ROOTFS';
          if (mnt == '/data') displayName = 'USERDATA';

          loaded.add(PartitionInfo(
            name: displayName,
            blockDevice: dev,
            mountPoint: mnt,
            fsType: mntInfo?['fsType'] ?? 'ext4',
            mountFlags: opts,
            sizeBytes: data['sizeBytes'],
            usedBytes: data['usedBytes'],
            availBytes: data['availBytes'],
            usePercentage: data['usePct'],
            totalInodes: inoInfo?['totalInodes'],
            usedInodes: inoInfo?['usedInodes'],
            freeInodes: inoInfo?['freeInodes'],
            inodeUsePct: inoInfo?['inodePct'],
            isReadOnly: isRo,
            category: getCategory(displayName, mnt),
          ));
        }
      });

      int totalBytes = 0;
      int usedBytes = 0;
      int totalIno = 0;
      int usedIno = 0;
      for (final p in loaded) {
        if (p.sizeBytes != null) {
          totalBytes += p.sizeBytes!;
          usedBytes += (p.usedBytes ?? 0);
        }
        if (p.totalInodes != null) {
          totalIno += p.totalInodes!;
          usedIno += (p.usedInodes ?? 0);
        }
      }

      setState(() {
        _partitions = loaded;
        _partitionScheme = scheme;
        _totalMountedBytes = totalBytes;
        _totalUsedBytes = usedBytes;
        _totalInodes = totalIno;
        _usedInodes = usedIno;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeTrim(String targetMount) async {
    final runner = ref.read(commandRunnerProvider);
    final isAll = targetMount == 'ALL';
    final targetLabel = isAll ? 'All Flash Partitions' : targetMount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Run Flash TRIM ($targetLabel)'),
        content: Text(
          'Automated TRIM executes the kernel fstrim ioctl across unused blocks to maintain NAND write endurance and reclaim erased flash blocks.\n\nTarget: $targetLabel',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Execute TRIM')),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Executing TRIM on $targetLabel...'), duration: const Duration(seconds: 2)),
    );

    String cmd = isAll ? 'fstrim -v /data; fstrim -v /cache; sm fstrim' : 'fstrim -v $targetMount';
    final result = await runner.runCommand(cmd);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TRIM Execution Result'),
        content: SelectableText(
          result.trim().isNotEmpty
              ? result
              : 'TRIM ioctl command dispatched successfully to block layer.',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  List<PartitionCategoryGroup> _buildCategoryGroups(List<PartitionInfo> partitions) {
    final Map<String, List<PartitionInfo>> map = {
      'System & OS': [],
      'Boot & Kernel': [],
      'Radio & Modem': [],
      'Firmware & Security': [],
      'User Storage & Cache': [],
      'Virtual Filesystems': [],
    };

    for (final p in partitions) {
      if (map.containsKey(p.category)) {
        map[p.category]!.add(p);
      } else {
        map['Virtual Filesystems']!.add(p);
      }
    }

    final List<PartitionCategoryGroup> groups = [];
    if (map['System & OS']!.isNotEmpty) {
      groups.add(PartitionCategoryGroup(
        title: 'Android System & OS Partitions',
        icon: Icons.dns_rounded,
        color: Colors.blueAccent,
        items: map['System & OS']!,
      ));
    }
    if (map['Boot & Kernel']!.isNotEmpty) {
      groups.add(PartitionCategoryGroup(
        title: 'Boot, Kernel & Recovery Subsystems',
        icon: Icons.memory_rounded,
        color: Colors.deepOrangeAccent,
        items: map['Boot & Kernel']!,
      ));
    }
    if (map['Radio & Modem']!.isNotEmpty) {
      groups.add(PartitionCategoryGroup(
        title: 'Radio, Modem & Baseband Firmware',
        icon: Icons.cell_tower_rounded,
        color: Colors.cyan,
        items: map['Radio & Modem']!,
      ));
    }
    if (map['Firmware & Security']!.isNotEmpty) {
      groups.add(PartitionCategoryGroup(
        title: 'Firmware, Security & Bootloader',
        icon: Icons.security_rounded,
        color: Colors.amber[700]!,
        items: map['Firmware & Security']!,
      ));
    }
    if (map['User Storage & Cache']!.isNotEmpty) {
      groups.add(PartitionCategoryGroup(
        title: 'User Storage & Cache Volumes',
        icon: Icons.storage_rounded,
        color: Colors.teal,
        items: map['User Storage & Cache']!,
      ));
    }
    if (map['Virtual Filesystems']!.isNotEmpty) {
      groups.add(PartitionCategoryGroup(
        title: 'Virtual Filesystems & Memory Mounts',
        icon: Icons.cloud_queue_rounded,
        color: Colors.purpleAccent,
        items: map['Virtual Filesystems']!,
      ));
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).colorScheme.outline;

    final categories = [
      'All',
      'System & OS',
      'Boot & Kernel',
      'Radio & Modem',
      'Firmware & Security',
      'User Storage & Cache',
      'Virtual Filesystems',
    ];

    final filtered = _partitions.where((p) {
      final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          (p.mountPoint?.toLowerCase().contains(q) ?? false) ||
          p.blockDevice.toLowerCase().contains(q) ||
          (p.fsType?.toLowerCase().contains(q) ?? false);
      return matchesCat && matchesQuery;
    }).toList();

    final groups = _buildCategoryGroups(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partition Manager', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded, size: 20),
            tooltip: 'Run Full TRIM',
            onPressed: () => _executeTrim('ALL'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadPartitionData,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy Partition Table',
            onPressed: () {
              final b = StringBuffer();
              b.writeln('=== ANDROID PARTITION MANAGER EXPORT ===');
              b.writeln('Scheme: $_partitionScheme');
              b.writeln('Total Partitions: ${_partitions.length}');
              b.writeln('');
              for (final p in _partitions) {
                b.writeln('${p.name.padRight(16)} | ${p.blockDevice.padRight(24)} | Mount: ${p.mountPoint ?? "Unmounted"} | FS: ${p.fsType ?? "Raw"} | Size: ${_formatBytes(p.sizeBytes)} | Used: ${_formatBytes(p.usedBytes)} (${p.usePercentage?.toStringAsFixed(0) ?? "0"}%) | Inodes: ${p.usedInodes ?? 0}/${p.totalInodes ?? 0}');
              }
              Clipboard.setData(ClipboardData(text: b.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partition table copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPartitionData,
              child: Column(
                children: [
                  // Search Bar matching DeviceManagerScreen
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search by partition name, mount point, node...',
                        hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.getSecondaryText(context)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161A24) : const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                  ),

                  // Architecture Scheme Banner & 3 Quick Stat Tiles
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_tree_rounded, size: 20, color: Colors.indigoAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PARTITION SCHEME',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.indigoAccent),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _partitionScheme,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatTile(
                                context,
                                title: 'Discovered',
                                value: '${_partitions.length}',
                                subtitle: 'Volumes',
                                icon: Icons.pie_chart_rounded,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatTile(
                                context,
                                title: 'VFS Space',
                                value: _formatBytes(_totalUsedBytes),
                                subtitle: 'of ${_formatBytes(_totalMountedBytes)}',
                                icon: Icons.folder_shared_rounded,
                                color: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatTile(
                                context,
                                title: 'Inodes',
                                value: _formatNumber(_usedInodes),
                                subtitle: 'of ${_formatNumber(_totalInodes)}',
                                icon: Icons.tag_rounded,
                                color: Colors.amber[700]!,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Category Filter Chips
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 38,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final cat = categories[idx];
                          final isSelected = cat == _selectedCategory;
                          final count = cat == 'All'
                              ? _partitions.length
                              : _partitions.where((p) => p.category == cat).length;

                          if (count == 0 && cat != 'All') return const SizedBox.shrink();

                          return ChoiceChip(
                            label: Text(
                              '$cat ($count)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Theme.of(context).colorScheme.primary,
                            backgroundColor: isDark ? const Color(0xFF1A1E29) : const Color(0xFFE5E7EB),
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = cat);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Partition Categories Accordion List (Matching DeviceManagerScreen exactly)
                  Expanded(
                    child: groups.isEmpty
                        ? Center(
                            child: Text(
                              'No partitions matching "$_searchQuery"',
                              style: TextStyle(color: AppTheme.getSecondaryText(context)),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];
                              return _buildGroupCard(context, group, isDark, borderColor);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupCard(BuildContext context, PartitionCategoryGroup group, bool isDark, Color borderColor) {
    final mountedCount = group.items.where((p) => p.mountPoint != null).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A24) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: group.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(group.icon, size: 20, color: group.color),
          ),
          title: Text(
            group.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${group.items.length} partitions • $mountedCount active VFS mounts',
            style: TextStyle(fontSize: 11, color: AppTheme.getSecondaryText(context)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: group.items.length,
                separatorBuilder: (_, _) => Divider(height: 16, color: borderColor.withValues(alpha: 0.5)),
                itemBuilder: (context, i) {
                  final p = group.items[i];
                  return _buildPartitionRow(context, p, isDark, borderColor);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartitionRow(BuildContext context, PartitionInfo p, bool isDark, Color borderColor) {
    final hasMount = p.mountPoint != null;
    final hasSize = p.sizeBytes != null && p.sizeBytes! > 0;
    final usePct = p.usePercentage ?? 0.0;

    return InkWell(
      onTap: () => _showPartitionDetails(p),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Name, Mount Point, Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.name,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                if (hasMount) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.mountPoint!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (hasMount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (p.isReadOnly ? Colors.amber : Colors.green).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.isReadOnly ? 'RO' : 'RW',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: p.isReadOnly ? Colors.amber[700] : Colors.green[700],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'RAW BLOCK',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 9.5,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Second Row: Block Node & Filesystem
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.blockDevice,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppTheme.getSecondaryText(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (p.fsType != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    p.fsType!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),

            // Third Row: Storage Usage Bar (if mounted)
            if (hasSize) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatBytes(p.usedBytes)} / ${_formatBytes(p.sizeBytes)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.getSecondaryText(context)),
                  ),
                  Text(
                    '${usePct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: usePct > 90 ? Colors.redAccent : (usePct > 75 ? Colors.amber[700] : Colors.teal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (usePct / 100.0).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: isDark ? const Color(0xFF232836) : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    usePct > 90 ? Colors.redAccent : (usePct > 75 ? Colors.amber[700]! : Colors.teal),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A24) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.getSecondaryText(context)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9.5, color: AppTheme.getSecondaryText(context)),
          ),
        ],
      ),
    );
  }

  void _showPartitionDetails(PartitionInfo p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF11141B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (p.mountPoint != null && !p.isReadOnly)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.cleaning_services_rounded, size: 14),
                      label: const Text('TRIM Partition', style: TextStyle(fontSize: 11.5)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _executeTrim(p.mountPoint!);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildPropRow('Block Device', p.blockDevice),
              if (p.mountPoint != null) _buildPropRow('Mount Point', p.mountPoint!),
              _buildPropRow('Category', p.category),
              if (p.fsType != null) _buildPropRow('Filesystem', p.fsType!.toUpperCase()),
              if (p.mountFlags != null) _buildPropRow('Mount Flags', p.mountFlags!),
              if (p.sizeBytes != null) _buildPropRow('Total Capacity', _formatBytes(p.sizeBytes)),
              if (p.usedBytes != null) _buildPropRow('Used Space', '${_formatBytes(p.usedBytes)} (${p.usePercentage?.toStringAsFixed(1)}%)'),
              if (p.availBytes != null) _buildPropRow('Available Space', _formatBytes(p.availBytes)),
              if (p.totalInodes != null) _buildPropRow('Inodes Total', _formatNumber(p.totalInodes)),
              if (p.usedInodes != null) _buildPropRow('Inodes Used', '${_formatNumber(p.usedInodes)} (${p.inodeUsePct?.toStringAsFixed(1)}%)'),
              _buildPropRow('Protection', p.isReadOnly ? 'Read-Only (dm-verity integrity secured)' : (p.mountPoint != null ? 'Read-Write (Active Volume)' : 'Raw Block (Unmounted)')),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Path'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: p.blockDevice));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Block path copied!')));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.developer_board_rounded, size: 16),
                      label: const Text('Inspect Blocks'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final runner = ref.read(commandRunnerProvider);
                        final out = await runner.runCommand('ls -ld "${p.blockDevice}"; blockdev --getsize64 "${p.blockDevice}" 2>/dev/null');
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: Text('Block Inspection: ${p.name}'),
                            content: SelectableText(out.isNotEmpty ? out : 'No block geometry available for node.', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                            actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Done'))],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: (label.contains('Path') || label.contains('Flags') || label.contains('Block')) ? 'monospace' : null,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(i > 1 ? 2 : 0)} ${suffixes[i]}';
  }

  String _formatNumber(int? n) {
    if (n == null || n <= 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
