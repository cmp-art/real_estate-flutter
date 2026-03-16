// features/properties/presentation/widgets/property_list_card.dart
// Redesigned to match PropertyGridCard visual style — no archive button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/cdn_service.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../providers/property_providers.dart';
import '../providers/video_providers.dart';
import '../screens/property_edit_screen.dart';
import 'package:real_estate_app/features/settings/presentation/screens/app_translations.dart';

class PropertyListCard extends ConsumerStatefulWidget {
  final dynamic property;
  final VoidCallback onTap;
  final VoidCallback? onShare;

  const PropertyListCard({
    super.key,
    required this.property,
    required this.onTap,
    this.onShare,
  });

  @override
  ConsumerState<PropertyListCard> createState() => _PropertyListCardState();
}

class _PropertyListCardState extends ConsumerState<PropertyListCard> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  // Only stream video when user explicitly taps play (saves egress)
  bool _userTappedPlay = false;

  // ── Video lifecycle (tap-to-play) ─────────────────────────────────────────

  Future<void> _initVideo() async {
    if (_videoController != null) return;
    if (widget.property.videos.isEmpty) return;
    if (mounted) setState(() => _isVideoLoading = true);
    try {
      _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.property.videos.first));
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      final isMuted = ref.read(videoMuteProvider);
      await _videoController!.setVolume(isMuted ? 0 : 1);
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
        // Only play if user explicitly tapped — never autoplay in list
        if (_userTappedPlay) _videoController!.play();
      }
    } catch (e) {
      if (mounted) setState(() => _isVideoLoading = false);
      debugPrint('Video init error: $e');
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _isVideoLoading = false;
    _userTappedPlay = false;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction > 0.5) {
      // Resume only if user already tapped play for this card
      if (_userTappedPlay && _isVideoInitialized && !_videoController!.value.isPlaying) {
        _videoController!.play();
      }
      // Do NOT auto-init — wait for explicit tap
    } else if (info.visibleFraction == 0) {
      if (_videoController != null) setState(() { _disposeVideo(); });
    } else {
      if (_isVideoInitialized && _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
    }
  }

  // ── Video tile ─────────────────────────────────────────────────────────────

  Widget _buildVideoTile(bool isMuted) {
    if (_isVideoLoading) {
      return Container(
        color: Colors.black87,
        child: const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)));
    }
    if (!_isVideoInitialized || _videoController == null) {
      // Tap-to-play: show property image as poster — no video stream until tap
      return GestureDetector(
        onTap: () {
          setState(() => _userTappedPlay = true);
          _initVideo();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.property.images.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.property.images.first,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.darken,
                placeholder: (_, __) => Container(color: Colors.grey.shade900),
                errorWidget: (_, __, ___) => Container(color: Colors.grey.shade900),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                  ),
                ),
              ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 40),
              ),
            ),
          ],
        ),
      );
    }
    _videoController!.setVolume(isMuted ? 0 : 1);
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              final current = ref.read(videoMuteProvider);
              ref.read(videoMuteProvider.notifier).state = !current;
              _videoController?.setVolume(current ? 1 : 0);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: Icon(
                isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: ResponsiveHelper.getResponsiveIconSize(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Owner actions ──────────────────────────────────────────────────────────

  Future<void> _handleShare() async {
    final currentLanguage = ref.read(languageProvider).languageCode;
    final currentCurrency = ref.read(currencyProvider);
    String t(String key) => AppTranslations.translate(key, currentLanguage);
    try {
      final text = '${t('property')}: ${widget.property.title}\n'
          '${t('price')}: ${Formatters.formatCurrency(widget.property.price, currencyCode: currentCurrency)}\n'
          '${t('location')}: ${widget.property.location}\n'
          '${t('bedrooms')}: ${widget.property.bedrooms}, ${t('bathrooms')}: ${widget.property.bathrooms}\n'
          '${t('area')}: ${widget.property.area.toInt()} ${t('sqft')}';
      await Share.share(text);
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'error');
    }
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyEditScreen(property: widget.property),
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
          (failure) => SnackbarUtils.showError(context, t('error')),
          (_) {
            SnackbarUtils.showSuccess(context, t('property_deleted'));
            ref.read(myPropertiesProvider.notifier).removeProperty(widget.property.id);
            ref.read(propertyListProvider.notifier).removeProperty(widget.property.id);
          },
        );
      }
    }
  }

  void _showMoreOptions() {
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
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
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
                  color: isDarkMode ? Colors.grey[400] : ThemeConfig.textSecondaryColor),
              title: Text(t('share'),
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              onTap: () { Navigator.pop(context); _handleShare(); },
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
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isForRent = widget.property.type == PropertyType.rent;
    final currentCurrency = ref.watch(currencyProvider);
    final currentLanguage = ref.watch(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    final isLandOrCommercial = widget.property.category == PropertyCategory.land ||
        widget.property.category == PropertyCategory.commercial;

    String rentDurationText = '';
    if (isForRent) {
      final rentDuration = widget.property.rentDuration;
      rentDurationText = (rentDuration == null || rentDuration == RentDuration.monthly)
          ? t('per_month')
          : t('per_year');
    }

    final currentUser = ref.watch(authNotifierProvider).value;
    final isOwner = currentUser?.id == widget.property.ownerId;

    final cardColor = theme.cardColor;
    final shadowColor = ThemeConfig.getColor(
      context,
      lightColor: Colors.black.withOpacity(0.1),
      darkColor: Colors.black.withOpacity(0.4),
    );
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final iconColor = theme.iconTheme.color ?? Colors.grey;
    final backgroundColor = ThemeConfig.getColor(
      context,
      lightColor: Colors.grey[200]!,
      darkColor: Colors.grey[800]!,
    );
    final buttonBg = cardColor;
    final statusColor = _getStatusColor(widget.property.status, isDarkMode);
    final statusTextColor = _getStatusTextColor(widget.property.status, isDarkMode);

    final hasVideo = widget.property.videos.isNotEmpty;
    final totalMedia = widget.property.images.length + (hasVideo ? 1 : 0);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(
              ResponsiveHelper.getResponsiveBorderRadius(context)),
          boxShadow: [
            BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Media section ────────────────────────────────────────────────
            VisibilityDetector(
              key: Key('prop-list-${widget.property.id}'),
              onVisibilityChanged: _onVisibilityChanged,
              child: Stack(
                children: [
                  // Image / video carousel
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: (widget.property.images.isNotEmpty || hasVideo)
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: totalMedia,
                              onPageChanged: (index) =>
                                  setState(() => _currentImageIndex = index),
                              itemBuilder: (context, index) {
                                if (hasVideo &&
                                    index == widget.property.images.length) {
                                  final isMuted = ref.watch(videoMuteProvider);
                                  return _buildVideoTile(isMuted);
                                }
                                return CachedNetworkImage(
                                  imageUrl: widget.property.images[index],
                                  cacheManager: CustomCacheManager.instance,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: backgroundColor,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          color: ThemeConfig.primaryColor),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: backgroundColor,
                                    child: Icon(Icons.home,
                                        size: ResponsiveHelper
                                            .getResponsiveIconSize(context),
                                        color: iconColor),
                                  ),
                                  fadeInDuration:
                                      const Duration(milliseconds: 300),
                                  fadeOutDuration:
                                      const Duration(milliseconds: 100),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(Icons.home,
                                size: ResponsiveHelper.getResponsiveIconSize(
                                    context),
                                color: iconColor),
                          ),
                  ),

                  // Status badge — top left
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.property.status.displayName.toUpperCase(),
                        style: TextStyle(
                          color: statusTextColor,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context, mobile: 10),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Tier badge — top right (offset when counter also showing)
                  if (widget.property.ownerTier == 'pro' ||
                      widget.property.ownerTier == 'basic')
                    Positioned(
                      top: 8,
                      right: totalMedia > 1 ? 48 : 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.property.ownerTier == 'pro'
                              ? Colors.green[700]
                              : Colors.blue[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.property.ownerTier == 'pro'
                                  ? Icons.workspace_premium
                                  : Icons.verified,
                              color: Colors.white,
                              size: ResponsiveHelper.getResponsiveIconSize(
                                  context),
                            ),
                            SizedBox(
                                width: ResponsiveHelper.getResponsiveSpacing(
                                        context) /
                                    2),
                            Text(
                              widget.property.ownerTier == 'pro'
                                  ? 'PRO'
                                  : 'BASIC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    ResponsiveHelper.getResponsiveFontSize(
                                        context, mobile: 10),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Image counter badge — top right
                  if (totalMedia > 1)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(
                              ResponsiveHelper.getResponsiveBorderRadius(
                                  context)),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/$totalMedia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context, mobile: 10),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Dot indicators — bottom centre
                  if (totalMedia > 1)
                    Positioned(
                      bottom: hasVideo ? 28 : 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          totalMedia,
                          (index) => GestureDetector(
                            onTap: () => _pageController.animateToPage(index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut),
                            child: Container(
                              width: 6, height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // VIDEO badge — bottom left
                  if (hasVideo)
                    Positioned(
                      bottom: 28, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(
                              ResponsiveHelper.getResponsiveBorderRadius(
                                      context) /
                                  2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_rounded,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              'VIDEO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    ResponsiveHelper.getResponsiveFontSize(
                                        context, mobile: 10),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Details section ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(
                  context,
                  multiplier: 1.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Price row + owner actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.formatCurrency(widget.property.price,
                                  currencyCode: currentCurrency),
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
                                    fontSize:
                                        ResponsiveHelper.getResponsiveFontSize(
                                            context, mobile: 12),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Action buttons
                      if (isOwner)
                        // Owner: favorite + more options (NO archive)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CircleIconButton(
                              bg: buttonBg,
                              shadow: shadowColor,
                              child: FavoriteButton(
                                  propertyId: widget.property.id),
                            ),
                            SizedBox(
                                width: ResponsiveHelper.getResponsiveSpacing(
                                    context)),
                            _CircleIconButton(
                              bg: buttonBg,
                              shadow: shadowColor,
                              child: IconButton(
                                onPressed: _showMoreOptions,
                                icon: Icon(Icons.more_vert, color: iconColor),
                                iconSize: 20,
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        )
                      else
                        // Non-owner: just favorite
                        _CircleIconButton(
                          bg: buttonBg,
                          shadow: shadowColor,
                          child: FavoriteButton(
                              propertyId: widget.property.id),
                        ),
                    ],
                  ),

                  SizedBox(
                      height:
                          ResponsiveHelper.getResponsiveSpacing(context)),

                  // Title
                  Text(
                    widget.property.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(
                      height: ResponsiveHelper.getResponsiveSpacing(context) /
                          2),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: ResponsiveHelper.getResponsiveIconSize(context),
                          color: secondaryTextColor),
                      SizedBox(
                          width:
                              ResponsiveHelper.getResponsiveSpacing(context) /
                                  2),
                      Expanded(
                        child: Text(
                          widget.property.location,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: secondaryTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(
                      height: ResponsiveHelper.getResponsiveSpacing(context,
                          multiplier: 1.5)),

                  // Stats row
                  Row(
                    children: [
                      if (!isLandOrCommercial) ...[
                        _PropertyDetailItem(
                          icon: Icons.bed,
                          value: '${widget.property.bedrooms}',
                          label: t('beds'),
                          iconColor: iconColor,
                          valueColor: textColor,
                          labelColor: secondaryTextColor,
                        ),
                        SizedBox(
                            width: ResponsiveHelper.getResponsivePadding(
                                context)),
                        _PropertyDetailItem(
                          icon: Icons.bathtub,
                          value: '${widget.property.bathrooms}',
                          label: t('baths'),
                          iconColor: iconColor,
                          valueColor: textColor,
                          labelColor: secondaryTextColor,
                        ),
                        SizedBox(
                            width: ResponsiveHelper.getResponsivePadding(
                                context)),
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
                      // Rent / Sale badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isForRent
                              ? ThemeConfig.primaryColor
                                  .withOpacity(isDarkMode ? 0.2 : 0.1)
                              : ThemeConfig.secondaryColor
                                  .withOpacity(isDarkMode ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.property.type.displayName,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context, mobile: 12),
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
      case PropertyStatus.sold:
      case PropertyStatus.rented:
        return Colors.white;
      case PropertyStatus.pending:
        return isDarkMode ? Colors.white : Colors.black;
    }
  }
}

// ── Shared helper widgets ──────────────────────────────────────────────────

/// Wraps any widget in a circular card with shadow — matches grid card's button style.
class _CircleIconButton extends StatelessWidget {
  final Widget child;
  final Color bg;
  final Color shadow;

  const _CircleIconButton({
    required this.child,
    required this.bg,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: child,
    );
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
      children: [
        Icon(icon,
            size: ResponsiveHelper.getResponsiveIconSize(context),
            color: iconColor),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context) / 2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: valueColor)),
            Text(label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context,
                      mobile: 10),
                )),
          ],
        ),
      ],
    );
  }
}