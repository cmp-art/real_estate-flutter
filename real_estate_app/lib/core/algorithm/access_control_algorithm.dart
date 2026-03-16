// lib/core/algorithm/access_control_algorithm.dart
import '../../core/utils/logger.dart';
import '../services/subscription_service.dart';
import '../../features/subscriptions/data/models/subscription_model.dart';

/// Central algorithm for managing feature access based on subscription tiers
class AccessControlAlgorithm {
  final SubscriptionService _subscriptionService;
  static const String _tag = 'AccessControl';

  AccessControlAlgorithm(this._subscriptionService);

  /// Check if user can access a specific feature
  Future<FeatureAccessResult> canAccessFeature({
    required String userId,
    required String featureName,
    Map<String, dynamic>? additionalContext,
  }) async {
    try {
      final subscription = await _subscriptionService.getUserSubscription(userId);
      final currentTier = subscription?.tier ?? SubscriptionTier.free;

      final tierFeatures = _getTierFeatures(currentTier);
      if (!tierFeatures.containsKey(featureName)) {
        return FeatureAccessResult(
          canAccess: false,
          reason: 'Feature not available in your plan',
          requiresUpgrade: true,
          suggestedTier: _getSuggestedUpgradeTier(currentTier),
        );
      }

      return await _checkQuotaLimit(
        userId: userId,
        featureName: featureName,
        currentTier: currentTier,
        additionalContext: additionalContext,
      );
    } catch (e, stack) {
      logger.e('Error checking feature access', error: e, stackTrace: stack);
      return FeatureAccessResult(
        canAccess: false,
        reason: 'Error validating access',
        requiresUpgrade: false,
      );
    }
  }

  /// Check quota limits with proper daily/monthly reset.
  /// For 'create_listing':
  ///   - Free tier  → daily key 'create_listing'        (limit: 1 per day)
  ///   - Basic tier → monthly key 'create_listing_monthly' (limit: 10 per month)
  ///   - Pro tier   → unlimited
  Future<FeatureAccessResult> _checkQuotaLimit({
    required String userId,
    required String featureName,
    required SubscriptionTier currentTier,
    Map<String, dynamic>? additionalContext,
  }) async {
    final limits = _getTierLimits(currentTier);

    // create_listing is now enforced via check_property_creation_allowed RPC.
    // This fallback path uses total (non-daily) usage for free tier.
    final String trackingKey = featureName;
    final limit = limits[trackingKey];

    if (limit == null || limit == -1) {
      return FeatureAccessResult(canAccess: true);
    }

    final currentUsage = await _subscriptionService.getMonthlyUsage(
      userId: userId,
      featureName: trackingKey,
    );

    if (currentUsage >= limit) {
      return FeatureAccessResult(
        canAccess: false,
        reason: 'Limit reached ($currentUsage/$limit). Upgrade to Pro for unlimited access.',
        requiresUpgrade: true,
        suggestedTier: _getSuggestedUpgradeTier(currentTier),
        currentUsage: currentUsage,
        maxUsage: limit,
      );
    }

    return FeatureAccessResult(
      canAccess: true,
      currentUsage: currentUsage,
      maxUsage: limit,
    );
  }

  /// Get features available for each tier
  Map<String, bool> _getTierFeatures(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return {
          'browse_properties': true,
          'basic_search': true,
          'create_listing': true,
          'save_favorites': true,
          'send_messages': true,
          'view_ads': true,
        };
      case SubscriptionTier.pro:
        return {
          'browse_properties': true,
          'basic_search': true,
          'advanced_search': true,
          'create_listing': true,
          'save_favorites': true,
          'send_messages': true,
          'analytics_dashboard': true,
          'advanced_analytics': true,
          'priority_listing': true,
          'featured_badge': true,
          'priority_support': true,
          'no_ads': true,
          'unlimited_everything': true,
        };
    }
  }

  /// Get quota limits for each tier.
  /// -1 = unlimited. create_listing for free = 10 total (image only, enforced via RPC).
  Map<String, int> _getTierLimits(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return {
          'browse_properties': -1,
          'create_listing': 10, // 10 image-only listings total (video blocked by RPC)
          'save_favorites': 5,
          'send_messages': 20,
        };
      case SubscriptionTier.pro:
        return {
          'browse_properties': -1,
          'create_listing': -1,
          'save_favorites': -1,
          'send_messages': -1,
        };
    }
  }

  /// Suggest upgrade tier based on current tier
  SubscriptionTier _getSuggestedUpgradeTier(SubscriptionTier currentTier) {
    switch (currentTier) {
      case SubscriptionTier.free:
        return SubscriptionTier.pro;
      case SubscriptionTier.pro:
        return SubscriptionTier.pro;
    }
  }

  /// Validate if user can perform bulk operation
  Future<BulkOperationResult> canPerformBulkOperation({
    required String userId,
    required String operationType,
    required int itemCount,
  }) async {
    final subscription = await _subscriptionService.getUserSubscription(userId);
    final currentTier = subscription?.tier ?? SubscriptionTier.free;

    final limits = _getTierLimits(currentTier);
    final featureLimit = limits[operationType];

    if (featureLimit == null || featureLimit == -1) {
      return BulkOperationResult(
        canProceed: true,
        allowedCount: itemCount,
        deniedCount: 0,
      );
    }

    final currentUsage = await _subscriptionService.getMonthlyUsage(
      userId: userId,
      featureName: operationType,
    );

    final availableQuota = featureLimit - currentUsage;

    if (availableQuota <= 0) {
      return BulkOperationResult(
        canProceed: false,
        allowedCount: 0,
        deniedCount: itemCount,
        reason: 'Quota limit reached',
      );
    }

    if (availableQuota >= itemCount) {
      return BulkOperationResult(
        canProceed: true,
        allowedCount: itemCount,
        deniedCount: 0,
      );
    }

    return BulkOperationResult(
      canProceed: true,
      allowedCount: availableQuota,
      deniedCount: itemCount - availableQuota,
      reason: 'Partial quota available',
    );
  }
}

/// Result of feature access check
class FeatureAccessResult {
  final bool canAccess;
  final String? reason;
  final bool requiresUpgrade;
  final SubscriptionTier? suggestedTier;
  final int? currentUsage;
  final int? maxUsage;

  FeatureAccessResult({
    required this.canAccess,
    this.reason,
    this.requiresUpgrade = false,
    this.suggestedTier,
    this.currentUsage,
    this.maxUsage,
  });

  double get usagePercentage {
    if (currentUsage == null || maxUsage == null || maxUsage == -1) {
      return 0.0;
    }
    return (currentUsage! / maxUsage!) * 100;
  }

  bool get isNearLimit => usagePercentage >= 80.0;
}

/// Result of bulk operation validation
class BulkOperationResult {
  final bool canProceed;
  final int allowedCount;
  final int deniedCount;
  final String? reason;

  BulkOperationResult({
    required this.canProceed,
    required this.allowedCount,
    required this.deniedCount,
    this.reason,
  });
}