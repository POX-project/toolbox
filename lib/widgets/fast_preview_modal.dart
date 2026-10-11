import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/xapk_service.dart';
import '../theme/app_theme.dart';
import 'package:toolbox/screens/tools/file_manager_screen.dart';
import 'package:toolbox/widgets/package_installer_sheet.dart';

enum PreviewType {
  image,
  video,
  audio,
  text,
  json,
  markdown,
  font,
  package,
  hex,
  unsupported,
}

class FastPreviewModal extends ConsumerStatefulWidget {
  final FileItem item;
  final VoidCallback? onOpenFullEditor;

  const FastPreviewModal({
    super.key,
    required this.item,
    this.onOpenFullEditor,
  });

  static Future<void> show(
    BuildContext context,
    FileItem item, {
    VoidCallback? onOpenFullEditor,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FastPreviewModal(
        item: item,
        onOpenFullEditor: onOpenFullEditor,
      ),
    );
  }

  static PreviewType detectPreviewType(String fileName) {
    final lower = fileName.toLowerCase();
    final ext = lower.contains('.') ? lower.split('.').last : '';

    if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'ico', 'svg'].contains(ext)) {
      return PreviewType.image;
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'flv', 'mts', 'm2ts', 'm4v', 'wmv'].contains(ext)) {
      return PreviewType.video;
    }
    if (['mp3', 'flac', 'wav', 'ogg', 'm4a', 'aac', 'opus', 'wma', 'mid', 'midi'].contains(ext)) {
      return PreviewType.audio;
    }
    if (['ttf', 'otf'].contains(ext)) {
      return PreviewType.font;
    }
    if (['apk', 'xapk', 'apks', 'apkm'].contains(ext)) {
      return PreviewType.package;
    }
    if (ext == 'json') {
      return PreviewType.json;
    }
    if (ext == 'md') {
      return PreviewType.markdown;
    }
    if ([
      'txt', 'xml', 'html', 'css', 'js', 'ts', 'yaml', 'yml', 'sh', 'py',
      'conf', 'rc', 'prop', 'log', 'cfg', 'ini', 'dart', 'c', 'cpp', 'h',
      'java', 'kt', 'gradle', 'kts', 'properties', 'env', 'csv', 'tsv', 'sql'
    ].contains(ext)) {
      return PreviewType.text;
    }
    if (['bin', 'so', 'dat', 'img', 'dex', 'class', 'iso', 'db', 'sqlite', 'raw'].contains(ext)) {
      return PreviewType.hex;
    }

    return PreviewType.unsupported;
  }

  @override
  ConsumerState<FastPreviewModal> createState() => _FastPreviewModalState();
}

class _FastPreviewModalState extends ConsumerState<FastPreviewModal> {
  late PreviewType _type;
  bool _isLoading = true;
  String? _errorMessage;

  // Text / Code State
  String _textContent = '';
  String _prettyJson = '';
  bool _isJsonFormatted = false;
  bool _wordWrap = true;
  bool _showLineNumbers = true;
  bool _forceHexView = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _textScrollController = ScrollController();

  // Image State
  int _imageQuarterTurns = 0;
  Size? _imageSize;

  // Font State
  String? _dynamicFontFamily;
  double _fontSize = 20.0;
  final TextEditingController _fontSampleController = TextEditingController(
    text: 'Sphinx of black quartz, judge my vow. 1234567890',
  );

  // APK / XAPK State
  ApkMetadata? _apkMetadata;

  // Hex State
  List<int> _rawBytes = [];

  @override
  void initState() {
    super.initState();
    _type = FastPreviewModal.detectPreviewType(widget.item.name);
    _loadFileContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _textScrollController.dispose();
    _fontSampleController.dispose();
    super.dispose();
  }

  Future<void> _loadFileContent() async {
    setState(() => _isLoading = true);

    try {
      final file = File(widget.item.fullPath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'File does not exist: ${widget.item.fullPath}';
          _isLoading = false;
        });
        return;
      }

