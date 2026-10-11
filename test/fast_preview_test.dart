import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/widgets/fast_preview_modal.dart';

void main() {
  group('FastPreviewModal Type Detection Tests', () {
    test('Image extensions map to PreviewType.image', () {
      final imageExts = ['photo.jpg', 'img.jpeg', 'graphic.png', 'banner.webp', 'anim.gif', 'icon.ico', 'vector.svg', 'bitmap.bmp'];
      for (final f in imageExts) {
        expect(FastPreviewModal.detectPreviewType(f), PreviewType.image, reason: 'Failed for $f');
      }
    });

    test('Video extensions map to PreviewType.video', () {
      final videoExts = ['clip.mp4', 'movie.mkv', 'rec.avi', 'recording.mov', 'feed.webm', 'old.3gp', 'stream.flv', 'segment.mts'];
      for (final f in videoExts) {
        expect(FastPreviewModal.detectPreviewType(f), PreviewType.video, reason: 'Failed for $f');
      }
    });

    test('Audio extensions map to PreviewType.audio', () {
      final audioExts = ['song.mp3', 'lossless.flac', 'audio.wav', 'track.ogg', 'voice.m4a', 'record.aac', 'podcast.opus'];
      for (final f in audioExts) {
        expect(FastPreviewModal.detectPreviewType(f), PreviewType.audio, reason: 'Failed for $f');
      }
    });

    test('Font extensions map to PreviewType.font', () {
      expect(FastPreviewModal.detectPreviewType('Roboto-Bold.ttf'), PreviewType.font);
      expect(FastPreviewModal.detectPreviewType('FiraCode.otf'), PreviewType.font);
    });

    test('Package extensions map to PreviewType.package', () {
      expect(FastPreviewModal.detectPreviewType('app-release.apk'), PreviewType.package);
      expect(FastPreviewModal.detectPreviewType('game_bundle.xapk'), PreviewType.package);
      expect(FastPreviewModal.detectPreviewType('splits.apks'), PreviewType.package);
      expect(FastPreviewModal.detectPreviewType('mod.apkm'), PreviewType.package);
    });

    test('Special structured formats map to json and markdown', () {
      expect(FastPreviewModal.detectPreviewType('manifest.json'), PreviewType.json);
      expect(FastPreviewModal.detectPreviewType('README.md'), PreviewType.markdown);
    });

    test('Source code and text files map to PreviewType.text', () {
      final textFiles = [
        'notes.txt', 'script.sh', 'main.dart', 'server.py', 'config.yaml',
        'build.gradle', 'activity.kt', 'service.java', 'styles.css',
        'index.html', 'app.js', 'index.ts', 'data.csv', 'schema.sql'
      ];
      for (final f in textFiles) {
        expect(FastPreviewModal.detectPreviewType(f), PreviewType.text, reason: 'Failed for $f');
      }
    });

    test('Binary/compiled files map to PreviewType.hex', () {
      final binaryFiles = [
        'libnative.so', 'classes.dex', 'kernel.img', 'firmware.bin',
        'data.dat', 'storage.db', 'app.sqlite', 'disc.iso'
      ];
      for (final f in binaryFiles) {
        expect(FastPreviewModal.detectPreviewType(f), PreviewType.hex, reason: 'Failed for $f');
      }
    });
  });
}
