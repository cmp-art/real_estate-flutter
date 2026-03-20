// lib/features/properties/presentation/widgets/direct_ad_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/cdn_service.dart';
import '../../../../core/services/direct_ad_models.dart';
import '../../../../core/config/theme_config.dart';
import '../../../users/presentation/screens/user_profileview_screen.dart';
import '../../presentation/screens/property_detail_screen.dart';
import '../providers/video_providers.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../settings/presentation/screens/app_translations.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../../core/widgets/report_bottom_sheet.dart';

/// Widget for displaying direct ads in property listings
/// - Native-style design that matches the app theme
/// - Clear "Sponsored" label for transparency
/// - Optimized for real estate content
/// - Supports both images and videos
class DirectAdWidget extends ConsumerStatefulWidget {
  final DirectAd ad;
  final VoidCallback onImpression;
  final VoidCallback onClick;

  const DirectAdWidget({
    super.key,
    required this.ad,
    required this.onImpression,
    required this.onClick,
  });

  @override
  ConsumerState<DirectAdWidget> createState() => _DirectAdWidgetState();
}

class _DirectAdWidgetState extends ConsumerState<DirectAdWidget> {
  bool _hasRecordedImpression = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;

  String _t(String key) => AppTranslations.translate(
      key, ref.read(languageProvider).languageCode);

  @override
  void initState() {
    super.initState();
    // Video is NOT auto-initialized — user must tap play to stream (saves egress)
    // Impression is recorded in _onVisibilityChanged, not here.
    // Firing on build means off-screen ads count as impressions — advertisers
    // pay for ads nobody saw. We wait until the widget is actually on screen.
  }

  void _onVisibilityChanged(bool isVisible) {
    if (isVisible && !_hasRecordedImpression) {
      _hasRecordedImpression = true;
      widget.onImpression();
    }
  }

