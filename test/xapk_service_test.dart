import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/services/xapk_service.dart';
import 'package:archive/archive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('XapkService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('xapk_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('isPackageFile identifies package extensions correctly', () {
      expect(XapkService.isPackageFile('app.apk'), isTrue);
      expect(XapkService.isPackageFile('game.xapk'), isTrue);
      expect(XapkService.isPackageFile('split.apks'), isTrue);
      expect(XapkService.isPackageFile('bundle.apkm'), isTrue);
      expect(XapkService.isPackageFile('archive.zip'), isFalse);
      expect(XapkService.isPackageFile('document.pdf'), isFalse);
    });

    test('isXapkOrSplit detects split bundles accurately', () {
      expect(XapkService.isXapkOrSplit('game.xapk'), isTrue);
      expect(XapkService.isXapkOrSplit('app.apks'), isTrue);
      expect(XapkService.isXapkOrSplit('bundle.apkm'), isTrue);
      expect(XapkService.isXapkOrSplit('standalone.apk'), isFalse);
    });

    test('shellEscape handles quotes and spaces safely', () {
      expect(XapkService.shellEscape(''), "''");
      expect(XapkService.shellEscape('/sdcard/app.apk'), "'/sdcard/app.apk'");
      expect(XapkService.shellEscape('/sdcard/my app.apk'), "'/sdcard/my app.apk'");
      expect(XapkService.shellEscape("/sdcard/it's cool.apk"), "'/sdcard/it'\\''s cool.apk'");
    });

    test('parsePackage parses XAPK archive with manifest.json correctly', () async {
      final xapkPath = '${tempDir.path}/test_app.xapk';
      final archive = Archive();

      const manifestContent = '''{
        "xapk_version": 1,
        "package_name": "com.test.game",
        "name": "Test Epic Game",
        "version_name": "2.4.1",
        "version_code": "241",
        "min_sdk_version": "24",
        "target_sdk_version": "34",
        "permissions": ["android.permission.INTERNET", "android.permission.VIBRATE"],
        "split_apks": [
          {"file": "base.apk", "id": "base"},
          {"file": "config.arm64_v8a.apk", "id": "config.arm64_v8a"}
        ],
        "expansions": [
          {"file": "Android/obb/com.test.game/main.241.com.test.game.obb", "install_location": "EXTERNAL_STORAGE"}
        ]
      }''';

      archive.addFile(ArchiveFile('manifest.json', manifestContent.length, manifestContent.codeUnits));
      archive.addFile(ArchiveFile('base.apk', 10, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
      archive.addFile(ArchiveFile('config.arm64_v8a.apk', 8, [1, 2, 3, 4, 5, 6, 7, 8]));
      archive.addFile(ArchiveFile('Android/obb/com.test.game/main.241.com.test.game.obb', 12, [9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 1, 2]));

      final zipData = ZipEncoder().encode(archive);
      await File(xapkPath).writeAsBytes(zipData);

      final metadata = await XapkService.parsePackage(xapkPath);

      expect(metadata.isXapk, isTrue);
      expect(metadata.appName, 'Test Epic Game');
      expect(metadata.packageName, 'com.test.game');
      expect(metadata.versionName, '2.4.1');
      expect(metadata.versionCode, 241);
      expect(metadata.minSdk, 24);
      expect(metadata.targetSdk, 34);
      expect(metadata.permissions, contains('android.permission.INTERNET'));
      expect(metadata.permissions, contains('android.permission.VIBRATE'));
      expect(metadata.splitApks.length, 2);
      expect(metadata.obbFiles.length, 1);
    });

    test('extractAndStageXapk extracts split APKs to staging folder', () async {
      final xapkPath = '${tempDir.path}/test_split.xapk';
      final archive = Archive();

      archive.addFile(ArchiveFile('base.apk', 4, [10, 20, 30, 40]));
      archive.addFile(ArchiveFile('split_config.apk', 4, [50, 60, 70, 80]));

      final zipData = ZipEncoder().encode(archive);
      await File(xapkPath).writeAsBytes(zipData);

      double lastProgress = 0.0;
      String lastStatus = '';

      final res = await XapkService.extractAndStageXapk(
        xapkPath: xapkPath,
        packageName: 'com.example.splitapp',
        onProgress: (p, s) {
          lastProgress = p;
          lastStatus = s;
        },
      );

      expect(lastProgress, 1.0);
      expect(lastStatus, 'Extraction complete');

      final stagingDir = res['stagingDirectory'] as String;
      final apks = res['apkPaths'] as List<String>;

      expect(apks.length, 2);
      for (final p in apks) {
        expect(File(p).existsSync(), isTrue);
      }

      // Cleanup
      final dir = Directory(stagingDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
  });
}
