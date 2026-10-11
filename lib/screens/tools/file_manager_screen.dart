import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/archive_service.dart';
import '../../services/command_runner.dart';
import '../../services/xapk_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fast_preview_modal.dart';
import '../../widgets/package_installer_sheet.dart';

enum ViewMode { detailedList, compactList, grid }
enum SortField { name, date, size, type }

class FileItem {
  final String name;
  final String fullPath;
  final bool isDirectory;
  final bool isLink;
  final String? linkTarget;
  final int sizeBytes;
  final String permissions;
  final String owner;
  final String modified;
  final bool isArchive;

  const FileItem({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    this.isLink = false,
    this.linkTarget,
    this.sizeBytes = 0,
    this.permissions = '',
    this.owner = '',
    this.modified = '',
    this.isArchive = false,
  });
}

String shellEscapePath(String path) {
  return "'${path.replaceAll("'", "'\\''")}'";
}

FileItem? parseLsLine(String line, String currentDir) {
  final tLine = line.trim();
  if (tLine.isEmpty || tLine.startsWith('total')) return null;

  // Regex matching ISO timestamp (2026-10-11 06:02:15 or 2026-10-11 06:02)
  // or traditional UNIX timestamp (Oct 11 06:02 or Oct 11 2025)
  final tsRegex = RegExp(
    r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+(?:\d{2}:\d{2}|\d{4}))',
  );

  final match = tsRegex.firstMatch(tLine);
  if (match == null) {
    final parts = tLine.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final perms = parts[0];
    final name = parts.last;
    if (name == '.' || name == '..') return null;
    final isDir = perms.startsWith('d');
    final isLink = perms.startsWith('l');
    final itemPath = currentDir == '/' ? '/$name' : '$currentDir/$name';
    return FileItem(
      name: name,
      fullPath: itemPath,
      isDirectory: isDir,
      isLink: isLink,
      permissions: perms,
      isArchive: !isDir && ArchiveService.isArchive(itemPath),
    );
  }

  final mod = match.group(0)!;
  final nameSection = tLine.substring(match.end).trim();
  if (nameSection.isEmpty || nameSection == '.' || nameSection == '..') return null;

  final prefix = tLine.substring(0, match.start).trim();
  final tokens = prefix.split(RegExp(r'\s+'));
  final perms = tokens.isNotEmpty ? tokens[0] : '';
  final size = tokens.length >= 2 ? (int.tryParse(tokens.last) ?? 0) : 0;
  final owner = tokens.length >= 4
      ? tokens.sublist(tokens.length - 3, tokens.length - 1).join(':')
      : (tokens.length >= 3 ? tokens[1] : '');

  String name = nameSection;
  String? target;
  bool isLink = perms.startsWith('l');

  if (nameSection.contains(' -> ')) {
    final linkParts = nameSection.split(' -> ');
    name = linkParts[0].trim();
    target = linkParts[1].trim();
    isLink = true;
  }

  bool isDir = perms.startsWith('d');
  final itemPath = currentDir == '/' ? '/$name' : '$currentDir/$name';

  // Resolve symlink directory
  if (isLink) {
    try {
      if (FileSystemEntity.typeSync(itemPath, followLinks: true) == FileSystemEntityType.directory) {
        isDir = true;
      }
    } catch (_) {}

    if (!isDir && target != null) {
      if (target.endsWith('/') ||
          target.startsWith('/storage') ||
          target.startsWith('/data') ||
          target.startsWith('/system') ||
          name == 'sdcard' ||
          name == 'vendor' ||
          name == 'etc' ||
          name == 'product') {
        isDir = true;
      }
    }
  }

  return FileItem(
    name: name,
    fullPath: itemPath,
    isDirectory: isDir,
    isLink: isLink,
    linkTarget: target,
    sizeBytes: size,
    permissions: perms,
    owner: owner,
    modified: mod,
    isArchive: !isDir && ArchiveService.isArchive(itemPath),
  );
}