      switch (_type) {
        case PreviewType.package:
          _apkMetadata = await XapkService.parsePackage(widget.item.fullPath);
          break;

        case PreviewType.image:
          // Read image dimensions
          final bytes = await file.readAsBytes();
          try {
            final decoded = await decodeImageFromList(bytes);
            _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
          } catch (_) {}
          break;

        case PreviewType.font:
          final fontBytes = await file.readAsBytes();
          final family = 'DynamicFont_${DateTime.now().millisecondsSinceEpoch}';
          final loader = FontLoader(family);
          loader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
          await loader.load();
          _dynamicFontFamily = family;
          break;

        case PreviewType.text:
        case PreviewType.json:
        case PreviewType.markdown:
          // Read up to 256KB for fast preview
          final bytes = await _readChunk(file, 256 * 1024);
          _textContent = utf8.decode(bytes, allowMalformed: true);

          if (_type == PreviewType.json) {
            try {
              final parsed = jsonDecode(_textContent);
              _prettyJson = const JsonEncoder.withIndent('  ').convert(parsed);
              _isJsonFormatted = true;
            } catch (_) {
              _isJsonFormatted = false;
            }
          }
          break;

        case PreviewType.hex:
        case PreviewType.unsupported:
        case PreviewType.video:
        case PreviewType.audio:
          _rawBytes = await _readChunk(file, 64 * 1024);
          break;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<int>> _readChunk(File file, int maxBytes) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final len = await file.length();
      final toRead = min(len, maxBytes);
      final bytes = await raf.read(toRead);
      return bytes;
    } finally {
      await raf.close();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11141D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
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

          // Header bar
          _buildHeaderBar(context, isDark),

          const Divider(height: 1),

          // Main Content Viewer
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _forceHexView
                        ? _buildHexViewer(isDark)
                        : _buildMainViewer(context, isDark),
          ),

