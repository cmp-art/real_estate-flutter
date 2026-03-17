// features/authentication/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../presentation/screens/login_screen.dart';
import '../../../properties/presentation/providers/property_providers.dart';
import '../../../favorites/presentation/providers/favorite_providers.dart';
import '../../../properties/presentation/screens/property_create_screen.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';
import '../../../properties/presentation/screens/property_edit_screen.dart';
import '../../../properties/presentation/widgets/property_grid_card.dart';
import '../../../properties/presentation/widgets/property_list_card.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/screens/edit_profile_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const String _tag = 'ProfileScreen';

  final ImageHelper _imageHelper = ImageHelper();
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) return;

    if (_tabController.index == 0) {
      ref.read(myPropertiesProvider.notifier).loadProperties();
    } else if (_tabController.index == 1) {
      ref.invalidate(favoritePropertiesProvider);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _showPropertyOptions(dynamic property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.edit, color: Theme.of(context).primaryColor),
              title: const Text('Edit Property'),
              onTap: () {
                Navigator.pop(context);
                _handleEditProperty(property);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Theme.of(context).primaryColor),
              title: const Text('Share Property'),
              onTap: () {
                Navigator.pop(context);
                SnackbarUtils.showInfo(context, 'Share functionality coming soon');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(
                'Delete Property',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleDeleteProperty(property.id);
              },
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProfilePictureUpdate() async {
    final image = await _imageHelper.showImageSourceDialog(context);
    if (image != null && mounted) {
      DialogUtils.showLoadingDialog(context, message: 'Updating profile picture...');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        DialogUtils.hideLoadingDialog(context);
        SnackbarUtils.showSuccess(context, 'Profile picture updated successfully!');
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Theme.of(context).primaryColor),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Text('Sign Out', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(authNotifierProvider.notifier).logout();
      await Future.delayed(const Duration(milliseconds: 100));
      
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Signed out successfully'),
              backgroundColor: ThemeConfig.secondaryColor,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          logger.d('Could not show snackbar: $e');
        }
      });
    } catch (e, stack) {
      logger.e('Sign out error', error: e, stackTrace: stack);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleDeleteProperty(String propertyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Text('Delete Property', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this property?\n\nIt will be hidden from the public listing. An admin can restore it if needed.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repository = ref.read(propertyRepositoryProvider);
      final result = await repository.deleteProperty(propertyId);

      if (!mounted) return;

      result.fold(
        (failure) => SnackbarUtils.showError(context, failure.message),
        (_) {
          ref.read(myPropertiesProvider.notifier).removeProperty(propertyId);
          ref.read(propertyListProvider.notifier).removeProperty(propertyId);
          ref.invalidate(favoritePropertiesProvider);
          SnackbarUtils.showSuccess(context, 'Property deleted successfully');
        },
      );
    } catch (e, stack) {
      logger.e('Error deleting property', error: e, stackTrace: stack);
      if (mounted) SnackbarUtils.showError(context, 'Error deleting property: ${e.toString()}');
    }
  }

  Future<void> _handleEditProperty(dynamic property) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PropertyEditScreen(property: property)),
    );

    if (result == true && mounted) {
      ref.read(myPropertiesProvider.notifier).loadProperties();
      ref.read(propertyListProvider.notifier).loadProperties(refresh: true);
      ref.invalidate(favoritePropertiesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final authState = ref.watch(authNotifierProvider);
    final myPropertiesState = ref.watch(myPropertiesProvider);
    final favoritesAsync = ref.watch(favoritePropertiesProvider);
    final showFab = ref.watch(showAddPropertyFabProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, size: ResponsiveHelper.getResponsiveIconSize(context), color: Theme.of(context).disabledColor),
                  SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                  Text('Not logged in',
                      style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18), fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface)),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                  Text('Please log in to view your profile',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).appBarTheme.backgroundColor,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ThemeConfig.getColor(context,
                                        lightColor: Colors.white,
                                        darkColor: ThemeConfig.darkTextPrimary),
                                    width: 4,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: ThemeConfig.getColor(context,
                                      lightColor: Colors.white,
                                      darkColor: Colors.grey.shade800),
                                  backgroundImage: user.avatarUrl != null
                                      ? CachedNetworkImageProvider(user.avatarUrl!)
                                      : null,
                                  child: user.avatarUrl == null
                                      ? Text(
                                          user.fullName.isNotEmpty
                                              ? user.fullName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 40),
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _handleProfilePictureUpdate,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ThemeConfig.getColor(context,
                                            lightColor: Colors.white,
                                            darkColor: ThemeConfig.darkTextPrimary),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: ThemeConfig.getColor(context,
                                          lightColor: Colors.white,
                                          darkColor: Colors.black),
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                          Text(
                            user.fullName,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
                              fontWeight: FontWeight.bold,
                              color: ThemeConfig.getColor(context,
                                  lightColor: Colors.white,
                                  darkColor: ThemeConfig.darkTextPrimary),
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                          if (user.bio != null && user.bio!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveHorizontalPadding(context)),
                              child: Text(
                                user.bio!,
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                                  color: ThemeConfig.getColor(context,
                                      lightColor: Colors.white.withOpacity(0.9),
                                      darkColor: ThemeConfig.darkTextSecondary),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (user.showPhone && user.phone != null && user.phone!.isNotEmpty) ...[
                                Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: ThemeConfig.getColor(context,
                                      lightColor: Colors.white.withOpacity(0.9),
                                      darkColor: ThemeConfig.darkTextSecondary),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.phone!,
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                                    color: ThemeConfig.getColor(context,
                                        lightColor: Colors.white.withOpacity(0.9),
                                        darkColor: ThemeConfig.darkTextSecondary),
                                  ),
                                ),
                              ],
                              if (user.showEmail && user.email.isNotEmpty) ...[
                                if (user.showPhone && user.phone != null && user.phone!.isNotEmpty)
                                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                                Icon(
                                  Icons.email,
                                  size: 14,
                                  color: ThemeConfig.getColor(context,
                                      lightColor: Colors.white.withOpacity(0.9),
                                      darkColor: ThemeConfig.darkTextSecondary),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    user.email,
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                                      color: ThemeConfig.getColor(context,
                                          lightColor: Colors.white.withOpacity(0.9),
                                          darkColor: ThemeConfig.darkTextSecondary),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: Theme.of(context).appBarTheme.foregroundColor),
                      onSelected: (value) {
                        if (value == 'edit_profile') {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                        } else if (value == 'settings') {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) => const SettingsScreen()));
                        } else if (value == 'logout') {
                          _handleSignOut();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit_profile',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
                              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                              Text('Edit Profile',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
                              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                              Text('Settings & Support',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              const Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                              const Text('Sign Out', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    Consumer(
                      builder: (context, ref, child) {
                        final propertiesCount = ref.watch(myPropertiesProvider).properties.length;
                        final favoritesCount = ref.watch(favoritePropertiesProvider).when(
                              data: (favorites) => favorites.length,
                              loading: () => 0,
                              error: (_, __) => 0,
                            );

                        return TabBar(
                          controller: _tabController,
                          labelColor: Theme.of(context).primaryColor,
                          unselectedLabelColor: Theme.of(context).unselectedWidgetColor,
                          indicatorColor: Theme.of(context).primaryColor,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: [
                            Tab(text: 'Properties ($propertiesCount)', icon: Icon(Icons.home_work, size: ResponsiveHelper.getResponsiveIconSize(context))),
                            Tab(text: 'Favorites ($favoritesCount)', icon: Icon(Icons.favorite, size: ResponsiveHelper.getResponsiveIconSize(context))),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPropertiesGrid(myPropertiesState, user),
                _buildFavoritesGrid(favoritesAsync),
              ],
            ),
          ),
          floatingActionButton: showFab
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PropertyCreateScreen()),
                    );
                    if (result == true && mounted) {
                      ref.read(myPropertiesProvider.notifier).loadProperties();
                      ref.read(propertyListProvider.notifier).loadProperties(refresh: true);
                      ref.invalidate(filteredSearchResultsProvider);
                      SnackbarUtils.showSuccess(context, 'Property added successfully!');
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Property'),
                )
              : null,
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
        ),
      ),
      error: (error, stack) {
        logger.e('Profile error', error: error, stackTrace: stack);
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: ResponsiveHelper.getResponsiveIconSize(context), color: Theme.of(context).colorScheme.error),
                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                Text('Error: ${error.toString()}'),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                ElevatedButton(
                  onPressed: () => ref.invalidate(authNotifierProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPropertiesGrid(MyPropertiesState propertiesState, dynamic user) {
    if (propertiesState.isLoading && propertiesState.properties.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
    }

    if (propertiesState.error != null && propertiesState.properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: ResponsiveHelper.getResponsiveIconSize(context), color: Theme.of(context).colorScheme.error),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            Text('Error: ${propertiesState.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            ElevatedButton(
              onPressed: () => ref.read(myPropertiesProvider.notifier).loadProperties(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Theme.of(context).primaryColor,
      onRefresh: () async => ref.read(myPropertiesProvider.notifier).loadProperties(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (propertiesState.properties.isEmpty)
              _buildEmptyPropertiesState()
            else
              _buildPropertiesList(propertiesState.properties),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPropertiesState() {
    return Padding(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work_outlined, size: ResponsiveHelper.getResponsiveIconSize(context), color: Theme.of(context).disabledColor),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            Text('No properties yet',
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18), fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Text('Start by adding your first property', style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PropertyCreateScreen()),
                );
                if (result == true && mounted) {
                  ref.read(myPropertiesProvider.notifier).loadProperties();
                  ref.read(propertyListProvider.notifier).loadProperties(refresh: true);
                  ref.invalidate(filteredSearchResultsProvider);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesList(List<dynamic> properties) {
    final cols = ResponsiveHelper.getPropertyGridColumns(context);
    final hPad = ResponsiveHelper.getResponsiveHorizontalPadding(context);
    const spacing = 16.0;

    Future<void> navigate(dynamic property) async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PropertyDetailScreen(propertyId: property.id),
        ),
      );
      if (mounted) {
        ref.read(myPropertiesProvider.notifier).loadProperties();
        ref.invalidate(favoritePropertiesProvider);
      }
    }

    if (cols == 1) {
      // Mobile: single-column list (unchanged)
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: properties.length,
              separatorBuilder: (_, __) => const SizedBox(height: 15),
              itemBuilder: (_, index) {
                final property = properties[index];
                return GestureDetector(
                  onTap: () => navigate(property),
                  onLongPress: () => _showPropertyOptions(property),
                  child: PropertyGridCard(
                    property: property,
                    onTap: () => navigate(property),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Tablet / Desktop: multi-column Wrap layout (natural card heights)
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth =
              (constraints.maxWidth - spacing * (cols - 1)) / cols;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: properties.map((property) {
              return SizedBox(
                width: cardWidth,
                child: GestureDetector(
                  onLongPress: () => _showPropertyOptions(property),
                  child: PropertyGridCard(
                    property: property,
                    onTap: () => navigate(property),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesGrid(AsyncValue<List<dynamic>> favoritesAsync) {
    return favoritesAsync.when(
      data: (favorites) {
        if (favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: ResponsiveHelper.getResponsiveIconSize(context), color: Theme.of(context).disabledColor),
                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                Text('No favorites yet',
                    style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18), fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                Text('Your favorite properties will appear here',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: Theme.of(context).primaryColor,
          onRefresh: () async {
            ref.invalidate(favoritePropertiesProvider);
            await ref.read(favoritePropertiesProvider.future);
          },
          child: _buildFavoritesList(favorites),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)),
      error: (error, stack) {
        logger.e('Favorites error', error: error, stackTrace: stack);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: ResponsiveHelper.getResponsiveIconSize(context), color: Theme.of(context).colorScheme.error),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              Text('Error: ${error.toString()}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              ElevatedButton(
                onPressed: () => ref.invalidate(favoritePropertiesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Renders the favorites list: single column on mobile, multi-column grid on
  /// tablet and desktop.
  Widget _buildFavoritesList(List<dynamic> favorites) {
    final cols = ResponsiveHelper.getPropertyGridColumns(context);
    final padding = ResponsiveHelper.getResponsivePadding(context);

    Future<void> navigate(dynamic property) async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PropertyDetailScreen(propertyId: property.id),
        ),
      );
      if (mounted) {
        ref.read(myPropertiesProvider.notifier).loadProperties();
        ref.invalidate(favoritePropertiesProvider);
      }
    }

    if (cols == 1) {
      // Mobile: current single-column list with PropertyListCard
      return ListView.separated(
        padding: EdgeInsets.all(padding),
        itemCount: favorites.length,
        separatorBuilder: (_, __) =>
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        itemBuilder: (_, index) {
          final property = favorites[index];
          return PropertyListCard(
            property: property,
            onTap: () => navigate(property),
            onShare: () =>
                SnackbarUtils.showInfo(context, 'Share functionality coming soon'),
          );
        },
      );
    }

    // Tablet / Desktop: GridView with PropertyGridCard
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: ResponsiveHelper.isDesktop(context) ? 0.82 : 0.88,
      ),
      itemCount: favorites.length,
      itemBuilder: (_, index) {
        final property = favorites[index];
        return PropertyGridCard(
          property: property,
          onTap: () => navigate(property),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => kTextTabBarHeight;
  @override
  double get maxExtent => kTextTabBarHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).colorScheme.surface, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}