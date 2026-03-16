// features/favorites/presentation/screens/favorites_screen.dart
// FULLY RESPONSIVE VERSION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';
import '../../../properties/presentation/widgets/property_card.dart';
import '../../../../core/middleware/feature_gate_middleware.dart';
import '../providers/favorite_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritePropertiesProvider);
    final user = ref.watch(authNotifierProvider).value;
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final gridColumns = ResponsiveHelper.getGridColumns(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Favorites',
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(
              context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
          ),
        ),
        actions: [
          if (user != null)
            const QuotaIndicator(featureName: 'save_favorites'),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: ResponsiveHelper.getMaxContentWidth(context, isWide: true),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.getResponsiveHorizontalPadding(context),
        ),
        child: favoritesAsync.when(
          data: (properties) {
            if (properties.isEmpty) {
              return const EmptyState(
                icon: Icons.favorite_border,
                title: 'No Favorites Yet',
                message: 'Properties you favorite will appear here.',
               // iconSize: ResponsiveHelper.isMobile(context) ? 80 : 120,
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(favoritePropertiesProvider);
              },
              child: _buildContent(context, properties, gridColumns, isDesktop),
            );
          },
          loading: () => const LoadingIndicator(
            message: 'Loading favorites...',
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: ResponsiveHelper.isMobile(context) ? 60 : 80,
                  color: Colors.red,
                ),
                SizedBox(
                  height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2),
                ),
                Text(
                  'Error: ${error.toString()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                    ),
                  ),
                ),
                SizedBox(
                  height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(favoritePropertiesProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<dynamic> properties,
    int gridColumns,
    bool isDesktop,
  ) {
    final padding = ResponsiveHelper.getResponsivePadding(context);

    // Use grid layout for tablet and desktop
    if (gridColumns > 1) {
      return GridView.builder(
        padding: EdgeInsets.all(padding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridColumns,
          crossAxisSpacing: padding,
          mainAxisSpacing: padding,
          childAspectRatio: isDesktop ? 1.1 : 0.95,
        ),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          return PropertyCard(
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
          );
        },
      );
    }

    // Use list layout for mobile
    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return Padding(
          padding: EdgeInsets.only(bottom: padding),
          child: PropertyCard(
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
          ),
        );
      },
    );
  }
}