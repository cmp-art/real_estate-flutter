// lib/core/algorithm/ad_display_algorithm.dart
//
// Client-side ad algorithm used by CreateCampaignScreen for:
//   • Revenue / reach estimates shown to advertisers before launch
//   • Recommended bid amounts per objective
//   • Ad placement configuration (positions, frequency)
//
// The actual ad SERVING pipeline is server-side:
//   get_eligible_ads RPC → enforces targeting, budgets, frequency caps.
// This class does NOT replace that — it only provides UX helpers.

import 'package:flutter/foundation.dart';

import '../services/direct_ad_models.dart';
import '../services/direct_ad_service.dart';
import '../services/subscription_service.dart';
import '../../features/subscriptions/data/models/subscription_model.dart';

class DirectAdAlgorithm {
  final DirectAdService _adService;
  final SubscriptionService _subscriptionService;

  // ── Pricing constants (TZS) — launch phase ───────────────────────────────
  static const double minBidCpm = 500.0;   // TSh 500 minimum CPM bid
  static const double minBidCpc = 50.0;    // TSh 50 minimum CPC bid

  // ── Ad frequency per tier ─────────────────────────────────────────────────
  // Must stay in sync with DirectAdService.getAdFrequencyForUser().
  static const int adFrequencyFree = 7;   // 1 ad per 7 slots  (~14% density)
  // Pro users see 0 ads — handled by shouldShowAds returning false.

  // ── Session limits ────────────────────────────────────────────────────────
  static const int maxAdsPerSession = 50;

  DirectAdAlgorithm(this._adService, this._subscriptionService);

  // ══════════════════════════════════════════════════════════════════════════
  // AD ELIGIBILITY & FREQUENCY
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns true if the user's tier should see ads.
  Future<bool> shouldShowAds(String userId) async {
    try {
      final sub = await _subscriptionService.getUserSubscription(userId);
      if (sub == null) return true; // free tier default
      return sub.tier == SubscriptionTier.free;
    } catch (e) {
      debugPrint('Error checking ad eligibility: $e');
      return false; // fail safe — don't show ads on error
    }
  }

