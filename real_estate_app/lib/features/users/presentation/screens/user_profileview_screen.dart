// features/users/presentation/screens/user_profileview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../properties/presentation/widgets/property_grid_card.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';
import '../../../chat/presentation/screens/chat_helper.dart';
import '../providers/user_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

class UserProfileViewScreen extends ConsumerWidget {
  final String userId;

  const UserProfileViewScreen({
    super.key,
    required this.userId,
  });

  Future<void> _startDirectMessage(
    BuildContext context,
    WidgetRef ref,
    String currentUserId,
    String currentUserName,
    dynamic user,
    dynamic properties,
  ) async {
    logger.d('Direct message from profile view - User: $currentUserId, Target: ${user.id}');

    if (currentUserId == user.id) {
      logger.w('User trying to message themselves');
      if (context.mounted) {
        SnackbarUtils.showInfo(context, 'You cannot message yourself');
      }
      return;
    }

    try {
      await ChatHelper.startConversation(
        context: context,
        ref: ref,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        ownerId: user.id,
        ownerName: user.fullName ?? 'User',
        ownerAvatar: user.avatarUrl,
        propertyId: null,
        propertyTitle: null,
        propertyImage: null,
      );
    } catch (e, stackTrace) {
      logger.e('Error starting direct message', error: e, stackTrace: stackTrace);
      
      if (context.mounted) {
        SnackbarUtils.showError(
          context,
          'Unable to start conversation. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByIdProvider(userId));
    final currentUser = ref.watch(authNotifierProvider).value;
    final userPropertiesAsync = ref.watch(userPropertiesProvider(userId));

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.grey),
                  SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                  Text(
                    'User not found',
                    style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18), color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final isCurrentUser = currentUser?.id == userId;
          final propertiesCount = userPropertiesAsync.when(
            data: (properties) => properties.length,
            loading: () => 0,
            error: (_, __) => 0,
          );

          return CustomScrollView(
            slivers: [
              // Profile Header
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          ThemeConfig.primaryColor,
                          ThemeConfig.primaryColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Hero(
                          tag: 'user_avatar_${user.id}',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage: user.avatarUrl != null
                                  ? CachedNetworkImageProvider(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(
                                      user.fullName[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 40),
                                        fontWeight: FontWeight.bold,
                                        color: ThemeConfig.primaryColor,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 22),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) * 1.25),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            user.userType.displayName,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bio Section
                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: ThemeConfig.primaryColor,
                                    ),
                                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                                    Text(
                                      'About',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                                Text(
                                  user.bio!,
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                      ],

                      // Contact Information Card
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contact Information',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                              if (user.showEmail) ...[
                                _InfoRow(
                                  icon: Icons.email,
                                  label: 'Email',
                                  value: user.email,
                                ),
                                const Divider(height: 24),
                              ],
                              if (user.phone != null && user.showPhone) ...[
                                _InfoRow(
                                  icon: Icons.phone,
                                  label: 'Phone',
                                  value: user.phone!,
                                ),
                                const Divider(height: 24),
                              ],
                              _InfoRow(
                                icon: Icons.calendar_today,
                                label: 'Member Since',
                                value: Formatters.formatDate(user.createdAt),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Message Button
                      if (!isCurrentUser && currentUser != null) ...[
                        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                        userPropertiesAsync.when(
                          data: (properties) => SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _startDirectMessage(
                                context,
                                ref,
                                currentUser.id,
                                currentUser.fullName,
                                user,
                                properties,
                              ),
                              icon: const Icon(Icons.message),
                              label: const Text('Send Message'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeConfig.primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                                ),
                              ),
                            ),
                          ),
                          loading: () => SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: null,
                              icon: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              label: const Text('Loading...'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                                ),
                              ),
                            ),
                          ),
                          error: (_, __) => SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.error),
                              label: const Text('Unable to Message'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                      // Properties Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Properties',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeConfig.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) * 1.25),
                            ),
                            child: Text(
                              '$propertiesCount ${propertiesCount == 1 ? 'Property' : 'Properties'}',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                                fontWeight: FontWeight.w600,
                                color: ThemeConfig.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                    ],
                  ),
                ),
              ),

              // Properties Grid
              userPropertiesAsync.when(
                data: (properties) {
                  if (properties.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.home_work_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                              Text(
                                'No properties listed yet',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                              Text(
                                isCurrentUser
                                    ? 'Start listing your properties to showcase them here'
                                    : 'This user hasn\'t listed any properties yet',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Tablet / Desktop: multi-column grid
                  final cols = ResponsiveHelper.getPropertyGridColumns(context);
                  if (cols > 1) {
                    return SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.getContentHorizontalPadding(context),
                        vertical: 8,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio:
                              ResponsiveHelper.isDesktop(context) ? 0.82 : 0.88,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final property = properties[index];
                            return PropertyGridCard(
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
                          childCount: properties.length,
                        ),
                      ),
                    );
                  }

                  // Mobile: single-column list
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final property = properties[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: PropertyGridCard(
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
                      childCount: properties.length,
                    ),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: ThemeConfig.errorColor,
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                          Text(
                            'Failed to load properties',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                          Text(
                            error.toString(),
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                              color: ThemeConfig.textSecondaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(userPropertiesProvider(userId));
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: ResponsiveHelper.getResponsivePadding(context))),
            ],
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading profile...'),
        error: (error, stack) => CustomErrorWidget(
          message: 'Failed to load user profile: ${error.toString()}',
          onRetry: () {
            ref.invalidate(userByIdProvider(userId));
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: ResponsiveHelper.getResponsiveIconSize(context), color: ThemeConfig.primaryColor),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: ThemeConfig.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}