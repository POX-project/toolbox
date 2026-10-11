import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/services/archive_service.dart';

void main() {
  group('ArchiveService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('archive_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('isArchive accurately identifies archive extensions', () {
      expect(ArchiveService.isArchive('package.zip'), isTrue);
      expect(ArchiveService.isArchive('data.tar.gz'), isTrue);
      expect(ArchiveService.isArchive('bundle.apk'), isTrue);
      expect(ArchiveService.isArchive('file.txt'), isFalse);
      expect(ArchiveService.isArchive('image.png'), isFalse);
    });

    test('createArchive creates valid ZIP, lists entries, and extracts properly', () async {
      // 1. Create source files
      final file1 = File('${tempDir.path}/hello.txt');
      await file1.writeAsString('Hello World from Toolbox!');

      final subDir = Directory('${tempDir.path}/nested');
      await subDir.create();
      final file2 = File('${subDir.path}/config.json');
      await file2.writeAsString('{"status": "ok", "power": 100}');

      final zipPath = '${tempDir.path}/output.zip';

      // 2. Compress
      await ArchiveService.createArchive(
        sourcePaths: [file1.path, subDir.path],
        outputFilePath: zipPath,
        format: 'zip',
      );

      expect(File(zipPath).existsSync(), isTrue);
      expect(File(zipPath).lengthSync(), greaterThan(0));

      // 3. Test integrity
      final integrity = await ArchiveService.testArchive(zipPath);
      expect(integrity, contains('verified OK'));

      // 4. List virtual entries
      final entries = await ArchiveService.listEntries(zipPath);
      expect(entries.length, greaterThanOrEqualTo(2));
      final names = entries.map((e) => e.name).toList();
      expect(names, contains('hello.txt'));
      expect(names, contains('config.json'));

      // 5. Read single file content from archive
      final readBytes = await ArchiveService.readFileFromArchive(
        archivePath: zipPath,
        innerFilePath: 'hello.txt',
      );
      expect(readBytes, isNotNull);
      expect(String.fromCharCodes(readBytes!), equals('Hello World from Toolbox!'));

      // 6. Extract archive to new destination
      final extractDir = '${tempDir.path}/extracted';
      await ArchiveService.extractArchive(
        archivePath: zipPath,
        destinationDir: extractDir,
      );

      final extractedFile1 = File('$extractDir/hello.txt');
      expect(extractedFile1.existsSync(), isTrue);
      expect(await extractedFile1.readAsString(), equals('Hello World from Toolbox!'));

      final extractedFile2 = File('$extractDir/nested/config.json');
      expect(extractedFile2.existsSync(), isTrue);
      expect(await extractedFile2.readAsString(), equals('{"status": "ok", "power": 100}'));
    });

    test('createArchive creates valid TAR.GZ archive', () async {
      final file = File('${tempDir.path}/sample.log');
      await file.writeAsString('Kernel trace log entry');

      final tarGzPath = '${tempDir.path}/sample.tar.gz';
      await ArchiveService.createArchive(
        sourcePaths: [file.path],
        outputFilePath: tarGzPath,
        format: 'tar.gz',
      );

      expect(File(tarGzPath).existsSync(), isTrue);
      final entries = await ArchiveService.listEntries(tarGzPath);
      expect(entries.any((e) => e.name == 'sample.log'), isTrue);
    });
  });
}
