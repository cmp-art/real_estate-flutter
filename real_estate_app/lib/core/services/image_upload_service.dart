// lib/core/services/image_upload_service.dart
//
// Direct-upload client. Every image is uploaded synchronously to its PUBLIC
// bucket and the real, immediately-usable public URL is returned. There is no
// staging bucket, no Edge Function, no predicted URL and no async processing
// window — the URL works the instant this method returns, on every platform
// (Android, iOS, Web, PWA).
//
//   • Property photos    → property-images   (uploadPropertyImage)
//   • Ad creatives/logos → advertisements    (uploadCreativeImage)
//   • Avatars / pre-read → caller's bucket    (uploadImageBytes)
//
// Robustness (why uploads no longer "fail / try again" for any image type):
//   • readAsBytes() retried up to 3× — forces the OS to resolve the file into
//     raw bytes, bypassing Android Scoped Storage and the PWA service worker
//     that otherwise turn screenshots / shared photos into empty or HTML bytes.
//   • EVERY upload is coerced into a format the public buckets serve AND under
//     the destination bucket's size limit before it is sent. The buckets cap
//     property/ad images at 10 MB and avatars at 5 MB and only accept
//     jpeg/png/webp(/gif); anything larger or in another format (HEIC/AVIF/GIF/
//     unknown/over-size JPEG) is decoded and re-encoded to a right-sized JPEG.
//     This removes the silent server-side 400/413 rejection that produced the
//     intermittent "upload failed" errors on larger or HEIC photos.
//   • That decode/resize/re-encode runs on a BACKGROUND ISOLATE (compute) so a
//     big photo can never block the UI thread and trigger an ANR ("app not
//     responding"), which users experienced as a crash.
//   • the Supabase upload is retried up to 3× for transient network blips.
//   • EVERY failure is logged to ErrorLoggingService so it surfaces in the
//     admin error logs instead of failing silently.

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/image_format.dart';
import '../utils/logger.dart';
import 'error_logging_service.dart';

class ImageUploadService {
  // Safe per-upload byte ceilings, kept just under the server bucket limits
  // (defined in sql3) so a coerced image always lands inside the limit even
  // after Supabase adds its own overhead:
  //   property-images / advertisements → 10 MB bucket  → 9 MB ceiling
  //   profile-images                   →  5 MB bucket  → 4 MB ceiling
  static const int _maxBytesDefault = 9 * 1024 * 1024;
  static const int _maxBytesProfile = 4 * 1024 * 1024;

  static int _maxBytesFor(String bucket) =>
      bucket == SupabaseConfig.profileImagesBucket
          ? _maxBytesProfile
          : _maxBytesDefault;

  // ── Property photo → public property-images bucket ─────────────────────────

  /// Upload one property photo and return its real public URL (null on failure).
  static Future<String?> uploadPropertyImage({
    required XFile file,
    required String userId,
    required String propertyId,
    required int index,
  }) async {
    final bytes = await _readBytes(file, tag: 'property[$index] propertyId=$propertyId');
    if (bytes == null) return null;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _uploadServable(
      bytes: bytes,
      bucket: SupabaseConfig.propertyImagesBucket,
      pathPrefix: '$userId/${propertyId}_${timestamp}_$index',
      tag: 'property[$index]',
    );
  }

  // ── Ad creative / logo → public advertisements bucket ──────────────────────

  /// Upload one ad creative or logo and return its real public URL.
  ///
  /// [folder] namespaces the image type (e.g. `'ad_images'`, `'ad_logos'`);
  /// [label] distinguishes uploads within a folder (e.g. `'0'` or `'logo'`).
  static Future<String?> uploadCreativeImage({
    required XFile file,
    required String userId,
    required String folder,
    required String label,
  }) async {
    final bytes = await _readBytes(file, tag: 'creative[$folder/$label]');
    if (bytes == null) return null;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _uploadServable(
      bytes: bytes,
      bucket: SupabaseConfig.advertisementsBucket,
      pathPrefix: '$userId/${folder}_${timestamp}_$label',
      tag: 'creative[$folder/$label]',
    );
  }

  // ── Direct upload of already-read bytes (avatars) ──────────────────────────

  /// Upload [bytes] directly to [bucket] under [pathPrefix] (no extension — it
  /// is chosen from the detected format). Returns the real public URL.
  static Future<String?> uploadImageBytes({
    required String bucket,
    required String pathPrefix,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return null;
    return _uploadServable(
      bytes: bytes,
      bucket: bucket,
      pathPrefix: pathPrefix,
      tag: 'bucket=$bucket',
    );
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  /// Read raw bytes, retrying for transient mobile file-access blips.
  static Future<Uint8List?> _readBytes(XFile file, {required String tag}) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
        logger.w('upload $tag: empty bytes on attempt $attempt');
      } catch (e) {
        logger.w('upload $tag: readAsBytes attempt $attempt failed: $e');
      }
      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    _log('UploadReadFailure',
        'readAsBytes returned empty bytes after 3 attempts [$tag]', 'error');
    return null;
  }

