import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

class ArchiveEntry {
  final String path;
  final String name;
  final bool isDirectory;
  final int uncompressedSize;
  final int? compressedSize;
  final int? modifiedTime;

  const ArchiveEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.uncompressedSize,
    this.compressedSize,
    this.modifiedTime,
  });
}

class ArchiveService {
  static const Set<String> supportedArchiveExtensions = {
    'zip',
    'tar',
    'gz',
    'tgz',
    'tar.gz',
    'bz2',
    'tbz',
    'tbz2',
    'tar.bz2',
    'xz',
    'txz',
    'tar.xz',
    'apk',
    'jar',
  };

  static bool isArchive(String filePath) {
    final lower = filePath.toLowerCase();
    for (final ext in supportedArchiveExtensions) {
      if (lower.endsWith('.$ext')) return true;
    }
    return false;
  }

  /// Decode an archive into memory-efficient archive structure.
  static Future<Archive> loadArchive(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final lower = filePath.toLowerCase();

    if (lower.endsWith('.zip') || lower.endsWith('.apk') || lower.endsWith('.jar')) {
      return ZipDecoder().decodeBytes(bytes);
    } else if (lower.endsWith('.tar')) {
      return TarDecoder().decodeBytes(bytes);
    } else if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      final decompressed = GZipDecoder().decodeBytes(bytes);
      return TarDecoder().decodeBytes(decompressed);
    } else if (lower.endsWith('.tar.bz2') || lower.endsWith('.tbz') || lower.endsWith('.tbz2')) {
      final decompressed = BZip2Decoder().decodeBytes(bytes);
      return TarDecoder().decodeBytes(decompressed);
    } else if (lower.endsWith('.tar.xz') || lower.endsWith('.txz')) {
      final decompressed = XZDecoder().decodeBytes(bytes);
      return TarDecoder().decodeBytes(decompressed);
    } else if (lower.endsWith('.gz')) {
      final decompressed = GZipDecoder().decodeBytes(bytes);
      final singleName = filePath.split('/').last.replaceAll(RegExp(r'\.gz$', caseSensitive: false), '');
      final archive = Archive();
      archive.addFile(ArchiveFile(singleName, decompressed.length, decompressed));
      return archive;
    } else if (lower.endsWith('.bz2')) {
      final decompressed = BZip2Decoder().decodeBytes(bytes);
      final singleName = filePath.split('/').last.replaceAll(RegExp(r'\.bz2$', caseSensitive: false), '');
      final archive = Archive();
      archive.addFile(ArchiveFile(singleName, decompressed.length, decompressed));
      return archive;
    } else {
      // Default fallback to zip
      return ZipDecoder().decodeBytes(bytes);
    }
  }

  /// List entries inside an archive (for virtual archive browsing)
  static Future<List<ArchiveEntry>> listEntries(String filePath) async {
    final archive = await loadArchive(filePath);
    final List<ArchiveEntry> entries = [];

    for (final file in archive.files) {
      final rawPath = file.name.replaceAll('\\', '/');
      final isDir = !file.isFile || rawPath.endsWith('/');
      final cleanPath = rawPath.endsWith('/') ? rawPath.substring(0, rawPath.length - 1) : rawPath;
      final name = cleanPath.split('/').last;

      entries.add(ArchiveEntry(
        path: cleanPath,
        name: name.isNotEmpty ? name : cleanPath,
        isDirectory: isDir,
        uncompressedSize: file.size,
        modifiedTime: file.lastModTime,
      ));
    }

    return entries;
  }

  /// Test archive integrity
  static Future<String> testArchive(String filePath) async {
    try {
      final archive = await loadArchive(filePath);
      int count = 0;
      int totalBytes = 0;
      for (final file in archive.files) {
        count++;
        totalBytes += file.size;
      }
      return 'Archive integrity verified OK. Found $count items (${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB uncompressed).';
    } catch (e) {
      return 'Archive integrity verification failed: $e';
    }
  }

  /// Extract entire archive to a target directory
  static Future<void> extractArchive({
    required String archivePath,
    required String destinationDir,
    void Function(double progress, String currentItem)? onProgress,
  }) async {
    final archive = await loadArchive(archivePath);
    final dest = Directory(destinationDir);
    if (!await dest.exists()) {
      await dest.create(recursive: true);
    }

    final total = archive.files.length;
    int current = 0;

    for (final file in archive.files) {
      current++;
      final filename = file.name.replaceAll('\\', '/');
      if (onProgress != null) {
        onProgress(total > 0 ? current / total : 1.0, filename);
      }

      final outPath = '$destinationDir/$filename';
      if (!file.isFile || filename.endsWith('/')) {
        await Directory(outPath).create(recursive: true);
      } else {
        final parentDir = Directory(outPath.substring(0, outPath.lastIndexOf('/')));
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }
        final outFile = File(outPath);
        final content = file.content as List<int>;
        await outFile.writeAsBytes(content);
      }
    }
  }

  /// Read content of a single file from within the archive
  static Future<Uint8List?> readFileFromArchive({
    required String archivePath,
    required String innerFilePath,
  }) async {
    final archive = await loadArchive(archivePath);
    final target = innerFilePath.replaceAll('\\', '/');
    for (final file in archive.files) {
      final name = file.name.replaceAll('\\', '/');
      if (name == target || (name.endsWith('/') && name.substring(0, name.length - 1) == target)) {
        if (!file.isFile) return null;
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    return null;
  }

  /// Create an archive from a list of file and directory paths
  static Future<void> createArchive({
    required List<String> sourcePaths,
    required String outputFilePath,
    String format = 'zip', // 'zip', 'tar', 'tar.gz'
    int compressionLevel = 6, // 0 = Store, 9 = Maximum
    void Function(double progress, String currentItem)? onProgress,
  }) async {
    final archive = Archive();
    final List<File> filesToAdd = [];
    final Map<String, String> relativeNameMap = {};

    for (final path in sourcePaths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        final dir = Directory(path);
        final baseName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final e in entities) {
          if (e is File) {
            filesToAdd.add(e);
            final rel = e.path.substring(dir.path.length);
            final cleanRel = rel.startsWith('/') ? rel.substring(1) : rel;
            relativeNameMap[e.path] = '$baseName/$cleanRel';
          }
        }
      } else if (type == FileSystemEntityType.file) {
        final f = File(path);
        filesToAdd.add(f);
        final baseName = path.split('/').last;
        relativeNameMap[f.path] = baseName;
      }
    }

    final total = filesToAdd.length;
    int current = 0;

    for (final file in filesToAdd) {
      current++;
      final relName = relativeNameMap[file.path] ?? file.path.split('/').last;
      if (onProgress != null) {
        onProgress(total > 0 ? current / total : 1.0, relName);
      }
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(relName, bytes.length, bytes));
    }

    final outputFile = File(outputFilePath);
    if (!await outputFile.parent.exists()) {
      await outputFile.parent.create(recursive: true);
    }

    List<int> encoded;
    if (format == 'tar') {
      encoded = TarEncoder().encode(archive);
    } else if (format == 'tar.gz' || format == 'tgz') {
      final tarData = TarEncoder().encode(archive);
      encoded = GZipEncoder().encode(tarData);
    } else {
      // default zip
      int zipLevel = DeflateLevel.bestSpeed;
      if (compressionLevel == 0) {
        zipLevel = DeflateLevel.none;
      } else if (compressionLevel >= 7) {
        zipLevel = DeflateLevel.bestCompression;
      }
      encoded = ZipEncoder().encode(
        archive,
        level: zipLevel,
      );
    }

    await outputFile.writeAsBytes(encoded);
  }
}
