// lib/core/services/image_upload_service.dart
//
// Universal Upload Architecture — "dumb pipe" client implementation.
//
// For property photo batches: uploadRawToStaging() pushes raw bytes to the
// private staging_media bucket and returns the deterministic final URL that
// the process-staged-image Edge Function will create in public_media.
// No client-side format detection or transcoding — the backend handles all of it.
//
// For single-image uploads (avatars): use uploadImageBytes() → direct to the
// public profile-images bucket.  The image is already a normalised JPEG after
// ImageHelper.normalizeForUpload(), so no staging pipeline is needed and the
// URL is immediately usable (no async processing window).
//
// For ad creatives / logos: uploadSingleRawToStaging() uses the same async
// staging pipeline as property photos.
//
// All methods retry up to 3 times (read + upload separately) and log failures
// to ErrorLoggingService so they appear in the admin error logs.

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/image_format.dart';
import '../utils/logger.dart';
import 'error_logging_service.dart';

class ImageUploadService {
  // ── Property-photo batch upload (staging pipeline) ─────────────────────────

  /// Upload a raw image [file] to the private staging bucket.
  ///
  /// Uses `readAsBytes()` as the critical cross-platform fix: it forces the OS
  /// to resolve the file stream into raw bytes immediately, bypassing Android
  /// Scoped Storage and iOS sandbox path restrictions that cause screenshots
  /// and WhatsApp photos to silently fail on mobile browsers / PWA.
  ///
  /// Retries both `readAsBytes()` and the Supabase upload up to 3 times each
  /// so that transient OS / network blips don't surface as user-visible errors.
  ///
  /// Returns the predicted final public URL on success, null on failure.
  static Future<String?> uploadRawToStaging({
    required XFile file,
    required String userId,
    required String propertyId,
    required int index,
  }) async {
    // ── Step 1: read bytes (retry up to 3× for mobile file-access blips) ────
    Uint8List? rawBytes;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          rawBytes = bytes;
          break;
        }
        logger.w('uploadRawToStaging[$index]: empty bytes on attempt $attempt');
      } catch (e) {
        logger.w('uploadRawToStaging[$index]: readAsBytes attempt $attempt failed: $e');
      }
      if (attempt < 3) await Future.delayed(Duration(milliseconds: 500 * attempt));
    }

    if (rawBytes == null || rawBytes.isEmpty) {
      const msg = 'readAsBytes returned empty bytes after 3 attempts';
      logger.e('uploadRawToStaging[$index]: $msg');
      ErrorLoggingService.instance?.logError(
        errorType: 'UploadReadFailure',
        errorMessage: '$msg [index=$index, propertyId=$propertyId]',
        screenName: 'ImageUploadService',
        severity: 'error',
      );
      return null;
    }

    if (_isHtmlPage(rawBytes)) {
      const msg = 'readAsBytes returned an HTML page (service-worker offline fallback)';
      logger.w('uploadRawToStaging[$index]: $msg');
      ErrorLoggingService.instance?.logError(
        errorType: 'UploadHtmlPage',
        errorMessage: '$msg [index=$index]',
        screenName: 'ImageUploadService',
        severity: 'warning',
      );
      return null;
    }

    // ── Step 2: upload to staging (retry up to 3×) ──────────────────────────
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stagingPath = '$userId/${propertyId}_${timestamp}_$index.raw';

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await Supabase.instance.client.storage
            .from(SupabaseConfig.stagingMediaBucket)
            .uploadBinary(
              stagingPath,
              rawBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        // The Edge Function will create the JPEG at this deterministic path.
        // Return the predicted URL immediately — the shimmer covers the 1-3 s
        // processing window.
        final publicPath = '$userId/${propertyId}_${timestamp}_$index.jpg';
        return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/'
            '${SupabaseConfig.publicMediaBucket}/$publicPath';
      } catch (e) {
        logger.w('uploadRawToStaging[$index]: upload attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
        } else {
          logger.e('uploadRawToStaging[$index] failed after 3 attempts', error: e);
          ErrorLoggingService.instance?.logError(
            errorType: 'UploadStorageFailure',
            errorMessage: 'Staging upload failed after 3 attempts: $e',
            screenName: 'ImageUploadService',
            severity: 'error',
          );
        }
      }
    }
    return null;
  }

  // ── Single-image staging upload (ad creatives, logos) ─────────────────────

  /// Upload a single raw image [file] to the private staging bucket for
  /// non-property images (ad creatives, logos).
  ///
  /// Same retry-protected "dumb pipe" pipeline as [uploadRawToStaging].
  ///
  /// [folder] namespaces the image type, e.g. `'ad_images'`, `'ad_logos'`.
  /// [label] distinguishes uploads within the same folder, e.g. `'0'` or `'main'`.
  ///
  /// Returns the predicted final public URL in public_media, or null on failure.
  static Future<String?> uploadSingleRawToStaging({
    required XFile file,
    required String userId,
    required String folder,
    required String label,
  }) async {
    // ── Step 1: read bytes ────────────────────────────────────────────────────
    Uint8List? rawBytes;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          rawBytes = bytes;
          break;
        }
        logger.w('uploadSingleRawToStaging[$folder/$label]: empty bytes on attempt $attempt');
      } catch (e) {
        logger.w('uploadSingleRawToStaging[$folder/$label]: readAsBytes attempt $attempt failed: $e');
      }
      if (attempt < 3) await Future.delayed(Duration(milliseconds: 500 * attempt));
    }

    if (rawBytes == null || rawBytes.isEmpty) {
      const msg = 'readAsBytes returned empty bytes after 3 attempts';
      logger.e('uploadSingleRawToStaging[$folder/$label]: $msg');
      ErrorLoggingService.instance?.logError(
        errorType: 'UploadReadFailure',
        errorMessage: '$msg [folder=$folder, label=$label]',
        screenName: 'ImageUploadService',
        severity: 'error',
      );
      return null;
    }

    if (_isHtmlPage(rawBytes)) {
      const msg = 'readAsBytes returned an HTML page (service-worker offline fallback)';
      logger.w('uploadSingleRawToStaging[$folder/$label]: $msg');
      ErrorLoggingService.instance?.logError(
        errorType: 'UploadHtmlPage',
        errorMessage: '$msg [folder=$folder, label=$label]',
        screenName: 'ImageUploadService',
        severity: 'warning',
      );
      return null;
    }

    // ── Step 2: upload to staging ─────────────────────────────────────────────
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stagingPath = '$userId/${folder}_${timestamp}_$label.raw';

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await Supabase.instance.client.storage
            .from(SupabaseConfig.stagingMediaBucket)
            .uploadBinary(
              stagingPath,
              rawBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        final publicPath = '$userId/${folder}_${timestamp}_$label.jpg';
        return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/'
            '${SupabaseConfig.publicMediaBucket}/$publicPath';
      } catch (e) {
        logger.w('uploadSingleRawToStaging[$folder/$label]: upload attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
        } else {
          logger.e('uploadSingleRawToStaging[$folder/$label] failed after 3 attempts', error: e);
          ErrorLoggingService.instance?.logError(
            errorType: 'UploadStorageFailure',
            errorMessage: 'Staging upload failed after 3 attempts: $e',
            screenName: 'ImageUploadService',
            severity: 'error',
          );
        }
      }
    }
    return null;
  }

  // ── Direct upload (avatars and any pre-normalised bytes) ───────────────────

  /// Upload [bytes] directly to [bucket] (no staging pipeline).
  ///
  /// Use this for avatars and other images that are already normalised JPEGs
  /// (e.g. after [ImageHelper.normalizeForUpload]).  The URL returned is real
  /// and immediately accessible — there is no async processing window.
  ///
  /// Retries the Supabase upload up to 3 times for transient failures.
  /// Returns the public URL, or null if all attempts fail.
  static Future<String?> uploadImageBytes({
    required String bucket,
    required String pathPrefix,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return null;

    final fmt = detectImageFormat(bytes);
    if (fmt == DetectedImageFormat.html) {
      logger.w('uploadImageBytes: bytes are an HTML page — refusing');
      ErrorLoggingService.instance?.logError(
        errorType: 'UploadHtmlPage',
        errorMessage: 'uploadImageBytes received an HTML page [bucket=$bucket]',
        screenName: 'ImageUploadService',
        severity: 'warning',
      );
      return null;
    }

    final path = '$pathPrefix.${fmt.fileExtension}';

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await Supabase.instance.client.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: fmt.mimeType,
                cacheControl: '31536000',
                upsert: true,
              ),
            );
        return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
      } catch (e) {
        logger.w('uploadImageBytes: attempt $attempt failed for $bucket/$path: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
        } else {
          logger.e('uploadImageBytes failed after 3 attempts', error: e);
          ErrorLoggingService.instance?.logError(
            errorType: 'UploadStorageFailure',
            errorMessage: 'Direct upload failed after 3 attempts: $e',
            screenName: 'ImageUploadService',
            severity: 'error',
          );
        }
      }
    }
    return null;
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  static bool _isHtmlPage(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final head = String.fromCharCodes(bytes.take(15)).toLowerCase();
    return head.contains('<!doc') || head.contains('<html');
  }
}