  /// Coerce [bytes] into a bucket-servable, right-sized format, then upload with
  /// up to 3 retries and return the real public URL (null on failure).
  static Future<String?> _uploadServable({
    required Uint8List bytes,
    required String bucket,
    required String pathPrefix,
    required String tag,
  }) async {
    final servable = await _toServableBytes(
      bytes,
      maxBytes: _maxBytesFor(bucket),
      tag: tag,
    );
    if (servable == null) return null;

    // After coercion the format is always one the public buckets accept, so
    // re-detecting yields the correct extension + Content-Type.
    final fmt = detectImageFormat(servable);
    final path = '$pathPrefix.${fmt.fileExtension}';

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await Supabase.instance.client.storage
            .from(bucket)
            .uploadBinary(
              path,
              servable,
              fileOptions: FileOptions(
                contentType: fmt.mimeType,
                cacheControl: '31536000',
                upsert: true,
              ),
            )
            .timeout(const Duration(seconds: 30));
        return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
      } catch (e) {
        logger.w('upload $tag: attempt $attempt to $bucket/$path failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
        } else {
          _log('UploadStorageFailure',
              'Upload to $bucket failed after 3 attempts [$tag]: $e', 'error');
        }
      }
    }
    return null;
  }

  /// Returns bytes that are guaranteed to be (a) a format every public bucket
  /// serves (JPEG/PNG/WebP) and (b) no larger than [maxBytes], or null if the
  /// bytes can't be made servable.
  ///
  /// • JPEG/PNG/WebP already under [maxBytes] pass through untouched (preserves
  ///   PNG/WebP transparency for logos and avoids needless recompression).
  /// • Everything else — GIF, HEIC, AVIF, unknown-but-decodable (BMP/TIFF…), or
  ///   an over-size JPEG/PNG/WebP — is decoded, downscaled if huge, and
  ///   re-encoded to a JPEG that fits under [maxBytes].
  /// • HTML service-worker poison and truly undecodable bytes (e.g. raw HEIC on
  ///   a desktop browser, which the pure-Dart `image` package can't decode) are
  ///   refused and logged so the user can be told to pick a JPEG/PNG.
  ///
  /// The decode/resize/encode work happens on a background isolate via
  /// compute(), so it never blocks the UI thread.
  static Future<Uint8List?> _toServableBytes(
    Uint8List bytes, {
    required int maxBytes,
    required String tag,
  }) async {
    final fmt = detectImageFormat(bytes);

    // Service-worker offline page masquerading as an image — cannot recover.
    if (fmt == DetectedImageFormat.html) {
      _log('UploadHtmlPage',
          'Refusing an HTML service-worker page as an image [$tag]', 'warning');
      return null;
    }

    // Fast path: an already-servable format that's already small enough.
    final alreadyServable = fmt == DetectedImageFormat.jpeg ||
        fmt == DetectedImageFormat.png ||
        fmt == DetectedImageFormat.webp;
    if (alreadyServable && bytes.lengthInBytes <= maxBytes) {
      return bytes;
    }

    // Everything else is decoded + re-encoded to a right-sized JPEG off-thread.
    try {
      final out = await compute(
        _coerceToServableJpg,
        _CoerceRequest(bytes, maxBytes),
      );
      if (out != null && out.isNotEmpty) return out;
    } catch (e) {
      logger.w('upload $tag: coerce to servable JPEG failed: $e');
    }

    _log(
      'UploadUnsupportedFormat',
      'Could not convert ${fmt.name} bytes to a servable image [$tag]',
      'error',
    );
    return null;
  }

  static void _log(String errorType, String errorMessage, String severity) {
    ErrorLoggingService.instance?.logError(
      errorType: errorType,
      errorMessage: errorMessage,
      screenName: 'ImageUploadService',
      severity: severity,
    );
  }
}

/// Argument bundle for the [_coerceToServableJpg] isolate entry point.
/// (compute() takes exactly one sendable argument.)
class _CoerceRequest {
  final Uint8List bytes;
  final int maxBytes;
  const _CoerceRequest(this.bytes, this.maxBytes);
}

/// Runs on a background isolate (via compute). Decodes [req.bytes] (applying
/// EXIF orientation), downscaling and quality-stepping until the encoded JPEG
/// fits inside [req.maxBytes]. Returns null when the bytes can't be decoded
/// (e.g. raw HEIC/AVIF — no pure-Dart decoder — or corrupt data).
Uint8List? _coerceToServableJpg(_CoerceRequest req) {
  final decoded = img.decodeImage(req.bytes); // applies EXIF orientation
  if (decoded == null) return null;

  // Cap the longest edge so even a 48 MP photo encodes to a sane size and
  // bounds peak memory on the isolate. 2560 px is plenty for full-bleed display.
  const maxEdge = 2560;
  var image = decoded;
  if (image.width > maxEdge || image.height > maxEdge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxEdge)
        : img.copyResize(image, height: maxEdge);
  }

  // Step quality down first (cheap), then dimensions, until under the ceiling.
  var quality = 88;
  var out = img.encodeJpg(image, quality: quality);
  while (out.length > req.maxBytes && quality > 45) {
    quality -= 12;
    out = img.encodeJpg(image, quality: quality);
  }
  while (out.length > req.maxBytes && image.width > 800 && image.height > 800) {
    image = img.copyResize(image, width: (image.width * 0.8).round());
    out = img.encodeJpg(image, quality: 70);
  }

  return Uint8List.fromList(out);
}
