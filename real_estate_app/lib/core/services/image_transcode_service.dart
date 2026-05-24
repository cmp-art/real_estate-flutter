// lib/core/services/image_transcode_service.dart
//
// Server-side image transcoding for formats the client cannot decode itself.
//
// WHY THIS EXISTS:
//   iPhones save photos as HEIC. On native, image_picker transcodes HEIC→JPEG
//   at pick time, so this is never needed there. But on the web/PWA, no browser
//   except Safari can decode HEIC — Chrome/Firefox/Android browsers cannot turn
//   those bytes into pixels at all, so the client cannot crop or re-encode them.
//   Rather than store an unrenderable file, we POST the raw bytes to the
//   `transcode-image` Supabase Edge Function, which converts them to JPEG with
//   ImageMagick and returns the JPEG bytes.
//
// GRACEFUL DEGRADATION:
//   Every failure path returns null. If the Edge Function is not deployed yet,
//   times out, or errors, the caller treats the photo as "could not be
//   processed" and skips it with a user-facing message — the rest of the batch
//   uploads normally. Deploying the function is what turns HEIC-on-web from
//   "skipped" into "works"; no client release is required.

import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class ImageTranscodeService {
  // Match the app's image-size limit and the Edge Function's own MAX_INPUT_BYTES
  // (both 15 MB). A larger body has already been filtered out upstream and the
  // function would reject it anyway, so skip the round-trip and let the caller
  // drop it.
  static const int _maxInputBytes = AppConstants.maxImageSize;

  /// Convert arbitrary image [bytes] (typically HEIC) to JPEG via the
  /// `transcode-image` Edge Function. Returns JPEG bytes on success, or null
  /// on any failure (function missing, network error, timeout, bad response).
  static Future<Uint8List?> transcodeToJpeg(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > _maxInputBytes) return null;

    final baseUrl = SupabaseConfig.supabaseUrl;
    final anonKey = SupabaseConfig.supabaseAnonKey;
    if (baseUrl.isEmpty || anonKey.isEmpty) return null;

    final uri = Uri.parse('$baseUrl/functions/v1/transcode-image');

    // Header strategy for Supabase's new API-key system: publishable keys
    // (sb_publishable_...) are NOT JWTs. The function is deployed with
    // verify_jwt=false, so the gateway accepts the `apikey` header alone. We add
    // an `Authorization: Bearer` header ONLY when we have a real user-session
    // JWT — sending the publishable key there makes the gateway reject the call
    // with UNAUTHORIZED_INVALID_JWT_FORMAT, which is what silently broke HEIC/
    // AVIF uploads on the web.
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    final headers = <String, String>{
      'apikey': anonKey,
      'Content-Type': 'application/octet-stream',
    };
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    try {
      final resp = await http
          .post(uri, headers: headers, body: bytes)
          .timeout(const Duration(seconds: 45));

      if (resp.statusCode != 200) {
        logger.w('transcodeToJpeg: HTTP ${resp.statusCode} '
            '${resp.body.isNotEmpty ? '- ${resp.body}' : ''}');
        return null;
      }

      final out = resp.bodyBytes;
      if (out.isEmpty) return null;
      return out;
    } catch (e) {
      logger.w('transcodeToJpeg failed', error: e);
      return null;
    }
  }
}
