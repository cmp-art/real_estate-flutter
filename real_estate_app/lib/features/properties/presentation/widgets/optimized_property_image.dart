// features/properties/presentation/widgets/optimized_property_image.dart
// Optimized image widget with CDN support, caching, and a robust display chain.
//
// Images are uploaded directly to a public bucket, so the stored URL is live
// immediately. For bandwidth we first request Supabase's image-transform
// endpoint (/render/image). If that endpoint errors — e.g. the project's plan
// doesn't include transformations — we automatically fall back to the original
// object URL so the image ALWAYS shows. A short retry then covers transient
// network blips before any permanent placeholder is shown.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/cdn_service.dart';

class OptimizedPropertyImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isThumbnail;
  final BorderRadius? borderRadius;

  const OptimizedPropertyImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isThumbnail = true,
    this.borderRadius,
  });

  @override
  State<OptimizedPropertyImage> createState() => _OptimizedPropertyImageState();
}

class _OptimizedPropertyImageState extends State<OptimizedPropertyImage> {
  // Retry up to 3 times (= 6 s) for transient network errors before the
  // permanent placeholder. (Uploads are synchronous now, so there is no
  // processing window to wait out — these retries are purely for flaky links.)
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  int _retryCount = 0;
  Timer? _retryTimer;
  bool _retryScheduled = false;

  // Once the transform endpoint errors we switch to the original object URL.
  bool _useOriginal = false;
  bool _fallbackScheduled = false;

  @override
  void didUpdateWidget(OptimizedPropertyImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      // Parent gave us a new URL — reset all display state for the fresh image.
      _retryTimer?.cancel();
      _retryCount = 0;
      _retryScheduled = false;
      _useOriginal = false;
      _fallbackScheduled = false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  // Switch to the original (un-transformed) URL once, deferred out of build.
  void _scheduleFallbackToOriginal() {
    if (_useOriginal || _fallbackScheduled) return;
    _fallbackScheduled = true;
    Future.microtask(() {
      if (mounted) setState(() => _useOriginal = true);
    });
  }

  // Schedules one timer to bump _retryCount; the new count changes the
  // CachedNetworkImage key, forcing a fresh widget and network request.
  void _scheduleRetry() {
    if (_retryCount >= _maxRetries || _retryScheduled) return;
    _retryScheduled = true;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      _retryScheduled = false;
      if (mounted) setState(() => _retryCount++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final transformedUrl = widget.isThumbnail
        ? CdnService.getThumbnailUrl(widget.imageUrl)
        : CdnService.getMediumUrl(widget.imageUrl);
    final originalUrl = CdnService.getOriginalUrl(widget.imageUrl);
    final displayUrl = _useOriginal ? originalUrl : transformedUrl;
    // We can still fall back if we're on the transformed URL and the original
    // is a genuinely different URL to try.
    final canFallback =
        !_useOriginal && originalUrl.isNotEmpty && originalUrl != transformedUrl;

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      child: CachedNetworkImage(
        // The key includes _useOriginal + _retryCount so each transition creates
        // a fresh widget instance, forcing a new network request without having
        // to evict the cache manually.
        key: ValueKey('${displayUrl}_${_useOriginal}_$_retryCount'),
        imageUrl: displayUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheManager: CustomCacheManager.instance,
        placeholder: (context, url) => _buildShimmer(context),
        errorWidget: (context, url, error) {
          // 1. Transform endpoint failed → drop to the original object URL.
          if (canFallback) {
            _scheduleFallbackToOriginal();
            return _buildShimmer(context);
          }
          // 2. Transient failure on the final URL → retry a few times.
          if (_retryCount < _maxRetries) {
            _scheduleRetry();
            return _buildShimmer(context);
          }
          // 3. All options exhausted — permanent placeholder.
          return _buildFinalError(context);
        },
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.white,
      ),
    );
  }

  Widget _buildFinalError(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: widget.width,
      height: widget.height,
      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 32,
          color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
        ),
      ),
    );
  }
}

/// Gallery widget for multiple images (used in detail screens).
class OptimizedImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final double height;

  const OptimizedImageGallery({
    super.key,
    required this.imageUrls,
    this.height = 300,
  });

  @override
  State<OptimizedImageGallery> createState() => _OptimizedImageGalleryState();
}

class _OptimizedImageGalleryState extends State<OptimizedImageGallery> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
          ),
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return OptimizedPropertyImage(
                imageUrl: widget.imageUrls[index],
                height: widget.height,
                isThumbnail: false,
                borderRadius: BorderRadius.zero,
              );
            },
          ),
        ),

        // Image counter
        if (widget.imageUrls.length > 1)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        // Navigation arrows (for desktop/tablet)
        if (widget.imageUrls.length > 1) ...[
          Positioned(
            left: 16,
            top: widget.height / 2 - 24,
            child: _NavigationButton(
              icon: Icons.chevron_left,
              onTap: () {
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
          Positioned(
            right: 16,
            top: widget.height / 2 - 24,
            child: _NavigationButton(
              icon: Icons.chevron_right,
              onTap: () {
                if (_currentIndex < widget.imageUrls.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavigationButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
