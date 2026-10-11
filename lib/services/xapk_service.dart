import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'command_runner.dart';

class ApkMetadata {
  final String appName;
  final String packageName;
  final String versionName;
  final int versionCode;
  final int minSdk;
  final int targetSdk;
  final int fileSizeBytes;
  final Uint8List? iconBytes;
  final List<String> permissions;
  final bool isXapk;
  final List<String> splitApks;
  final List<String> obbFiles;
  final String sourcePath;

  const ApkMetadata({
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.minSdk,
    required this.targetSdk,
    required this.fileSizeBytes,
    this.iconBytes,
    this.permissions = const [],
    this.isXapk = false,
    this.splitApks = const [],
    this.obbFiles = const [],
    required this.sourcePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'packageName': packageName,
      'versionName': versionName,
      'versionCode': versionCode,
      'minSdk': minSdk,
      'targetSdk': targetSdk,
      'fileSizeBytes': fileSizeBytes,
      'isXapk': isXapk,
      'splitApks': splitApks,
      'obbFiles': obbFiles,
      'sourcePath': sourcePath,
    };
  }
}

class XapkService {
  static const _platform = MethodChannel('com.txorav.andbox/native');

  /// Check if file extension is an Android package or bundle
  static bool isPackageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.apk') ||
        lower.endsWith('.xapk') ||
        lower.endsWith('.apks') ||
        lower.endsWith('.apkm');
  }

  /// Check if file is an XAPK or split package bundle
  static bool isXapkOrSplit(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.xapk') ||
        lower.endsWith('.apks') ||
        lower.endsWith('.apkm');
  }

  /// Parse metadata from an APK or XAPK/APKS file
  static Future<ApkMetadata> parsePackage(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }
    final size = await file.length();

    if (!isXapkOrSplit(filePath)) {
      // Standard single APK
      return await _parseSingleApk(filePath, size);
    } else {
      // XAPK / APKS / APKM bundle
      return await _parseXapkBundle(filePath, size);
    }
  }

  static Future<ApkMetadata> _parseSingleApk(String filePath, int fileSize) async {
    try {
      final res = await _platform.invokeMethod<Map<dynamic, dynamic>>('getApkDetails', {
        'filePath': filePath,
      });

      if (res != null) {
        Uint8List? iconBytes;
        final iconBase64 = res['iconBase64'] as String?;
        if (iconBase64 != null && iconBase64.isNotEmpty) {
          try {
            iconBytes = base64Decode(iconBase64);
          } catch (_) {}
        }

        final permissions = (res['permissions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        return ApkMetadata(
          appName: (res['appName'] as String?)?.isNotEmpty == true
              ? res['appName'] as String
              : filePath.split('/').last.replaceAll('.apk', ''),
          packageName: res['packageName'] as String? ?? '',
          versionName: res['versionName'] as String? ?? '1.0',
          versionCode: (res['versionCode'] as num?)?.toInt() ?? 1,
          minSdk: (res['minSdk'] as num?)?.toInt() ?? 21,
          targetSdk: (res['targetSdk'] as num?)?.toInt() ?? 33,
          fileSizeBytes: fileSize,
          iconBytes: iconBytes,
          permissions: permissions,
          isXapk: false,
          splitApks: [filePath.split('/').last],
          obbFiles: const [],
          sourcePath: filePath,
        );
      }
    } catch (e) {
      debugPrint('Native APK parsing failed: $e, falling back to basic metadata');
    }

    // Fallback if native parsing fails
    final fileName = filePath.split('/').last;
    return ApkMetadata(
      appName: fileName.replaceAll('.apk', ''),
      packageName: 'unknown.package',
      versionName: '1.0',
      versionCode: 1,
      minSdk: 21,
      targetSdk: 33,
      fileSizeBytes: fileSize,
      iconBytes: null,
      permissions: const [],
      isXapk: false,
      splitApks: [fileName],
      obbFiles: const [],
      sourcePath: filePath,
    );
  }

  static Future<ApkMetadata> _parseXapkBundle(String filePath, int fileSize) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? manifestJson;
    Uint8List? iconBytes;
    final List<String> splitApks = [];
    final List<String> obbFiles = [];
    ArchiveFile? baseApkFile;

    for (final entry in archive.files) {
      final name = entry.name.replaceAll('\\', '/');
      final lowerName = name.toLowerCase();

      if (lowerName == 'manifest.json') {
        manifestJson = utf8.decode(entry.content as List<int>, allowMalformed: true);
      } else if (lowerName == 'icon.png' || lowerName.endsWith('/icon.png')) {
        iconBytes = Uint8List.fromList(entry.content as List<int>);
      } else if (lowerName.endsWith('.apk')) {
        splitApks.add(name);
        if (lowerName == 'base.apk' || lowerName.endsWith('/base.apk') || baseApkFile == null) {
          baseApkFile = entry;
        }
      } else if (lowerName.endsWith('.obb')) {
        obbFiles.add(name);
      }
    }

    String appName = filePath.split('/').last.replaceAll(RegExp(r'\.(xapk|apks|apkm)$', caseSensitive: false), '');
    String packageName = '';
    String versionName = '1.0';
    int versionCode = 1;
    int minSdk = 21;
    int targetSdk = 33;
    List<String> permissions = [];

    // Parse manifest.json if present
    if (manifestJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(manifestJson);
        if (data['name'] != null) appName = data['name'].toString();
        if (data['package_name'] != null) packageName = data['package_name'].toString();
        if (data['version_name'] != null) versionName = data['version_name'].toString();
        if (data['version_code'] != null) versionCode = int.tryParse(data['version_code'].toString()) ?? 1;
        if (data['min_sdk_version'] != null) minSdk = int.tryParse(data['min_sdk_version'].toString()) ?? 21;
        if (data['target_sdk_version'] != null) targetSdk = int.tryParse(data['target_sdk_version'].toString()) ?? 33;

        if (data['permissions'] is List) {
          permissions = (data['permissions'] as List).map((e) => e.toString()).toList();
        }

        if (data['split_apks'] is List && splitApks.isEmpty) {
          for (final item in data['split_apks']) {
            if (item is Map && item['file'] != null) {
              splitApks.add(item['file'].toString());
            }
          }
        }
      } catch (e) {
        debugPrint('Error decoding manifest.json: $e');
      }
    }

    // If packageName or icon is still missing and we have an extracted APK, extract it temporarily to parse details
    if ((packageName.isEmpty || iconBytes == null) && baseApkFile != null) {
      try {
        final tempDir = Directory.systemTemp;
        final tempApk = File('${tempDir.path}/temp_base_${DateTime.now().millisecondsSinceEpoch}.apk');
        await tempApk.writeAsBytes(baseApkFile.content as List<int>);

        final parsedBase = await _parseSingleApk(tempApk.path, baseApkFile.size);
        if (packageName.isEmpty) packageName = parsedBase.packageName;
        if (appName.isEmpty || appName == filePath.split('/').last) appName = parsedBase.appName;
        if (versionName == '1.0') versionName = parsedBase.versionName;
        if (versionCode == 1) versionCode = parsedBase.versionCode;
        iconBytes ??= parsedBase.iconBytes;
        if (permissions.isEmpty) permissions = parsedBase.permissions;
        if (minSdk == 21) minSdk = parsedBase.minSdk;
        if (targetSdk == 33) targetSdk = parsedBase.targetSdk;

        if (await tempApk.exists()) {
          await tempApk.delete();
        }
      } catch (e) {
        debugPrint('Failed to extract base APK for details: $e');
      }
    }

    if (packageName.isEmpty) {
      packageName = 'com.unknown.package';
    }

    return ApkMetadata(
      appName: appName,
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      minSdk: minSdk,
      targetSdk: targetSdk,
      fileSizeBytes: fileSize,
      iconBytes: iconBytes,
      permissions: permissions,
      isXapk: true,
      splitApks: splitApks,
      obbFiles: obbFiles,
      sourcePath: filePath,
    );
  }

  /// Extract split APKs and OBB files from XAPK bundle to staging folder
  static Future<Map<String, dynamic>> extractAndStageXapk({
    required String xapkPath,
    required String packageName,
    Function(double progress, String status)? onProgress,
  }) async {
    final file = File(xapkPath);
    if (!await file.exists()) {
      throw Exception('XAPK file not found: $xapkPath');
    }

    onProgress?.call(0.05, 'Reading archive structure...');
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final stagingDir = Directory('${Directory.systemTemp.path}/xapk_staging_${DateTime.now().millisecondsSinceEpoch}');
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }

    final List<String> extractedApkPaths = [];
    final List<String> extractedObbPaths = [];
    final totalFiles = archive.files.length;
    int index = 0;

    for (final entry in archive.files) {
      index++;
      final name = entry.name.replaceAll('\\', '/');
      final lowerName = name.toLowerCase();

      final currentProgress = 0.1 + (0.8 * (index / totalFiles));

      if (lowerName.endsWith('.apk')) {
        onProgress?.call(currentProgress, 'Extracting split APK: ${name.split('/').last}');
        final apkFile = File('${stagingDir.path}/${name.split('/').last}');
        await apkFile.writeAsBytes(entry.content as List<int>);
        extractedApkPaths.add(apkFile.path);
      } else if (lowerName.endsWith('.obb')) {
        final obbFileName = name.split('/').last;
        onProgress?.call(currentProgress, 'Extracting OBB: $obbFileName');

        // Target OBB folder: /sdcard/Android/obb/<packageName>/
        final obbDir = Directory('/sdcard/Android/obb/$packageName');
        try {
          if (!await obbDir.exists()) {
            await obbDir.create(recursive: true);
          }
          final obbFile = File('${obbDir.path}/$obbFileName');
          await obbFile.writeAsBytes(entry.content as List<int>);
          extractedObbPaths.add(obbFile.path);
        } catch (e) {
          // If direct write fails due to permission restrictions, stage in temp
          final stagedObb = File('${stagingDir.path}/$obbFileName');
          await stagedObb.writeAsBytes(entry.content as List<int>);
          extractedObbPaths.add(stagedObb.path);
        }
      }
    }

    onProgress?.call(1.0, 'Extraction complete');
    return {
      'stagingDirectory': stagingDir.path,
      'apkPaths': extractedApkPaths,
      'obbPaths': extractedObbPaths,
    };
  }

  /// Install application package (Single APK or XAPK splits)
  static Future<bool> installPackage({
    required ApkMetadata metadata,
    List<String>? stagedApkPaths,
    CommandRunner? runner,
    Function(double progress, String status)? onProgress,
  }) async {
    if (!metadata.isXapk) {
      // Single APK installation
      onProgress?.call(0.5, 'Starting APK installation...');
      try {
        await _platform.invokeMethod('installApk', {'filePath': metadata.sourcePath});
        onProgress?.call(1.0, 'Installation prompt launched');
        return true;
      } catch (e) {
        if (runner != null) {
          onProgress?.call(0.7, 'Retrying with shell runner...');
          final esc = shellEscape(metadata.sourcePath);
          final res = await runner.runCommand('pm install -r $esc 2>&1');
          return res.contains('Success');
        }
        rethrow;
      }
    }

    // XAPK / Split APK installation
    List<String> apkPathsToInstall = stagedApkPaths ?? [];
    String? stagingDir;

    if (apkPathsToInstall.isEmpty) {
      onProgress?.call(0.1, 'Unpacking package splits and assets...');
      final staged = await extractAndStageXapk(
        xapkPath: metadata.sourcePath,
        packageName: metadata.packageName,
        onProgress: onProgress,
      );
      apkPathsToInstall = List<String>.from(staged['apkPaths'] as List);
      stagingDir = staged['stagingDirectory'] as String?;
    }

    if (apkPathsToInstall.isEmpty) {
      throw Exception('No APK files found inside bundle.');
    }

    onProgress?.call(0.85, 'Committing split APKs session...');

    try {
      // First try native PackageInstaller session (standard Android system prompt)
      await _platform.invokeMethod('installSplitApks', {'apkPaths': apkPathsToInstall});
      onProgress?.call(1.0, 'Split package installation dispatched!');
      return true;
    } catch (nativeError) {
      debugPrint('Native installSplitApks error: $nativeError. Attempting shell session install...');

      // Elevated / Shizuku / Root fallback: pm install-create & pm install-write & pm install-commit
      if (runner != null) {
        try {
          final createRes = await runner.runCommand('pm install-create -r 2>&1');
          final match = RegExp(r'\[(\d+)\]').firstMatch(createRes);
          if (match != null) {
            final sessionId = match.group(1);
            int idx = 0;
            for (final apkPath in apkPathsToInstall) {
              idx++;
              final f = File(apkPath);
              final size = await f.length();
              final name = 'split_$idx.apk';
              final escPath = shellEscape(apkPath);
              await runner.runCommand('pm install-write -S $size $sessionId $name $escPath 2>&1');
            }
            final commitRes = await runner.runCommand('pm install-commit $sessionId 2>&1');
            if (commitRes.contains('Success')) {
              onProgress?.call(1.0, 'Installed successfully via shell session!');
              return true;
            }
          }
        } catch (shellError) {
          debugPrint('Shell session install error: $shellError');
        }
      }
      rethrow;
    } finally {
      // Cleanup staging directory if created
      if (stagingDir != null) {
        try {
          final dir = Directory(stagingDir);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  /// Open any file with external system application
  static Future<bool> openWithSystem(String filePath, {String? mimeType}) async {
    try {
      final res = await _platform.invokeMethod<bool>('openWithSystem', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('openWithSystem failed: $e');
      return false;
    }
  }

  /// Escape paths for shell commands safely
  static String shellEscape(String path) {
    if (path.isEmpty) return "''";
    return "'${path.replaceAll("'", "'\\''")}'";
  }
}
