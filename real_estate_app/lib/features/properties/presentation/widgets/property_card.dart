import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/property_entity.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../../core/utils/responsive_helper.dart';

class PropertyCard extends StatelessWidget {
  final PropertyEntity property;
  final VoidCallback onTap;

  const PropertyCard({
    super.key,
    required this.property,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Favorite Button
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: property.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: property.images.first,
                          memCacheWidth: 400, // ✅ Resize for memory efficiency
                          memCacheHeight: 300,
                          maxWidthDiskCache: 800, // ✅ Disk cache limits
                          maxHeightDiskCache: 600,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.home_work, size: 50),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.home_work, size: 50),
                        ),
                ),
                // Favorite Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FavoriteButton(
                      propertyId: property.id,
                      size: ResponsiveHelper.getResponsiveIconSize(context),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price and Type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          Formatters.formatCurrency(property.price),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: ThemeConfig.primaryColor,
                                  ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: property.type == PropertyType.sale
                              ? ThemeConfig.secondaryColor.withOpacity(0.1)
                              : ThemeConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                        ),
                        child: Text(
                          property.type.displayName,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                            fontWeight: FontWeight.w600,
                            color: property.type == PropertyType.sale
                                ? ThemeConfig.secondaryColor
                                : ThemeConfig.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                  // Title
                  Text(
                    property.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context) / 2),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: ResponsiveHelper.getResponsiveIconSize(context),
                        color: ThemeConfig.textSecondaryColor,
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context) / 2),
                      Expanded(
                        child: Text(
                          property.location,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: ThemeConfig.textSecondaryColor,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                  // Details
                  Row(
                    children: [
                      _DetailChip(
                        icon: Icons.bed_outlined,
                        label: '${property.bedrooms} Beds',
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      _DetailChip(
                        icon: Icons.bathtub_outlined,
                        label: '${property.bathrooms} Baths',
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      _DetailChip(
                        icon: Icons.square_foot_outlined,
                        label: Formatters.formatArea(property.area),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: ResponsiveHelper.getResponsiveIconSize(context),
          color: ThemeConfig.textSecondaryColor,
        ),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context) / 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ThemeConfig.textSecondaryColor,
              ),
        ),
      ],
    );
  }
}