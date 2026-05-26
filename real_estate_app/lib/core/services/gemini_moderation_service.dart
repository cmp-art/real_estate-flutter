// lib/core/services/gemini_moderation_service.dart
//
// Cross-platform client for the `validate-content` Supabase Edge Function,
// which runs Gemini Flash-Lite image moderation server-side. Works identically
// on Android, iOS, Web and PWA because it is just an authenticated HTTPS call —
// there is no on-device model and the Gemini API key never reaches the client.
//
// For each photo this:
//   1. reads the raw bytes (with retries for flaky mobile / PWA file access),
//   2. downscales it to a small JPEG (~512 px long edge) on a background isolate
//      so a big photo never blocks the UI thread and the upload payload stays
//      tiny (~30-80 KB/image),
//   3. base64-encodes it and sends the batch to the Edge Function,
//   4. returns the structured verdict.
//
// Returns `null` on ANY failure (function undeployed, key unset, network error,
// timeout, undecodable input) so the caller can fall back to its rule-based
// text check and never hard-fail a submission.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/image_format.dart';
import '../utils/logger.dart';

/// Structured outcome of a Gemini moderation call.
class GeminiModerationResult {
  final bool approved;
  final int confidence; // 0-100
  final String category; // dominant subject / safety label
  final String reason; // one user-facing sentence

  const GeminiModerationResult({
    required this.approved,
    required this.confidence,
    required this.category,
    required this.reason,
  });
}

class GeminiModerationService {
  GeminiModerationService(this._supabase);

  final SupabaseClient _supabase;

  /// Name of the deployed Edge Function. NOTE: the slug uses a HYPHEN to match
  /// the deployed function and the project's other functions (transcode-image,
  /// etc.) — an underscore here 404s ("Requested function was not found").
  static const String _functionName = 'validate-content';

  /// Long-edge target for the thumbnail sent to Gemini — plenty for the model
  /// to recognise the subject, while keeping each image tiny on the wire.
  static const int _maxEdge = 512;
  static const int _jpegQuality = 70;

  /// If an image can't be decoded/downscaled (e.g. HEIC on desktop web), we
  /// only forward the raw bytes when they are a format Gemini accepts AND under
  /// this size, so we never push a huge payload.
  static const int _maxRawFallbackBytes = 4 * 1024 * 1024;

  static const Duration _timeout = Duration(seconds: 45);

  /// Moderate [images]. [isAd] selects the ad safety prompt (sexual/violent
  /// only) vs the stricter property prompt (must be real estate).
  ///
  /// Returns null when the service is unreachable / unconfigured / errored.
  Future<GeminiModerationResult?> moderate({
    required List<XFile> images,
    required bool isAd,
  }) async {
    if (images.isEmpty) return null;

    final payload = <Map<String, String>>[];
    for (final file in images) {
      final part = await _toInlinePart(file);
      if (part != null) payload.add(part);
    }
    if (payload.isEmpty) {
      logger.w('Gemini moderation: no usable images after encoding');
      return null;
    }

    try {
      final res = await _supabase.functions.invoke(
        _functionName,
        body: {
          'contentType': isAd ? 'ad' : 'property',
          'images': payload,
        },
      ).timeout(_timeout);

      final data = res.data;
      if (data is! Map) {
        logger.w('Gemini moderation: unexpected response type ${data.runtimeType}');
        return null;
      }
      if (data['ok'] != true) {
        logger.w('Gemini moderation not ok: stage=${data['stage']} '
            'detail=${data['detail']}');
        return null;
      }
      return GeminiModerationResult(
        approved: data['approved'] == true,
        confidence: (data['confidence'] as num?)?.round() ?? 0,
        category: (data['category'] as String?) ?? '',
        reason: (data['reason'] as String?) ?? '',
      );
    } catch (e) {
      logger.w('Gemini moderation call failed: $e');
      return null;
    }
  }

  /// Read + downscale one file into a Gemini inline-data part, or null if it
  /// can't be turned into something the model accepts.
  Future<Map<String, String>?> _toInlinePart(XFile file) async {
    Uint8List? bytes;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final b = await file.readAsBytes();
        if (b.isNotEmpty) {
          bytes = b;
          break;
        }
      } catch (_) {/* transient mobile / PWA file-access blip — retry */}
      await Future.delayed(Duration(milliseconds: 300 * attempt));
    }
    if (bytes == null || bytes.isEmpty) return null;

    final fmt = detectImageFormat(bytes);
    if (fmt == DetectedImageFormat.html) return null; // service-worker poison

    // Preferred path: decode + downscale to a small JPEG off the UI thread.
    try {
      final small = await compute(
        _downscaleToJpeg,
        _DownscaleRequest(bytes, _maxEdge, _jpegQuality),
      );
      if (small != null && small.isNotEmpty) {
        return {'mimeType': 'image/jpeg', 'data': base64Encode(small)};
      }
    } catch (e) {
      logger.w('Gemini moderation: downscale failed ($e) — trying raw bytes');
    }

    // Fallback: forward the original bytes only if Gemini can read the format
    // and the payload isn't huge (covers HEIC picked on a desktop browser,
    // which the pure-Dart decoder can't handle).
    const geminiReadable = {
      DetectedImageFormat.jpeg,
      DetectedImageFormat.png,
      DetectedImageFormat.webp,
      DetectedImageFormat.heic,
    };
    if (geminiReadable.contains(fmt) && bytes.length <= _maxRawFallbackBytes) {
      return {'mimeType': fmt.mimeType, 'data': base64Encode(bytes)};
    }
    return null;
  }
}

/// Argument bundle for the [_downscaleToJpeg] isolate entry point
/// (compute() takes exactly one sendable argument).
class _DownscaleRequest {
  final Uint8List bytes;
  final int maxEdge;
  final int quality;
  const _DownscaleRequest(this.bytes, this.maxEdge, this.quality);
}

/// Runs on a background isolate (via compute). Decodes the bytes (applying EXIF
/// orientation), downscales the long edge to [req.maxEdge], and re-encodes as a
/// JPEG. Returns null if the bytes can't be decoded (e.g. raw HEIC/AVIF, which
/// the pure-Dart `image` package can't read).
Uint8List? _downscaleToJpeg(_DownscaleRequest req) {
  final decoded = img.decodeImage(req.bytes); // applies EXIF orientation
  if (decoded == null) return null;

  var image = decoded;
  if (image.width > req.maxEdge || image.height > req.maxEdge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: req.maxEdge)
        : img.copyResize(image, height: req.maxEdge);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: req.quality));
}
