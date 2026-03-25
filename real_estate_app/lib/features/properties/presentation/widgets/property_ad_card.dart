// lib/features/properties/presentation/widgets/direct_ad_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/cdn_service.dart';
import '../../../../core/services/direct_ad_models.dart';
import '../../../../core/config/theme_config.dart';
import '../../../users/presentation/screens/user_profileview_screen.dart';
import '../../presentation/screens/property_detail_screen.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../settings/presentation/screens/app_translations.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../../core/widgets/report_bottom_sheet.dart';

/// Widget for displaying direct ads in property listings
/// - Native-style design that matches the app theme
/// - Clear "Sponsored" label for transparency
/// - Optimized for real estate content
/// - Supports image ads
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

  String _t(String key) => AppTranslations.translate(
      key, ref.read(languageProvider).languageCode);

  void _onVisibilityChanged(bool isVisible) {
    if (isVisible && !_hasRecordedImpression) {
      _hasRecordedImpression = true;
      widget.onImpression();
    }
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

                // Ad Media
                _buildMediaContent(context),

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

  Widget _buildMediaContent(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CachedNetworkImage(
          imageUrl: CdnService.getMediumUrl(widget.ad.imageUrl),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
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