          // Bottom Quick Bar
          _buildBottomBar(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, bool isDark) {
    final ext = widget.item.name.contains('.') ? widget.item.name.split('.').last.toUpperCase() : 'FILE';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 12, 10),
      child: Row(
        children: [
          // Extension badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ext,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          // File Name & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_formatBytes(widget.item.sizeBytes)} • ${widget.item.permissions.isNotEmpty ? widget.item.permissions : widget.item.modified}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.getSecondaryText(context),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          // Hex View Toggle
          IconButton(
            icon: Icon(
              _forceHexView ? Icons.visibility_rounded : Icons.code_rounded,
              size: 20,
              color: _forceHexView ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: _forceHexView ? 'Standard Preview' : 'Inspect Raw Hex Dump',
            onPressed: () {
              setState(() {
                _forceHexView = !_forceHexView;
                if (_forceHexView && _rawBytes.isEmpty) {
                  _loadFileContent();
                }
              });
            },
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMainViewer(BuildContext context, bool isDark) {
    switch (_type) {
      case PreviewType.image:
        return _buildImageViewer(isDark);
      case PreviewType.video:
        return _buildMediaViewer(context, isDark, isVideo: true);
      case PreviewType.audio:
        return _buildMediaViewer(context, isDark, isVideo: false);
      case PreviewType.font:
        return _buildFontViewer(context, isDark);
      case PreviewType.package:
        return _buildPackageViewer(context, isDark);
      case PreviewType.text:
      case PreviewType.json:
      case PreviewType.markdown:
        return _buildTextViewer(context, isDark);
      case PreviewType.hex:
      case PreviewType.unsupported:
        return _buildHexViewer(isDark);
    }
  }

  // ==================== 1. IMAGE VIEWER ====================
  Widget _buildImageViewer(bool isDark) {
    return Column(
      children: [
        // Image metadata & toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (_imageSize != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1D2230) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_imageSize!.width.toInt()} × ${_imageSize!.height.toInt()} px',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.rotate_right_rounded, size: 20),
                tooltip: 'Rotate 90°',
                onPressed: () => setState(() => _imageQuarterTurns = (_imageQuarterTurns + 1) % 4),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                tooltip: 'Open with Gallery',
                onPressed: () => XapkService.openWithSystem(widget.item.fullPath, mimeType: 'image/*'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF090B10) : const Color(0xFFF3F4F6),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6.0,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _imageQuarterTurns,
                  child: Image.file(
                    File(widget.item.fullPath),
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Failed to load image format'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 2. VIDEO & AUDIO VIEWER ====================
  Widget _buildMediaViewer(BuildContext context, bool isDark, {required bool isVideo}) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isVideo
                      ? [Colors.deepOrangeAccent, Colors.redAccent]
                      : [Colors.tealAccent.shade700, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isVideo ? Colors.deepOrange : Colors.teal).withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.item.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${isVideo ? "Video Media File" : "Audio Track"} • ${_formatBytes(widget.item.sizeBytes)}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.getSecondaryText(context),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => XapkService.openWithSystem(
                widget.item.fullPath,
                mimeType: isVideo ? 'video/*' : 'audio/*',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                isVideo ? 'Play in Video Player' : 'Play in Audio Player',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 3. TEXT & CODE VIEWER ====================
  Widget _buildTextViewer(BuildContext context, bool isDark) {
    final isJson = _type == PreviewType.json;
    final displayedText = isJson && _isJsonFormatted ? _prettyJson : _textContent;

    final lines = displayedText.split('\n');
    final query = _searchQuery.trim().toLowerCase();
    int matchCount = 0;
    if (query.isNotEmpty) {
      for (final line in lines) {
        if (line.toLowerCase().contains(query)) matchCount++;
      }
    }

    return Column(
      children: [
        // Search & Mode bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: isDark ? const Color(0xFF161A26) : const Color(0xFFF9FAFB),
          child: Row(
            children: [
              // Search input
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search text...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1F2433) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '$matchCount matches',
                  style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(width: 8),
              // Line numbers toggle
              IconButton(
                icon: Icon(
                  Icons.format_list_numbered_rounded,
                  size: 18,
                  color: _showLineNumbers ? Theme.of(context).colorScheme.primary : null,
                ),
                tooltip: 'Line numbers',
                onPressed: () => setState(() => _showLineNumbers = !_showLineNumbers),
              ),
              // Word wrap toggle
              IconButton(
                icon: Icon(
                  Icons.wrap_text_rounded,
                  size: 18,
                  color: _wordWrap ? Theme.of(context).colorScheme.primary : null,
                ),
                tooltip: 'Word wrap',
                onPressed: () => setState(() => _wordWrap = !_wordWrap),
              ),
              // JSON pretty format toggle
              if (isJson)
                IconButton(
                  icon: Icon(
                    Icons.auto_fix_high_rounded,
                    size: 18,
                    color: _isJsonFormatted ? Colors.amber : null,
                  ),
                  tooltip: _isJsonFormatted ? 'Show Raw JSON' : 'Format JSON',
                  onPressed: () => setState(() => _isJsonFormatted = !_isJsonFormatted),
                ),
            ],
          ),
        ),

        // Text Scroll View
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0C0E14) : const Color(0xFFFAFAFA),
            child: ListView.builder(
              controller: _textScrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: lines.length,
              itemBuilder: (ctx, idx) {
                final line = lines[idx];
                final isMatch = query.isNotEmpty && line.toLowerCase().contains(query);

                return Container(
                  color: isMatch ? Colors.yellow.withValues(alpha: 0.25) : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showLineNumbers)
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white30 : Colors.black26,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      if (_showLineNumbers) const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          line.isEmpty ? ' ' : line,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                          ),
                          softWrap: _wordWrap,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 4. LIVE DYNAMIC FONT VIEWER ====================
  Widget _buildFontViewer(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.font_download_rounded, size: 24, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(
                widget.item.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Font size slider
          Row(
            children: [
              const Text('Font Size:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 48.0,
                  divisions: 36,
                  label: '${_fontSize.toInt()}pt',
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
              Text('${_fontSize.toInt()} pt', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          // Custom text field
          TextField(
            controller: _fontSampleController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Preview Text (Type to test glyphs)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF191E2A) : const Color(0xFFF3F4F6),
            ),
          ),
          const SizedBox(height: 20),
          // Sample rendering container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1218) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fontSampleController.text.isNotEmpty
                      ? _fontSampleController.text
                      : 'The quick brown fox jumps over the lazy dog.',
                  style: TextStyle(
                    fontFamily: _dynamicFontFamily,
                    fontSize: _fontSize,
                    height: 1.4,
                  ),
                ),
                const Divider(height: 28),
                Text(
                  'ABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789\n!@#\$%^&*()_+-=[]{}|;:,.<>?',
                  style: TextStyle(
                    fontFamily: _dynamicFontFamily,
                    fontSize: _fontSize * 0.75,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 5. APK / XAPK CARD VIEWER ====================
  Widget _buildPackageViewer(BuildContext context, bool isDark) {
    if (_apkMetadata == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final meta = _apkMetadata!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2333) : const Color(0xFFEDF2F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: meta.iconBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(meta.iconBytes!, fit: BoxFit.cover),
                      )
                    : Icon(
                        meta.isXapk ? Icons.dashboard_customize_rounded : Icons.android_rounded,
                        size: 36,
                        color: meta.isXapk ? Colors.amber : Colors.green,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.appName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      meta.packageName,
                      style: TextStyle(fontSize: 11, color: AppTheme.getSecondaryText(context), fontFamily: 'monospace'),
                    ),
                    Text(
                      'v${meta.versionName} (${meta.versionCode}) • ${_formatBytes(meta.fileSizeBytes)}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(context, meta.isXapk ? 'XAPK Bundle' : 'APK Package', meta.isXapk ? Colors.amber : Colors.green),
              _buildBadge(context, 'Min SDK ${meta.minSdk}', Colors.blueAccent),
              _buildBadge(context, 'Target SDK ${meta.targetSdk}', Colors.indigoAccent),
              if (meta.splitApks.length > 1)
                _buildBadge(context, '${meta.splitApks.length} Splits', Colors.purpleAccent),
              if (meta.obbFiles.isNotEmpty)
                _buildBadge(context, '${meta.obbFiles.length} OBBs', Colors.deepOrangeAccent),
            ],
          ),
          const SizedBox(height: 20),
          // Install Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                PackageInstallerSheet.show(context, meta);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(meta.isXapk ? Icons.downloading_rounded : Icons.install_mobile_rounded),
              label: Text(
                meta.isXapk ? 'Open XAPK Installer Suite' : 'Install APK',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 6. FAST PAGINATED HEX VIEWER ====================
  Widget _buildHexViewer(bool isDark) {
    if (_rawBytes.isEmpty) {
      return const Center(child: Text('No binary bytes available.'));
    }

    final totalRows = (_rawBytes.length / 16).ceil();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: isDark ? const Color(0xFF131722) : const Color(0xFFE5E7EB),
          child: Row(
            children: [
              const Text('OFFSET (HEX)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              const SizedBox(width: 14),
              const Expanded(
                flex: 3,
                child: Text('00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              ),
              const Expanded(
                flex: 1,
                child: Text('ASCII', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: totalRows,
            itemBuilder: (ctx, rowIdx) {
              final start = rowIdx * 16;
              final end = min(start + 16, _rawBytes.length);
              final slice = _rawBytes.sublist(start, end);

              final offsetStr = start.toRadixString(16).padLeft(8, '0').toUpperCase();

              final hexBuffer = StringBuffer();
              final asciiBuffer = StringBuffer();

              for (int i = 0; i < 16; i++) {
                if (i == 8) hexBuffer.write(' ');
                if (i < slice.length) {
                  final b = slice[i];
                  hexBuffer.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
                  hexBuffer.write(' ');

                  // Printable ASCII: 32 to 126
                  if (b >= 32 && b <= 126) {
                    asciiBuffer.write(String.fromCharCode(b));
                  } else {
                    asciiBuffer.write('.');
                  }
                } else {
                  hexBuffer.write('   ');
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1.5),
                child: Row(
                  children: [
                    Text(
                      offsetStr,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: Colors.tealAccent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Text(
                        hexBuffer.toString(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        asciiBuffer.toString(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed to preview file',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11141D) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Open with system chooser
          TextButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open With...'),
            onPressed: () => XapkService.openWithSystem(widget.item.fullPath),
          ),
          // Full Text Editor (if text/code)
          if (_type == PreviewType.text || _type == PreviewType.json || _type == PreviewType.markdown)
            TextButton.icon(
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text('Edit in Editor'),
              onPressed: () {
                Navigator.pop(context);
                widget.onOpenFullEditor?.call();
              },
            ),
          // Copy Path
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Path'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.item.fullPath));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File path copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
}
