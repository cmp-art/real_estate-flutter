// lib/core/services/subscription_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../features/subscriptions/data/models/subscription_model.dart';

/// Service for managing user subscriptions and usage tracking
class SubscriptionService {
  final SupabaseClient _supabase;
  static const String _tag = 'SubscriptionService';

  SubscriptionService(this._supabase);

  // ===========================================================================
  // SUBSCRIPTION MANAGEMENT
  // ===========================================================================

  /// Get user's current active subscription
  Future<UserSubscription?> getUserSubscription(String userId) async {
    try {
      logger.d('[$_tag] Fetching subscription for user: $userId');
      
      // FIXED: Use correct query format with foreign key relationship
      final response = await _supabase
          .from('user_subscriptions')
          .select('*, subscription_tiers(*)')  // Join with subscription_tiers table
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) {
        logger.d('[$_tag] No active subscription found for user: $userId');
        return null;
      }
      
      final subscription = UserSubscription.fromJson(response);
      logger.d('[$_tag] Found subscription: ${subscription.tier.name}');
      return subscription;
    } catch (e, stack) {
      logger.e('[$_tag] Error fetching subscription', 
        error: e, stackTrace: stack);
      return null;
    }
  }

  /// Create new subscription for user
  Future<UserSubscription?> createSubscription({
    required String userId,
    required SubscriptionTier tier,
    required String paymentProviderId,
    Duration duration = const Duration(days: 30),
  }) async {
    try {
      logger.d('[$_tag] Creating subscription for user: $userId, tier: ${tier.name}');
      
      // First, verify user exists and is authenticated
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        logger.e('[$_tag] User not authenticated or ID mismatch');
        throw Exception('User authentication required');
      }
      
      // Get tier ID from subscription_tiers table
      logger.d('[$_tag] Fetching tier ID for: ${tier.name}');
      final tierResponse = await _supabase
          .from('subscription_tiers')
          .select('id')
          .eq('name', tier.name)
          .single();

      final tierId = tierResponse['id'] as String;
      logger.d('[$_tag] Tier ID found: $tierId');
      
      final now = DateTime.now();
      final expiresAt = now.add(duration);

      // Prepare subscription data
      final subscriptionData = {
        'user_id': userId,
        'tier_id': tierId,  // Use tier_id instead of tier name
        'status': 'active',
        'started_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'auto_renew': true,
        'payment_provider_id': paymentProviderId,
      };
      
      logger.d('[$_tag] Inserting subscription data: $subscriptionData');

      // Create subscription with proper error handling
      try {
        final response = await _supabase
            .from('user_subscriptions')
            .insert(subscriptionData)
            .select('*, subscription_tiers(*)')  // Join to get tier data
            .single();

        final subscription = UserSubscription.fromJson(response);
        logger.d('[$_tag] ✅ Subscription created successfully: ${subscription.id}');
        return subscription;
        
      } catch (insertError) {
        // Check if it's an RLS error
        if (insertError.toString().contains('row-level security') || 
            insertError.toString().contains('42501')) {
          logger.e('[$_tag] ❌ RLS Policy Error - User does not have permission to insert subscription');
          logger.e('[$_tag] This means the RLS policies are not properly configured in Supabase');
          logger.e('[$_tag] Please run the complete_subscription_schema.sql script in your Supabase SQL Editor');
          throw Exception('Permission denied: Please contact support to enable subscription features');
        }
        rethrow;
      }
      
    } catch (e, stack) {
      logger.e('[$_tag] Error creating subscription', 
        error: e, stackTrace: stack);
      
      // Provide user-friendly error messages
      if (e.toString().contains('Permission denied')) {
        return null; // Already handled above
      } else if (e.toString().contains('authentication')) {
        logger.e('[$_tag] Authentication error');
      } else if (e is PostgrestException) {
        logger.e('[$_tag] Database error: ${e.message}');
      }
      
      return null;
    }
  }

  /// Update subscription tier
  Future<UserSubscription?> updateSubscription({
    required String userId,
    required SubscriptionTier newTier,
    required String paymentProviderId,
  }) async {
    try {
      logger.d('[$_tag] Updating subscription for user: $userId to tier: ${newTier.name}');
      
      final currentSub = await getUserSubscription(userId);
      
      // If no active subscription, create new one
      if (currentSub == null) {
        logger.d('[$_tag] No active subscription found, creating new one');
        return await createSubscription(
          userId: userId,
          tier: newTier,
          paymentProviderId: paymentProviderId,
        );
      }

      // Get new tier ID
      final tierResponse = await _supabase
          .from('subscription_tiers')
          .select('id')
          .eq('name', newTier.name)
          .single();

      final tierId = tierResponse['id'] as String;

      // Update subscription
      final response = await _supabase
          .from('user_subscriptions')
          .update({
            'tier_id': tierId,
            'payment_provider_id': paymentProviderId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentSub.id)
          .select('*, subscription_tiers(*)')
          .single();

      final subscription = UserSubscription.fromJson(response);
      logger.d('[$_tag] ✅ Subscription updated successfully');
      return subscription;
    } catch (e, stack) {
      logger.e('[$_tag] Error updating subscription', 
        error: e, stackTrace: stack);
      return null;
    }
  }

  /// Cancel active subscription
  Future<bool> cancelSubscription(String userId) async {
    try {
      logger.d('[$_tag] Canceling subscription for user: $userId');
      
      await _supabase
          .from('user_subscriptions')
          .update({
            'status': 'cancelled',
            'auto_renew': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('status', 'active');

      logger.d('[$_tag] ✅ Subscription cancelled');
      return true;
    } catch (e, stack) {
      logger.e('[$_tag] Error canceling subscription', 
        error: e, stackTrace: stack);
      return false;
    }
  }

  /// Renew subscription
  Future<UserSubscription?> renewSubscription({
    required String userId,
    required String paymentProviderId,
    Duration duration = const Duration(days: 30),
  }) async {
    try {
      logger.d('[$_tag] Renewing subscription for user: $userId');
      
      final currentSub = await getUserSubscription(userId);
      if (currentSub == null) {
        logger.w('[$_tag] No subscription to renew');
        return null;
      }

      final now = DateTime.now();
      final expiresAt = now.add(duration);

      final response = await _supabase
          .from('user_subscriptions')
          .update({
            'status': 'active',
            'expires_at': expiresAt.toIso8601String(),
            'payment_provider_id': paymentProviderId,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', currentSub.id)
          .select('*, subscription_tiers(*)')
          .single();

      final subscription = UserSubscription.fromJson(response);
      logger.d('[$_tag] ✅ Subscription renewed');
      return subscription;
    } catch (e, stack) {
      logger.e('[$_tag] Error renewing subscription', 
        error: e, stackTrace: stack);
      return null;
    }
  }

  /// Check if subscription has expired
  Future<bool> hasSubscriptionExpired(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return true;
      return subscription.expiresAt.isBefore(DateTime.now());
    } catch (e, stack) {
      logger.e('[$_tag] Error checking expiration', 
        error: e, stackTrace: stack);
      return true;
    }
  }

  /// Get subscription statistics
  Future<SubscriptionStats> getSubscriptionStats(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);

      if (subscription == null) {
        return SubscriptionStats(
          tier: SubscriptionTier.free,
          daysRemaining: 0,
          isActive: false,
        );
      }

      final daysRemaining = subscription.expiresAt
          .difference(DateTime.now())
          .inDays
          .clamp(0, 365);

      return SubscriptionStats(
        tier: subscription.tier,
        daysRemaining: daysRemaining,
        isActive: subscription.status == 'active',
        startedAt: subscription.startedAt,
        expiresAt: subscription.expiresAt,
        autoRenew: subscription.autoRenew,
      );
    } catch (e, stack) {
      logger.e('[$_tag] Error fetching stats', 
        error: e, stackTrace: stack);
      return SubscriptionStats(
        tier: SubscriptionTier.free,
        daysRemaining: 0,
        isActive: false,
      );
    }
  }

  /// Get all available subscription tiers
  Future<List<SubscriptionTierInfo>> getAvailableTiers() async {
    try {
      logger.d('[$_tag] Fetching available tiers');
      
      final response = await _supabase
          .from('subscription_tiers')
          .select('*')
          .eq('is_active', true)
          .order('price');

      final tiers = (response as List)
          .map((json) => SubscriptionTierInfo.fromJson(json))
          .toList();
          
      logger.d('[$_tag] Found ${tiers.length} tiers');
      return tiers;
    } catch (e, stack) {
      logger.e('[$_tag] Error fetching tiers', 
        error: e, stackTrace: stack);
      return [];
    }
  }

  /// Stream subscription changes
  Stream<UserSubscription?> subscriptionStream(String userId) {
    return _supabase
        .from('user_subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          if (data.isEmpty) return null;
          return UserSubscription.fromJson(data.first);
        });
  }

  // ===========================================================================
  // USAGE TRACKING - USING DATABASE FUNCTIONS (RECOMMENDED)
  // ===========================================================================

  /// Increment usage count for a feature (uses RPC function)
  Future<void> incrementUsage({
    required String userId,
    required String featureName,
  }) async {
    try {
      await _supabase.rpc('increment_usage', params: {
        'p_user_id': userId,
        'p_feature_name': featureName,
      });
      
      logger.d('[$_tag] ✅ Usage incremented: $featureName');
    } catch (e, stack) {
      logger.e('[$_tag] Error incrementing usage', 
        error: e, stackTrace: stack);
      // Fallback to direct table access
      logger.d('[$_tag] Trying direct table access...');
      await incrementUsageDirect(userId: userId, featureName: featureName);
    }
  }

  /// Increment monthly usage for a feature (e.g. create_listing for free tier).
  /// Sums all usage_tracking rows for this feature in the current calendar month.
  Future<void> incrementMonthlyUsage({
    required String userId,
    required String featureName,
  }) async {
    // The increment_usage RPC already uses date = TODAY, so we just call it
    // with the monthly feature key. Summation for the month is done in
    // getMonthlyUsage below.
    await incrementUsage(userId: userId, featureName: featureName);
  }

  /// Get current usage for a feature (uses RPC function)
  Future<int> getCurrentUsage({
    required String userId,
    required String featureName,
  }) async {
    try {
      final result = await _supabase.rpc('get_current_usage', params: {
        'p_user_id': userId,
        'p_feature_name': featureName,
      }) as int;
      
      return result;
    } catch (e, stack) {
      logger.e('[$_tag] Error fetching current usage', 
        error: e, stackTrace: stack);
      return await getDailyUsageDirect(userId: userId, featureName: featureName);
    }
  }

  /// Get total usage for the current calendar month for a given feature key.
  /// Used for free-tier 'create_listing' (10 total limit).
  Future<int> getMonthlyUsage({
    required String userId,
    required String featureName,
  }) async {
    try {
      final now = DateTime.now();
      final firstOfMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('usage_tracking')
          .select('usage_count')
          .eq('user_id', userId)
          .eq('feature_name', featureName)
          .gte('date', firstOfMonth)
          .lte('date', today);

      final rows = response as List;
      final total = rows.fold<int>(
        0,
        (sum, row) => sum + ((row['usage_count'] as int?) ?? 0),
      );
      logger.d('[$_tag] Monthly usage for $featureName: $total');
      return total;
    } catch (e, stack) {
      logger.e('[$_tag] Error fetching monthly usage',
          error: e, stackTrace: stack);
      return 0;
    }
  }

  /// Get usage history for a date range
  Future<Map<DateTime, int>> getUsageHistory({
    required String userId,
    required String featureName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase.rpc('get_usage_history', params: {
        'p_user_id': userId,
        'p_feature_name': featureName,
        'p_start_date': startDate.toIso8601String().split('T')[0],
        'p_end_date': endDate.toIso8601String().split('T')[0],
      }) as List;

      final result = <DateTime, int>{};
      var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final endDateTime = DateTime(endDate.year, endDate.month, endDate.day);
      
      while (!currentDate.isAfter(endDateTime)) {
        final date = currentDate;
        final dateKey = DateTime(date.year, date.month, date.day);
        result[dateKey] = 0;
        currentDate = currentDate.add(const Duration(days: 1));
      }

      for (final item in response) {
        final dateStr = item['date'] as String;
        final dateParts = dateStr.split('-');
        if (dateParts.length == 3) {
          final date = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );
          result[date] = item['usage_count'] as int;
        }
      }

      return result;
    } catch (e, stack) {
      logger.e('[$_tag] Error fetching usage history', 
        error: e, stackTrace: stack);
      return {};
    }
  }

  // ===========================================================================
  // USAGE TRACKING - DIRECT TABLE ACCESS (FALLBACK)
  // ===========================================================================

  Future<void> incrementUsageDirect({
    required String userId,
    required String featureName,
  }) async {
    try {
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final now = DateTime.now().toIso8601String();

      final existing = await _supabase
          .from('usage_tracking')
          .select('usage_count')
          .eq('user_id', userId)
          .eq('feature_name', featureName)
          .eq('date', dateString)
          .maybeSingle();

      if (existing != null) {
        final newCount = (existing['usage_count'] as int) + 1;
        await _supabase
            .from('usage_tracking')
            .update({
              'usage_count': newCount,
              'updated_at': now,
              'last_used_at': now,
            })
            .eq('user_id', userId)
            .eq('feature_name', featureName)
            .eq('date', dateString);
      } else {
        await _supabase.from('usage_tracking').insert({
          'user_id': userId,
          'feature_name': featureName,
          'date': dateString,
          'usage_count': 1,
          'created_at': now,
          'updated_at': now,
          'last_used_at': now,
        });
      }
      
      logger.d('[$_tag] ✅ Usage incremented (direct): $featureName');
    } catch (e, stack) {
      logger.e('[$_tag] Error incrementing usage direct', 
        error: e, stackTrace: stack);
    }
  }

  Future<int> getDailyUsageDirect({
    required String userId,
    required String featureName,
  }) async {
    try {
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('usage_tracking')
          .select('usage_count')
          .eq('user_id', userId)
          .eq('feature_name', featureName)
          .eq('date', dateString)
          .maybeSingle();

      return response?['usage_count'] as int? ?? 0;
    } catch (e, stack) {
      logger.e('[$_tag] Error fetching daily usage direct', 
        error: e, stackTrace: stack);
      return 0;
    }
  }

  Future<bool> hasReachedQuota({
    required String userId,
    required String featureName,
    required int quotaLimit,
  }) async {
    try {
      final currentUsage = await getCurrentUsage(
        userId: userId,
        featureName: featureName,
      );
      
      return currentUsage >= quotaLimit;
    } catch (e, stack) {
      logger.e('[$_tag] Error checking quota', 
        error: e, stackTrace: stack);
      return false;
    }
  }

  Future<int> getRemainingQuota({
    required String userId,
    required String featureName,
    required int quotaLimit,
  }) async {
    try {
      final currentUsage = await getCurrentUsage(
        userId: userId,
        featureName: featureName,
      );
      
      return (quotaLimit - currentUsage).clamp(0, quotaLimit);
    } catch (e, stack) {
      logger.e('[$_tag] Error getting remaining quota', 
        error: e, stackTrace: stack);
      return quotaLimit;
    }
  }
}

