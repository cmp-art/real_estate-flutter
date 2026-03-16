// lib/core/services/admin_service.dart
// Comprehensive admin & role-based access control service
// Handles: users, properties (with media), ads, notifications, archive/audit

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ENUMS & ROLE MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum UserRole {
  superAdmin,
  admin,
  moderator,
  advertiser,
  agent,
  user;

  String get value {
    switch (this) {
      case UserRole.superAdmin:  return 'super_admin';
      case UserRole.admin:       return 'admin';
      case UserRole.moderator:   return 'moderator';
      case UserRole.advertiser:  return 'advertiser';
      case UserRole.agent:       return 'agent';
      case UserRole.user:        return 'user';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'super_admin': return UserRole.superAdmin;
      case 'admin':       return UserRole.admin;
      case 'moderator':   return UserRole.moderator;
      case 'advertiser':  return UserRole.advertiser;
      case 'agent':       return UserRole.agent;
      default:            return UserRole.user;
    }
  }

  bool get isAdmin =>
      this == UserRole.superAdmin ||
      this == UserRole.admin ||
      this == UserRole.moderator;
  bool get isSuperAdmin => this == UserRole.superAdmin;
}

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class UserProfile {
  final String id;
  final UserRole role;
  final List<String> permissions;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final bool isActive;
  final bool isVerified;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime? deactivatedAt;
  final String? deactivationReason;
  final DateTime? deletedAt;

  UserProfile({
    required this.id,
    required this.role,
    required this.permissions,
    this.fullName,
    this.phone,
    this.avatarUrl,
    required this.isActive,
    required this.isVerified,
    this.lastLoginAt,
    required this.createdAt,
    this.deactivatedAt,
    this.deactivationReason,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      role: UserRole.fromString(json['role'] as String? ?? 'user'),
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      deactivatedAt: json['deactivated_at'] != null
          ? DateTime.parse(json['deactivated_at'] as String)
          : null,
      deactivationReason: json['deactivation_reason'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }
}

class AdminDashboardStats {
  final int totalUsers;
  final int newUsers30d;
  final int activeUsers;
  final int totalAdmins;
  final int totalAdvertisers;
  final int activeCampaigns;
  final int pendingAds;
  final double totalAdvertiserBalance;
  final double totalAdRevenue;
  final int adminActions24h;
  final int totalProperties;
  final int activeSubscriptions;

  AdminDashboardStats({
    required this.totalUsers,
    required this.newUsers30d,
    required this.activeUsers,
    required this.totalAdmins,
    required this.totalAdvertisers,
    required this.activeCampaigns,
    required this.pendingAds,
    required this.totalAdvertiserBalance,
    required this.totalAdRevenue,
    required this.adminActions24h,
    required this.totalProperties,
    required this.activeSubscriptions,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalUsers: json['total_users'] as int? ?? 0,
      newUsers30d: json['new_users_30d'] as int? ?? 0,
      activeUsers: json['active_users'] as int? ?? 0,
      totalAdmins: json['total_admins'] as int? ?? 0,
      totalAdvertisers: json['total_advertisers'] as int? ?? 0,
      activeCampaigns: json['active_campaigns'] as int? ?? 0,
      pendingAds: json['pending_ads'] as int? ?? 0,
      totalAdvertiserBalance:
          (json['total_advertiser_balance'] as num?)?.toDouble() ?? 0.0,
      totalAdRevenue:
          (json['total_ad_revenue'] as num?)?.toDouble() ?? 0.0,
      adminActions24h: json['admin_actions_24h'] as int? ?? 0,
      totalProperties: json['total_properties'] as int? ?? 0,
      activeSubscriptions: json['active_subscriptions'] as int? ?? 0,
    );
  }
}

class AdminActivityLog {
  final String id;
  final String adminId;
  final String adminEmail;
  final String adminRole;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  AdminActivityLog({
    required this.id,
    required this.adminId,
    required this.adminEmail,
    required this.adminRole,
    required this.action,
    this.targetType,
    this.targetId,
    this.description,
    this.metadata,
    required this.createdAt,
  });

  factory AdminActivityLog.fromJson(Map<String, dynamic> json) {
    return AdminActivityLog(
      id: json['id'] as String,
      adminId: json['admin_id'] as String,
      adminEmail: json['admin_email'] as String? ?? '',
      adminRole: json['admin_role'] as String? ?? '',
      action: json['action'] as String,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Archive models
class ArchivedCampaign {
  final String id;
  final String advertiserCompany;
  final String advertiserEmail;
  final String campaignName;
  final double totalBudget;
  final double spentAmount;
  final int impressionsCount;
  final int clicksCount;
  final String status;
  final DateTime? deletedAt;
  final String? deletionReason;
  final DateTime createdAt;

  const ArchivedCampaign({
    required this.id,
    required this.advertiserCompany,
    required this.advertiserEmail,
    required this.campaignName,
    required this.totalBudget,
    required this.spentAmount,
    required this.impressionsCount,
    required this.clicksCount,
    required this.status,
    this.deletedAt,
    this.deletionReason,
    required this.createdAt,
  });

  factory ArchivedCampaign.fromJson(Map<String, dynamic> json) {
    return ArchivedCampaign(
      id: json['id'] as String,
      advertiserCompany: json['advertiser_company'] as String? ?? 'Unknown',
      advertiserEmail: json['advertiser_email'] as String? ?? 'Unknown',
      campaignName: json['campaign_name'] as String,
      totalBudget: (json['total_budget'] as num).toDouble(),
      spentAmount: (json['spent_amount'] as num).toDouble(),
      impressionsCount: json['impressions_count'] as int? ?? 0,
      clicksCount: json['clicks_count'] as int? ?? 0,
      status: json['status'] as String,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      deletionReason: json['deletion_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  double get budgetUtilizationPercent =>
      totalBudget > 0 ? (spentAmount / totalBudget) * 100 : 0;
}

class CancelledSubscription {
  final String id;
  final String userEmail;
  final String? userFullName;
  final String tierName;
  final double tierPrice;
  final DateTime startedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final int activeDays;

  const CancelledSubscription({
    required this.id,
    required this.userEmail,
    this.userFullName,
    required this.tierName,
    required this.tierPrice,
    required this.startedAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.activeDays,
  });

  factory CancelledSubscription.fromJson(Map<String, dynamic> json) {
    return CancelledSubscription(
      id: json['id'] as String,
      userEmail: json['user_email'] as String? ?? 'Unknown',
      userFullName: json['user_full_name'] as String?,
      tierName: json['tier_name'] as String,
      tierPrice: (json['tier_price'] as num).toDouble(),
      startedAt: DateTime.parse(json['started_at'] as String),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
      activeDays: json['active_days'] as int? ?? 0,
    );
  }
}

class AdminArchiveStats {
  final int totalAccounts;
  final int activeAccounts;
  final int deactivatedAccounts;
  final int deletedAccounts;
  final int totalSubscriptions;
  final int activeSubscriptions;
  final int cancelledSubscriptions;
  final int expiredSubscriptions;
  final double totalSubscriptionRevenueUsd;
  final int totalProperties;
  final int activeProperties;
  final int deletedProperties;
  final int totalCampaigns;
  final int activeCampaigns;
  final int deletedCampaigns;
  final double totalCampaignSpendTzs;
  final double totalImpressionRevenueTzs;
  final double totalClickRevenueTzs;
  final int totalCreatives;
  final int deletedCreatives;
  final int pendingApproval;

  double get totalAdRevenueTzs => 
      totalCampaignSpendTzs + totalImpressionRevenueTzs + totalClickRevenueTzs;

  const AdminArchiveStats({
    required this.totalAccounts,
    required this.activeAccounts,
    required this.deactivatedAccounts,
    required this.deletedAccounts,
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.cancelledSubscriptions,
    required this.expiredSubscriptions,
    required this.totalSubscriptionRevenueUsd,
    required this.totalProperties,
    required this.activeProperties,
    required this.deletedProperties,
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.deletedCampaigns,
    required this.totalCampaignSpendTzs,
    required this.totalImpressionRevenueTzs,
    required this.totalClickRevenueTzs,
    required this.totalCreatives,
    required this.deletedCreatives,
    required this.pendingApproval,
  });

  factory AdminArchiveStats.fromJson(Map<String, dynamic> json) {
    return AdminArchiveStats(
      totalAccounts: json['total_accounts'] as int? ?? 0,
      activeAccounts: json['active_accounts'] as int? ?? 0,
      deactivatedAccounts: json['deactivated_accounts'] as int? ?? 0,
      deletedAccounts: json['deleted_accounts'] as int? ?? 0,
      totalSubscriptions: json['total_subscriptions'] as int? ?? 0,
      activeSubscriptions: json['active_subscriptions'] as int? ?? 0,
      cancelledSubscriptions: json['cancelled_subscriptions'] as int? ?? 0,
      expiredSubscriptions: json['expired_subscriptions'] as int? ?? 0,
      totalSubscriptionRevenueUsd:
          (json['total_subscription_revenue_usd'] as num?)?.toDouble() ?? 0.0,
      totalProperties: json['total_properties'] as int? ?? 0,
      activeProperties: json['active_properties'] as int? ?? 0,
      deletedProperties: json['deleted_properties'] as int? ?? 0,
      totalCampaigns: json['total_campaigns'] as int? ?? 0,
      activeCampaigns: json['active_campaigns'] as int? ?? 0,
      deletedCampaigns: json['deleted_campaigns'] as int? ?? 0,
      totalCampaignSpendTzs:
          (json['total_campaign_spend_tzs'] as num?)?.toDouble() ?? 0.0,
      totalImpressionRevenueTzs:
          (json['total_impression_revenue_tzs'] as num?)?.toDouble() ?? 0.0,
      totalClickRevenueTzs:
          (json['total_click_revenue_tzs'] as num?)?.toDouble() ?? 0.0,
      totalCreatives: json['total_creatives'] as int? ?? 0,
      deletedCreatives: json['deleted_creatives'] as int? ?? 0,
      pendingApproval: json['pending_approval'] as int? ?? 0,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN SERVICE
// ══════════════════════════════════════════════════════════════════════════════

class AdminService {
  final SupabaseClient _supabase;

  AdminService(this._supabase);

  // ── ROLE CHECKS ─────────────────────────────────────────────────────────────

  Future<bool> isCurrentUserAdmin() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    return isAdmin(userId);
  }

  Future<bool> isAdmin(String userId) async {
    try {
      final result = await _supabase.rpc('is_admin', params: {'user_id': userId});
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  Future<bool> isCurrentUserSuperAdmin() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    return isSuperAdmin(userId);
  }

  Future<bool> isSuperAdmin(String userId) async {
    try {
      final result = await _supabase.rpc('is_super_admin', params: {'user_id': userId});
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking super admin status: $e');
      return false;
    }
  }

  Future<UserRole> getCurrentUserRole() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return UserRole.user;
    return getUserRole(userId);
  }

  Future<UserRole> getUserRole(String userId) async {
    try {
      final result = await _supabase.rpc('get_user_role', params: {'user_id': userId});
      return UserRole.fromString(result as String? ?? 'user');
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return UserRole.user;
    }
  }

  // ── PROFILE MANAGEMENT ──────────────────────────────────────────────────────

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      return UserProfile.fromJson(data);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<bool> updateUserRole({required String userId, required UserRole role}) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({'role': role.value, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      await logAction(
        action: 'update_user_role',
        targetType: 'user',
        targetId: userId,
        description: 'Role changed to ${role.value}',
      );
      return true;
    } catch (e) {
      debugPrint('Error updating user role: $e');
      return false;
    }
  }

  /// Ban user with automatic notification to the user
  Future<bool> banUser(String userId, {String? reason}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return false;

      final result = await _supabase.rpc('admin_ban_user_with_notify', params: {
        'p_user_id': userId,
        'p_admin_id': adminId,
        'p_reason': reason,
      });

      return result['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error banning user: $e');
      // Fallback: direct update without notification
      try {
        await _supabase.from('user_profiles').update({
          'is_active': false,
          'deactivated_at': DateTime.now().toIso8601String(),
          'deactivation_reason': reason ?? 'Banned by admin',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Unban user with automatic notification to the user
  Future<bool> unbanUser(String userId) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return false;

      final result = await _supabase.rpc('admin_unban_user_with_notify', params: {
        'p_user_id': userId,
        'p_admin_id': adminId,
      });

      return result['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error unbanning user: $e');
      try {
        await _supabase.from('user_profiles').update({
          'is_active': true,
          'deactivated_at': null,
          'deactivation_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Send a custom notification to any user
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    String type = 'admin_message',
    Map<String, dynamic>? data,
  }) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return false;

      final result = await _supabase.rpc('admin_send_notification', params: {
        'p_admin_id': adminId,
        'p_user_id': userId,
        'p_type': type,
        'p_title': title,
        'p_message': message,
        'p_data': data,
      });

      return result['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error sending notification: $e');
      // Fallback: direct insert
      try {
        await _supabase.from('user_notifications').insert({
          'user_id': userId,
          'type': type,
          'title': title,
          'message': message,
          'data': data,
        });
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // ── ADMIN DASHBOARD ─────────────────────────────────────────────────────────

  Future<AdminDashboardStats?> getDashboardStats() async {
    try {
      final data = await _supabase
          .from('admin_dashboard_stats')
          .select()
          .single();
      return AdminDashboardStats.fromJson(data);
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return null;
    }
  }

  /// Get ALL registered users — uses admin_all_accounts view which
  /// JOINs from auth.users, so every account appears even without a profile.
  Future<List<Map<String, dynamic>>> getAllUsers({
    int limit = 200,
    int offset = 0,
    String? searchQuery,
    bool includeDeleted = false,
  }) async {
    try {
      var query = _supabase.from('admin_all_accounts').select();

      if (!includeDeleted) {
        query = query.isFilter('deleted_at', null);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('email.ilike.%$searchQuery%,full_name.ilike.%$searchQuery%');
      }

      return await query
          .order('auth_created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPendingReview() async {
    try {
      return await _supabase.from('admin_pending_review').select();
    } catch (e) {
      debugPrint('Error getting pending review: $e');
      return [];
    }
  }

  // ── PROPERTY MANAGEMENT ─────────────────────────────────────────────────────

  /// Get all properties with images and videos included
  /// deletedOnly       = true  → only admin-deleted OR user-deleted
  /// userDeletedOnly   = true  → only properties deleted by the owner themselves
  /// adminDeletedOnly  = true  → only properties deleted by an admin
  Future<List<Map<String, dynamic>>> getAllPropertiesAdmin({
    int limit = 100,
    int offset = 0,
    bool deletedOnly = false,
    bool userDeletedOnly = false,
    bool adminDeletedOnly = false,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase.from('admin_all_properties').select();

      if (userDeletedOnly) {
        // User deleted their own property
        query = query
            .not('deleted_at', 'is', null)
            .eq('deleted_by_user', true);
      } else if (adminDeletedOnly) {
        // Admin deleted this property
        query = query
            .not('deleted_at', 'is', null)
            .not('deleted_by_admin', 'is', null);
      } else if (deletedOnly) {
        // Any deleted (admin or user)
        query = query.not('deleted_at', 'is', null);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
            'title.ilike.%$searchQuery%,owner_email.ilike.%$searchQuery%,location.ilike.%$searchQuery%');
      }

      return await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (e) {
      debugPrint('Error getting all properties: $e');
      return [];
    }
  }

  /// Admin soft-delete property with owner notification
  Future<Map<String, dynamic>> adminDeleteProperty(String propertyId, {String? reason}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return {'success': false, 'error': 'Not authenticated'};

      final result = await _supabase.rpc(
          'admin_soft_delete_property_with_notify',
          params: {
            'p_property_id': propertyId,
            'p_admin_id': adminId,
            'p_reason': reason,
          });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error deleting property: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Admin restore soft-deleted property with owner notification
  Future<Map<String, dynamic>> adminRestoreProperty(String propertyId, {String? note}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return {'success': false, 'error': 'Not authenticated'};

      final result = await _supabase.rpc(
          'admin_restore_property_with_notify',
          params: {
            'p_property_id': propertyId,
            'p_admin_id': adminId,
            'p_note': note,
          });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error restoring property: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Admin feature/unfeature a property
  Future<bool> adminFeatureProperty(String propertyId, {required bool featured}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return false;

      final result = await _supabase.rpc('admin_feature_property', params: {
        'p_property_id': propertyId,
        'p_admin_id': adminId,
        'p_featured': featured,
      });
      return result['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error featuring property: $e');
      return false;
    }
  }

  /// Admin verify/unverify a property
  Future<bool> adminVerifyProperty(String propertyId, {required bool verified}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return false;

      final result = await _supabase.rpc('admin_verify_property', params: {
        'p_property_id': propertyId,
        'p_admin_id': adminId,
        'p_verified': verified,
      });
      return result['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error verifying property: $e');
      return false;
    }
  }

  /// Delete a specific media item (image or video) from a property
  Future<Map<String, dynamic>> adminDeletePropertyMedia(
    String propertyId,
    String mediaUrl, {
    String? reason,
  }) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return {'success': false, 'error': 'Not authenticated'};

      final result = await _supabase.rpc('admin_delete_property_media', params: {
        'p_property_id': propertyId,
        'p_admin_id': adminId,
        'p_media_url': mediaUrl,
        'p_reason': reason,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error deleting property media: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── CONTENT MODERATION ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAdCreativeDetails(String creativeId) async {
    try {
      final data = await _supabase
          .from('ad_creatives')
          .select('''
            id, campaign_id, ad_format, headline, description,
            call_to_action, image_url, logo_url, landing_url,
            video_url, media_type, status, is_approved,
            created_at, deleted_at, deletion_reason,
            ad_campaigns (
              campaign_name, campaign_objective, total_budget,
              daily_budget, start_date, end_date, advertiser_id,
              spent_amount, impressions_count, clicks_count,
              advertisers ( company_name, contact_name, email, phone )
            )
          ''')
          .eq('id', creativeId)
          .single();
      return data;
    } catch (e) {
      debugPrint('Error fetching ad creative details: $e');
      return null;
    }
  }

  /// Approve an ad creative — calls admin_approve_creative which atomically
  /// sets is_approved=TRUE, status='active', starts the campaign, and notifies the advertiser.
  Future<bool> approveAd(String creativeId, {String? notes}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return false;

      final result = await _supabase.rpc('admin_approve_creative', params: {
        'p_creative_id': creativeId,
        'p_admin_id': adminId,
      });

      final success = result['success'] as bool? ?? false;
      if (!success) {
        debugPrint('admin_approve_creative failed: ${result['error']}');
      }
      return success;
    } catch (e) {
      debugPrint('Error approving ad (rpc failed, trying direct): $e');
      // Fallback: direct update — sets both fields atomically
      try {
        final adminId = _supabase.auth.currentUser?.id;
        final row = await _supabase
            .from('ad_creatives')
            .update({
              'is_approved': true,
              'status': 'active',
              'reviewed_by': adminId,
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', creativeId)
            .select('campaign_id')
            .single();

        final campaignId = row['campaign_id'] as String?;
        if (campaignId != null) {
          await _supabase.from('ad_campaigns').update({
            'status': 'running',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', campaignId);
        }
        return true;
      } catch (e2) {
        debugPrint('Fallback approve also failed: $e2');
        return false;
      }
    }
  }

  /// Admin soft-delete an ad creative with advertiser notification
  Future<Map<String, dynamic>> adminDeleteCreative(String creativeId, {String? reason}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return {'success': false, 'error': 'Not authenticated'};

      final result = await _supabase.rpc('admin_soft_delete_creative', params: {
        'p_creative_id': creativeId,
        'p_admin_id': adminId,
        'p_reason': reason,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error deleting creative (rpc failed, trying direct): $e');
      // Fallback: direct update
      try {
        await _supabase.from('ad_creatives').update({
          'deleted_at': DateTime.now().toIso8601String(),
          'deletion_reason': reason,
          'status': 'paused',  // soft-delete: use 'paused' (closest valid value, deleted_at marks it deleted)
          'is_approved': false,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', creativeId);
        return {'success': true, 'message': 'Ad removed'};
      } catch (e2) {
        return {'success': false, 'error': e.toString()};
      }
    }
  }

  /// Admin restore a soft-deleted ad creative with advertiser notification
  Future<Map<String, dynamic>> adminRestoreCreative(String creativeId, {String? note}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return {'success': false, 'error': 'Not authenticated'};

      final result = await _supabase.rpc('admin_restore_creative', params: {
        'p_creative_id': creativeId,
        'p_admin_id': adminId,
        'p_note': note,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error restoring creative (rpc failed, trying direct): $e');
      // Fallback: direct update
      try {
        await _supabase.from('ad_creatives').update({
          'deleted_at': null,
          'deletion_reason': null,
          'status': 'paused',  // restore to paused for re-review (valid values: active/paused/rejected/archived)
          'is_approved': false,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', creativeId);
        return {'success': true, 'message': 'Ad restored to pending review'};
      } catch (e2) {
        return {'success': false, 'error': e.toString()};
      }
    }
  }

  /// Reject an ad creative — calls admin_reject_creative which sets status='rejected',
  /// notifies the advertiser, and logs the action.
  Future<bool> rejectAd(String creativeId, String reason) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return false;

      final result = await _supabase.rpc('admin_reject_creative', params: {
        'p_creative_id': creativeId,
        'p_admin_id': adminId,
        'p_reason': reason,
      });

      final success = result['success'] as bool? ?? false;
      if (!success) {
        debugPrint('admin_reject_creative failed: ${result['error']}');
      }
      return success;
    } catch (e) {
      debugPrint('Error rejecting ad (rpc failed, trying direct): $e');
      // Fallback: direct update
      try {
        final adminId = _supabase.auth.currentUser?.id;
        await _supabase.from('ad_creatives').update({
          'is_approved': false,
          'reviewed_by': adminId,
          'reviewed_at': DateTime.now().toIso8601String(),
          'rejection_reason': reason,
          'status': 'rejected',
        }).eq('id', creativeId);
        return true;
      } catch (e2) {
        debugPrint('Fallback reject also failed: $e2');
        return false;
      }
    }
  }

  // ── ARCHIVE & AUDIT ──────────────────────────────────────────────────────────

  Future<AdminArchiveStats?> getArchiveStats() async {
    try {
      final data = await _supabase.rpc('get_admin_archive_stats');
      if (data == null) return null;
      return AdminArchiveStats.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('Error getting archive stats: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllCampaignsAdmin({
    int limit = 50,
    int offset = 0,
    bool deletedOnly = false,
  }) async {
    try {
      var query = _supabase.from('admin_all_campaigns').select();
      if (deletedOnly) query = query.not('deleted_at', 'is', null);
      return await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (e) {
      debugPrint('Error getting all campaigns: $e');
      return [];
    }
  }

  Future<List<ArchivedCampaign>> getDeletedCampaigns({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final data = await _supabase.rpc(
        'get_admin_deleted_campaigns',
        params: {'p_limit': limit, 'p_offset': offset},
      );
      if (data == null) return [];
      final List<dynamic> list = data is List ? data : [data];
      return list
          .map((json) => ArchivedCampaign.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting deleted campaigns: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllSubscriptionsAdmin({
    int limit = 50,
    int offset = 0,
    String? statusFilter,
  }) async {
    try {
      var query = _supabase.from('admin_all_subscriptions').select();
      if (statusFilter != null) query = query.eq('status', statusFilter);
      return await query
          .order('started_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (e) {
      debugPrint('Error getting all subscriptions: $e');
      return [];
    }
  }

  Future<List<CancelledSubscription>> getCancelledSubscriptions({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final data = await _supabase.rpc(
        'get_admin_cancelled_subscriptions',
        params: {'p_limit': limit, 'p_offset': offset},
      );
      if (data == null) return [];
      final List<dynamic> list = data is List ? data : [data];
      return list
          .map((json) => CancelledSubscription.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting cancelled subscriptions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllAccountsAdmin({
    int limit = 50,
    int offset = 0,
    bool deletedOnly = false,
    bool deactivatedOnly = false,
    String? searchQuery,
  }) async {
    try {
      var query = _supabase.from('admin_all_accounts').select();
      if (deletedOnly) {
        query = query.not('deleted_at', 'is', null);
      } else if (deactivatedOnly) {
        query = query.eq('is_active', false);
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('email.ilike.%$searchQuery%,full_name.ilike.%$searchQuery%');
      }
      return await query
          .order('auth_created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (e) {
      debugPrint('Error getting all accounts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllCreativesAdmin({
    int limit = 50,
    int offset = 0,
    bool deletedOnly = false,
  }) async {
    try {
      var query = _supabase.from('admin_all_creatives').select();
      if (deletedOnly) query = query.not('deleted_at', 'is', null);
      return await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (e) {
      debugPrint('Error getting all creatives: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSubscriptionRevenueReport({int limitMonths = 12}) async {
    try {
      return await _supabase
          .from('admin_subscription_revenue_summary')
          .select()
          .limit(limitMonths * 3);
    } catch (e) {
      debugPrint('Error getting subscription revenue report: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdRevenueReport({int limitMonths = 12}) async {
    try {
      return await _supabase
          .from('admin_ad_revenue_summary')
          .select()
          .limit(limitMonths * 20);
    } catch (e) {
      debugPrint('Error getting ad revenue report: $e');
      return [];
    }
  }

  /// Legacy methods (kept for backwards compat)
  Future<bool> restoreDeletedProperty(String propertyId) async {
    final result = await adminRestoreProperty(propertyId);
    return result['success'] as bool? ?? false;
  }

  Future<bool> adminCancelSubscription(String subscriptionId, {required String reason}) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      await _supabase.from('user_subscriptions').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancelled_by': adminId,
        'cancellation_reason': 'Admin action: $reason',
        'auto_renew': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', subscriptionId);

      await logAction(
        action: 'admin_cancel_subscription',
        targetType: 'user_subscription',
        targetId: subscriptionId,
        description: 'Subscription cancelled by admin: $reason',
        metadata: {'reason': reason},
      );
      return true;
    } catch (e) {
      debugPrint('Error admin-cancelling subscription: $e');
      return false;
    }
  }

  // ── ACTIVITY LOG ─────────────────────────────────────────────────────────────

  Future<void> logAction({
    required String action,
    String? targetType,
    String? targetId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) return;
      await _supabase.rpc('log_admin_action', params: {
        'p_admin_id': adminId,
        'p_action': action,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_description': description,
        'p_metadata': metadata,
      });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  Future<List<AdminActivityLog>> getActivityLogs({
    int limit = 50,
    int offset = 0,
    String? adminId,
    String? action,
    String? targetType,
  }) async {
    try {
      var query = _supabase.from('admin_activity_log').select();
      if (adminId != null) query = query.eq('admin_id', adminId);
      if (action != null) query = query.eq('action', action);
      if (targetType != null) query = query.eq('target_type', targetType);
      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return data.map((json) => AdminActivityLog.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting activity logs: $e');
      return [];
    }
  }
}