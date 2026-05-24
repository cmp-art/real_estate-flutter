// lib/core/utils/image_format.dart
// Single source of truth for "what kind of bytes is this, really?".
//
// File extensions and XFile.mimeType both lie: image_picker on web hands back
// blob: URLs named "image.jpg" that may actually be HEIC, and a PWA service
// worker can return an HTML fallback page in place of a blob. We therefore
// decide the format from the raw magic bytes only — never from the name/mime.
//
// Used by the upload pipeline to:
//   • set the correct Content-Type + file extension on the stored object, and
//   • refuse to store bytes no browser can render (HTML poison / undecodable).

import 'dart:typed_data';

enum DetectedImageFormat {
  jpeg,
  png,
  webp,
  gif,
  heic, // HEIC/HEIF — only Safari decodes this; needs transcoding elsewhere.
  avif, // AVIF — not universally renderable (older Safari/browsers); transcode.
  html, // service-worker offline page returned in place of an image.
  unknown,
}

extension DetectedImageFormatX on DetectedImageFormat {
  /// MIME type to send as the storage object's Content-Type.
  String get mimeType {
    switch (this) {
      case DetectedImageFormat.jpeg:
        return 'image/jpeg';
      case DetectedImageFormat.png:
        return 'image/png';
      case DetectedImageFormat.webp:
        return 'image/webp';
      case DetectedImageFormat.gif:
        return 'image/gif';
      case DetectedImageFormat.heic:
        return 'image/heic';
      case DetectedImageFormat.avif:
        return 'image/avif';
      case DetectedImageFormat.html:
      case DetectedImageFormat.unknown:
        return 'application/octet-stream';
    }
  }

  /// File extension (no leading dot) for the stored object's key.
  String get fileExtension {
    switch (this) {
      case DetectedImageFormat.jpeg:
        return 'jpg';
      case DetectedImageFormat.png:
        return 'png';
      case DetectedImageFormat.webp:
        return 'webp';
      case DetectedImageFormat.gif:
        return 'gif';
      case DetectedImageFormat.heic:
        return 'heic';
      case DetectedImageFormat.avif:
        return 'avif';
      case DetectedImageFormat.html:
      case DetectedImageFormat.unknown:
        return 'bin';
    }
  }

  /// True for formats that every target browser can render in an <img> tag.
  /// HEIC (Safari-only) and AVIF (no older Safari/browsers) are excluded so
  /// they get transcoded first; HTML/unknown are obviously excluded.
  bool get isBrowserRenderable {
    switch (this) {
      case DetectedImageFormat.jpeg:
      case DetectedImageFormat.png:
      case DetectedImageFormat.webp:
      case DetectedImageFormat.gif:
        return true;
      case DetectedImageFormat.heic:
      case DetectedImageFormat.avif:
      case DetectedImageFormat.html:
      case DetectedImageFormat.unknown:
        return false;
    }
  }
}

/// Detect the real image format from the leading bytes.
///
/// Recognises JPEG, PNG, GIF, WebP, the HEIF/HEIC family and AVIF, plus the
/// HTML fallback page a service worker may substitute for a blob. Anything else
/// is [DetectedImageFormat.unknown].
DetectedImageFormat detectImageFormat(Uint8List b) {
  if (b.length < 12) return DetectedImageFormat.unknown;

  // JPEG: FF D8 FF
  if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return DetectedImageFormat.jpeg;
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A) {
    return DetectedImageFormat.png;
  }

  // GIF: "GIF8"
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) {
    return DetectedImageFormat.gif;
  }

  // WebP: "RIFF" .... "WEBP"
  if (b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return DetectedImageFormat.webp;
  }

  // HEIF / HEIC and AVIF: ISO-BMFF "ftyp" box at offset 4, told apart by the
  // major brand at offset 8. Both need server-side transcoding for the web —
  // no mobile browser canvas reliably decodes HEIC, and AVIF isn't renderable
  // on older Safari/browsers (some viewers would see it broken).
  // HEIF brands: heic, heix, hevc, heim, heis, hevm, hevs, mif1, msf1, heif.
  if (b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
    final brand = String.fromCharCodes(b.sublist(8, 12)).toLowerCase();
    const heifBrands = {
      'heic', 'heix', 'hevc', 'heim', 'heis', 'hevm', 'hevs', 'mif1', 'msf1',
      'heif',
    };
    if (heifBrands.contains(brand)) return DetectedImageFormat.heic;
    if (brand == 'avif' || brand == 'avis') return DetectedImageFormat.avif;
  }

  // HTML — a service worker returned the offline fallback page instead of the
  // image blob. Skip the first few whitespace/BOM bytes before sniffing.
  var i = 0;
  while (i < b.length && i < 8 && (b[i] == 0x20 || b[i] == 0x09 || b[i] == 0x0A || b[i] == 0x0D || b[i] == 0xEF || b[i] == 0xBB || b[i] == 0xBF)) {
    i++;
  }
  if (i < b.length && b[i] == 0x3C) {
    // '<'
    final head = String.fromCharCodes(b.sublist(i, (i + 14).clamp(0, b.length)))
        .toLowerCase();
    if (head.startsWith('<!doc') ||
        head.startsWith('<html') ||
        head.startsWith('<?xml') ||
        head.startsWith('<svg')) {
      return DetectedImageFormat.html;
    }
  }

  return DetectedImageFormat.unknown;
}
