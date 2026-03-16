// features/properties/presentation/widgets/user_property_card.dart

// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../properties/domain/entities/property_entity.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive_helper.dart';


class UserPropertyCard extends StatefulWidget {
  final PropertyEntity property;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onShare;
  final VoidCallback onToggleAvailability;
  final bool showFilterButton;
  final VoidCallback onFilterPressed;

  const UserPropertyCard({
    super.key,
    required this.property,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
    required this.onShare,
    required this.onToggleAvailability,
    this.showFilterButton = false,
    required this.onFilterPressed,
  });

  @override
  State<UserPropertyCard> createState() => _UserPropertyCardState();
}

class _UserPropertyCardState extends State<UserPropertyCard> {
  int _currentImageIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextImage() {
    if (_currentImageIndex < widget.property.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousImage() {
    if (_currentImageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.property.status == PropertyStatus.available;
    final isSold = widget.property.status == PropertyStatus.sold;
    final isRented = widget.property.status == PropertyStatus.rented;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Gallery with Navigation
          Stack(
            children: [
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.property.images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: widget.property.images[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.home_work,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Image Indicator Dots
              if (widget.property.images.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.property.images.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == index
                              ? ThemeConfig.primaryColor
                              : Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ),

              // Navigation Arrows
              if (widget.property.images.length > 1)
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    onPressed: _previousImage,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) * 1.25),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

              if (widget.property.images.length > 1)
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    onPressed: _nextImage,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) * 1.25),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

              // Status Badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.green
                        : (isSold ? Colors.blue : Colors.orange),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) * 1.25),
                  ),
                  child: Text(
                    isAvailable
                        ? 'Available'
                        : (isSold ? 'Sold' : 'Rented'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Property Details
          Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row with Share Button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.property.title,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onShare,
                      icon: const Icon(
                        Icons.share,
                        color: ThemeConfig.primaryColor,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                // Price
                Text(
                  Formatters.formatCurrency(widget.property.price),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.primaryColor,
                  ),
                ),

                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: ThemeConfig.textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.property.location,
                        style: const TextStyle(
                          color: ThemeConfig.textSecondaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

                // Action Buttons
                Row(
                  children: [
                    // Edit Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: Icon(Icons.edit, size: ResponsiveHelper.getResponsiveIconSize(context)),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThemeConfig.primaryColor,
                          side: const BorderSide(
                            color: ThemeConfig.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),

                    // Toggle Availability Button
                    if (!isAvailable)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onToggleAvailability,
                          icon: Icon(Icons.refresh, size: ResponsiveHelper.getResponsiveIconSize(context)),
                          label: const Text('Make Available'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    if (!isAvailable) SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),

                    // Archive Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onArchive,
                        icon: Icon(Icons.archive, size: ResponsiveHelper.getResponsiveIconSize(context)),
                        label: const Text('Archive'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),

                    // Delete Button
                    OutlinedButton.icon(
                      onPressed: widget.onDelete,
                      icon: Icon(Icons.delete, size: ResponsiveHelper.getResponsiveIconSize(context)),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThemeConfig.errorColor,
                        side: const BorderSide(color: ThemeConfig.errorColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}