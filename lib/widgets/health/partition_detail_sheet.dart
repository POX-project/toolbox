import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/device_health_model.dart';
import '../../theme/app_theme.dart';

class PartitionDetailSheet extends StatefulWidget {
  final List<PartitionInfo> partitions;

  const PartitionDetailSheet({super.key, required this.partitions});

  @override
  State<PartitionDetailSheet> createState() => _PartitionDetailSheetState();
}

class _PartitionDetailSheetState extends State<PartitionDetailSheet> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF11141B) : Colors.white;
    final borderColor = Theme.of(context).colorScheme.outline;

    final categories = ['All', ...widget.partitions.map((p) => p.category).toSet()];

    final filtered = widget.partitions.where((p) {
      final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          (p.mountPoint?.toLowerCase().contains(q) ?? false) ||
          p.blockDevice.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          (p.fsType?.toLowerCase().contains(q) ?? false);
      return matchesCat && matchesQuery;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.pie_chart_rounded, color: Colors.indigoAccent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Flash Partitions & Volumes',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.partitions.length} partitions discovered from kernel block table',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getSecondaryText(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      tooltip: 'Copy Partition Table',
                      onPressed: () {
                        final buffer = StringBuffer();
                        buffer.writeln('=== ANDROID HARDWARE PARTITION TABLE ===');
                        for (final p in widget.partitions) {
                          buffer.writeln('${p.name.padRight(16)} | ${p.blockDevice.padRight(24)} | Mount: ${p.mountPoint ?? "Unmounted"} | FS: ${p.fsType ?? "Raw"} | Size: ${_formatBytes(p.sizeBytes)} | Used: ${_formatBytes(p.usedBytes)} (${p.usePercentage?.toStringAsFixed(0) ?? "0"}%) | Inodes: ${p.usedInodes ?? 0}/${p.totalInodes ?? 0}');
                        }
                        Clipboard.setData(ClipboardData(text: buffer.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Partition table copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search partitions, mount points, block nodes...',
                    hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.getSecondaryText(context)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1E29) : const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),

              // Category Filter Chips
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == _selectedCategory;
                    final count = cat == 'All'
                        ? widget.partitions.length
                        : widget.partitions.where((p) => p.category == cat).length;

                    return ChoiceChip(
                      label: Text(
                        '$cat ($count)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: isDark ? const Color(0xFF1E2330) : const Color(0xFFE5E7EB),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        }
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 12),

              // Partitions List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No partitions matching "$_searchQuery"',
                          style: TextStyle(fontSize: 13, color: AppTheme.getSecondaryText(context)),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final partition = filtered[index];
                          return _buildPartitionCard(context, partition, isDark, borderColor);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartitionCard(
    BuildContext context,
    PartitionInfo p,
    bool isDark,
    Color borderColor,
  ) {
    final isMounted = p.mountPoint != null;
    final hasCapacity = p.sizeBytes != null && p.sizeBytes! > 0;
    final usePct = p.usePercentage ?? 0.0;
    final inodePct = p.inodeUsePct ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A24) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name, Badges (Mount state, Category, RO/RW)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (p.mountPoint != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.mountPoint!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.blockDevice,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.getSecondaryText(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Category & Status Badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222836) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isMounted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (p.isReadOnly ? Colors.amber : const Color(0xFF10B981)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.isReadOnly ? 'Read-Only (dm-verity)' : 'Read-Write (Active)',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: p.isReadOnly ? Colors.amber[700] : const Color(0xFF10B981),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Unmounted Block',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getSecondaryText(context),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Row 2: Filesystem & Mount options
          if (p.fsType != null || p.mountFlags != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (p.fsType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.fsType!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ),
                if (p.mountFlags != null)
                  Expanded(
                    child: Text(
                      p.mountFlags!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.getSecondaryText(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Row 3: Storage Capacity Progress Bar (if mounted with df data)
          if (hasCapacity) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Storage: ${_formatBytes(p.usedBytes)} of ${_formatBytes(p.sizeBytes)} used',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${usePct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _getProgressColor(usePct),
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
                backgroundColor: isDark ? const Color(0xFF222836) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(usePct)),
              ),
            ),
          ],

          // Row 4: Inode Usage Progress Bar (if inode data available)
          if (p.totalInodes != null && p.totalInodes! > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inodes: ${_formatNumber(p.usedInodes ?? 0)} / ${_formatNumber(p.totalInodes!)} used',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
                Text(
                  '${inodePct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _getProgressColor(inodePct),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (inodePct / 100.0).clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: isDark ? const Color(0xFF222836) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(inodePct)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getProgressColor(double pct) {
    if (pct >= 90) return Colors.redAccent;
    if (pct >= 75) return Colors.orangeAccent;
    return const Color(0xFF10B981);
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 B';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  String _formatNumber(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000.0).toStringAsFixed(2)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000.0).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}
