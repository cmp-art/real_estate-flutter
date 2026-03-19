// lib/core/services/direct_ad_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'direct_ad_models.dart';
import 'subscription_service.dart';
import '../../features/subscriptions/data/models/subscription_model.dart';

/// Result of a soft-delete operation
class AdDeleteResult {
  final bool success;
  final String message;
  final String? error;

  const AdDeleteResult({
    required this.success,
    required this.message,
    this.error,
  });

  factory AdDeleteResult.fromJson(Map<String, dynamic> json) {
    return AdDeleteResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      error: json['error'] as String?,
    );
  }
}

/// Ad in-app notification (approval, rejection, payment confirmed)
class AdNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  AdNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AdNotification.fromJson(Map<String, dynamic> json) {
    return AdNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  void operator [](String other) {}
}

/// Holds the parameters for a single queued impression.
class _QueuedImpression {
  final String campaignId;
  final String creativeId;
  final String advertiserId;
  final String userId;
  final String screenName;
  final String? propertyId;
  final double cost;

  const _QueuedImpression({
    required this.campaignId,
    required this.creativeId,
    required this.advertiserId,
    required this.userId,
    required this.screenName,
    this.propertyId,
    required this.cost,
  });
}

class DirectAdService {
  final SupabaseClient _supabase;
  final SubscriptionService _subscriptionService;

  // ── Impression batch queue ────────────────────────────────────────────────
  // Impressions are collected locally and flushed to Supabase every 10 items
  // OR every 30 seconds (whichever comes first). This reduces RPC call volume.
  final List<_QueuedImpression> _impressionQueue = [];
  Timer? _impressionFlushTimer;
  static const int _batchFlushSize = 10;
  static const Duration _batchFlushInterval = Duration(seconds: 30);

  DirectAdService(this._supabase, this._subscriptionService);

  // ============================================================
  // SUBSCRIPTION-AWARE AD SERVING
  // ============================================================

  /// Returns true if user should see ads (free tier only).
  /// Defaults to TRUE on any error — never silently blocks ads.
  Future<bool> shouldShowAdsForUser(String userId) async {
    try {
      final subscription =
          await _subscriptionService.getUserSubscription(userId);
      if (subscription == null) return true;
      switch (subscription.tier) {
        case SubscriptionTier.free:
          return true;
        case SubscriptionTier.pro:
          return false;
      }
    } catch (e) {
      debugPrint('⚠️ shouldShowAdsForUser error (defaulting to show): $e');
      return true;
    }
  }

  /// Returns ad display frequency (list items between ad slots).
  ///
  /// Free → 7  (1 ad per 7 slots, ~14% density)
  /// Pro  → 0  (no ads)
  ///
  /// Must stay in sync with DirectAdAlgorithm constants.
  Future<int> getAdFrequencyForUser(String userId) async {
    try {
      final subscription =
          await _subscriptionService.getUserSubscription(userId);
      if (subscription == null ||
          subscription.tier == SubscriptionTier.free) {
        return 7;
      }
      return 0; // Pro — no ads
    } catch (e) {
      debugPrint('⚠️ getAdFrequencyForUser error (defaulting to 7): $e');
      return 7;
    }
  }

  // ============================================================
  // AD SERVING
  // ============================================================

