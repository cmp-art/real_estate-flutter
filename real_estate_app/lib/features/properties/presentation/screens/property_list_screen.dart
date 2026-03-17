// features/properties/presentation/screens/property_list_screen.dart
// COMPLETE FIXED VERSION - ALL ERRORS RESOLVED

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../advertising/presentation/provider/ad_providers.dart';
import '../../../../core/services/direct_ad_models.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../providers/property_providers.dart';

import '../widgets/property_ad_card.dart';
import '../widgets/property_grid_card.dart';
import '../widgets/property_list_card.dart';
import 'property_detail_screen.dart';
import 'property_search_screen.dart';
import 'property_filter_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

import '../../../../core/services/cdn_service.dart';

class PropertyListScreen extends ConsumerStatefulWidget {
  const PropertyListScreen({super.key});

  @override
  ConsumerState<PropertyListScreen> createState() => 
      _PropertyListScreenDirectAdsState();
}

class _PropertyListScreenDirectAdsState 
    extends ConsumerState<PropertyListScreen> {
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;
  bool _hasLoadedInitially = false;
  
  // Ad state
  bool _shouldShowAds = false;
  int _adFrequency = 7;
  List<DirectAd> _loadedAds = [];
  List<DirectAd> _shuffledAdPool = [];
  int _adPoolIndex = 0;
  final Map<String, String> _impressionIds = {};
  final Set<String> _sessionImpressionRecorded = {};
  int _propertyViewCount = 0;

  static const Duration _adRefreshInterval = Duration(minutes: 15);
  DateTime? _lastAdLoadTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasLoadedInitially) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasLoadedInitially = true;
        debugPrint('🚀 Initial load - PropertyListScreenDirectAds');
        ref.read(propertyListProvider.notifier).loadProperties(refresh: true);
        _loadAdsAndCheckEligibility();
        _warmImageCache();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static const String _adminEmail = 'collinmarine9@gmail.com';

  /// ✅ FIXED: Use state.properties directly, not whenData
  Future<void> _warmImageCache() async {
    final state = ref.read(propertyListProvider);
    
    // ✅ FIXED: Access properties directly from state
    if (state.properties.isNotEmpty) {
      for (int i = 0; i < state.properties.length && i < 10; i++) {
        if (state.properties[i].images.isNotEmpty) {
          final thumbnailUrl = CdnService.getThumbnailUrl(state.properties[i].images.first);
          CustomCacheManager.instance.downloadFile(thumbnailUrl);
        }
      }
      debugPrint('🖼️ Cache warming: Pre-loaded first 10 thumbnails');
    }
  }

  Future<String?> _resolveUserRegion(dynamic user) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 8),
        );

        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final region = place.administrativeArea ??
              place.subAdministrativeArea ??
              place.locality;
          if (region != null && region.isNotEmpty) {
            debugPrint('🌍 ADS: GPS region=$region');
            return region;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ ADS: GPS failed ($e) — trying profile');
    }

    final metaRegion = user.userMetadata?['region'] as String? ??
        user.userMetadata?['city'] as String? ??
        user.userMetadata?['location'] as String?;
    if (metaRegion != null) {
      debugPrint('🌍 ADS: metadata region=$metaRegion');
      return metaRegion;
    }

    try {
      final supabase = ref.read(supabaseClientProvider);
      final profile = await supabase
          .from('users')
          .select('location')
          .eq('id', user.id)
          .maybeSingle();
      final dbRegion = profile?['location'] as String?;
      if (dbRegion != null) {
        debugPrint('🌍 ADS: DB region=$dbRegion');
        return dbRegion;
      }
    } catch (e) {
      debugPrint('⚠️ ADS: DB region lookup failed ($e)');
    }

    debugPrint('🌍 ADS: region=null → no location filter (all Tanzania)');
    return null;
  }

  Future<void> _loadAdsAndCheckEligibility() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) {
      debugPrint('🔴 ADS: user null — skip');
      return;
    }

    debugPrint('🔵 ADS: loading for user ${user.id}');
    final adService = ref.read(directAdServiceProvider);

    final userEmail = user.email ?? '';
    final isAdmin = userEmail == _adminEmail;

    if (isAdmin) {
      debugPrint('🔵 ADS: admin user — bypassing subscription + frequency cap');
      List<DirectAd> ads = [];
      try {
        ads = await adService.getEligibleAds(
          userId: user.id,
          screenName: 'property_list',
          userRegion: null,
          limit: 10,
        );
      } catch (e) {
        debugPrint('🔴 ADS: admin getEligibleAds failed: $e');
      }
      if (mounted) {
        setState(() {
          _shouldShowAds = ads.isNotEmpty;
          _adFrequency = 7;
          _loadedAds = ads;
          _shuffledAdPool = _buildShuffledPool(ads);
          _adPoolIndex = 0;
          _lastAdLoadTime = DateTime.now();
          _sessionImpressionRecorded.clear();
          _impressionIds.clear();
        });
        if (ads.isEmpty) {
          debugPrint('⚠️ ADS: admin 0 ads');
        } else {
          debugPrint('🟢 ADS: admin loaded ${ads.length} ads');
        }
      }
      return;
    }

    bool shouldShow = true;
    try {
      shouldShow = await adService.shouldShowAdsForUser(user.id);
      debugPrint('🔵 ADS: shouldShow=$shouldShow');
    } catch (e) {
      debugPrint('⚠️ ADS: subscription check failed ($e) — showing ads');
    }
    if (!shouldShow) {
      if (mounted) setState(() => _shouldShowAds = false);
      debugPrint('⭐ ADS: Pro user — no ads');
      return;
    }

    int frequency = 7;
    try {
      frequency = await adService.getAdFrequencyForUser(user.id);
      debugPrint('🔵 ADS: frequency=$frequency');
    } catch (e) {
      debugPrint('⚠️ ADS: frequency check failed ($e) — default 7');
    }

    final userRegion = await _resolveUserRegion(user);

    List<DirectAd> ads = [];
    try {
      ads = await adService.getEligibleAds(
        userId: user.id,
        screenName: 'property_list',
        userRegion: userRegion,
        limit: 10,
      );
      debugPrint('🟢 ADS: RPC returned ${ads.length} ads');
    } catch (e) {
      debugPrint('🔴 ADS: getEligibleAds RPC failed: $e');
    }

    if (mounted) {
      setState(() {
        _shouldShowAds = ads.isNotEmpty;
        _adFrequency = frequency;
        _loadedAds = ads;
        _shuffledAdPool = _buildShuffledPool(ads);
        _adPoolIndex = 0;
        _lastAdLoadTime = DateTime.now();
        _sessionImpressionRecorded.clear();
        _impressionIds.clear();
      });
      if (ads.isEmpty) {
        debugPrint('🔴 ADS: 0 ads returned');
      } else {
        debugPrint('🟢 ADS: ${ads.length} ads loaded ✅');
      }
    }
  }

  List<DirectAd> _buildShuffledPool(List<DirectAd> ads) {
    if (ads.isEmpty) return [];
    final pool = List<DirectAd>.from(ads);
    pool.shuffle();
    return pool;
  }

  Future<void> _refreshAdsIfStale() async {
    if (!_shouldShowAds) return;
    if (_lastAdLoadTime == null) return;
    final stale = DateTime.now().difference(_lastAdLoadTime!) > _adRefreshInterval;
    if (!stale) return;

    debugPrint('🔄 ADS: pool is stale — refreshing silently');
    await _loadAdsAndCheckEligibility();
  }

  void _onScroll() {
    if (_scrollController.offset > 500 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 500 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(propertyListProvider.notifier).loadMore();
      _refreshAdsIfStale();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleRefresh() async {
    await ref.read(propertyListProvider.notifier).loadProperties(refresh: true);
    await _loadAdsAndCheckEligibility();
  }

  DirectAd? _getAdForPosition(int position) {
    if (_shuffledAdPool.isEmpty) return null;
    final adIndex = position ~/ _adFrequency % _shuffledAdPool.length;
    return _shuffledAdPool[adIndex];
  }

  Future<void> _recordAdImpression(DirectAd ad) async {
    if (_sessionImpressionRecorded.contains(ad.creativeId)) return;
    _sessionImpressionRecorded.add(ad.creativeId);

    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    final adService = ref.read(directAdServiceProvider);

    final impressionId = await adService.recordImpression(
      campaignId: ad.campaignId,
      creativeId: ad.creativeId,
      advertiserId: ad.advertiserId,
      userId: user.id,
      screenName: 'property_list',
      cost: ad.impressionCost,
    );

    if (impressionId != null && mounted) {
      setState(() => _impressionIds[ad.creativeId] = impressionId);
      debugPrint('✅ Impression recorded: ${ad.headline}');
    }
  }

  Future<void> _recordAdClick(DirectAd ad) async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    final impressionId = _impressionIds[ad.creativeId];
    if (impressionId == null) {
      debugPrint('⚠️ No impression ID found for click — recording impression first');
      await _recordAdImpression(ad);
      return;
    }

    final adService = ref.read(directAdServiceProvider);

    final clickId = await adService.recordClick(
      impressionId: impressionId,
      campaignId: ad.campaignId,
      creativeId: ad.creativeId,
      advertiserId: ad.advertiserId,
      userId: user.id,
      cost: ad.bidAmount,
    );

    if (clickId != null) {
      debugPrint('💰 Recorded click for ad: ${ad.headline}');
    }
  }

  void _handlePropertyShare(dynamic property) {
    final shareText = '''
Check out this property! 🏡

${property.title}
📍 ${property.location}
💰 TZS ${property.price.toStringAsFixed(0)}
🏠 ${property.bedrooms} beds • ${property.bathrooms} baths • ${property.area.toInt()} sqft

View full details: https://yourapp.com/property/${property.id}

Shared via Makazi Estate
''';

    Share.share(shareText, subject: property.title);
  }

  @override
  Widget build(BuildContext context) {
    final propertyListState = ref.watch(propertyListProvider);
    final theme = Theme.of(context);
    final appBarForegroundColor = theme.appBarTheme.foregroundColor ?? 
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Properties',
          style: TextStyle(
            color: appBarForegroundColor,
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: appBarForegroundColor),
            tooltip: 'Search Properties',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PropertySearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: appBarForegroundColor),
            tooltip: 'Filter Properties',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PropertyFilterScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: theme.primaryColor,
            child: _buildBody(propertyListState, theme),
          ),
          if (_showScrollToTop)
            Positioned(
              right: 16,
              bottom: 80,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  onTap: _scrollToTop,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(PropertyListState state, ThemeData theme) {
    if (state.isLoading && state.properties.isEmpty) {
      return const LoadingIndicator(message: 'Loading properties...');
    }

    if (state.error != null && state.properties.isEmpty) {
      return CustomErrorWidget(
        message: state.error!,
        onRetry: () {
          ref.read(propertyListProvider.notifier).loadProperties(refresh: true);
        },
      );
    }

    final availableProperties = state.properties
        .where((p) =>
            p.status == PropertyStatus.available ||
            p.status == PropertyStatus.pending)
        .toList();

    if (availableProperties.isEmpty) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: const EmptyState(
              icon: Icons.home_work_outlined,
              title: 'No Properties Found',
              message: 'Pull down to refresh or check back later.',
              actionText: null,
              onActionPressed: null,
            ),
          ),
        ),
      );
    }

    return _buildPropertyList(availableProperties, state, theme);
  }

  Widget _buildPropertyList(
    List<dynamic> properties,
    PropertyListState state,
    ThemeData theme,
  ) {
    // Build interleaved list with ads (same logic as before)
    final itemsWithAds = <dynamic>[];
    int propertyIndex = 0;
    for (var property in properties) {
      itemsWithAds.add(property);
      propertyIndex++;
      if (_shouldShowAds &&
          propertyIndex % _adFrequency == 0 &&
          _shuffledAdPool.isNotEmpty) {
        final ad = _getAdForPosition(itemsWithAds.length);
        if (ad != null) itemsWithAds.add(ad);
      }
    }

    final isMobile = ResponsiveHelper.isMobile(context);
    final hPad = isMobile
        ? ResponsiveHelper.getResponsivePadding(context)
        : ResponsiveHelper.getContentHorizontalPadding(context);

    // ── Mobile: single-column ListView with PropertyListCard ──────────────
    if (isMobile) {
      return ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(hPad),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemsWithAds.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == itemsWithAds.length) return _buildLoadingIndicator(theme);
          final item = itemsWithAds[index];
          if (item is DirectAd) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DirectAdWidget(
                ad: item,
                onImpression: () {
                  if (!_sessionImpressionRecorded.contains(item.creativeId)) {
                    _recordAdImpression(item);
                    _sessionImpressionRecorded.add(item.creativeId);
                  }
                },
                onClick: () => _recordAdClick(item),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PropertyListCard(
              property: item,
              onTap: () => _navigateToDetail(item),
              onShare: () => _handlePropertyShare(item),
            ),
          );
        },
      );
    }

    // ── Tablet / Desktop: multi-column grid, ads remain full-width ────────
    final cols = ResponsiveHelper.getPropertyGridColumns(context);
    final displayRows = _buildGridRows(itemsWithAds, cols);
    const spacing = 16.0;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: displayRows.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayRows.length) return _buildLoadingIndicator(theme);
        final rowItem = displayRows[index];

        // Full-width ad card
        if (rowItem is DirectAd) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DirectAdWidget(
              ad: rowItem,
              onImpression: () {
                if (!_sessionImpressionRecorded.contains(rowItem.creativeId)) {
                  _recordAdImpression(rowItem);
                  _sessionImpressionRecorded.add(rowItem.creativeId);
                }
              },
              onClick: () => _recordAdClick(rowItem),
            ),
          );
        }

        // Row of property grid cards
        final row = rowItem as List<dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: spacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < cols; i++) ...[
                if (i > 0) const SizedBox(width: spacing),
                Expanded(
                  child: i < row.length
                      ? PropertyGridCard(
                          property: row[i],
                          onTap: () => _navigateToDetail(row[i]),
                        )
                      : const SizedBox(), // empty filler for last incomplete row
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Groups a flat [itemsWithAds] list into display rows:
  /// - [DirectAd] → full-width row on its own
  /// - properties → grouped into rows of [cols] items
  List<dynamic> _buildGridRows(List<dynamic> itemsWithAds, int cols) {
    final result = <dynamic>[];
    List<dynamic> currentRow = [];
    for (final item in itemsWithAds) {
      if (item is DirectAd) {
        if (currentRow.isNotEmpty) {
          result.add(List<dynamic>.from(currentRow));
          currentRow = [];
        }
        result.add(item);
      } else {
        currentRow.add(item);
        if (currentRow.length == cols) {
          result.add(List<dynamic>.from(currentRow));
          currentRow = [];
        }
      }
    }
    if (currentRow.isNotEmpty) result.add(List<dynamic>.from(currentRow));
    return result;
  }

  Future<void> _navigateToDetail(dynamic property) async {
    _propertyViewCount++;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailScreen(propertyId: property.id),
      ),
    );
    if (mounted) {
      ref.read(propertyListProvider.notifier).loadProperties(refresh: true);
    }
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.primaryColor,
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Text(
              'Loading more...',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isAdPosition(int index) {
    return (index + 1) % _adFrequency == 0;
  }

  int _getPropertyIndex(int listIndex) {
    if (!_shouldShowAds) return listIndex;
    final adsBefore = (listIndex + 1) ~/ _adFrequency;
    return listIndex - adsBefore;
  }

  int _calculateTotalItemsWithAds(int propertyCount) {
    if (!_shouldShowAds || _adFrequency <= 1) return propertyCount;
    final adCount = propertyCount ~/ (_adFrequency - 1);
    return propertyCount + adCount;
  }
}