// features/properties/presentation/screens/property_detail_screen.dart
// COMPLETE FIXED VERSION - Fully theme-controlled
// ignore_for_file: unused_local_variable

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:patamjengo_app/features/settings/presentation/providers/app_providers.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';


import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar_utils.dart';

import '../../../../presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../chat/presentation/screens/chat_helper.dart';
import '../../../settings/presentation/screens/app_translations.dart';
import '../providers/property_providers.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../domain/entities/property_entity.dart';
import '../providers/video_providers.dart';
import 'property_edit_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
  });

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  final PageController _headerPageController = PageController();
  int _currentHeaderIndex = 0;
  VideoPlayerController? _headerVideoController;
  bool _headerVideoInitialized = false;
  bool _headerVideoLoading = false; // true while buffering
  // Only load/stream video when user explicitly taps play (saves egress)
  bool _headerVideoPlayPressed = false;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    // Do NOT pre-buffer video — wait for user tap to avoid wasted egress
  }

  @override
  void dispose() {
    _headerPageController.dispose();
    _headerVideoController?.dispose();
    super.dispose();
  }

  Future<void> _initHeaderVideo(String url) async {
    if (_headerVideoController != null) return;
    if (mounted) setState(() => _headerVideoLoading = true);
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      final isMuted = ref.read(videoMuteProvider);
      await ctrl.setVolume(isMuted ? 0 : 1);
      // Only play if user explicitly pressed play — never autoplay
      if (_headerVideoPlayPressed) await ctrl.play();
      if (mounted) {
        setState(() {
          _headerVideoController = ctrl;
          _headerVideoInitialized = true;
          _headerVideoLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Detail video error: $e');
      if (mounted) setState(() => _headerVideoLoading = false);
    }
  }

  String get propertyId => widget.propertyId;

  @override
  Widget build(BuildContext context) {
    final WidgetRef ref = this.ref;
    final propertyDetailState = ref.watch(propertyDetailProvider(propertyId));
    // Video is NOT pre-buffered — only starts when user taps play
    final user = ref.watch(authNotifierProvider).value;
    final currentLanguage = ref.watch(languageProvider).languageCode;

    String t(String key) => AppTranslations.translate(key, currentLanguage);

    return Scaffold(
      body: propertyDetailState.isLoading
          ? LoadingIndicator(message: t('loading_property'))
          : propertyDetailState.error != null
              ? CustomErrorWidget(
                  message: propertyDetailState.error!,
                  onRetry: () {
                    ref
                        .read(propertyDetailProvider(propertyId).notifier)
                        .loadProperty(propertyId);
                  },
                )
              : propertyDetailState.property != null
                  ? _buildPropertyDetail(
                      context, ref, propertyDetailState.property!, user, t)
                  : Center(child: Text(t('property_not_found'))),
    );
  }


  // ── Header media: images + video in one PageView ──────────────────────────
  Widget _buildHeaderMedia(
    BuildContext context,
    WidgetRef ref,
    PropertyEntity property,
    String Function(String) t,
  ) {
    final hasVideos  = property.videos.isNotEmpty;
    final hasImages  = property.images.isNotEmpty;
    final totalItems = property.images.length + (hasVideos ? 1 : 0);
    final allMedia   = [...property.images, ...property.videos];

    if (!hasImages && !hasVideos) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(child: Icon(Icons.home_work, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.white24)),
      );
    }

    return Stack(
      children: [
        // PageView: images first, then video page(s) at the end
        PageView.builder(
          controller: _headerPageController,
          itemCount: totalItems,
          onPageChanged: (index) {
            setState(() => _currentHeaderIndex = index);
            if (hasVideos && index == property.images.length) {
              // Resume only if user had already pressed play for this video
              if (_headerVideoInitialized && _headerVideoPlayPressed) {
                _headerVideoController?.play();
              }
              // Otherwise do nothing — wait for explicit tap on play button
            } else {
              _headerVideoController?.pause();
            }
          },
          itemBuilder: (context, index) {
            final isVideoPage = hasVideos && index == property.images.length;
            if (isVideoPage) {
              return _buildHeaderVideoPage(context, ref, property);
            }
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenGallery(
                    mediaItems: allMedia,
                    initialIndex: index,
                    propertyTitle: property.title,
                  ),
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: property.images[index],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Icon(Icons.home_work, size: ResponsiveHelper.getResponsiveIconSize(context)),
                ),
              ),
            );
          },
        ),

        // Media counter (e.g. "2 / 3")
        if (totalItems > 1)
          Positioned(
            bottom: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentHeaderIndex + 1} / $totalItems',
                style: TextStyle(
                    color: Colors.white, fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), fontWeight: FontWeight.w600),
              ),
            ),
          ),

        // VIDEO badge (bottom-left) on video page
        if (hasVideos && _currentHeaderIndex == property.images.length)
          Positioned(
            bottom: 16, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.white, size: ResponsiveHelper.getResponsiveIconSize(context)),
                  const SizedBox(width: 4),
                  Text('VIDEO TOUR',
                      style: TextStyle(
                          color: Colors.white, fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

        // Navigation dots
        if (totalItems > 1)
          Positioned(
            bottom: 52, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalItems,
                (i) => Container(
                  width: 7, height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentHeaderIndex == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),

        // Left / Right arrow buttons — only on tablet & desktop
        if (totalItems > 1 && !ResponsiveHelper.isMobile(context)) ...[
          // Left arrow
          Positioned(
            left: 12, top: 0, bottom: 0,
            child: Center(
              child: _currentHeaderIndex > 0
                  ? _NavArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () {
                        _headerPageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Right arrow
          Positioned(
            right: 12, top: 0, bottom: 0,
            child: Center(
              child: _currentHeaderIndex < totalItems - 1
                  ? _NavArrowButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () {
                        _headerPageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderVideoPage(BuildContext context, WidgetRef ref, PropertyEntity property) {
    final isMuted = ref.watch(videoMuteProvider);
    final allMedia = [...property.images, ...property.videos];
    
    if (!_headerVideoInitialized || _headerVideoController == null) {
      // Show poster + play button — video only loads when user taps play
      return Stack(
        fit: StackFit.expand,
        children: [
          // Poster: first image darkened
          if (property.images.isNotEmpty)
            CachedNetworkImage(
              imageUrl: property.images.first,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.45),
              colorBlendMode: BlendMode.darken,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                ),
              ),
            ),
          // Play button or loading spinner
          Center(
            child: _headerVideoLoading
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const SizedBox(
                      width: 36, height: 36,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() => _headerVideoPlayPressed = true);
                      _initHeaderVideo(property.videos.first);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 2),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 44),
                    ),
                  ),
          ),
          // Label
          if (!_headerVideoLoading)
            Positioned(
              bottom: 70, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Tap to play video tour',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ),
            ),
        ],
      );
    }
    // Sync volume with global mute state
    _headerVideoController!.setVolume(isMuted ? 0 : 1);
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _headerVideoController!.value.size.width,
            height: _headerVideoController!.value.size.height,
            child: VideoPlayer(_headerVideoController!),
          ),
        ),
        // Mute button
        Positioned(
          bottom: 60, right: 16,
          child: GestureDetector(
            onTap: () {
              final current = ref.read(videoMuteProvider);
              ref.read(videoMuteProvider.notifier).state = !current;
            },
            child: Container(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: Icon(
                isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white, size: 20,
              ),
            ),
          ),
        ),
        // Tap overlay to open full-screen (FIXED)
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              // Pause the video before navigating
              _headerVideoController?.pause();
              // Navigate to full-screen gallery
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenGallery(
                    mediaItems: allMedia,
                    initialIndex: property.images.length, // Video index
                    propertyTitle: property.title,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyDetail(
    BuildContext context,
    WidgetRef ref,
    PropertyEntity property,
    UserEntity? user,
    String Function(String) t,
  ) {
    final isOwner = user?.id == property.ownerId;
    final isForRent = property.type == PropertyType.rent;
    final isAvailable = property.status == PropertyStatus.available;
    final currentCurrency = ref.watch(currencyProvider);

    // Get rent duration text
    String rentDurationText = '';
    if (isForRent) {
      final rentDuration = property.rentDuration;
      if (rentDuration == RentDuration.yearly) {
        rentDurationText = t('per_year');
      } else {
        rentDurationText = t('per_month');
      }
    }

    return CustomScrollView(
      slivers: [
        // App Bar with Image Gallery
        SliverAppBar(
          leading: IconButton(
            icon: Container(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          expandedHeight: 500,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeaderMedia(context, ref, property, t),
          ),
          actions: [
            // Share Button
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                onPressed: () {
                  final currency = ref.read(currencyProvider);
                  final priceStr = Formatters.formatCurrency(property.price, currencyCode: currency);
                  Share.share(
                    '🏠 ${property.title}\n'
                    '📍 ${property.location}\n'
                    '💰 $priceStr\n'
                    '🛏 ${property.bedrooms} bed  '
                    '🚿 ${property.bathrooms} bath  '
                    '📐 ${property.area.toInt()} sqft\n\n'
                    '${property.description.length > 120 ? '${property.description.substring(0, 120)}...' : property.description}\n\n'
                    'Find more properties on Patamjengo',
                    subject: property.title,
                  );
                },
              ),
            ),
            // Favorite Button
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: ThemeConfig.getColor(
                  context,
                  lightColor: Colors.grey.shade800.withOpacity(0.9),
                  darkColor: Colors.grey.shade800.withOpacity(0.9),
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FavoriteButton(propertyId: propertyId),
            ),
            // Owner Actions Menu
            if (isOwner)
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: ThemeConfig.getColor(
                    context,
                    lightColor: Colors.white.withOpacity(0.9),
                    darkColor: Colors.grey.shade800.withOpacity(0.9),
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit,
                          color: Theme.of(context).iconTheme.color,),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                          Text(t('edit')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                          Text(t('delete'),
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PropertyEditScreen(property: property),
                        ),
                      );

                      if (result == true && context.mounted) {
                        ref
                            .read(propertyDetailProvider(propertyId).notifier)
                            .loadProperty(propertyId);
                      }
                    } else if (value == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(t('delete_property')),
                          content: const Text(
                            'Are you sure you want to delete this property?\n\nIt will be hidden from the public listing. An admin can restore it if needed.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(t('cancel')),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeConfig.errorColor,
                              ),
                              child: Text(t('delete')),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        final success = await ref
                            .read(propertyDetailProvider(propertyId).notifier)
                            .deleteProperty(propertyId);

                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t('property_deleted')),
                              backgroundColor: ThemeConfig.secondaryColor,
                            ),
                          );
                          ref
                              .read(propertyListProvider.notifier)
                              .loadProperties(refresh: true);
                        }
                      }
                    }
                  },
                ),
              ),
          ],
        ),

        // Content Section
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price and Type Badge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Formatters.formatCurrency(property.price,
                                currencyCode: currentCurrency),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                          // Show rent duration below price
                          if (rentDurationText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                rentDurationText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isForRent
                            ? ThemeConfig.getColor(
                                context,
                                lightColor:
                                    ThemeConfig.lightPrimary.withOpacity(0.1),
                                darkColor:
                                    ThemeConfig.darkPrimary.withOpacity(0.2),
                              )
                            : ThemeConfig.getColor(
                                context,
                                lightColor:
                                    ThemeConfig.lightSecondary.withOpacity(0.1),
                                darkColor:
                                    ThemeConfig.darkSecondary.withOpacity(0.2),
                              ),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                      ),
                      child: Text(
                        property.type.displayName,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                          fontWeight: FontWeight.w600,
                          color: isForRent
                              ? Theme.of(context).primaryColor
                              : ThemeConfig.getColor(
                                  context,
                                  lightColor: ThemeConfig.lightSecondary,
                                  darkColor: ThemeConfig.darkSecondary,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

                // Title
                Text(
                  property.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                // Location
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        property.location,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                // Property Details Grid
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                  decoration: BoxDecoration(
                    color: ThemeConfig.getColor(
                      context,
                      lightColor: Colors.grey.shade50,
                      darkColor: Colors.grey.shade900,
                    ),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DetailItem(
                        context: context,
                        icon: Icons.bed_outlined,
                        label: t('bedrooms'),
                        value: '${property.bedrooms}',
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor,
                      ),
                      _DetailItem(
                        context: context,
                        icon: Icons.bathtub_outlined,
                        label: t('bathrooms'),
                        value: '${property.bathrooms}',
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor,
                      ),
                      _DetailItem(
                        context: context,
                        icon: Icons.square_foot_outlined,
                        label: t('area'),
                        value: '${property.area.toInt()} ${t('sqft')}',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                // Category Section
                _SectionTitle(title: t('category')),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThemeConfig.getColor(
                      context,
                      lightColor: ThemeConfig.lightPrimary.withOpacity(0.1),
                      darkColor: ThemeConfig.darkPrimary.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(property.category),
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      Text(
                        property.category.displayName,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                // Description Section
                _SectionTitle(title: t('description')),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                _ExpandableText(
                  text: property.description,
                  maxLines: 4,
                  isExpanded: _isDescriptionExpanded,
                  onToggle: () => setState(
                      () => _isDescriptionExpanded = !_isDescriptionExpanded),
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                // Status Section
                _SectionTitle(title: t('status')),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(property.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(property.status),
                        size: 20,
                        color: _getStatusColor(property.status),
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      Text(
                        property.status.displayName,
                        style: TextStyle(
                          color: _getStatusColor(property.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                // Posted Date
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${t('posted_time')} ${Formatters.formatRelativeTime(property.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

                // Message Owner Button
                if (!isOwner && isAvailable)
                  _buildMessageOwnerButton(context, ref, user, property, t),

                // If property is not available
                if (!isAvailable && !isOwner)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                    decoration: BoxDecoration(
                      color: ThemeConfig.getColor(
                        context,
                        lightColor: Colors.grey.shade100,
                        darkColor: Colors.grey.shade800,
                      ),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).iconTheme.color,
                          size: 32,
                        ),
                        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                        Text(
                          '${t('property_currently')} ${property.status.displayName.toLowerCase()}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        Text(
                          t('contact_not_available'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                // Owner Actions
                if (isOwner)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                        decoration: BoxDecoration(
                          color: ThemeConfig.getColor(
                            context,
                            lightColor:
                                ThemeConfig.lightPrimary.withOpacity(0.1),
                            darkColor: ThemeConfig.darkPrimary.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                          border: Border.all(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person,
                              color: Theme.of(context).primaryColor,
                              size: 32,
                            ),
                            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                            Text(
                              t('this_is_your_property'),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t('you_can_edit_delete'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                    ],
                  ),

                // Mortgage Calculator (free feature — no backend needed)
                if (property.type == PropertyType.sale)
                  _MortgageCalculator(propertyPrice: property.price),

                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                // Report this listing
                if (!isOwner)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showReportDialog(context, property.id, t),
                      icon: Icon(Icons.flag_outlined, size: 16,
                          color: Colors.red.shade400),
                      label: Text(t('report_listing'),
                          style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
                    ),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showReportDialog(BuildContext ctx, String propertyId, String Function(String) t) {
    String? selectedReason;
    final reasons = ['fake','wrong_price','wrong_location','already_sold','spam','offensive','other'];
    showDialog(
      context: ctx,
      builder: (c) => StatefulBuilder(
        builder: (c2, setS) => AlertDialog(
          title: const Text('Report this listing'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) => RadioListTile<String>(
              title: Text(r.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontSize: 13)),
              value: r,
              groupValue: selectedReason,
              onChanged: (v) => setS(() => selectedReason = v),
              dense: true,
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c2), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedReason == null ? null : () async {
                Navigator.pop(c2);
                try {
                  await Supabase.instance.client.from('property_reports').insert({
                    'property_id': propertyId,
                    'reported_by': Supabase.instance.client.auth.currentUser?.id,
                    'reason': selectedReason,
                  });
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Report submitted. Thank you.')));
                  }
                } catch (_) {}
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageOwnerButton(
    BuildContext context,
    WidgetRef ref,
    UserEntity? user,
    PropertyEntity property,
    String Function(String) t,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleMessageOwner(context, ref, user, property, t),
        icon: Icon(Icons.message, size: ResponsiveHelper.getResponsiveIconSize(context)),
        label: Text(
          t('message_owner'),
          style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  void _handleMessageOwner(
    BuildContext context,
    WidgetRef ref,
    UserEntity? user,
    PropertyEntity property,
    String Function(String) t,
  ) async {
    if (user == null) {
      SnackbarUtils.showError(context, t('please_login_to_message'));
      return;
    }

    if (user.id == property.ownerId) {
      SnackbarUtils.showInfo(context, t('this_is_your_own_property'));
      return;
    }

    try {
      await ChatHelper.startConversation(
        context: context,
        ref: ref,
        currentUserId: user.id,
        currentUserName: user.fullName,
        ownerId: property.ownerId,
        ownerName: property.ownerName.isNotEmpty
            ? property.ownerName
            : 'Property Owner',
        ownerAvatar: property.ownerAvatar,
        propertyId: property.id,
        propertyTitle: property.title,
        propertyImage:
            property.images.isNotEmpty ? property.images.first : null,
      );
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(
          context,
          t('something_went_wrong'),
        );
      }
    }
  }

  // Get category icon
  IconData _getCategoryIcon(PropertyCategory category) {
    switch (category) {
      case PropertyCategory.house:
        return Icons.home;
      case PropertyCategory.apartment:
        return Icons.apartment;
      case PropertyCategory.land:
        return Icons.landscape;
      case PropertyCategory.commercial:
        return Icons.business;
    }
  }

  // Get status color
  Color _getStatusColor(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.available:
        return ThemeConfig.successColor;
      case PropertyStatus.sold:
        return ThemeConfig.errorColor;
      case PropertyStatus.rented:
        return ThemeConfig.primaryColor;
      case PropertyStatus.pending:
        return ThemeConfig.warningColor;
    }
  }

  // Get status icon
  IconData _getStatusIcon(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.available:
        return Icons.check_circle;
      case PropertyStatus.sold:
        return Icons.sell;
      case PropertyStatus.rented:
        return Icons.key;
      case PropertyStatus.pending:
        return Icons.pending;
    }
  }
}

// Full Screen Gallery Screen
class FullScreenGallery extends StatefulWidget {
  final List<String> mediaItems;
  final int initialIndex;
  final String propertyTitle;

  const FullScreenGallery({
    super.key,
    required this.mediaItems,
    this.initialIndex = 0,
    required this.propertyTitle,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1}/${widget.mediaItems.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.mediaItems.length,
            builder: (context, index) {
              final mediaUrl = widget.mediaItems[index];

              final isVideo = mediaUrl.toLowerCase().endsWith('.mp4') ||
                  mediaUrl.toLowerCase().endsWith('.mov') ||
                  mediaUrl.toLowerCase().endsWith('.avi');

              if (isVideo) {
                return PhotoViewGalleryPageOptions.customChild(
                  child: _VideoPlayerWidget(videoUrl: mediaUrl),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 1.5,
                );
              } else {
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(mediaUrl),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.0,
                  heroAttributes: PhotoViewHeroAttributes(tag: mediaUrl),
                );
              }
            },
            onPageChanged: _onPageChanged,
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                ),
              ),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.mediaItems.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Video Player Widget
class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? posterUrl; // shown while the video buffers — no black screen

  // ignore: unused_element_parameter
  const _VideoPlayerWidget({required this.videoUrl, this.posterUrl});

  @override
  __VideoPlayerWidgetState createState() => __VideoPlayerWidgetState();
}

class __VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  final bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    if (widget.videoUrl.startsWith('http')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else if (widget.videoUrl.startsWith('file://')) {
      _videoController = VideoPlayerController.file(
          File(widget.videoUrl.replaceFirst('file://', '')));
    } else {
      _videoController = VideoPlayerController.asset(widget.videoUrl);
    }

    await _videoController.initialize();

    setState(() {
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowFullScreen: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: ThemeConfig.primaryColor,
          handleColor: ThemeConfig.primaryColor,
          backgroundColor: Colors.grey.shade600,
          bufferedColor: Colors.grey.shade400,
        ),
      );
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null) {
      // Show poster frame while video buffers — never a black screen
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.posterUrl != null)
              CachedNetworkImage(
                imageUrl: widget.posterUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
                placeholder: (_, __) => Container(color: Colors.black),
                errorWidget: (_, __, ___) => Container(color: Colors.black),
              )
            else
              Container(color: Colors.black),
            const Center(
              child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
            ),
          ],
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: Chewie(controller: _chewieController!),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.context,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: Theme.of(context).primaryColor,
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

// ── Expandable description text ──────────────────────────────────────────────
class _ExpandableText extends StatelessWidget {
  final String text;
  final int maxLines;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ExpandableText({
    required this.text,
    required this.maxLines,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: isExpanded ? null : maxLines,
          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
        // Only show toggle if text is likely longer than maxLines
        if (text.length > 200)
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                isExpanded ? 'Show less' : 'Read more',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Mortgage Calculator (free feature — no backend, pure Flutter math) ─────
class _MortgageCalculator extends StatefulWidget {
  final double propertyPrice;

  const _MortgageCalculator({required this.propertyPrice});

  @override
  State<_MortgageCalculator> createState() => _MortgageCalculatorState();
}

class _MortgageCalculatorState extends State<_MortgageCalculator> {
  double _downPaymentPct = 20; // %
  double _interestRate = 12;   // % per year (Tanzania average)
  double _termYears = 15;

  double get _loanAmount =>
      widget.propertyPrice * (1 - _downPaymentPct / 100);

  double get _monthlyPayment {
    final principal = _loanAmount;
    if (principal <= 0) return 0;
    final monthlyRate = _interestRate / 100 / 12;
    final n = _termYears * 12;
    if (monthlyRate == 0) return principal / n;
    final factor = math.pow(1 + monthlyRate, n).toDouble();
    return principal * (monthlyRate * factor) / (factor - 1);
  }

  double get _totalCost => _monthlyPayment * _termYears * 12;

  String _fmt(double v) {
    if (v >= 1000000) return 'TZS ${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return 'TZS ${(v / 1000).toStringAsFixed(0)}K';
    return 'TZS ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.calculate_rounded, color: primary, size: 22),
              const SizedBox(width: 8),
              Text('Mortgage Calculator',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text('Estimate your monthly repayment',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500)),
            const SizedBox(height: 20),

            // Down payment
            _SliderRow(
              label: 'Down Payment',
              value: _downPaymentPct,
              min: 5,
              max: 50,
              divisions: 45,
              displayValue: '${_downPaymentPct.round()}%',
              onChanged: (v) => setState(() => _downPaymentPct = v),
            ),

            // Interest rate
            _SliderRow(
              label: 'Interest Rate',
              value: _interestRate,
              min: 5,
              max: 30,
              divisions: 50,
              displayValue: '${_interestRate.toStringAsFixed(1)}%',
              onChanged: (v) => setState(() => _interestRate = v),
            ),

            // Loan term
            _SliderRow(
              label: 'Loan Term',
              value: _termYears,
              min: 1,
              max: 30,
              divisions: 29,
              displayValue: '${_termYears.round()} yrs',
              onChanged: (v) => setState(() => _termYears = v),
            ),

            const Divider(height: 28),

            // Results row
            Row(
              children: [
                Expanded(
                  child: _CalcResult(
                    label: 'Loan Amount',
                    value: _fmt(_loanAmount),
                    color: primary,
                  ),
                ),
                Expanded(
                  child: _CalcResult(
                    label: 'Monthly',
                    value: _fmt(_monthlyPayment),
                    color: Colors.green.shade600,
                    highlight: true,
                  ),
                ),
                Expanded(
                  child: _CalcResult(
                    label: 'Total Cost',
                    value: _fmt(_totalCost),
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '* Estimates only. Consult your bank for actual rates.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade500, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 110,
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w500)),
      ),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 52,
        child: Text(displayValue,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor)),
      ),
    ]);
  }
}

class _CalcResult extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool highlight;

  const _CalcResult({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: highlight ? 15 : 13,
            ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 2),
      Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey.shade500, fontSize: 11),
          textAlign: TextAlign.center),
    ]);
  }
}

// ── Navigation arrow button for carousel (tablet / desktop) ──────────────────
class _NavArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}