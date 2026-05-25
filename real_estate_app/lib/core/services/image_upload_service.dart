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
// Robustness:
//   • readAsBytes() retried up to 3× — forces the OS to resolve the file into
//     raw bytes, bypassing Android Scoped Storage and the PWA service worker
//     that otherwise turn screenshots / shared photos into empty or HTML bytes.
//   • the Supabase upload is retried up to 3× for transient network blips.
//   • the stored object is guaranteed to be a format the public buckets serve
//     (JPEG/PNG/WebP/GIF). HEIC/AVIF/unknown bytes are re-encoded to JPEG when
//     decodable; truly unservable bytes are refused.
//   • EVERY failure is logged to ErrorLoggingService so it surfaces in the
//     admin error logs instead of failing silently.

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/image_format.dart';
import '../utils/logger.dart';
import 'error_logging_service.dart';

class ImageUploadService {
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

  /// Coerce [bytes] into a bucket-servable format, then upload with up to 3
  /// retries and return the real public URL (null on failure).
  static Future<String?> _uploadServable({
    required Uint8List bytes,
    required String bucket,
    required String pathPrefix,
    required String tag,
  }) async {
    final servable = _toServableBytes(bytes, tag: tag);
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

  /// Returns bytes in a format the public buckets serve (JPEG/PNG/WebP/GIF), or
  /// null if the bytes can't be made servable.
  ///
  /// JPEG/PNG/WebP/GIF pass through untouched. HEIC/AVIF/unknown bytes are
  /// re-encoded to JPEG via the `image` package when decodable (covers stray
  /// formats like BMP/TIFF too). HTML service-worker poison and undecodable
  /// bytes are refused and logged.
  static Uint8List? _toServableBytes(Uint8List bytes, {required String tag}) {
    final fmt = detectImageFormat(bytes);
    switch (fmt) {
      case DetectedImageFormat.jpeg:
      case DetectedImageFormat.png:
      case DetectedImageFormat.webp:
      case DetectedImageFormat.gif:
        return bytes;
      case DetectedImageFormat.html:
        _log('UploadHtmlPage',
            'Refusing an HTML service-worker page as an image [$tag]', 'warning');
        return null;
      case DetectedImageFormat.heic:
      case DetectedImageFormat.avif:
      case DetectedImageFormat.unknown:
        try {
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            return Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
          }
        } catch (e) {
          logger.w('upload $tag: re-encode to JPEG failed: $e');
        }
        _log('UploadUnsupportedFormat',
            'Could not convert ${fmt.name} bytes to a servable image [$tag]',
            'error');
        return null;
    }
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