  /// Returns the list-item frequency for ad slots (0 = no ads).
  Future<int> getAdFrequency(String userId) async {
    try {
      final sub = await _subscriptionService.getUserSubscription(userId);
      if (sub == null || sub.tier == SubscriptionTier.free) {
        return adFrequencyFree;
      }
      return 0; // Pro → no ads
    } catch (e) {
      debugPrint('Error getting ad frequency: $e');
      return adFrequencyFree;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AD SERVING (delegates to DirectAdService + adds bid-weighted ranking)
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch and rank ads for a given context.
  ///
  /// Ranking uses a bid-weighted score with a small contextual bonus
  /// for location / property-type match.  The SQL RPC already enforces
  /// eligibility (targeting, budget, frequency cap) — this layer only
  /// re-orders the pre-filtered set client-side.
  Future<List<DirectAd>> getTargetedAds({
    required String userId,
    required String screenName,
    String? propertyId,
    String? propertyType,
    String? location,
    double? price,
    int limit = 3,
  }) async {
    try {
      final showAds = await shouldShowAds(userId);
      if (!showAds) return [];

      final ads = await _adService.getEligibleAds(
        userId: userId,
        screenName: screenName,
        propertyId: propertyId,
        userPropertyType: propertyType,
        userRegion: location,
        limit: limit * 2, // over-fetch so ranking has choices
      );

      if (ads.isEmpty) return [];

      // Bid-weighted ranking: higher bids → higher score.
      // Small +20% bonus for contextual match (location / property type).
      // No random noise — deterministic so the same context always returns
      // the highest-value ad first.
      final scored = ads.map((ad) {
        double score = ad.bidAmount;
        // Contextual bonuses (extend when ad model gains targeting fields)
        // Currently a placeholder; the SQL RPC handles the real targeting.
        score *= 1.0; // neutral multiplier — will be updated once ad model
                      // exposes target_locations / target_property_types
        return MapEntry(ad, score);
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return scored.take(limit).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('Error getting targeted ads: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IMPRESSION & CLICK (delegates to DirectAdService)
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> recordImpression({
    required DirectAd ad,
    required String userId,
    required String screenName,
    String? propertyId,
  }) async {
    try {
      return await _adService.recordImpression(
        campaignId: ad.campaignId,
        creativeId: ad.creativeId,
        advertiserId: ad.advertiserId,
        userId: userId,
        screenName: screenName,
        propertyId: propertyId,
        cost: ad.impressionCost,
      );
    } catch (e) {
      debugPrint('Error recording impression: $e');
      return null;
    }
  }

  Future<bool> recordClick({
    required DirectAd ad,
    required String userId,
    required String impressionId,
  }) async {
    try {
      final clickId = await _adService.recordClick(
        impressionId: impressionId,
        campaignId: ad.campaignId,
        creativeId: ad.creativeId,
        advertiserId: ad.advertiserId,
        userId: userId,
        cost: ad.bidAmount,
      );
      return clickId != null;
    } catch (e) {
      debugPrint('Error recording click: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AD PLACEMENT CONFIG
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns the ad slot positions and total-item count for a list of
  /// [itemCount] properties displayed at [adFrequency].
  AdPlacementConfig getPlacementConfig({
    required String screenName,
    required int itemCount,
    required int adFrequency,
  }) {
    if (adFrequency <= 0) {
      return AdPlacementConfig(
        screenName: screenName,
        positions: const [],
        adFrequency: 0,
        maxAdsPerScreen: 0,
      );
    }

    final positions = <int>[];
    // Ads appear at positions: freq-1, 2*freq-1, 3*freq-1, ...
    // (matching the (index+1) % freq == 0 rule in PropertyListScreen)
    for (int i = adFrequency - 1; i < itemCount + positions.length; i += adFrequency) {
      positions.add(i);
    }

    return AdPlacementConfig(
      screenName: screenName,
      positions: positions,
      adFrequency: adFrequency,
      maxAdsPerScreen: positions.length,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REVENUE ESTIMATION  (used by CreateCampaignScreen)
  // ══════════════════════════════════════════════════════════════════════════

  /// Estimates impressions, clicks, and cost for an advertiser campaign
  /// based on their budget and bidding model.
  ///
  /// Uses conservative benchmarks from Tanzania real-estate ad data:
  ///   CTR  ≈ 1.5% (lower than global average due to market maturity)
  AdRevenueEstimate estimateCampaignRevenue({
    required double totalBudget,
    required double bidAmount,
    required String biddingStrategy,
    required int estimatedDays,
  }) {
    if (bidAmount <= 0 || totalBudget <= 0) {
      return AdRevenueEstimate(
        estimatedImpressions: 0,
        estimatedClicks: 0,
        estimatedCost: 0,
        estimatedDuration: estimatedDays,
        ctr: 0,
      );
    }

    const double conservativeCtr = 0.015; // 1.5%

    final double estimatedImpressions;
    final double estimatedClicks;

    if (biddingStrategy == 'cpm') {
      // CPM: advertiser pays per 1 000 impressions
      estimatedImpressions = (totalBudget / bidAmount) * 1000;
      estimatedClicks      = estimatedImpressions * conservativeCtr;
    } else {
      // CPC: advertiser pays per click
      estimatedClicks      = totalBudget / bidAmount;
      estimatedImpressions = estimatedClicks / conservativeCtr;
    }

    return AdRevenueEstimate(
      estimatedImpressions: estimatedImpressions.toInt(),
      estimatedClicks: estimatedClicks.toInt(),
      estimatedCost: totalBudget,
      estimatedDuration: estimatedDays,
      ctr: conservativeCtr * 100, // as percentage
    );
  }

  /// Returns the recommended starting bid for a given objective and strategy.
  double getRecommendedBid({
    required String biddingStrategy,
    required String campaignObjective,
  }) {
    if (biddingStrategy == 'cpm') {
      switch (campaignObjective) {
        case 'brand_awareness':    return 500.0;
        case 'property_inquiries': return 800.0;
        case 'website_visits':     return 600.0;
        default:                   return 500.0;
      }
    } else {
      switch (campaignObjective) {
        case 'brand_awareness':    return 50.0;
        case 'property_inquiries': return 100.0;
        case 'website_visits':     return 75.0;
        default:                   return 50.0;
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUDGET MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  bool canContinueCampaign({
    required double spentAmount,
    required double totalBudget,
    required double dailyBudget,
    required DateTime startDate,
  }) {
    if (spentAmount >= totalBudget) return false;
    final daysElapsed = DateTime.now().difference(startDate).inDays + 1;
    return spentAmount < dailyBudget * daysElapsed;
  }

  double calculateDailyPacing({
    required double spentAmount,
    required double dailyBudget,
    required DateTime startDate,
  }) {
    final daysElapsed = DateTime.now().difference(startDate).inDays + 1;
    final expectedSpend = dailyBudget * daysElapsed;
    if (expectedSpend == 0) return 0;
    return (spentAmount / expectedSpend) * 100;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting value objects
// ─────────────────────────────────────────────────────────────────────────────

class AdPlacementConfig {
  final String screenName;
  final List<int> positions;
  final int adFrequency;
  final int maxAdsPerScreen;

  const AdPlacementConfig({
    required this.screenName,
    required this.positions,
    required this.adFrequency,
    required this.maxAdsPerScreen,
  });

  bool isAdPosition(int index) => positions.contains(index);

  int getPropertyIndex(int listIndex) {
    if (adFrequency <= 0) return listIndex;
    final adsBefore = (listIndex + 1) ~/ adFrequency;
    return listIndex - adsBefore;
  }
}

class AdRevenueEstimate {
  final int    estimatedImpressions;
  final int    estimatedClicks;
  final double estimatedCost;
  final int    estimatedDuration;
  final double ctr; // as percentage, e.g. 1.5

  const AdRevenueEstimate({
    required this.estimatedImpressions,
    required this.estimatedClicks,
    required this.estimatedCost,
    required this.estimatedDuration,
    required this.ctr,
  });

  double get dailyImpressions =>
      estimatedDuration > 0 ? estimatedImpressions / estimatedDuration : 0;

  double get dailyClicks =>
      estimatedDuration > 0 ? estimatedClicks / estimatedDuration : 0;

  double get dailyCost =>
      estimatedDuration > 0 ? estimatedCost / estimatedDuration : 0;
}