  Future<void> _initializeVideo() async {
    if (_videoController != null) return;
    if (mounted) setState(() => _isVideoLoading = true);
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.ad.videoUrl!),
      );
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.setVolume(0); // start muted
      // Play immediately — user tapped the play button
      await _videoController!.play();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isVideoLoading = false);
      debugPrint('Error initializing video: $e');
    }
  }

  void _toggleMute() {
    if (_videoController == null) return;
    final current = ref.read(videoMuteProvider);
    ref.read(videoMuteProvider.notifier).state = !current;
    _videoController!.setVolume(current ? 1 : 0);
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {});
    _videoController!.value.isPlaying
        ? _videoController!.pause()
        : _videoController!.play();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _handleClick() async {
    widget.onClick();
    if (!context.mounted) return;

    switch (widget.ad.destinationType) {
      // ── WhatsApp with pre-filled message ──────────────────────────────
      // landing_url = https://wa.me/<number>?text=<encoded_msg>
      // Opens WhatsApp app directly if installed, web fallback otherwise.
      case 'whatsapp':
        try {
          final uri = Uri.parse(widget.ad.landingUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Error launching WhatsApp: $e');
        }
        break;

      // ── In-app property detail ────────────────────────────────────────
      case 'property':
        final propertyId = widget.ad.linkedPropertyId;
        if (propertyId != null && propertyId.isNotEmpty && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailScreen(propertyId: propertyId),
            ),
          );
        }
        break;

      // ── In-app agent profile ──────────────────────────────────────────
      case 'profile':
        final profileUserId = widget.ad.advertiserUserId;
        if (profileUserId != null &&
            profileUserId.isNotEmpty &&
            context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileViewScreen(userId: profileUserId),
            ),
          );
        }
        break;

      // ── External website ──────────────────────────────────────────────
      default: // 'website'
        try {
          final uri = Uri.parse(widget.ad.landingUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Error launching URL: $e');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Wrap in NotificationListener so impression fires only when ad is visible.
    // Using addPostFrameCallback on every scroll event + initial layout check.
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final box = context.findRenderObject() as RenderBox?;
          if (box == null || !box.attached) return;
          final viewport = MediaQuery.of(context).size;
          final pos = box.localToGlobal(Offset.zero);
          _onVisibilityChanged(
              pos.dy < viewport.height && pos.dy + box.size.height > 0);
        });
        return false;
      },
      child: Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _hasRecordedImpression) return;
          final box = context.findRenderObject() as RenderBox?;
          if (box == null || !box.attached) return;
          final viewport = MediaQuery.of(context).size;
          final pos = box.localToGlobal(Offset.zero);
          _onVisibilityChanged(
              pos.dy < viewport.height && pos.dy + box.size.height > 0);
        });
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
            side: BorderSide(
              color: ThemeConfig.getColor(
                context,
                lightColor: ThemeConfig.lightBorder,
                darkColor: ThemeConfig.darkBorder,
              ),
              width: 1,
            ),
          ),
          color: ThemeConfig.getCardColor(context),
          child: InkWell(
            onTap: _handleClick,
            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sponsored Label + Report button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5),
                    vertical: ResponsiveHelper.getResponsiveSpacing(context),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: ResponsiveHelper.getResponsiveIconSize(context),
                        color: ThemeConfig.getTextSecondaryColor(context),
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context) / 2),
                      Text(
                        _t('sponsored'),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                          fontWeight: FontWeight.w600,
                          color: ThemeConfig.getTextSecondaryColor(context),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => ReportBottomSheet.showAd(
                          context,
                          widget.ad.creativeId,
                          widget.ad.campaignId,
                        ),
                        child: Icon(
                          Icons.more_vert,
                          size: ResponsiveHelper.getResponsiveIconSize(context),
                          color: ThemeConfig.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // Ad Media (Image or Video)
                _buildMediaContent(context, isDark),

                // Ad Content
                Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Headline with Logo
                      Row(
                        children: [
                          if (widget.ad.logoUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                              child: CachedNetworkImage(
                                imageUrl: CdnService.getThumbnailUrl(widget.ad.logoUrl!),
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              widget.ad.headline,
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 17),
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.getTextPrimaryColor(context),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Description
                      if (widget.ad.description != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          widget.ad.description!,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                            color: ThemeConfig.getTextSecondaryColor(context),
                            height: 1.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

                      // Call to Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleClick,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                ThemeConfig.getPrimaryColor(context),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            widget.ad.callToAction,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }), // Builder
    ); // NotificationListener
  }

  Widget _buildMediaContent(BuildContext context, bool isDark) {
    final isVideoAd =
        widget.ad.mediaType == 'video' && widget.ad.videoUrl != null;

    // ── VIDEO PATH ────────────────────────────────────────────────────
    if (isVideoAd) {
      // While video is buffering, show the ad's image as a poster frame
      // so the user never sees a black screen.
      if (_isVideoLoading || !_isVideoInitialized) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: SizedBox(
            height: 200, // Fixed 200px — never expands
            child: GestureDetector(
              onTap: _isVideoLoading ? null : _initializeVideo, // tap to stream
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster frame — ad image with slight dark overlay
                  CachedNetworkImage(
                    imageUrl: CdnService.getMediumUrl(widget.ad.imageUrl),
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.35),
                    colorBlendMode: BlendMode.darken,
                    placeholder: (_, __) =>
                        Container(color: Colors.grey.shade900),
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey.shade900),
                  ),
                  // Play button or loading indicator
                  Center(
                    child: _isVideoLoading
                        ? const SizedBox(
                            width: 36, height: 36,
                            child: CircularProgressIndicator(
                                color: Colors.white70, strokeWidth: 2.5))
                        : Icon(Icons.play_circle_outline_rounded,
                            size: ResponsiveHelper.getResponsiveIconSize(context),
                            color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Video ready — fixed 200px container; video scales to fit via FittedBox.
      // The container never grows to match the video's natural aspect ratio.
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: SizedBox(
          height: 200, // Fixed height — matches image ads exactly
          width: double.infinity,
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // FittedBox scales the video's natural size DOWN to fit inside
                // the 200px container while preserving aspect ratio (no stretch).
                LayoutBuilder(
                  builder: (context, constraints) {
                    final containerW = constraints.maxWidth;
                    const containerH = 200.0;
                    final videoAspect = _videoController!.value.aspectRatio;

                    double renderW, renderH;
                    if (containerW / containerH > videoAspect) {
                      // Container is wider — scale to fill width, crop height
                      renderW = containerW;
                      renderH = containerW / videoAspect;
                    } else {
                      // Container is taller — scale to fill height, crop width
                      renderH = containerH;
                      renderW = containerH * videoAspect;
                    }

                    return ClipRect(
                      child: OverflowBox(
                        maxWidth: renderW,
                        maxHeight: renderH,
                        child: SizedBox(
                          width: renderW,
                          height: renderH,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    );
                  },
                ),
                // Pause overlay
                if (!_videoController!.value.isPlaying)
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                    decoration: const BoxDecoration(
                        color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
                  ),
                // Mute button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: Icon(
                        ref.watch(videoMuteProvider)
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: ResponsiveHelper.getResponsiveIconSize(context),
                      ),
                    ),
                  ),
                ),
                // VIDEO AD badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_rounded,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 3),
                        Text(_t('video_ad'),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── IMAGE PATH ────────────────────────────────────────────────────
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: CachedNetworkImage(
        imageUrl: CdnService.getMediumUrl(widget.ad.imageUrl),
        width: double.infinity,
        height: 200, // Fixed 200px
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 200,
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightInputFill,
            darkColor: ThemeConfig.darkInputFill,
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ThemeConfig.getPrimaryColor(context),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightInputFill,
            darkColor: ThemeConfig.darkInputFill,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: ResponsiveHelper.getResponsiveIconSize(context),
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              Text(
                _t('ad_media_unavailable'),
                style: TextStyle(
                  color: ThemeConfig.getTextSecondaryColor(context),
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact banner version for alternate placement
class DirectAdBanner extends ConsumerStatefulWidget {
  final DirectAd ad;
  final VoidCallback onImpression;
  final VoidCallback onClick;

  const DirectAdBanner({
    super.key,
    required this.ad,
    required this.onImpression,
    required this.onClick,
  });

  @override
  ConsumerState<DirectAdBanner> createState() => _DirectAdBannerState();
}

class _DirectAdBannerState extends ConsumerState<DirectAdBanner> {
  bool _hasRecordedImpression = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasRecordedImpression) {
        _hasRecordedImpression = true;
        widget.onImpression();
      }
    });
  }

  Future<void> _handleClick() async {
    widget.onClick();
    if (!context.mounted) return;

    switch (widget.ad.destinationType) {
      case 'whatsapp':
        try {
          final uri = Uri.parse(widget.ad.landingUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Error launching WhatsApp: $e');
        }
        break;
      case 'property':
        final propertyId = widget.ad.linkedPropertyId;
        if (propertyId != null && propertyId.isNotEmpty && context.mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PropertyDetailScreen(propertyId: propertyId),
              ));
        }
        break;
      case 'profile':
        final profileUserId = widget.ad.advertiserUserId;
        if (profileUserId != null &&
            profileUserId.isNotEmpty &&
            context.mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileViewScreen(userId: profileUserId),
              ));
        }
        break;
      default: // 'website'
        try {
          final uri = Uri.parse(widget.ad.landingUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Error launching URL: $e');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, lang);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
        side: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder,
          ),
          width: 1,
        ),
      ),
      color: ThemeConfig.getCardColor(context),
      child: InkWell(
        onTap: _handleClick,
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          child: Row(
            children: [
              // Ad Image/Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: CdnService.getThumbnailUrl(widget.ad.imageUrl),
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 90,
                    height: 90,
                    color: ThemeConfig.getColor(
                      context,
                      lightColor: ThemeConfig.lightInputFill,
                      darkColor: ThemeConfig.darkInputFill,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 90,
                    height: 90,
                    color: ThemeConfig.getColor(
                      context,
                      lightColor: ThemeConfig.lightInputFill,
                      darkColor: ThemeConfig.darkInputFill,
                    ),
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: ThemeConfig.getTextSecondaryColor(context),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Ad Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sponsored label
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: ResponsiveHelper.getResponsiveIconSize(context),
                          color: ThemeConfig.getTextSecondaryColor(context),
                        ),
                        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context) / 2),
                        Text(
                          t('sponsored'),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                            fontWeight: FontWeight.w600,
                            color: ThemeConfig.getTextSecondaryColor(context),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Headline
                    Text(
                      widget.ad.headline,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                        fontWeight: FontWeight.w600,
                        color: ThemeConfig.getTextPrimaryColor(context),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // CTA
                    Text(
                      widget.ad.callToAction,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                        color: ThemeConfig.getPrimaryColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: ResponsiveHelper.getResponsiveIconSize(context),
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}