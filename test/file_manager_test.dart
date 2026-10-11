import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/screens/tools/file_manager_screen.dart';

void main() {
  group('FileManager Unit Tests', () {
    test('shellEscapePath wraps strings and escapes embedded single quotes', () {
      expect(shellEscapePath('/sdcard/My File.txt'), "'/sdcard/My File.txt'");
      expect(shellEscapePath("/sdcard/Bob's Music"), "'/sdcard/Bob'\\''s Music'");
      expect(shellEscapePath('/sdcard/\$HOME/test.sh'), "'/sdcard/\$HOME/test.sh'");
    });

    test('parseLsLine parses toybox ISO date format correctly', () {
      const line = 'drwxrwx--x 40 root sdcard_rw 4096 2026-10-11 06:02 Android';
      final item = parseLsLine(line, '/sdcard');

      expect(item, isNotNull);
      expect(item!.name, 'Android');
      expect(item.fullPath, '/sdcard/Android');
      expect(item.isDirectory, isTrue);
      expect(item.isLink, isFalse);
      expect(item.sizeBytes, 4096);
      expect(item.modified, '2026-10-11 06:02');
      expect(item.permissions, 'drwxrwx--x');
    });

    test('parseLsLine parses traditional Unix date format without prepending time', () {
      const line = 'drwxr-xr-x 2 root root 4096 Oct 11 06:02 bin';
      final item = parseLsLine(line, '/');

      expect(item, isNotNull);
      expect(item!.name, 'bin'); // MUST NOT be "06:02 bin"
      expect(item.fullPath, '/bin');
      expect(item.isDirectory, isTrue);
      expect(item.sizeBytes, 4096);
      expect(item.modified, 'Oct 11 06:02');
    });

    test('parseLsLine resolves symlinks pointing to directories', () {
      const line = 'lrwxrwxrwx 1 root root 21 2026-10-11 06:02 sdcard -> /storage/emulated/0';
      final item = parseLsLine(line, '/');

      expect(item, isNotNull);
      expect(item!.name, 'sdcard');
      expect(item.fullPath, '/sdcard');
      expect(item.isLink, isTrue);
      expect(item.linkTarget, '/storage/emulated/0');
      expect(item.isDirectory, isTrue); // Resolved directory target
    });

    test('parseLsLine ignores total lines and empty lines', () {
      expect(parseLsLine('total 248', '/sdcard'), isNull);
      expect(parseLsLine('', '/sdcard'), isNull);
      expect(parseLsLine('   ', '/sdcard'), isNull);
    });

    test('parseLsLine identifies APK files properly', () {
      const line = '-rw-r--r-- 1 u0_a123 u0_a123 48723910 2026-10-11 06:15 update.apk';
      final item = parseLsLine(line, '/sdcard/Download');

      expect(item, isNotNull);
      expect(item!.name, 'update.apk');
      expect(item.isDirectory, isFalse);
      expect(item.isArchive, isTrue); // ArchiveService recognizes .apk as archive container
      expect(item.sizeBytes, 48723910);
    });
  });
}
