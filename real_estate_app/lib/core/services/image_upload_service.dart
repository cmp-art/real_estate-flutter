// lib/core/services/image_upload_service.dart
//
// Universal Upload Architecture — "dumb pipe" client implementation.
//
// For property photo batches: uploadRawToStaging() pushes raw bytes to the
// private staging_media bucket and returns the deterministic final URL that
// the process-staged-image Edge Function will create in public_media.
// No client-side format detection or transcoding — the backend handles all of it.
//
// For single-image uploads (avatars, ad creatives, logos): uploadSingleRawToStaging()
// uses the same async staging pipeline — raw bytes → staging_media → public_media.
// uploadImageBytes() is kept only as a legacy fallback.

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/image_format.dart';
import '../utils/logger.dart';

class ImageUploadService {
  /// Upload a raw image [file] to the private staging bucket.
  ///
  /// Uses `readAsBytes()` as the critical cross-platform fix: it forces the OS
  /// to resolve the file stream into raw bytes immediately, bypassing Android
  /// Scoped Storage and iOS sandbox path restrictions that cause screenshots
  /// and WhatsApp photos to silently fail on mobile browsers / PWA.
  ///
  /// The [propertyId] and [index] are encoded into the staging path so the
  /// backend can derive a deterministic output path (`.raw` → `.jpg`) in
  /// public_media without any extra DB round-trip.
  ///
  /// Returns the predicted final public URL on success, null on failure.
  static Future<String?> uploadRawToStaging({
    required XFile file,
    required String userId,
    required String propertyId,
    required int index,
  }) async {
    // CRITICAL PWA / Scoped Storage fix:
    // readAsBytes() forces the OS to expose the actual file bytes immediately,
    // bypassing any intermediate path (blob URL, content URI, sandbox symlink)
    // that the service worker or OS might intercept and poison with an error page.
    final Uint8List rawBytes = await file.readAsBytes();
    if (rawBytes.isEmpty) {
      logger.w('uploadRawToStaging[$index]: empty byte stream — skipping');
      return null;
    }

    // Refuse only an HTML page — a service worker offline fallback substituted
    // for an image blob. Everything else (HEIC, AVIF, PNG, unknown) is uploaded
    // as-is; the backend transcodes all formats to JPEG.
    if (_isHtmlPage(rawBytes)) {
      logger.w('uploadRawToStaging[$index]: bytes are an HTML page — skipping');
      return null;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stagingPath = '$userId/${propertyId}_${timestamp}_$index.raw';

    try {
      await Supabase.instance.client.storage
          .from(SupabaseConfig.stagingMediaBucket)
          .uploadBinary(
            stagingPath,
            rawBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // The Edge Function will create the JPEG at this deterministic path in
      // public_media. Returning this URL now lets the caller store it in the DB
      // immediately — the image widget's natural loading shimmer covers the brief
      // processing window (typically 1–3 seconds).
      final publicPath = '$userId/${propertyId}_${timestamp}_$index.jpg';
      return '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/'
          '${SupabaseConfig.publicMediaBucket}/$publicPath';
    } catch (e) {
      logger.e('uploadRawToStaging[$index] failed', error: e);
      return null;
    }
  }

  /// Upload a single raw image [file] to the private staging bucket for
  /// non-property images (avatars, ad creatives, logos).
  ///
  /// Same "dumb pipe" pipeline as [uploadRawToStaging]: `readAsBytes()` is used
  /// as the critical cross-platform fix, bypassing OS path restrictions on
  /// Android Scoped Storage, iOS sandbox, and PWA service-worker interception.
  ///
  /// [folder] namespaces the image type, e.g. `'avatar'`, `'ad_images'`,
  /// `'ad_logos'`.  [label] distinguishes uploads within the same folder, e.g.
  /// `'0'` or `'main'`.
  ///
  /// Returns the predicted final public URL in public_media, or null on failure.
  static Future<String?> uploadSingleRawToStaging({
    required XFile file,
    required String userId,
    required String folder,
    required String label,
  }) async {
    final Uint8List rawBytes = await file.readAsBytes();
    if (rawBytes.isEmpty) {
      logger.w('uploadSingleRawToStaging[$folder/$label]: empty byte stream — skipping');
      return null;
    }
    if (_isHtmlPage(rawBytes)) {
      logger.w('uploadSingleRawToStaging[$folder/$label]: bytes are an HTML page — skipping');
      return null;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stagingPath = '$userId/${folder}_${timestamp}_$label.raw';

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
      logger.e('uploadSingleRawToStaging[$folder/$label] failed', error: e);
      return null;
    }
  }

  /// Upload [bytes] directly to [bucket] for single-image use cases where the
  /// caller has already normalised the bytes and wants direct-to-bucket storage.
  /// Returns the public URL, or null if the upload fails.
  ///
  /// Prefer [uploadSingleRawToStaging] for new upload flows.
  static Future<String?> uploadImageBytes({
    required String bucket,
    required String pathPrefix,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return null;

    final fmt = detectImageFormat(bytes);
    if (fmt == DetectedImageFormat.html) {
      logger.w('uploadImageBytes: bytes are an HTML page — refusing');
      return null;
    }

    try {
      final path = '$pathPrefix.${fmt.fileExtension}';
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
      logger.e('uploadImageBytes failed', error: e);
      return null;
    }
  }

  static bool _isHtmlPage(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final head = String.fromCharCodes(bytes.take(15)).toLowerCase();
    return head.contains('<!doc') || head.contains('<html');
  }
}