  /// Fetch eligible ads via get_eligible_ads RPC.
  /// Server enforces: location targeting, property type targeting,
  /// daily budget cap, frequency cap, approval status.
  Future<List<DirectAd>> getEligibleAds({
    required String userId,
    required String screenName,
    String? propertyId,
    String? userRegion,
    String? userPropertyType,
    int limit = 5,
  }) async {
    try {
      final show = await shouldShowAdsForUser(userId);
      if (!show) return [];

      final response = await _supabase.rpc(
        'get_eligible_ads',
        params: {
          'p_user_id': userId,
          'p_screen_name': screenName,
          'p_property_id': propertyId,
          'p_limit': limit,
          'p_user_region': userRegion,
          'p_user_property_type': userPropertyType,
        },
      );

      if (response == null) return [];
      final List<dynamic> data = response is List ? response : [response];
      return data
          .map((json) => DirectAd.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('🔴 getEligibleAds error: $e');
      return [];
    }
  }

  // ============================================================
  // IMPRESSION & CLICK TRACKING
  // ============================================================

  /// Record an ad impression.
  /// Impressions are queued locally and flushed in batches of 10 or every 30 s.
  /// Returns null immediately (fire-and-forget); actual RPC happens in flush.
  ///
  /// Cost calculation (pass via impressionCost getter on DirectAd):
  ///   CPC campaigns → cost = 0.0 (charged only on click)
  ///   CPM campaigns → cost = bidAmount / 1000
  Future<String?> recordImpression({
    required String campaignId,
    required String creativeId,
    required String advertiserId,
    required String userId,
    required String screenName,
    String? propertyId,
    required double cost,
  }) async {
    _impressionQueue.add(_QueuedImpression(
      campaignId: campaignId,
      creativeId: creativeId,
      advertiserId: advertiserId,
      userId: userId,
      screenName: screenName,
      propertyId: propertyId,
      cost: cost,
    ));

    // Start periodic flush timer on first enqueue.
    _impressionFlushTimer ??= Timer.periodic(_batchFlushInterval, (_) {
      flushImpressions();
    });

    // Flush immediately once the batch size threshold is reached.
    if (_impressionQueue.length >= _batchFlushSize) {
      await flushImpressions();
    }

    return null;
  }

  /// Flush all queued impressions to Supabase.
  /// Call this on app pause or screen dispose to ensure nothing is lost.
  Future<void> flushImpressions() async {
    if (_impressionQueue.isEmpty) return;

    // Drain the queue atomically so concurrent calls don't double-send.
    final toFlush = List<_QueuedImpression>.from(_impressionQueue);
    _impressionQueue.clear();

    for (final imp in toFlush) {
      try {
        await _supabase.rpc(
          'record_ad_impression',
          params: {
            'p_campaign_id': imp.campaignId,
            'p_creative_id': imp.creativeId,
            'p_advertiser_id': imp.advertiserId,
            'p_user_id': imp.userId,
            'p_screen_name': imp.screenName,
            'p_property_id': imp.propertyId,
            'p_cost': imp.cost,
          },
        );
      } catch (e) {
        debugPrint('Error flushing impression: $e');
        // Re-queue failed impression so it is retried on the next flush.
        _impressionQueue.add(imp);
      }
    }

    // Cancel the timer when the queue is fully drained.
    if (_impressionQueue.isEmpty) {
      _impressionFlushTimer?.cancel();
      _impressionFlushTimer = null;
    }
  }

  /// Record an ad click. Returns the click UUID or null on error.
  /// Server-side fraud detection: >3 clicks/day by same user = zero cost.
  Future<String?> recordClick({
    required String impressionId,
    required String campaignId,
    required String creativeId,
    required String advertiserId,
    required String userId,
    required double cost,
  }) async {
    try {
      final response = await _supabase.rpc(
        'record_ad_click',
        params: {
          'p_impression_id': impressionId,
          'p_campaign_id': campaignId,
          'p_creative_id': creativeId,
          'p_advertiser_id': advertiserId,
          'p_user_id': userId,
          'p_cost': cost,
        },
      );
      return response as String?;
    } catch (e) {
      debugPrint('Error recording click: $e');
      return null;
    }
  }

  // ============================================================
  // SOFT DELETE
  // ============================================================

  /// Soft-delete a campaign and all its creatives.
  /// Sets campaign status = 'cancelled', creatives status = 'archived'.
  /// All impression/click history is preserved permanently.
  Future<AdDeleteResult> softDeleteCampaign({
    required String campaignId,
    required String userId,
    String? reason,
  }) async {
    try {
      final response = await _supabase.rpc(
        'soft_delete_campaign',
        params: {
          'p_campaign_id': campaignId,
          'p_user_id': userId,
          'p_reason': reason,
        },
      );
      if (response == null) {
        return const AdDeleteResult(
            success: false, message: '', error: 'No response from server');
      }
      return AdDeleteResult.fromJson(
          Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('Error soft-deleting campaign: $e');
      return AdDeleteResult(success: false, message: '', error: e.toString());
    }
  }

  /// Soft-delete a single creative.
  Future<AdDeleteResult> softDeleteCreative({
    required String creativeId,
    required String userId,
    String? reason,
  }) async {
    try {
      final response = await _supabase.rpc(
        'soft_delete_creative',
        params: {
          'p_creative_id': creativeId,
          'p_user_id': userId,
          'p_reason': reason,
        },
      );
      if (response == null) {
        return const AdDeleteResult(
            success: false, message: '', error: 'No response from server');
      }
      return AdDeleteResult.fromJson(
          Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('Error soft-deleting creative: $e');
      return AdDeleteResult(success: false, message: '', error: e.toString());
    }
  }

  // ============================================================
  // ADVERTISER MANAGEMENT
  // ============================================================

  Future<Advertiser?> getAdvertiserByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('advertisers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return Advertiser.fromJson(response);
    } catch (e) {
      debugPrint('Error getting advertiser: $e');
      return null;
    }
  }

  /// Create advertiser profile if it does not already exist.
  Future<Advertiser?> ensureAdvertiserExists({
    required String userId,
    required String email,
    String? fullName,
    String? phone,
  }) async {
    try {
      var advertiser = await getAdvertiserByUserId(userId);
      if (advertiser != null) return advertiser;

      final response = await _supabase.from('advertisers').insert({
        'user_id': userId,
        'company_name': fullName ?? 'My Company',
        'contact_name': fullName ?? 'Contact Person',
        'email': email,
        'phone': phone ?? 'N/A',
        'company_type': 'real_estate_agency',
        'status': 'active',
        'account_balance': 0.00,
        'total_spent': 0.00,
      }).select().single();

      return Advertiser.fromJson(response);
    } catch (e) {
      debugPrint('Error ensuring advertiser exists: $e');
      return null;
    }
  }

  Future<bool> updateAdvertiserProfile({
    required String advertiserId,
    String? companyName,
    String? contactName,
    String? phone,
    String? companyWebsite,
    String? companyDescription,
    String? companyType,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (companyName != null) updates['company_name'] = companyName;
      if (contactName != null) updates['contact_name'] = contactName;
      if (phone != null) updates['phone'] = phone;
      if (companyWebsite != null) updates['company_website'] = companyWebsite;
      if (companyDescription != null) {
        updates['company_description'] = companyDescription;
      }
      if (companyType != null) updates['company_type'] = companyType;
      if (updates.isEmpty) return false;
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from('advertisers')
          .update(updates)
          .eq('id', advertiserId);
      return true;
    } catch (e) {
      debugPrint('Error updating advertiser profile: $e');
      return false;
    }
  }

  // ============================================================
  // CAMPAIGN MANAGEMENT
  // ============================================================

  /// Returns non-deleted campaigns for an advertiser.
  Future<List<AdCampaign>> getCampaigns(String advertiserId) async {
    try {
      final response = await _supabase
          .from('ad_campaigns')
          .select()
          .eq('advertiser_id', advertiserId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(50);
      return response.map((json) => AdCampaign.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting campaigns: $e');
      return [];
    }
  }

  /// Create a new campaign.
  /// Dates are converted to UTC — device is UTC+3 (Tanzania) but Supabase
  /// stores and compares all timestamps in UTC. Without .toUtc() the
  /// start_date would be 3 hours in the future, blocking the campaign.
  Future<AdCampaign?> createCampaign({
    required String advertiserId,
    required String campaignName,
    required String campaignObjective,
    required double dailyBudget,
    required double totalBudget,
    required double bidAmount,
    required String biddingStrategy,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? targetPropertyTypes,
    List<String>? targetLocations,
    Map<String, dynamic>? targetPriceRange,
    List<String>? targetUserInterests,
  }) async {
    try {
      final response = await _supabase.from('ad_campaigns').insert({
        'advertiser_id': advertiserId,
        'campaign_name': campaignName,
        'campaign_objective': campaignObjective,
        'daily_budget': dailyBudget,
        'total_budget': totalBudget,
        'bid_amount': bidAmount,
        'bidding_strategy': biddingStrategy,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
        'target_property_types': targetPropertyTypes ?? [],
        'target_locations': targetLocations ?? [],
        'target_price_range': targetPriceRange,
        'target_user_interests': targetUserInterests ?? [],
        'status': 'running',  // Campaigns go live immediately — no admin review needed
      }).select().single();

      return AdCampaign.fromJson(response);
    } catch (e) {
      debugPrint('❌ createCampaign error: $e');
      // Common causes:
      // - status value not in CHECK constraint (valid: running, paused, draft, cancelled)
      // - advertiser_id not in advertisers table (call ensureAdvertiserExists first)
      // - campaign_objective not in CHECK constraint
      // - date constraint: end_date must be after start_date
      rethrow; // let the UI show the real error message
    }
  }

  Future<bool> updateCampaignStatus({
    required String campaignId,
    required String status,
  }) async {
    try {
      await _supabase
          .from('ad_campaigns')
          .update({
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', campaignId)
          .isFilter('deleted_at', null);
      return true;
    } catch (e) {
      debugPrint('Error updating campaign status: $e');
      return false;
    }
  }

  // ============================================================
  // CREATIVE MANAGEMENT
  // ============================================================

  /// Returns non-deleted creatives for a campaign.
  Future<List<AdCreative>> getCreatives(String campaignId) async {
    try {
      final response = await _supabase
          .from('ad_creatives')
          .select()
          .eq('campaign_id', campaignId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(50);
      return response.map((json) => AdCreative.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting creatives: $e');
      return [];
    }
  }

  Future<AdCreative?> createCreative({
    required String campaignId,
    required String adFormat,
    required String headline,
    String? description,
    required String callToAction,
    required String imageUrl,
    String? logoUrl,
    required String landingUrl,
    String mediaType = 'image',
    String? videoUrl,
  }) async {
    try {
      final response = await _supabase.from('ad_creatives').insert({
        'campaign_id': campaignId,
        'ad_format': adFormat,
        'headline': headline,
        'description': description,
        'call_to_action': callToAction,
        'image_url': imageUrl,
        'logo_url': logoUrl,
        'landing_url': landingUrl,
        'media_type': mediaType,
        'video_url': videoUrl,
        'status': 'paused',  // starts paused; AI validation in create_creative_screen sets to active
        'is_approved': false,
      }).select().single();

      return AdCreative.fromJson(response);
    } catch (e) {
      debugPrint('Error creating creative: $e');
      return null;
    }
  }

  // ============================================================
  // PAYMENT & BILLING
  // ============================================================

  /// Add funds via process_advertiser_payment RPC (additive, never overwrites).
  Future<bool> addToAdvertiserBalance({
    required String advertiserId,
    required double amount,
    required String transactionId,
    required String paymentMethod,
    String? providerReference,
  }) async {
    try {
      await _supabase.rpc(
        'process_advertiser_payment',
        params: {
          'p_advertiser_id': advertiserId,
          'p_amount': amount,
          'p_transaction_id': transactionId,
          'p_payment_method': paymentMethod,
          'p_provider_reference': providerReference,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error adding to advertiser balance: $e');
      return false;
    }
  }

  /// Alias — screens that call processPayment() continue to work.
  Future<bool> processPayment({
    required String advertiserId,
    required double amount,
    required String transactionId,
    required String paymentMethod,
    String? providerReference,
  }) =>
      addToAdvertiserBalance(
        advertiserId: advertiserId,
        amount: amount,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
        providerReference: providerReference,
      );

  /// Verify and complete a payment that may have been missed while the app
  /// was in the background. Calls verify_and_complete_payment RPC which is
  /// idempotent — safe to call multiple times for the same transaction.
  Future<bool> verifyAndCompletePayment({
    required String transactionId,
    required String providerReference,
    required double amount,
    required String advertiserId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'verify_and_complete_payment',
        params: {
          'p_transaction_id': transactionId,
          'p_provider_reference': providerReference,
          'p_amount': amount,
          'p_advertiser_id': advertiserId,
        },
      );
      final result = response as Map<String, dynamic>?;
      return result?['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      return false;
    }
  }

  Future<List<AdvertiserPayment>> getPaymentHistory(
      String advertiserId) async {
    try {
      final response = await _supabase
          .from('advertiser_payments')
          .select()
          .eq('advertiser_id', advertiserId)
          .order('created_at', ascending: false)
          .limit(50);
      return response
          .map((json) => AdvertiserPayment.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting payment history: $e');
      return [];
    }
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  Future<CampaignPerformance?> getCampaignPerformance(
      String campaignId) async {
    try {
      final campaign = await _supabase
          .from('ad_campaigns')
          .select()
          .eq('id', campaignId)
          .single();
      return CampaignPerformance.fromJson(campaign);
    } catch (e) {
      debugPrint('Error getting campaign performance: $e');
      return null;
    }
  }

  Future<AdvertiserStats?> getAdvertiserStats(String advertiserId) async {
    try {
      final campaigns = await getCampaigns(advertiserId);
      int totalImpressions = 0;
      int totalClicks = 0;
      double totalSpent = 0;
      int activeCampaigns = 0;

      for (final campaign in campaigns) {
        totalImpressions += campaign.impressionsCount;
        totalClicks += campaign.clicksCount;
        totalSpent += campaign.spentAmount;
        if (campaign.status == 'running') activeCampaigns++;
      }

      return AdvertiserStats(
        totalCampaigns: campaigns.length,
        activeCampaigns: activeCampaigns,
        totalImpressions: totalImpressions,
        totalClicks: totalClicks,
        totalSpent: totalSpent,
        averageCtr: totalImpressions > 0
            ? (totalClicks / totalImpressions) * 100
            : 0.0,
      );
    } catch (e) {
      debugPrint('Error getting advertiser stats: $e');
      return null;
    }
  }

  // ============================================================
  // IN-APP NOTIFICATIONS
  // ============================================================

  /// Fetch unread ad-related notifications for an advertiser.
  Future<List<AdNotification>> getAdNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .inFilter('type',
              ['ad_approved', 'ad_rejected', 'payment_confirmed'])
          .order('created_at', ascending: false);
      return response
          .map((json) => AdNotification.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting ad notifications: $e');
      return [];
    }
  }

  Future<bool> markNotificationRead(String notificationId) async {
    try {
      await _supabase.from('user_notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  Future<bool> markAllAdNotificationsRead(String userId) async {
    try {
      await _supabase
          .from('user_notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false)
          .inFilter('type',
              ['ad_approved', 'ad_rejected', 'payment_confirmed']);
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
      return false;
    }
  }
}