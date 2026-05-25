// features/properties/presentation/widgets/optimized_property_image.dart
// Optimized image widget with CDN support, caching, and auto-retry for images
// that are still being processed by the backend Edge Function.
//
// After a property is created, images are uploaded to staging_media and the
// process-staged-image Edge Function creates the final JPEG in public_media
// asynchronously (typically 1–3 seconds). The predicted public_media URL is
// stored in the DB immediately so cards can display it, but the file may 404
// during that short processing window. This widget retries on 404 (up to 5
// times, 2 s apart) so the image appears automatically without user action.

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
  // Retry up to 5 times (= 10 s total) before showing the permanent error state.
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 2);

  int _retryCount = 0;
  Timer? _retryTimer;
  bool _retryScheduled = false;

  @override
  void didUpdateWidget(OptimizedPropertyImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      // Parent gave us a new URL — reset retry state for the fresh image.
      _retryTimer?.cancel();
      _retryCount = 0;
      _retryScheduled = false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  // Called from the errorWidget builder. Schedules one timer to bump
  // _retryCount; the new count changes the CachedNetworkImage key, which
  // forces a fresh widget (and therefore a fresh network request).
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
    final optimizedUrl = widget.isThumbnail
        ? CdnService.getThumbnailUrl(widget.imageUrl)
        : CdnService.getMediumUrl(widget.imageUrl);

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      child: CachedNetworkImage(
        // The key includes _retryCount so each retry creates a new widget
        // instance, bypassing any in-memory error state and forcing a fresh
        // network request without needing to evict the cache manually.
        key: ValueKey('${optimizedUrl}_$_retryCount'),
        imageUrl: optimizedUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheManager: CustomCacheManager.instance,
        placeholder: (context, url) => _buildShimmer(context),
        errorWidget: (context, url, error) {
          if (_retryCount < _maxRetries) {
            // Image not accessible yet — likely still processing.
            // Show shimmer and schedule a retry.
            _scheduleRetry();
            return _buildShimmer(context);
          }
          // All retries exhausted — show a permanent placeholder.
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
