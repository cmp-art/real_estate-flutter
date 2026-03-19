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

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CdnService {
  // The Supabase project URL — read from .env, never hardcoded.
  static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Returns true when Supabase URL is available.
  static bool get isCdnEnabled => _supabaseUrl.isNotEmpty;

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

    final base = _buildRenderBase(storageUrlOrPath);
    if (base.isEmpty) return storageUrlOrPath;

    final params = <String, String>{};
    if (width != null) params['width'] = '$width';
    if (height != null) params['height'] = '$height';
    params['quality'] = '$quality';
    if (format != 'origin') params['format'] = format;

    return Uri.parse(base).replace(queryParameters: params).toString();
  }

  /// Thumbnail (300 × 200, quality 70, WebP). Used in property list cards.
  static String getThumbnailUrl(String storageUrlOrPath) =>
      getOptimizedImageUrl(storageUrlOrPath, width: 300, height: 200, quality: 70, format: 'webp');

  /// Medium (800 × 600, quality 75, WebP). Used in property detail hero.
  static String getMediumUrl(String storageUrlOrPath) =>
      getOptimizedImageUrl(storageUrlOrPath, width: 800, height: 600, quality: 75, format: 'webp');

  /// Full-size (1280 × 960, quality 80, WebP). Used in photo gallery.
  static String getFullSizeUrl(String storageUrlOrPath) =>
      getOptimizedImageUrl(storageUrlOrPath, width: 1280, height: 960, quality: 80, format: 'webp');

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
