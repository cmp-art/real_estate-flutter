// core/widgets/optimized_property_image.dart
// Optimized image widget with CDN support and caching

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/services/cdn_service.dart';


class OptimizedPropertyImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Get optimized URL based on size needed
    final optimizedUrl = isThumbnail
        ? CdnService.getThumbnailUrl(imageUrl)
        : CdnService.getMediumUrl(imageUrl);
    
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: optimizedUrl,
        width: width,
        height: height,
        fit: fit,
        cacheManager: CustomCacheManager.instance,  // Custom cache with 7-day TTL
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildError(context),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }
  
  Widget _buildPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        color: Colors.white,
      ),
    );
  }
  
  Widget _buildError(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Gallery widget for multiple images (used in detail screens)
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
                isThumbnail: false,  // Use medium size for gallery
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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