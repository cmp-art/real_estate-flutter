// test/unit/image_crop_math_test.dart
// Tests the 4:3 center-crop algorithm used in ImageHelper.cropToCard.
// Pure Dart — no Flutter, no image package, no file I/O.

import 'package:flutter_test/flutter_test.dart';

/// Replicates the crop calculation from ImageHelper.cropToCard exactly.
({int cropW, int cropH, int offsetX, int offsetY}) calc43Crop(
    int srcW, int srcH) {
  int cropW, cropH;
  if (srcW / srcH >= 4 / 3) {
    cropH = srcH;
    cropW = (srcH * 4 / 3).round();
  } else {
    cropW = srcW;
    cropH = (srcW * 3 / 4).round();
  }
  return (
    cropW: cropW,
    cropH: cropH,
    offsetX: (srcW - cropW) ~/ 2,
    offsetY: (srcH - cropH) ~/ 2,
  );
}

void main() {
  group('4:3 crop — output ratio', () {
    void assertRatio(int w, int h) {
      final r = calc43Crop(w, h);
      final ratio = r.cropW / r.cropH;
      expect(ratio, closeTo(4 / 3, 0.01),
          reason: 'Input ${w}x$h → output ${r.cropW}x${r.cropH} ratio $ratio');
    }

    test('landscape wide (1920×1080)', () => assertRatio(1920, 1080));
    test('landscape moderate (1280×720)', () => assertRatio(1280, 720));
    test('portrait (1080×1920)', () => assertRatio(1080, 1920));
    test('portrait narrow (720×1280)', () => assertRatio(720, 1280));
    test('square (1000×1000)', () => assertRatio(1000, 1000));
    test('exactly 4:3 (1280×960)', () => assertRatio(1280, 960));
    test('small square (100×100)', () => assertRatio(100, 100));
    test('very wide (3000×500)', () => assertRatio(3000, 500));
  });

  group('4:3 crop — crop rect fits inside source', () {
    void assertFits(int w, int h) {
      final r = calc43Crop(w, h);
      expect(r.cropW, lessThanOrEqualTo(w),
          reason: 'cropW ${r.cropW} exceeds srcW $w');
      expect(r.cropH, lessThanOrEqualTo(h),
          reason: 'cropH ${r.cropH} exceeds srcH $h');
      expect(r.offsetX, greaterThanOrEqualTo(0));
      expect(r.offsetY, greaterThanOrEqualTo(0));
      expect(r.offsetX + r.cropW, lessThanOrEqualTo(w));
      expect(r.offsetY + r.cropH, lessThanOrEqualTo(h));
    }

    test('landscape (1920×1080)', () => assertFits(1920, 1080));
    test('portrait (1080×1920)', () => assertFits(1080, 1920));
    test('square (1000×1000)', () => assertFits(1000, 1000));
    test('exactly 4:3 (1280×960)', () => assertFits(1280, 960));
    test('very wide (3000×500)', () => assertFits(3000, 500));
    test('very tall (500×3000)', () => assertFits(500, 3000));
  });

  group('4:3 crop — centering', () {
    test('landscape crop is horizontally centered', () {
      final r = calc43Crop(1920, 1080);
      // Wide image → height is preserved, width clipped from both sides equally
      expect(r.offsetY, equals(0));
      final leftPad = r.offsetX;
      final rightPad = 1920 - r.cropW - r.offsetX;
      expect((leftPad - rightPad).abs(), lessThanOrEqualTo(1));
    });

    test('portrait crop is vertically centered', () {
      final r = calc43Crop(1080, 1920);
      // Tall image → width is preserved, height clipped from top and bottom
      expect(r.offsetX, equals(0));
      final topPad = r.offsetY;
      final botPad = 1920 - r.cropH - r.offsetY;
      expect((topPad - botPad).abs(), lessThanOrEqualTo(1));
    });

    test('square crop has symmetric offsets', () {
      final r = calc43Crop(1000, 1000);
      // Square is taller than 4:3 → height clipped, offsetX = 0
      expect(r.offsetX, equals(0));
      expect(r.offsetY, greaterThan(0));
    });
  });

  group('4:3 crop — exact values', () {
    test('exactly 4:3 source produces no crop', () {
      final r = calc43Crop(1280, 960);
      expect(r.cropW, equals(1280));
      expect(r.cropH, equals(960));
      expect(r.offsetX, equals(0));
      expect(r.offsetY, equals(0));
    });

    test('1920×1080 clips to 1440×1080', () {
      final r = calc43Crop(1920, 1080);
      expect(r.cropH, equals(1080));
      expect(r.cropW, equals(1440)); // 1080 * 4/3
      expect(r.offsetX, equals(240)); // (1920-1440)/2
      expect(r.offsetY, equals(0));
    });

    test('1080×1920 clips to 1080×810', () {
      final r = calc43Crop(1080, 1920);
      expect(r.cropW, equals(1080));
      expect(r.cropH, equals(810)); // 1080 * 3/4
      expect(r.offsetX, equals(0));
      expect(r.offsetY, equals(555)); // (1920-810)/2
    });
  });
}
