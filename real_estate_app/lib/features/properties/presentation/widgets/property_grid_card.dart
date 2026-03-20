// features/properties/presentation/widgets/property_grid_card.dart
// FIXED - Full height display without overflow

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/cdn_service.dart';
import 'package:patamjengo_app/features/settings/presentation/screens/app_translations.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../core/middleware/feature_gate_middleware.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../providers/property_providers.dart';
import '../screens/property_edit_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/widgets/report_bottom_sheet.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/share_utils.dart';

class PropertyGridCard extends ConsumerStatefulWidget {
  final dynamic property;
  final VoidCallback onTap;

  const PropertyGridCard({
    super.key,
    required this.property,
    required this.onTap,
  });

  @override
  ConsumerState<PropertyGridCard> createState() => _PropertyGridCardState();
}

class _PropertyGridCardState extends ConsumerState<PropertyGridCard> {
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handleArchive() async {
    final currentLanguage = ref.read(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);
    
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: t('archive'),
      message: t('archive_property_confirm'),
      confirmText: t('archive'),
      isDanger: false,
    );

    if (!confirmed || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                    Text(t('archive')),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      // Change status to sold/rented - this marks property as archived
      // Properties with sold/rented status should be filtered from public listings
      final newStatus = widget.property.type == PropertyType.rent 
          ? PropertyStatus.rented 
          : PropertyStatus.sold;
      
      final updatedProperty = widget.property.copyWith(
        status: newStatus,
      );

      final repository = ref.read(propertyRepositoryProvider);
      final result = await repository.updateProperty(updatedProperty);

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      result.fold(
        (failure) {
          SnackbarUtils.showError(context, t('error'));
        },
        (property) {
          // IMPORTANT: Remove from public listings
          // This ensures archived properties (sold/rented) are NOT visible to public
          ref.read(propertyListProvider.notifier).removeProperty(widget.property.id);
          
          // Remove from user's active properties in profile
          ref.read(myPropertiesProvider.notifier).removeProperty(widget.property.id);
          
          // Invalidate archived properties provider to include this property
          // Archive screen will show properties with sold/rented status
          ref.invalidate(archivedPropertiesProvider);
          
          // Show success message - property is now archived and hidden from public
          SnackbarUtils.showSuccess(
            context, 
            '${property.title} ${t('property_archived')}. Property is now hidden from public listings.'
          );
          
          // Note: We don't navigate to archive screen
          // User stays on current screen, property is simply removed from view
        },
      );
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();
        SnackbarUtils.showError(context, t('error'));
      }
    }
  }

  Future<void> _handleShare() async {
    final currentCurrency = ref.read(currencyProvider);
    final p = widget.property;
    await ShareUtils.shareProperty(
      context,
      title: p.title,
      price: Formatters.formatCurrency(p.price, currencyCode: currentCurrency),
      location: p.location,
      bedrooms: p.bedrooms,
      bathrooms: p.bathrooms,
      area: p.area.toInt(),
      isRent: p.type == PropertyType.rent,
    );
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyEditScreen(
          property: widget.property,
        ),
      ),
    );

    if (result == true && mounted) {
      ref.read(myPropertiesProvider.notifier).loadProperties();
      ref.read(propertyListProvider.notifier).loadProperties(refresh: true);
    }
  }

  Future<void> _handleDelete() async {
    final currentLanguage = ref.read(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);
    
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: t('delete'),
      message: t('delete_property_confirm'),
      confirmText: t('delete'),
      isDanger: true,
    );

    if (confirmed && mounted) {
      DialogUtils.showLoadingDialog(context, message: '${t('delete')}...');

      final repository = ref.read(propertyRepositoryProvider);
      final result = await repository.deleteProperty(widget.property.id);

      if (mounted) {
        DialogUtils.hideLoadingDialog(context);
        
        result.fold(
          (failure) {
            SnackbarUtils.showError(context, t('error'));
          },
          (_) {
            SnackbarUtils.showSuccess(context, t('property_deleted'));
            
            ref.read(myPropertiesProvider.notifier).removeProperty(widget.property.id);
            ref.read(propertyListProvider.notifier).removeProperty(widget.property.id);
          },
        );
      }
    }
  }

  void _showMoreOptions(bool isOwner) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final currentLanguage = ref.read(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.share_outlined,
                  color: isDarkMode ? Colors.grey[400] : ThemeConfig.primaryColor),
              title: Text('Share',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              subtitle: Text('WhatsApp, email, SMS & more',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600])),
              onTap: () { Navigator.pop(context); _handleShare(); },
            ),
            if (isOwner) ...[
              ListTile(
                leading: Icon(Icons.archive_outlined,
                    color: isDarkMode ? Colors.grey[400] : ThemeConfig.primaryColor),
                title: Text(t('archive'),
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                onTap: () { Navigator.pop(context); _handleArchive(); },
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined,
                    color: isDarkMode ? Colors.grey[400] : ThemeConfig.primaryColor),
                title: Text(t('edit'),
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                onTap: () { Navigator.pop(context); _handleEdit(); },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: isDarkMode ? Colors.red[400] : ThemeConfig.errorColor),
                title: Text(t('delete'),
                    style: TextStyle(
                        color: isDarkMode ? Colors.red[400] : ThemeConfig.errorColor)),
                onTap: () { Navigator.pop(context); _handleDelete(); },
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.flag_outlined,
                    color: isDarkMode ? Colors.red[400] : Colors.red[600]),
                title: Text('Report Listing',
                    style: TextStyle(
                        color: isDarkMode ? Colors.red[400] : Colors.red[600])),
                subtitle: Text('Scam, wrong info, duplicate...',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600])),
                onTap: () {
                  Navigator.pop(context);
                  ReportBottomSheet.showProperty(context, widget.property.id);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isForRent = widget.property.type == PropertyType.rent;
    final currentCurrency = ref.watch(currencyProvider);
    final currentLanguage = ref.watch(languageProvider).languageCode;
    
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    String rentDurationText = '';
    if (isForRent) {
      final rentDuration = widget.property.rentDuration;
      if (rentDuration == null || rentDuration == RentDuration.monthly) {
        rentDurationText = t('per_month');
      } else {
        rentDurationText = t('per_year'); 
      }
    }

    final currentUser = ref.watch(authNotifierProvider).value;
    final isOwner = currentUser?.id == widget.property.ownerId;

    final cardColor = Theme.of(context).cardColor;
    final shadowColor = ThemeConfig.getColor(
      context,
      lightColor: Colors.black.withOpacity(0.1),
      darkColor: Colors.black.withOpacity(0.4),
    );
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    final iconColor = Theme.of(context).iconTheme.color ?? Colors.grey;
    final backgroundColor = ThemeConfig.getColor(
      context,
      lightColor: Colors.grey[200]!,
      darkColor: Colors.grey[800]!,
    );
    final buttonBackgroundColor = cardColor;
    
    final statusColor = _getStatusColor(widget.property.status, isDarkMode);
    final statusTextColor = _getStatusTextColor(widget.property.status, isDarkMode);

    // Check if property is Land or Commercial
    final isLandOrCommercial = widget.property.category == PropertyCategory.land ||
                               widget.property.category == PropertyCategory.commercial;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                // First image only — no carousel to reduce CDN egress
                Container(
                  height: 500,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: widget.property.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: widget.property.images.first,
                            cacheManager: CustomCacheManager.instance,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              color: backgroundColor,
                              child: const Center(child: CircularProgressIndicator(color: ThemeConfig.primaryColor)),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: backgroundColor,
                              child: Icon(Icons.home, size: ResponsiveHelper.getResponsiveIconSize(context), color: iconColor),
                            ),
                            fadeInDuration: const Duration(milliseconds: 300),
                            fadeOutDuration: const Duration(milliseconds: 100),
                          ),
                        )
                      : Center(child: Icon(Icons.home, size: ResponsiveHelper.getResponsiveIconSize(context), color: iconColor)),
                ),

                // Status badge — top left
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      widget.property.status.displayName.toUpperCase(),
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Tier badge — top right
                // Hidden for PRO subscribers (they already have full access; badge clutters the card)
                if ((widget.property.ownerTier == 'pro' || widget.property.ownerTier == 'basic') &&
                    !(ref.watch(userSubscriptionProvider)?.isPro ?? false))
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.property.ownerTier == 'pro' ? Colors.green[700] : Colors.blue[700],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.property.ownerTier == 'pro' ? Icons.workspace_premium : Icons.verified,
                            color: Colors.white,
                            size: ResponsiveHelper.getResponsiveIconSize(context),
                          ),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context) / 2),
                          Text(
                            widget.property.ownerTier == 'pro' ? 'PRO' : 'BASIC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Media count badge — bottom right (tap to see all in detail screen)
                if (widget.property.images.length + (widget.property.videos.isNotEmpty ? 1 : 0) > 1)
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_outlined, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.property.images.length + (widget.property.videos.isNotEmpty ? 1 : 0)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // VIDEO badge — bottom left
                if (widget.property.videos.isNotEmpty)
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text('VIDEO', style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                            fontWeight: FontWeight.bold,
                          )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.formatCurrency(widget.property.price, currencyCode: currentCurrency),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.primaryColor,
                              ),
                            ),
                            if (rentDurationText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  rentDurationText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: secondaryTextColor,
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      if (isOwner)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: buttonBackgroundColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: FavoriteButton(
                                propertyId: widget.property.id,
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                            
                            Container(
                              decoration: BoxDecoration(
                                color: buttonBackgroundColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _handleArchive,
                                icon: Icon(
                                  Icons.archive_outlined,
                                  color: iconColor,
                                ),
                                iconSize: 20,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                            
                            Container(
                              decoration: BoxDecoration(
                                color: buttonBackgroundColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => _showMoreOptions(isOwner),
                                icon: Icon(
                                  Icons.more_vert,
                                  color: iconColor,
                                ),
                                iconSize: 20,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: buttonBackgroundColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: FavoriteButton(
                                propertyId: widget.property.id,
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                            Container(
                              decoration: BoxDecoration(
                                color: buttonBackgroundColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => _showMoreOptions(false),
                                icon: Icon(Icons.more_vert, color: iconColor),
                                iconSize: 20,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                  Text(
                    widget.property.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context) / 2),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: ResponsiveHelper.getResponsiveIconSize(context),
                        color: secondaryTextColor,
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context) / 2),
                      Expanded(
                        child: Text(
                          widget.property.location,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

                  Row(
                    children: [
                      // Only show beds/baths for non-land/commercial properties
                      if (!isLandOrCommercial) ...[
                        _PropertyDetailItem(
                          icon: Icons.bed,
                          value: '${widget.property.bedrooms}',
                          label: 'Beds',
                          iconColor: iconColor,
                          valueColor: textColor,
                          labelColor: secondaryTextColor,
                        ),
                        const SizedBox(width: 8),
                        _PropertyDetailItem(
                          icon: Icons.bathtub,
                          value: '${widget.property.bathrooms}',
                          label: 'Baths',
                          iconColor: iconColor,
                          valueColor: textColor,
                          labelColor: secondaryTextColor,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _PropertyDetailItem(
                        icon: Icons.square_foot,
                        value: '${widget.property.area.toInt()}',
                        label: 'sqft',
                        iconColor: iconColor,
                        valueColor: textColor,
                        labelColor: secondaryTextColor,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isForRent
                              ? ThemeConfig.primaryColor.withOpacity(isDarkMode ? 0.2 : 0.1)
                              : ThemeConfig.secondaryColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.property.type.displayName,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                            fontWeight: FontWeight.w600,
                            color: isForRent
                                ? ThemeConfig.primaryColor
                                : ThemeConfig.secondaryColor,
                          ),
                        ),
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

  Color _getStatusColor(PropertyStatus status, bool isDarkMode) {
    switch (status) {
      case PropertyStatus.available:
        return isDarkMode ? Colors.green[800]! : Colors.green;
      case PropertyStatus.sold:
        return isDarkMode ? Colors.red[900]! : Colors.red;
      case PropertyStatus.rented:
        return isDarkMode ? Colors.blue[900]! : Colors.blue;
      case PropertyStatus.pending:
        return isDarkMode ? Colors.orange[900]! : Colors.orange;
    }
  }

  Color _getStatusTextColor(PropertyStatus status, bool isDarkMode) {
    switch (status) {
      case PropertyStatus.available:
        return Colors.white;
      case PropertyStatus.sold:
        return Colors.white;
      case PropertyStatus.rented:
        return Colors.white;
      case PropertyStatus.pending:
        return isDarkMode ? Colors.white : Colors.black;
    }
  }
}

class _PropertyDetailItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color valueColor;
  final Color labelColor;

  const _PropertyDetailItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: iconColor,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}