import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/command_runner.dart';
import '../services/xapk_service.dart';
import '../theme/app_theme.dart';

class PackageInstallerSheet extends ConsumerStatefulWidget {
  final ApkMetadata metadata;

  const PackageInstallerSheet({
    super.key,
    required this.metadata,
  });

  static Future<void> show(BuildContext context, ApkMetadata metadata) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PackageInstallerSheet(metadata: metadata),
    );
  }

  @override
  ConsumerState<PackageInstallerSheet> createState() => _PackageInstallerSheetState();
}

class _PackageInstallerSheetState extends ConsumerState<PackageInstallerSheet> {
  bool _isInstalling = false;
  double _installProgress = 0.0;
  String _installStatus = '';
  String? _errorMessage;
  bool _installComplete = false;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _startInstall() async {
    setState(() {
      _isInstalling = true;
      _installProgress = 0.05;
      _installStatus = 'Initializing installer...';
      _errorMessage = null;
      _installComplete = false;
    });

    try {
      final runner = ref.read(commandRunnerProvider);
      final success = await XapkService.installPackage(
        metadata: widget.metadata,
        runner: runner,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _installProgress = progress;
              _installStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isInstalling = false;
          _installComplete = success;
          if (success) {
            _installStatus = widget.metadata.isXapk
                ? 'Split package installation dispatched! Follow system prompt.'
                : 'Installation started. Complete the installation on your device.';
          } else {
            _errorMessage = 'Installation process could not be completed.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _installStatus = 'Installation error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.metadata;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131722) : Colors.white,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Main Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Header Card
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2333) : const Color(0xFFEDF2F7),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: meta.iconBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.memory(
                                  meta.iconBytes!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                meta.isXapk ? Icons.dashboard_customize_rounded : Icons.android_rounded,
                                size: 40,
                                color: meta.isXapk ? Colors.amber : Colors.green,
                              ),
                      ),
                      const SizedBox(width: 16),
                      // Title & Package details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta.appName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              meta.packageName,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.getSecondaryText(context),
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'v${meta.versionName} (${meta.versionCode}) • ${_formatBytes(meta.fileSizeBytes)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Metadata Badges Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill(
                        context,
                        icon: meta.isXapk ? Icons.auto_awesome_motion_rounded : Icons.apps_rounded,
                        label: meta.isXapk ? 'XAPK Bundle (Splits)' : 'Standalone APK',
                        color: meta.isXapk ? Colors.amber : Colors.green,
                      ),
                      _buildPill(
                        context,
                        icon: Icons.layers_rounded,
                        label: 'Min SDK ${meta.minSdk} • Target ${meta.targetSdk}',
                        color: Colors.blueAccent,
                      ),
                      if (meta.splitApks.length > 1)
                        _buildPill(
                          context,
                          icon: Icons.pie_chart_outline_rounded,
                          label: '${meta.splitApks.length} Split APKs',
                          color: Colors.purpleAccent,
                        ),
                      if (meta.obbFiles.isNotEmpty)
                        _buildPill(
                          context,
                          icon: Icons.extension_rounded,
                          label: '${meta.obbFiles.length} OBB Expansions',
                          color: Colors.deepOrangeAccent,
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Split APK Breakdown (if XAPK)
                  if (meta.isXapk && meta.splitApks.isNotEmpty) ...[
                    const Text(
                      'Split Components Included',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B202D) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: meta.splitApks.map((split) {
                          final isBase = split.toLowerCase().contains('base');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  isBase ? Icons.star_rounded : Icons.check_circle_outline_rounded,
                                  size: 15,
                                  color: isBase ? Colors.amber : Colors.blueAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    split,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isBase ? FontWeight.w700 : FontWeight.w500,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // OBB Expansion Info (if present)
                  if (meta.obbFiles.isNotEmpty) ...[
                    const Text(
                      'OBB Game Assets',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storage_rounded, size: 16, color: Colors.deepOrange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Assets will be installed into /sdcard/Android/obb/${meta.packageName}/',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...meta.obbFiles.map(
                            (o) => Text(
                              '• $o',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.getSecondaryText(context),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Permissions Summary
                  if (meta.permissions.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text(
                          'Requested Permissions',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${meta.permissions.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B202D) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: meta.permissions.length,
                        itemBuilder: (ctx, idx) {
                          final perm = meta.permissions[idx];
                          final shortName = perm.split('.').last;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              children: [
                                const Icon(Icons.security_rounded, size: 13, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    shortName,
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Progress & Status Indicator
                  if (_isInstalling) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: _installProgress > 0 ? _installProgress : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _installStatus,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${(_installProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _installProgress,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Error Message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Success Message
                  if (_installComplete) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _installStatus,
                              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131722) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isInstalling ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_installComplete ? 'Done' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isInstalling ? null : _startInstall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: _isInstalling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(meta.isXapk ? Icons.downloading_rounded : Icons.install_mobile_rounded, size: 18),
                    label: Text(
                      _isInstalling
                          ? 'Installing...'
                          : (meta.isXapk ? 'Install XAPK Splits' : 'Install APK'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