// Subscription statistics, usage record, and quota info classes remain the same
class SubscriptionStats {
  final SubscriptionTier tier;
  final int daysRemaining;
  final bool isActive;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final bool? autoRenew;

  SubscriptionStats({
    required this.tier,
    required this.daysRemaining,
    required this.isActive,
    this.startedAt,
    this.expiresAt,
    this.autoRenew,
  });

  bool get isExpiringSoon => daysRemaining <= 7 && daysRemaining > 0;
  bool get hasExpired => daysRemaining <= 0;
  bool get isPro => tier == SubscriptionTier.pro;
  bool get isPremium => tier == SubscriptionTier.pro;
  bool get isFree => tier == SubscriptionTier.free;

  double get progress {
    if (startedAt == null || expiresAt == null) return 0;
    final total = expiresAt!.difference(startedAt!).inDays;
    final remaining = expiresAt!.difference(DateTime.now()).inDays;
    if (total <= 0) return 0;
    return (total - remaining) / total;
  }

  String get formattedRemaining {
    if (hasExpired) return 'Expired';
    if (daysRemaining == 0) return 'Today';
    if (daysRemaining == 1) return '1 day';
    return '$daysRemaining days';
  }
}

class UsageRecord {
  final DateTime date;
  final int count;
  final String featureName;

  UsageRecord({
    required this.date,
    required this.count,
    required this.featureName,
  });

  factory UsageRecord.fromJson(Map<String, dynamic> json) {
    return UsageRecord(
      date: DateTime.parse(json['date'] as String),
      count: json['usage_count'] as int,
      featureName: json['feature_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'usage_count': count,
      'feature_name': featureName,
    };
  }
}

class QuotaInfo {
  final String featureName;
  final int limit;
  final int current;
  final int remaining;
  final bool isUnlimited;

  QuotaInfo({
    required this.featureName,
    required this.limit,
    required this.current,
    required this.remaining,
    this.isUnlimited = false,
  });

  bool get hasReached => remaining <= 0;
  double get percentage => current / limit;
  String get formatted => '$current / $limit';
}