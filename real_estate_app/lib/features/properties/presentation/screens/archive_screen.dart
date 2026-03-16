// features/properties/presentation/screens/archive_screen.dart
// FIXED - Loading dialog issues resolved

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../providers/property_providers.dart';
import '../../../properties/domain/entities/property_entity.dart';
import '../../../../core/constants/app_constants.dart';
import 'property_detail_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  Future<void> _unarchiveProperty(
    BuildContext context,
    WidgetRef ref,
    PropertyEntity property,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Unarchive Property'),
        content: Text('Do you want to make "${property.title}" available again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );

    if (!confirmed! || !context.mounted) return;

    // Show loading dialog with proper context handling
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
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
                    const Text('Unarchiving property...'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final updatedProperty = property.copyWith(
        status: PropertyStatus.available,
      );

      final repository = ref.read(propertyRepositoryProvider);
      final result = await repository.updateProperty(updatedProperty);

      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      result.fold(
        (failure) {
          SnackbarUtils.showError(context, 'Failed to unarchive property');
        },
        (updatedProperty) {
          SnackbarUtils.showSuccess(context, 'Property unarchived successfully');
          
          // IMPORTANT: Add back to public listings
          // This makes the property visible to everyone again
          ref.read(propertyListProvider.notifier).addProperty(updatedProperty);
          
          // Add back to user's active properties in profile
          ref.read(myPropertiesProvider.notifier).loadProperties();
          
          // Refresh archive list to remove this property
          ref.invalidate(archivedPropertiesProvider);
        },
      );
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();
        SnackbarUtils.showError(context, 'An error occurred');
      }
    }
  }

  Future<void> _deleteProperty(
    BuildContext context,
    WidgetRef ref,
    PropertyEntity property,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Property'),
        content: Text(
          'Are you sure you want to permanently delete "${property.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!confirmed! || !context.mounted) return;

    // Show loading dialog with proper context handling
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
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
                    const Text('Deleting property...'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final repository = ref.read(propertyRepositoryProvider);
      final result = await repository.deleteProperty(property.id);

      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      result.fold(
        (failure) {
          SnackbarUtils.showError(context, 'Failed to delete property');
        },
        (_) {
          SnackbarUtils.showSuccess(context, 'Property deleted successfully');
          // Refresh archive and profile providers immediately
          ref.invalidate(archivedPropertiesProvider);
          ref.invalidate(myPropertiesProvider);
        },
      );
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();
        SnackbarUtils.showError(context, 'An error occurred');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedPropertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Properties'),
        backgroundColor: ThemeConfig.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: archivedAsync.when(
        data: (properties) {
          if (properties.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                    Text(
                      'No Archived Properties',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                    Text(
                      'Archived properties will appear here',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(archivedPropertiesProvider);
            },
            child: ListView.builder(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              itemCount: properties.length,
              itemBuilder: (context, index) {
                final property = properties[index];
                return _ArchivedPropertyCard(
                  property: property,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PropertyDetailScreen(
                          propertyId: property.id,
                        ),
                      ),
                    );
                  },
                  onUnarchive: () => _unarchiveProperty(context, ref, property),
                  onDelete: () => _deleteProperty(context, ref, property),
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.red),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              Text('Error: ${error.toString()}'),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(archivedPropertiesProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedPropertyCard extends StatelessWidget {
  final PropertyEntity property;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  const _ArchivedPropertyCard({
    required this.property,
    required this.onTap,
    required this.onUnarchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image with Archived Badge
            Stack(
              children: [
                if (property.images.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: property.images.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: Icon(Icons.home_work, size: ResponsiveHelper.getResponsiveIconSize(context)),
                      ),
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(Icons.home_work, size: ResponsiveHelper.getResponsiveIconSize(context)),
                    ),
                  ),
                // Archived Badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.archive,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ARCHIVED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Status Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: property.status == PropertyStatus.sold
                          ? Colors.red
                          : Colors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      property.status.displayName.toUpperCase(),
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

            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    property.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                  // Price
                  Text(
                    Formatters.formatCurrency(property.price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ThemeConfig.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : ThemeConfig.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : ThemeConfig.textSecondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                  // Property Details
                  Row(
                    children: [
                      Icon(
                        Icons.bed,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : ThemeConfig.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text('${property.bedrooms} Beds'),
                      SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
                      Icon(
                        Icons.bathtub,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : ThemeConfig.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text('${property.bathrooms} Baths'),
                      SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
                      Icon(
                        Icons.square_foot,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : ThemeConfig.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text('${property.area.toInt()} sqft'),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                  // Archived Date
                  Text(
                    'Archived ${Formatters.formatRelativeTime(property.updatedAt)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onUnarchive,
                          icon: Icon(Icons.unarchive, size: ResponsiveHelper.getResponsiveIconSize(context)),
                          label: const Text('Unarchive'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ThemeConfig.primaryColor,
                            side: const BorderSide(
                              color: ThemeConfig.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: Icon(Icons.delete, size: ResponsiveHelper.getResponsiveIconSize(context)),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThemeConfig.errorColor,
                          side: const BorderSide(
                            color: ThemeConfig.errorColor,
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
}