class FileManagerScreen extends ConsumerStatefulWidget {
  final String initialPath;
  const FileManagerScreen({super.key, this.initialPath = '/sdcard'});

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> with WidgetsBindingObserver {
  static const _platform = MethodChannel('com.txorav.andbox/native');

  late String _currentPath;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<FileItem> _items = [];
  String _errorMsg = '';
  String _mountFreeSpace = '';
  bool _hasStoragePermission = true;

  // Multi-Selection State
  bool _isMultiSelect = false;
  final Set<String> _selectedPaths = {};

  // Clipboard State
  List<String> _clipboardPaths = [];
  bool _isCutOperation = false;

  // View & Sort Settings
  ViewMode _viewMode = ViewMode.detailedList;
  SortField _sortField = SortField.type;
  bool _sortAscending = true;
  bool _showHiddenFiles = false;

  // Virtual Archive Mode (ZArchiver style)
  bool _isViewingArchive = false;
  String? _activeArchivePath;
  List<ArchiveEntry> _allArchiveEntries = [];
  String _archiveInnerDir = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPath = widget.initialPath;
    _checkStoragePermission();
    _loadDirectory(_currentPath);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStoragePermission();
    }
  }

  Future<void> _checkStoragePermission() async {
    try {
      final bool granted = await _platform.invokeMethod('isStorageManager') ?? false;
      if (mounted) {
        setState(() => _hasStoragePermission = granted);
      }
    } catch (_) {}
  }

  Future<void> _requestStoragePermission() async {
    try {
      await _platform.invokeMethod('requestStoragePermission');
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 800));
    await _checkStoragePermission();
    _loadDirectory(_currentPath);
  }

  String _shellEscape(String path) => shellEscapePath(path);

  FileItem? _parseLsLine(String line, String currentDir) => parseLsLine(line, currentDir);


  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _currentPath = path;
      _errorMsg = '';
      _isViewingArchive = false;
      _activeArchivePath = null;
    });

    final runner = ref.read(commandRunnerProvider);
    final List<FileItem> loaded = [];

    // 1. Try POSIX Dart Directory
    bool dartSuccess = false;
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final entities = await dir.list(followLinks: false).toList();
        for (final e in entities) {
          final segments = e.uri.pathSegments.where((s) => s.isNotEmpty);
          final name = segments.isNotEmpty ? segments.last : e.path.split('/').last;
          if (!_showHiddenFiles && name.startsWith('.')) continue;

          bool isDir = e is Directory;
          bool isLink = e is Link;
          String? linkTarget;
          int size = 0;
          String modified = '';
          String perms = '';

          try {
            final stat = e.statSync();
            if (stat.type == FileSystemEntityType.directory) isDir = true;
            if (stat.type == FileSystemEntityType.link) isLink = true;
            size = stat.size;
            modified = stat.modified.toString().split('.').first;
            perms = stat.modeString();

            if (isLink) {
              try {
                linkTarget = Link(e.path).targetSync();
              } catch (_) {}

              if (!isDir && linkTarget != null) {
                if (linkTarget.endsWith('/') ||
                    linkTarget.startsWith('/storage') ||
                    linkTarget.startsWith('/data') ||
                    name == 'sdcard' ||
                    name == 'vendor' ||
                    name == 'etc') {
                  isDir = true;
                }
              }
            }
          } catch (_) {}

          loaded.add(FileItem(
            name: name,
            fullPath: e.path,
            isDirectory: isDir,
            isLink: isLink,
            linkTarget: linkTarget,
            sizeBytes: size,
            permissions: perms,
            modified: modified,
            isArchive: !isDir && ArchiveService.isArchive(e.path),
          ));
        }
        dartSuccess = true;
      }
    } catch (_) {
      dartSuccess = false;
    }

    // 2. Shell Fallback (for root/system/restricted paths or if Dart failed)
    if (!dartSuccess) {
      try {
        final flag = _showHiddenFiles ? '-la' : '-l';
        final escPath = _shellEscape(path);
        final lsOut = await runner.runCommand('ls $flag $escPath 2>/dev/null');
        if (lsOut.isNotEmpty && !lsOut.contains('Permission denied')) {
          loaded.clear();
          for (final line in lsOut.split('\n')) {
            final item = _parseLsLine(line, path);
            if (item != null) {
              if (!_showHiddenFiles && item.name.startsWith('.')) continue;
              loaded.add(item);
            }
          }
        } else if (lsOut.contains('Permission denied')) {
          _errorMsg = 'Permission Restricted by SELinux.\nAccess to this partition requires elevated Root or Shizuku privilege.';
        }
      } catch (e) {
        _errorMsg = 'Error reading directory: $e';
      }
    }

    _sortItems(loaded);

    // Immediately present items without blocking on df
    if (mounted) {
      setState(() {
        _items = loaded;
        _isLoading = false;
      });
    }

    // Mount Free Space in background
    try {
      final escPath = _shellEscape(path);
      runner.runCommand('df -h $escPath 2>/dev/null').then((dfOut) {
        if (!mounted) return;
        final lines = dfOut.trim().split('\n');
        if (lines.length >= 2) {
          final p = lines[1].trim().split(RegExp(r'\s+'));
          if (p.length >= 5) {
            setState(() {
              _mountFreeSpace = '${p[3]} Free of ${p[1]} (${p[4]} used)';
            });
          }
        }
      });
    } catch (_) {}
  }


  void _sortItems(List<FileItem> list) {
    list.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int comp = 0;
      switch (_sortField) {
        case SortField.name:
          comp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortField.date:
          comp = a.modified.compareTo(b.modified);
          break;
        case SortField.size:
          comp = a.sizeBytes.compareTo(b.sizeBytes);
          break;
        case SortField.type:
          final extA = a.name.contains('.') ? a.name.split('.').last : '';
          final extB = b.name.contains('.') ? b.name.split('.').last : '';
          comp = extA.compareTo(extB);
          if (comp == 0) comp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
      }
      return _sortAscending ? comp : -comp;
    });
  }

  void _navigateUp() {
    if (_isViewingArchive) {
      if (_archiveInnerDir.isEmpty) {
        // Exit archive view
        _loadDirectory(_currentPath);
      } else {
        final lastSlash = _archiveInnerDir.lastIndexOf('/');
        setState(() {
          _archiveInnerDir = lastSlash <= 0 ? '' : _archiveInnerDir.substring(0, lastSlash);
        });
      }
      return;
    }

    if (_currentPath == '/') return;
    final lastSlash = _currentPath.lastIndexOf('/');
    final parent = lastSlash <= 0 ? '/' : _currentPath.substring(0, lastSlash);
    _loadDirectory(parent);
  }

  // ==================== ZARCHIVER: VIRTUAL ARCHIVE BROWSING ====================

  Future<void> _openVirtualArchive(String archivePath) async {
    setState(() => _isLoading = true);
    try {
      final entries = await ArchiveService.listEntries(archivePath);
      setState(() {
        _isViewingArchive = true;
        _activeArchivePath = archivePath;
        _allArchiveEntries = entries;
        _archiveInnerDir = '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open archive: $e')));
      }
    }
  }

  List<ArchiveEntry> _getVisibleArchiveEntries() {
    final prefix = _archiveInnerDir.isEmpty ? '' : '$_archiveInnerDir/';
    final Map<String, ArchiveEntry> map = {};

    for (final e in _allArchiveEntries) {
      if (_archiveInnerDir.isEmpty) {
        final slashIndex = e.path.indexOf('/');
        if (slashIndex == -1) {
          map[e.path] = e;
        } else {
          final topFolder = e.path.substring(0, slashIndex);
          map[topFolder] = ArchiveEntry(
            path: topFolder,
            name: topFolder,
            isDirectory: true,
            uncompressedSize: 0,
          );
        }
      } else if (e.path.startsWith(prefix) && e.path != _archiveInnerDir) {
        final relative = e.path.substring(prefix.length);
        final slashIndex = relative.indexOf('/');
        if (slashIndex == -1) {
          map[relative] = e;
        } else {
          final nextFolder = relative.substring(0, slashIndex);
          map[nextFolder] = ArchiveEntry(
            path: '$prefix$nextFolder',
            name: nextFolder,
            isDirectory: true,
            uncompressedSize: 0,
          );
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> _handleArchiveEntryTap(ArchiveEntry entry) async {
    if (entry.isDirectory) {
      setState(() => _archiveInnerDir = entry.path);
    } else {
      // Preview file inside archive
      setState(() => _isLoading = true);
      try {
        final bytes = await ArchiveService.readFileFromArchive(
          archivePath: _activeArchivePath!,
          innerFilePath: entry.path,
        );
        setState(() => _isLoading = false);
        if (bytes != null && mounted) {
          final content = String.fromCharCodes(bytes);
          _showTextEditor(
            fileName: entry.name,
            filePath: '[Archive] ${entry.path}',
            content: content,
            readOnly: true,
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot preview: $e')));
        }
      }
    }
  }

  // ==================== ZARCHIVER: ARCHIVE ACTIONS DIALOG ====================

  void _showArchiveOptions(FileItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF11141B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.archive_rounded, size: 24, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ZArchiver Primary Actions
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_open_rounded, color: Colors.blueAccent),
                title: const Text('Open Archive (View Contents)', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Browse files inside archive without extracting'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openVirtualArchive(item.fullPath);
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.unarchive_rounded, color: Colors.green),
                title: const Text('Extract Here', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Extract files into $_currentPath'),
                onTap: () {
                  Navigator.pop(ctx);
                  _extractArchive(item.fullPath, _currentPath);
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.create_new_folder_rounded, color: Colors.teal),
                title: Text('Extract to ${item.name.split(".").first}/', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Create folder and extract contents'),
                onTap: () {
                  Navigator.pop(ctx);
                  final folder = item.name.split('.').first;
                  final target = _currentPath == '/' ? '/$folder' : '$_currentPath/$folder';
                  _extractArchive(item.fullPath, target);
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.verified_rounded, color: Colors.indigoAccent),
                title: const Text('Test Archive Integrity', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Verify archive headers and CRC checksums'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final res = await ArchiveService.testArchive(item.fullPath);
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Archive Integrity Test'),
                      content: Text(res),
                      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
                    ),
                  );
                },
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.info_outline_rounded, size: 16),
                    label: const Text('Properties'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showFileProperties(item);
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                    label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteItem(item);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _extractArchive(String archivePath, String targetDir) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Extracting Archive...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text('Target: $targetDir', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ],
        ),
      ),
    );

    try {
      await ArchiveService.extractArchive(
        archivePath: archivePath,
        destinationDir: targetDir,
      );
      if (mounted) Navigator.pop(context); // Close dialog
      _loadDirectory(_currentPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archive successfully extracted to $targetDir')));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Extraction failed: $e')));
      }
    }
  }

  // ==================== ZARCHIVER: CREATE ARCHIVE (COMPRESSION) ====================

  void _showCreateArchiveDialog(List<String> paths) {
    final nameController = TextEditingController(text: paths.length == 1 ? paths.first.split('/').last : 'archive');
    String selectedFormat = 'zip';
    int compressionLevel = 6;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.archive_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Text('Compress Archive', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Compressing ${paths.length} item(s)', style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context))),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Archive Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Archive Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 8,
                children: ['zip', 'tar', 'tar.gz'].map((fmt) {
                  return ChoiceChip(
                    label: Text(fmt.toUpperCase(), style: const TextStyle(fontSize: 11)),
                    selected: selectedFormat == fmt,
                    onSelected: (val) {
                      if (val) setDlgState(() => selectedFormat = fmt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text('Compression Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              DropdownButton<int>(
                value: compressionLevel,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Store (No compression / Fastest)')),
                  DropdownMenuItem(value: 1, child: Text('Fast (Speed prioritized)')),
                  DropdownMenuItem(value: 6, child: Text('Normal (Balanced)')),
                  DropdownMenuItem(value: 9, child: Text('Maximum (Smallest size)')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => compressionLevel = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ext = selectedFormat == 'tar.gz' ? '.tar.gz' : '.$selectedFormat';
                final outName = nameController.text.trim().endsWith(ext)
                    ? nameController.text.trim()
                    : '${nameController.text.trim()}$ext';
                final outPath = _currentPath == '/' ? '/$outName' : '$_currentPath/$outName';

                _executeCompression(paths, outPath, selectedFormat, compressionLevel);
              },
              child: const Text('Compress'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeCompression(List<String> paths, String outPath, String format, int level) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Compressing Archive...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text('Creating: ${outPath.split("/").last}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );

    try {
      await ArchiveService.createArchive(
        sourcePaths: paths,
        outputFilePath: outPath,
        format: format,
        compressionLevel: level,
      );
      if (mounted) Navigator.pop(context);
      _loadDirectory(_currentPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archive created: ${outPath.split("/").last}')));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Compression failed: $e')));
      }
    }
  }

  // ==================== ZARCHIVER: PERMISSIONS (CHMOD) ====================

  void _showPermissionsDialog(FileItem item) {
    int permValue = 0755;
    if (item.permissions.isNotEmpty && item.permissions.length >= 10) {
      int val = 0;
      if (item.permissions[1] == 'r') val += 0400;
      if (item.permissions[2] == 'w') val += 0200;
      if (item.permissions[3] == 'x') val += 0100;
      if (item.permissions[4] == 'r') val += 0040;
      if (item.permissions[5] == 'w') val += 0020;
      if (item.permissions[6] == 'x') val += 0010;
      if (item.permissions[7] == 'r') val += 0004;
      if (item.permissions[8] == 'w') val += 0002;
      if (item.permissions[9] == 'x') val += 0001;
      permValue = val;
    }

    bool uR = (permValue & 0400) != 0;
    bool uW = (permValue & 0200) != 0;
    bool uX = (permValue & 0100) != 0;

    bool gR = (permValue & 0040) != 0;
    bool gW = (permValue & 0020) != 0;
    bool gX = (permValue & 0010) != 0;

    bool oR = (permValue & 0004) != 0;
    bool oW = (permValue & 0002) != 0;
    bool oX = (permValue & 0001) != 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          int calcOctal() {
            int u = (uR ? 4 : 0) + (uW ? 2 : 0) + (uX ? 1 : 0);
            int g = (gR ? 4 : 0) + (gW ? 2 : 0) + (gX ? 1 : 0);
            int o = (oR ? 4 : 0) + (oW ? 2 : 0) + (oX ? 1 : 0);
            return u * 64 + g * 8 + o;
          }

          String octalStr = '0${calcOctal().toRadixString(8).padLeft(3, "0")}';

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.security_rounded, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text('Permissions: $octalStr', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    const TableRow(children: [
                      Text('Target', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                      Center(child: Text('Read', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      Center(child: Text('Write', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      Center(child: Text('Execute', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                    ]),
                    TableRow(children: [
                      const Text('Owner', style: TextStyle(fontSize: 12)),
                      Checkbox(value: uR, onChanged: (v) => setDlgState(() => uR = v ?? false)),
                      Checkbox(value: uW, onChanged: (v) => setDlgState(() => uW = v ?? false)),
                      Checkbox(value: uX, onChanged: (v) => setDlgState(() => uX = v ?? false)),
                    ]),
                    TableRow(children: [
                      const Text('Group', style: TextStyle(fontSize: 12)),
                      Checkbox(value: gR, onChanged: (v) => setDlgState(() => gR = v ?? false)),
                      Checkbox(value: gW, onChanged: (v) => setDlgState(() => gW = v ?? false)),
                      Checkbox(value: gX, onChanged: (v) => setDlgState(() => gX = v ?? false)),
                    ]),
                    TableRow(children: [
                      const Text('Others', style: TextStyle(fontSize: 12)),
                      Checkbox(value: oR, onChanged: (v) => setDlgState(() => oR = v ?? false)),
                      Checkbox(value: oW, onChanged: (v) => setDlgState(() => oW = v ?? false)),
                      Checkbox(value: oX, onChanged: (v) => setDlgState(() => oX = v ?? false)),
                    ]),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final runner = ref.read(commandRunnerProvider);
                  await runner.runCommand('chmod $octalStr "${item.fullPath}" 2>/dev/null');
                  _loadDirectory(_currentPath);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permissions set to $octalStr')));
                  }
                },
                child: const Text('Apply chmod'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== ZARCHIVER: CHECKSUM CALCULATOR ====================

  Future<void> _calculateChecksums(FileItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Computing Hashes...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 12),
            Text('Calculating MD5, SHA-1, and SHA-256...'),
          ],
        ),
      ),
    );

    final runner = ref.read(commandRunnerProvider);
    final md5Out = await runner.runCommand('md5sum "${item.fullPath}" 2>/dev/null');
    final sha1Out = await runner.runCommand('sha1sum "${item.fullPath}" 2>/dev/null');
    final sha256Out = await runner.runCommand('sha256sum "${item.fullPath}" 2>/dev/null');

    final md5 = md5Out.split(RegExp(r'\s+')).first;
    final sha1 = sha1Out.split(RegExp(r'\s+')).first;
    final sha256 = sha256Out.split(RegExp(r'\s+')).first;

    if (mounted) Navigator.pop(context);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.fingerprint_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text('File Checksums', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const Divider(height: 16),
              _buildHashBlock('MD5', md5),
              const SizedBox(height: 10),
              _buildHashBlock('SHA-1', sha1),
              const SizedBox(height: 10),
              _buildHashBlock('SHA-256', sha256),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
    }
  }

  Widget _buildHashBlock(String label, String hash) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hash));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied!')));
              },
            ),
          ],
        ),
        SelectableText(
          hash.isNotEmpty ? hash : 'Error computing hash',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ],
    );
  }

  // ==================== ZARCHIVER: BUILT-IN TEXT EDITOR / VIEWER ====================

  Future<void> _openTextEditor(FileItem item) async {
    final runner = ref.read(commandRunnerProvider);
    String content = '';
    try {
      final file = File(item.fullPath);
      if (await file.exists()) {
        content = await file.readAsString();
      }
    } catch (_) {}

    if (content.isEmpty) {
      final esc = _shellEscape(item.fullPath);
      content = await runner.runCommand('cat $esc 2>/dev/null | head -n 1000');
    }

    _showTextEditor(
      fileName: item.name,
      filePath: item.fullPath,
      content: content,
      readOnly: false,
    );
  }

  void _showTextEditor({
    required String fileName,
    required String filePath,
    required String content,
    required bool readOnly,
  }) {
    final textController = TextEditingController(text: content);
    bool isModified = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setEditorState) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF11141B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.code_rounded, size: 20, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!readOnly && isModified)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.save_rounded, size: 14),
                        label: const Text('Save Changes', style: TextStyle(fontSize: 11.5)),
                        onPressed: () async {
                          final newText = textController.text;
                          bool saved = false;
                          try {
                            await File(filePath).writeAsString(newText);
                            saved = true;
                          } catch (_) {}

                          if (!saved) {
                            try {
                              final runner = ref.read(commandRunnerProvider);
                              final tempDir = Directory.systemTemp;
                              final tmpFile = File('${tempDir.path}/edit_${DateTime.now().millisecondsSinceEpoch}.txt');
                              await tmpFile.writeAsString(newText);
                              final escTmp = _shellEscape(tmpFile.path);
                              final escDest = _shellEscape(filePath);
                              await runner.runCommand('cat $escTmp > $escDest; rm -f $escTmp');
                              saved = true;
                            } catch (_) {}
                          }

                          setEditorState(() => isModified = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(saved ? 'File saved successfully!' : 'Failed to save file.')),
                            );
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Text',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: textController.text));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                      },
                    ),
                  ],
                ),
                Text(filePath, style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.getSecondaryText(context))),
                const Divider(height: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1218) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: textController,
                      readOnly: readOnly,
                      maxLines: null,
                      expands: true,
                      onChanged: (_) {
                        if (!isModified) setEditorState(() => isModified = true);
                      },
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== SMART TAP & FILE OPEN HANDLERS ====================

  void _handleFileTap(FileItem item) {
    if (item.isDirectory) {
      _loadDirectory(item.fullPath);
      return;
    }

    // Launch instant Fast Preview for all extensions (images, video, audio, text, fonts, apks/xapks, hex dumps)
    FastPreviewModal.show(
      context,
      item,
      onOpenFullEditor: () => _openTextEditor(item),
    );
  }

  Future<void> _installApk(String path) async {
    try {
      final runner = ref.read(commandRunnerProvider);
      bool invokedNative = false;
      try {
        await _platform.invokeMethod('installApk', {'filePath': path});
        invokedNative = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Launching Android Package Installer...')),
          );
        }
      } catch (_) {
        invokedNative = false;
      }

      if (!invokedNative) {
        final escPath = _shellEscape(path);
        final res = await runner.runCommand('pm install -r $escPath 2>&1');
        if (mounted) {
          if (res.contains('Success')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('APK installed successfully (Success)!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Install result: ${res.trim().isEmpty ? "Unknown" : res.trim()}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to install APK: $e')),
        );
      }
    }
  }

  // ==================== FILE OPERATIONS: CUT, COPY, PASTE, DELETE, RENAME ====================

  void _copySelected() {
    setState(() {
      _clipboardPaths = _selectedPaths.toList();
      _isCutOperation = false;
      _isMultiSelect = false;
      _selectedPaths.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${_clipboardPaths.length} item(s) to clipboard')));
  }

  void _cutSelected() {
    setState(() {
      _clipboardPaths = _selectedPaths.toList();
      _isCutOperation = true;
      _isMultiSelect = false;
      _selectedPaths.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cut ${_clipboardPaths.length} item(s) to clipboard')));
  }

  Future<void> _pasteClipboard() async {
    final runner = ref.read(commandRunnerProvider);
    int count = 0;
    for (final src in _clipboardPaths) {
      final name = src.split('/').last;
      final dest = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
      bool ok = false;
      try {
        if (_isCutOperation) {
          if (FileSystemEntity.isDirectorySync(src)) {
            Directory(src).renameSync(dest);
          } else {
            File(src).renameSync(dest);
          }
          ok = true;
        } else {
          if (FileSystemEntity.isFileSync(src)) {
            File(src).copySync(dest);
            ok = true;
          }
        }
      } catch (_) {}

      if (!ok) {
        final escSrc = _shellEscape(src);
        final escDest = _shellEscape(dest);
        if (_isCutOperation) {
          await runner.runCommand('mv $escSrc $escDest 2>/dev/null');
        } else {
          await runner.runCommand('cp -r $escSrc $escDest 2>/dev/null');
        }
      }
      count++;
    }

    setState(() {
      _clipboardPaths.clear();
      _isCutOperation = false;
    });
    _loadDirectory(_currentPath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pasted $count item(s) successfully!')));
    }
  }

  Future<void> _deleteItem(FileItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File/Folder'),
        content: Text('Are you sure you want to permanently delete "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    bool deleted = false;
    try {
      if (item.isDirectory) {
        final d = Directory(item.fullPath);
        if (await d.exists()) {
          await d.delete(recursive: true);
          deleted = true;
        }
      } else {
        final f = File(item.fullPath);
        if (await f.exists()) {
          await f.delete();
          deleted = true;
        }
      }
    } catch (_) {}

    if (!deleted) {
      final runner = ref.read(commandRunnerProvider);
      final esc = _shellEscape(item.fullPath);
      await runner.runCommand('rm -rf $esc 2>/dev/null');
    }

    _loadDirectory(_currentPath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "${item.name}"')));
    }
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text('Are you sure you want to permanently delete ${_selectedPaths.length} items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final runner = ref.read(commandRunnerProvider);
    for (final path in _selectedPaths) {
      bool deleted = false;
      try {
        if (FileSystemEntity.isDirectorySync(path)) {
          Directory(path).deleteSync(recursive: true);
          deleted = true;
        } else if (FileSystemEntity.isFileSync(path)) {
          File(path).deleteSync();
          deleted = true;
        }
      } catch (_) {}

      if (!deleted) {
        final esc = _shellEscape(path);
        await runner.runCommand('rm -rf $esc 2>/dev/null');
      }
    }

    setState(() {
      _selectedPaths.clear();
      _isMultiSelect = false;
    });
    _loadDirectory(_currentPath);
  }

  void _renameItem(FileItem item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'New Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != item.name) {
                final parent = item.fullPath.substring(0, item.fullPath.lastIndexOf('/'));
                final newPath = parent == '/' ? '/$newName' : '$parent/$newName';
                bool renamed = false;
                try {
                  if (item.isDirectory) {
                    await Directory(item.fullPath).rename(newPath);
                  } else {
                    await File(item.fullPath).rename(newPath);
                  }
                  renamed = true;
                } catch (_) {}

                if (!renamed) {
                  final runner = ref.read(commandRunnerProvider);
                  final escOld = _shellEscape(item.fullPath);
                  final escNew = _shellEscape(newPath);
                  await runner.runCommand('mv $escOld $escNew 2>/dev/null');
                }
                _loadDirectory(_currentPath);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _createNewFolder() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Folder Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final target = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
                bool created = false;
                try {
                  await Directory(target).create(recursive: true);
                  created = true;
                } catch (_) {}

                if (!created) {
                  final runner = ref.read(commandRunnerProvider);
                  final esc = _shellEscape(target);
                  await runner.runCommand('mkdir -p $esc 2>/dev/null');
                }
                _loadDirectory(_currentPath);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createNewFile() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New File'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'File Name (e.g. notes.txt)'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final target = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
                bool created = false;
                try {
                  await File(target).create(recursive: true);
                  created = true;
                } catch (_) {}

                if (!created) {
                  final runner = ref.read(commandRunnerProvider);
                  final esc = _shellEscape(target);
                  await runner.runCommand('touch $esc 2>/dev/null');
                }
                _loadDirectory(_currentPath);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }


  void _showFileProperties(FileItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF11141B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                children: [
                  Icon(
                    item.isDirectory ? Icons.folder_rounded : (item.isArchive ? Icons.archive_rounded : Icons.insert_drive_file_rounded),
                    size: 22,
                    color: item.isArchive ? Colors.amber : Colors.blueAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: 14),
              _buildPropRow('Absolute Path', item.fullPath),
              _buildPropRow('File Type', item.isDirectory ? 'Directory' : (item.isArchive ? 'Archive Volume' : (item.isLink ? 'Symlink' : 'Regular File'))),
              if (item.linkTarget != null) _buildPropRow('Symlink Target', item.linkTarget!),
              _buildPropRow('Size', '${_formatBytes(item.sizeBytes)} (${item.sizeBytes} bytes)'),
              if (item.permissions.isNotEmpty) _buildPropRow('Permissions', item.permissions),
              if (item.owner.isNotEmpty) _buildPropRow('Owner:Group', item.owner),
              if (item.modified.isNotEmpty) _buildPropRow('Last Modified', item.modified),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Path'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.fullPath));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Path copied to clipboard!')));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!item.isDirectory)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.fingerprint_rounded, size: 16),
                        label: const Text('Checksum'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _calculateChecksums(item);
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.security_rounded, size: 16),
                      label: const Text('chmod'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showPermissionsDialog(item);
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
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: AppTheme.getSecondaryText(context), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFamily: (label.contains('Path') || label.contains('Permissions') || label.contains('Owner')) ? 'monospace' : null,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(i > 1 ? 1 : 0)} ${suffixes[i]}';
  }

  // ==================== BUILD UI ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).colorScheme.outline;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isViewingArchive ? 'Archive: ${_activeArchivePath!.split("/").last}' : 'File Explorer',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (!_isViewingArchive) ...[
            IconButton(
              icon: Icon(_isMultiSelect ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 20),
              tooltip: 'Multi-Select',
              onPressed: () {
                setState(() {
                  _isMultiSelect = !_isMultiSelect;
                  if (!_isMultiSelect) _selectedPaths.clear();
                });
              },
            ),
            IconButton(
              icon: Icon(_showHiddenFiles ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
              tooltip: 'Show/Hide Hidden Files',
              onPressed: () {
                setState(() => _showHiddenFiles = !_showHiddenFiles);
                _loadDirectory(_currentPath);
              },
            ),
            PopupMenuButton<SortField>(
              icon: const Icon(Icons.sort_rounded, size: 20),
              tooltip: 'Sort By',
              onSelected: (sort) {
                setState(() {
                  if (_sortField == sort) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortField = sort;
                    _sortAscending = true;
                  }
                  _sortItems(_items);
                });
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: SortField.type, child: Text('Sort by Type')),
                const PopupMenuItem(value: SortField.name, child: Text('Sort by Name')),
                const PopupMenuItem(value: SortField.size, child: Text('Sort by Size')),
                const PopupMenuItem(value: SortField.date, child: Text('Sort by Date')),
              ],
            ),
            IconButton(
              icon: Icon(_viewMode == ViewMode.grid ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20),
              tooltip: 'Switch View Mode',
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == ViewMode.grid ? ViewMode.detailedList : ViewMode.grid;
                });
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: () => _isViewingArchive ? _openVirtualArchive(_activeArchivePath!) : _loadDirectory(_currentPath),
          ),
        ],
      ),
      body: Column(
        children: [
          // Path Breadcrumbs Bar
          _buildBreadcrumbsBar(isDark, borderColor),

          // Storage Permission Banner
          if (!_hasStoragePermission) _buildStoragePermissionBanner(),

          // Quick Volume Shortcuts (when not viewing archive)
          if (!_isViewingArchive) _buildShortcutsBar(isDark),

          // Multi-Select Header (when active)
          if (_isMultiSelect) _buildMultiSelectHeader(isDark),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: _isViewingArchive ? 'Search in archive...' : 'Search current directory...',
                hintStyle: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF161A24) : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              ),
            ),
          ),

          // Main Directory/Archive Content View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isViewingArchive
                    ? _buildArchiveView(isDark, borderColor)
                    : _buildFilesystemView(isDark, borderColor),
          ),

          // Floating Paste Toolbar (when clipboard has items)
          if (_clipboardPaths.isNotEmpty) _buildClipboardPasteBar(isDark),
        ],
      ),
      floatingActionButton: _isViewingArchive
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.unarchive_rounded),
              label: const Text('Extract All'),
              onPressed: () => _extractArchive(_activeArchivePath!, _currentPath),
            )
          : FloatingActionButton(
              child: const Icon(Icons.add_rounded),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.create_new_folder_rounded, color: Colors.blueAccent),
                        title: const Text('New Folder'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _createNewFolder();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.note_add_rounded, color: Colors.green),
                        title: const Text('New File'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _createNewFile();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.archive_rounded, color: Colors.amber),
                        title: const Text('Create Archive'),
                        subtitle: const Text('Compress files in this folder'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showCreateArchiveDialog([_currentPath]);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStoragePermissionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Storage Access Restricted',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.amber),
                ),
                Text(
                  'Grant All Files Access to browse /sdcard and internal storage.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _requestStoragePermission,
            child: const Text('Grant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ==================== BREADCRUMBS & SHORTCUTS ====================

  Widget _buildBreadcrumbsBar(bool isDark, Color borderColor) {
    if (_isViewingArchive) {
      final innerSegments = _archiveInnerDir.isEmpty ? <String>[] : _archiveInnerDir.split('/');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: Colors.amber.withValues(alpha: 0.08),
        child: Row(
          children: [
            InkWell(
              onTap: _navigateUp,
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.amber),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.archive_rounded, size: 16, color: Colors.amber),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => setState(() => _archiveInnerDir = ''),
              child: Text(_activeArchivePath!.split('/').last, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            ...innerSegments.map((seg) {
              return Row(
                children: [
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                  Text(seg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              );
            }),
          ],
        ),
      );
    }

    final segments = _currentPath == '/' ? [''] : _currentPath.split('/');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141822) : const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _navigateUp,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.arrow_upward_rounded, size: 18, color: _currentPath == '/' ? Colors.grey : Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _loadDirectory('/'),
                    child: const Text(' / ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  ...segments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final seg = entry.value;
                    if (seg.isEmpty) return const SizedBox.shrink();

                    final segPath = segments.sublist(0, idx + 1).join('/');
                    final target = segPath.isEmpty ? '/' : segPath;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                        InkWell(
                          onTap: () => _loadDirectory(target),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              seg,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: idx == segments.length - 1 ? FontWeight.w800 : FontWeight.w600,
                                color: idx == segments.length - 1 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          if (_mountFreeSpace.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _mountFreeSpace,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShortcutsBar(bool isDark) {
    final shortcuts = [
      {'name': 'Internal Storage', 'path': '/sdcard', 'icon': Icons.phone_android_rounded},
      {'name': 'Downloads', 'path': '/sdcard/Download', 'icon': Icons.download_rounded},
      {'name': 'Root', 'path': '/', 'icon': Icons.computer_rounded},
      {'name': 'System', 'path': '/system', 'icon': Icons.settings_system_daydream_rounded},
      {'name': 'Vendor', 'path': '/vendor', 'icon': Icons.memory_rounded},
      {'name': 'Data', 'path': '/data', 'icon': Icons.security_rounded},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: shortcuts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final s = shortcuts[i];
          final isCurrent = _currentPath == s['path'];

          return ActionChip(
            avatar: Icon(s['icon'] as IconData, size: 14, color: isCurrent ? Colors.white : Theme.of(context).colorScheme.primary),
            label: Text(s['name'] as String, style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600, color: isCurrent ? Colors.white : null)),
            backgroundColor: isCurrent ? Theme.of(context).colorScheme.primary : (isDark ? const Color(0xFF1A1E29) : const Color(0xFFE5E7EB)),
            visualDensity: VisualDensity.compact,
            onPressed: () => _loadDirectory(s['path'] as String),
          );
        },
      ),
    );
  }

  Widget _buildMultiSelectHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Text('${_selectedPaths.length} Selected', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectedPaths.length == _items.length) {
                  _selectedPaths.clear();
                } else {
                  _selectedPaths.addAll(_items.map((e) => e.fullPath));
                }
              });
            },
            child: Text(_selectedPaths.length == _items.length ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 11.5)),
          ),
          IconButton(
            icon: const Icon(Icons.content_cut_rounded, size: 18),
            tooltip: 'Cut',
            onPressed: _selectedPaths.isEmpty ? null : _cutSelected,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy',
            onPressed: _selectedPaths.isEmpty ? null : _copySelected,
          ),
          IconButton(
            icon: const Icon(Icons.archive_rounded, size: 18, color: Colors.amber),
            tooltip: 'Compress',
            onPressed: _selectedPaths.isEmpty ? null : () => _showCreateArchiveDialog(_selectedPaths.toList()),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.redAccent),
            tooltip: 'Delete',
            onPressed: _selectedPaths.isEmpty ? null : _deleteSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildClipboardPasteBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.blueAccent.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(_isCutOperation ? Icons.content_cut_rounded : Icons.copy_rounded, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_clipboardPaths.length} item(s) in clipboard (${_isCutOperation ? "Move" : "Copy"})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _clipboardPaths.clear()),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.paste_rounded, size: 16),
            label: const Text('Paste Here', style: TextStyle(fontSize: 12)),
            onPressed: _pasteClipboard,
          ),
        ],
      ),
    );
  }

  // ==================== LIST / GRID VIEWS ====================

  Widget _buildFilesystemView(bool isDark, Color borderColor) {
    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 48, color: Colors.amber),
              const SizedBox(height: 12),
              Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      );
    }

    final filtered = _items.where((i) {
      if (_searchQuery.isEmpty) return true;
      return i.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return Center(child: Text('No files found', style: TextStyle(color: AppTheme.getSecondaryText(context))));
    }

    if (_viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) => _buildGridCard(filtered[i], isDark, borderColor),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: borderColor.withValues(alpha: 0.3)),
      itemBuilder: (ctx, i) => _buildListTile(filtered[i], isDark),
    );
  }

  Widget _buildListTile(FileItem item, bool isDark) {
    final isSelected = _selectedPaths.contains(item.fullPath);

    return InkWell(
      onTap: () {
        if (_isMultiSelect) {
          setState(() {
            if (isSelected) {
              _selectedPaths.remove(item.fullPath);
            } else {
              _selectedPaths.add(item.fullPath);
            }
          });
        } else {
          _handleFileTap(item);
        }
      },
      onLongPress: () {
        if (!_isMultiSelect) {
          setState(() {
            _isMultiSelect = true;
            _selectedPaths.add(item.fullPath);
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            if (_isMultiSelect)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
            _getFileIcon(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.isLink && item.linkTarget != null
                        ? '-> ${item.linkTarget}'
                        : (item.isDirectory
                            ? 'Directory • ${item.modified}'
                            : '${_formatBytes(item.sizeBytes)} • ${item.permissions.isNotEmpty ? item.permissions : item.modified}'),
                    style: TextStyle(fontSize: 10.5, color: AppTheme.getSecondaryText(context), fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onPressed: () => _showItemActions(item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(FileItem item, bool isDark, Color borderColor) {
    final isSelected = _selectedPaths.contains(item.fullPath);

    return InkWell(
      onTap: () {
        if (_isMultiSelect) {
          setState(() {
            if (isSelected) {
              _selectedPaths.remove(item.fullPath);
            } else {
              _selectedPaths.add(item.fullPath);
            }
          });
        } else {
          _handleFileTap(item);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF161A24) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : borderColor),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _getFileIcon(item, size: 36),
            const SizedBox(height: 8),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              item.isDirectory ? 'Folder' : _formatBytes(item.sizeBytes),
              style: TextStyle(fontSize: 9.5, color: AppTheme.getSecondaryText(context), fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveView(bool isDark, Color borderColor) {
    final visible = _getVisibleArchiveEntries().where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (visible.isEmpty) {
      return Center(child: Text('Archive folder is empty', style: TextStyle(color: AppTheme.getSecondaryText(context))));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: visible.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: borderColor.withValues(alpha: 0.3)),
      itemBuilder: (ctx, i) {
        final e = visible[i];
        return ListTile(
          dense: true,
          leading: Icon(
            e.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
            color: e.isDirectory ? Colors.amber : Colors.blueAccent,
            size: 22,
          ),
          title: Text(e.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text(
            e.isDirectory ? 'Archive Folder' : _formatBytes(e.uncompressedSize),
            style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.getSecondaryText(context)),
          ),
          onTap: () => _handleArchiveEntryTap(e),
        );
      },
    );
  }

  Widget _getFileIcon(FileItem item, {double size = 22}) {
    if (item.isDirectory) {
      return Icon(Icons.folder_rounded, color: Colors.amber, size: size);
    }
    if (item.isArchive) {
      return Icon(Icons.archive_rounded, color: Colors.orangeAccent, size: size);
    }
    if (item.isLink) {
      return Icon(item.isDirectory ? Icons.folder_shared_rounded : Icons.link_rounded, color: Colors.cyan, size: size);
    }

    final ext = item.name.contains('.') ? item.name.split('.').last.toLowerCase() : '';
    if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'ico', 'svg'].contains(ext)) {
      return Icon(Icons.image_rounded, color: Colors.purpleAccent, size: size);
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'flv', 'ts', 'm4v'].contains(ext)) {
      return Icon(Icons.video_file_rounded, color: Colors.redAccent, size: size);
    }
    if (['mp3', 'flac', 'wav', 'ogg', 'm4a', 'aac', 'opus', 'wma'].contains(ext)) {
      return Icon(Icons.audio_file_rounded, color: Colors.tealAccent, size: size);
    }
    if (['pdf'].contains(ext)) {
      return Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: size);
    }
    if (['apk'].contains(ext)) {
      return Icon(Icons.android_rounded, color: Colors.green, size: size);
    }
    if (['xapk', 'apks', 'apkm'].contains(ext)) {
      return Icon(Icons.dashboard_customize_rounded, color: Colors.amber, size: size);
    }
    if (['ttf', 'otf'].contains(ext)) {
      return Icon(Icons.font_download_rounded, color: Colors.indigoAccent, size: size);
    }
    if (['json'].contains(ext)) {
      return Icon(Icons.data_object_rounded, color: Colors.amberAccent, size: size);
    }
    if (['md'].contains(ext)) {
      return Icon(Icons.menu_book_rounded, color: Colors.lightBlueAccent, size: size);
    }
    if (['csv', 'tsv'].contains(ext)) {
      return Icon(Icons.table_chart_rounded, color: Colors.lightGreenAccent, size: size);
    }
    if (['db', 'sqlite'].contains(ext)) {
      return Icon(Icons.storage_rounded, color: Colors.cyanAccent, size: size);
    }
    if (['bin', 'so', 'dex', 'dat', 'img', 'iso'].contains(ext)) {
      return Icon(Icons.memory_rounded, color: Colors.blueGrey, size: size);
    }
    return Icon(Icons.description_rounded, color: Colors.blueAccent, size: size);
  }

  void _showItemActions(FileItem item) {
    final isPackage = XapkService.isPackageFile(item.fullPath);
    final isXapk = XapkService.isXapkOrSplit(item.fullPath);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF11141B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!item.isDirectory)
              ListTile(
                dense: true,
                leading: const Icon(Icons.preview_rounded, color: Colors.blueAccent),
                title: const Text('Fast Preview', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Instant multi-format viewer & hex inspector'),
                onTap: () {
                  Navigator.pop(ctx);
                  FastPreviewModal.show(
                    context,
                    item,
                    onOpenFullEditor: () => _openTextEditor(item),
                  );
                },
              ),
            if (isPackage) ...[
              ListTile(
                dense: true,
                leading: const Icon(Icons.install_mobile_rounded, color: Colors.green),
                title: Text(isXapk ? 'Install Package (XAPK / Splits)' : 'Install Package (.apk)', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(isXapk ? 'Extract splits & install package bundle' : 'Launch Android Package Installer'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final meta = await XapkService.parsePackage(item.fullPath);
                    if (mounted) {
                      PackageInstallerSheet.show(context, meta);
                    }
                  } catch (e) {
                    _installApk(item.fullPath);
                  }
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_zip_rounded, color: Colors.blueAccent),
                title: const Text('Open as Archive (Inspect APK)', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Browse AndroidManifest, DEX, assets & resources'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openVirtualArchive(item.fullPath);
                },
              ),
            ],
            if (item.isArchive)
              ListTile(
                dense: true,
                leading: const Icon(Icons.archive_rounded, color: Colors.amber),
                title: const Text('Archive Options (ZArchiver Suite)', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Extract, test integrity, or browse entries'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showArchiveOptions(item);
                },
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _renameItem(item);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy to Clipboard'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _clipboardPaths = [item.fullPath];
                  _isCutOperation = false;
                });
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.content_cut_rounded),
              title: const Text('Cut (Move)'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _clipboardPaths = [item.fullPath];
                  _isCutOperation = true;
                });
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.archive_rounded, color: Colors.amber),
              title: const Text('Compress to Archive'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateArchiveDialog([item.fullPath]);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.security_rounded, color: Colors.blueAccent),
              title: const Text('Change Permissions (chmod)'),
              onTap: () {
                Navigator.pop(ctx);
                _showPermissionsDialog(item);
              },
            ),
            if (!item.isDirectory)
              ListTile(
                dense: true,
                leading: const Icon(Icons.fingerprint_rounded, color: Colors.teal),
                title: const Text('Calculate Hashes (MD5/SHA256)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _calculateChecksums(item);
                },
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Properties'),
              onTap: () {
                Navigator.pop(ctx);
                _showFileProperties(item);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }
}

