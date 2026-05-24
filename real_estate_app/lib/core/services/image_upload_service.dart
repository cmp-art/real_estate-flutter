// lib/core/services/image_upload_service.dart
//
// Shared, format-correct image upload for single images (avatars, ad images,
// company logos). Property listings have their own batch uploader in
// PropertyRemoteDataSource, but they all follow the same rule enforced here:
// the stored object's extension and Content-Type come from the REAL bytes, and
// anything no browser can render is refused rather than stored broken.
//
// Pair this with ImageHelper.normalizeForUpload(), which produces the bytes
// (transcoding iPhone HEIC to JPEG on the web). This service is the final
// write step.

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/image_format.dart';
import '../utils/logger.dart';

class ImageUploadService {
  /// Upload [bytes] to [bucket] at "[pathPrefix].<ext>", where the extension
  /// and Content-Type are derived from the real bytes. Returns the public URL,
  /// or null if the bytes aren't a renderable image or the upload fails.
  ///
  /// [pathPrefix] must NOT include an extension — this picks the correct one.
  /// For buckets with per-user RLS (e.g. profile-images), the prefix must start
  /// with the user's id, e.g. "<userId>/avatar_<timestamp>".
  static Future<String?> uploadImageBytes({
    required String bucket,
    required String pathPrefix,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return null;

    final fmt = detectImageFormat(bytes);
    if (!fmt.isBrowserRenderable) {
      logger.w('uploadImageBytes: ${fmt.name} is not renderable — refusing');
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
}
