// lib/core/services/cdn_service.dart
// CDN URL management and image optimization
//
// This app uses Supabase's BUILT-IN image transformation CDN.
// No external CDN (CloudFront, Cloudflare, etc.) is required.
//
// Supabase serves images through its global edge network and automatically
// caches transformed images when Cache-Control headers are set (which we do
// with FileOptions(cacheControl: '31536000') on every upload).
//
// Transformation endpoint:
//   GET /storage/v1/render/image/public/<bucket>/<path>?width=W&height=H&quality=Q
//
// Docs: https://supabase.com/docs/guides/storage/serving/image-transformations

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CdnService {
  // The Supabase project URL — read from .env, never hardcoded.
  static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Returns true when Supabase URL is available.
  static bool get isCdnEnabled => _supabaseUrl.isNotEmpty;

  /// Supabase image transformations (the `/render/image` endpoint) require a
  /// PAID plan. This project's plan returns HTTP 403 for every transform
  /// request, so we serve the original object URLs instead (images are already
  /// resized to ~1280px at upload time, so this is fine). Flip to `true` only
  /// after moving to a Supabase plan that includes image transformations.
  static bool transformsEnabled = false;

  /// Returns the best image format for the current platform.
  /// WebP is supported on Web, Android, and iOS 14+.
  /// Falls back to jpeg for iOS 13 (universally supported, still smaller than PNG/HEIC).
  static String get _imageFormat {
    if (kIsWeb) return 'webp';
    if (Platform.isIOS) {
      // Platform.operatingSystemVersion on iOS: "Version 13.5 (Build 17F75)"
      final match = RegExp(r'Version (\d+)').firstMatch(Platform.operatingSystemVersion);
      final major = int.tryParse(match?.group(1) ?? '14') ?? 14;
      return major >= 14 ? 'webp' : 'jpeg';
    }
    return 'webp'; // Android and other platforms fully support WebP
  }

  // ── Image URL helpers ────────────────────────────────────────────────────

  /// Returns an optimised image URL using Supabase's built-in transformation CDN.
  /// Pass a full Supabase storage URL **or** a bare bucket path like
  ///   `property-images/uuid/photo.jpg`
  static String getOptimizedImageUrl(
    String storageUrlOrPath, {
    int? width,
    int? height,
    int quality = 75,
    String format = 'origin', // 'origin' | 'avif' | 'webp'
  }) {
    if (storageUrlOrPath.isEmpty) return '';

    // Transforms unavailable on this plan → serve the plain object URL so the
    // image loads on the first request (no 403 round-trip to /render/image).
    if (!transformsEnabled) return getOriginalUrl(storageUrlOrPath);

    final base = _buildRenderBase(storageUrlOrPath);
    if (base.isEmpty) return storageUrlOrPath;

    final params = <String, String>{};
    if (width != null) params['width'] = '$width';
    if (height != null) params['height'] = '$height';
    params['quality'] = '$quality';
    if (format != 'origin') params['format'] = format;

    return Uri.parse(base).replace(queryParameters: params).toString();
  }

  /// Thumbnail (300 × 200, quality 70). Used in property list cards.
  static String getThumbnailUrl(String storageUrlOrPath) =>
      getOptimizedImageUrl(storageUrlOrPath, width: 300, height: 200, quality: 70, format: _imageFormat);

  /// Medium (800 × 600, quality 75). Used in property detail hero.
  static String getMediumUrl(String storageUrlOrPath) =>
      getOptimizedImageUrl(storageUrlOrPath, width: 800, height: 600, quality: 75, format: _imageFormat);

  /// Full-size (1280 × 960, quality 80). Used in photo gallery.
  static String getFullSizeUrl(String storageUrlOrPath) =>
      getOptimizedImageUrl(storageUrlOrPath, width: 1280, height: 960, quality: 80, format: _imageFormat);

  /// The original, un-transformed object URL — the safe fallback when the image
  /// transform endpoint (/render/image) is unavailable (e.g. the Supabase plan
  /// doesn't include transformations) and returns an error. Images are already
  /// resized to ~1280px at upload time, so serving the original is fine.
  ///
  /// Accepts a full Supabase storage URL (object OR render form) or a bare
  /// bucket path, and always returns the plain `/object/public/` form.
  static String getOriginalUrl(String storageUrlOrPath) {
    if (storageUrlOrPath.isEmpty) return '';

    // A render/transform URL → rewrite back to the plain object URL.
    if (storageUrlOrPath.contains('/storage/v1/render/image/public/')) {
      final base = storageUrlOrPath.replaceFirst(
        '/storage/v1/render/image/public/',
        '/storage/v1/object/public/',
      );
      // Drop any transform query params (?width=…&quality=…) cleanly.
      final q = base.indexOf('?');
      return q == -1 ? base : base.substring(0, q);
    }

    // Already a plain object URL.
    if (storageUrlOrPath.contains('/storage/v1/object/public/')) {
      return storageUrlOrPath;
    }

    // Bare path like "property-images/uuid/photo.jpg".
    if (!storageUrlOrPath.startsWith('http') && _supabaseUrl.isNotEmpty) {
      return '$_supabaseUrl/storage/v1/object/public/$storageUrlOrPath';
    }

    return storageUrlOrPath;
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  static String _buildRenderBase(String input) {
    if (_supabaseUrl.isEmpty) return '';

    // Already a full Supabase storage URL?
    // https://xxx.supabase.co/storage/v1/object/public/bucket/path
    //                                  ↓ rewrite to render endpoint
    // https://xxx.supabase.co/storage/v1/render/image/public/bucket/path
    if (input.contains('/storage/v1/object/public/')) {
      return input.replaceFirst(
        '/storage/v1/object/public/',
        '/storage/v1/render/image/public/',
      );
    }

    // Bare path like "property-images/uuid/photo.jpg"
    if (!input.startsWith('http')) {
      return '$_supabaseUrl/storage/v1/render/image/public/$input';
    }

    return input; // Unknown format — return as-is
  }
}

// ── Custom local cache manager ───────────────────────────────────────────────
// Keeps up to 500 images on device for 30 days.
// Supabase already caches on its edge; this layer handles offline support.

class CustomCacheManager {
  static const key = 'realEstateCacheKey';

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  static Future<void> clearCache() => instance.emptyCache();
}
