// lib/core/services/price_drop_alert_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Model for Price Drop Alert
class PriceDropAlert {
  final String id;
  final String userId;
  final String propertyId;
  final double alertThreshold;
  final double originalPrice;
  final double? currentPrice;
  final DateTime? lastNotifiedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PriceDropAlert({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.alertThreshold,
    required this.originalPrice,
    this.currentPrice,
    this.lastNotifiedAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PriceDropAlert.fromJson(Map<String, dynamic> json) {
    return PriceDropAlert(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      propertyId: json['property_id'] as String,
      alertThreshold: (json['alert_threshold'] as num).toDouble(),
      originalPrice: (json['original_price'] as num).toDouble(),
      currentPrice: json['current_price'] != null 
          ? (json['current_price'] as num).toDouble() 
          : null,
      lastNotifiedAt: json['last_notified_at'] != null
          ? DateTime.parse(json['last_notified_at'] as String)
          : null,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'property_id': propertyId,
      'alert_threshold': alertThreshold,
      'original_price': originalPrice,
      'current_price': currentPrice,
      'last_notified_at': lastNotifiedAt?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Model for Price Drop Notification
class PriceDropNotification {
  final String id;
  final String userId;
  final String propertyId;
  final double oldPrice;
  final double newPrice;
  final double dropPercentage;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  PriceDropNotification({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.oldPrice,
    required this.newPrice,
    required this.dropPercentage,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory PriceDropNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    
    return PriceDropNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      propertyId: data['property_id'] as String? ?? '',
      oldPrice: (data['old_price'] as num?)?.toDouble() ?? 0.0,
      newPrice: (data['new_price'] as num?)?.toDouble() ?? 0.0,
      dropPercentage: (data['drop_percentage'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Service for managing price drop alerts
class PriceDropAlertService {
  final SupabaseClient _supabase;

  PriceDropAlertService(this._supabase);

  /// Create a price drop alert (Pro feature only)
  Future<PriceDropAlertResult> createAlert({
    required String userId,
    required String propertyId,
    required double threshold,
    required double originalPrice,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_price_drop_alert',
        params: {
          'p_user_id': userId,
          'p_property_id': propertyId,
          'p_threshold': threshold,
          'p_original_price': originalPrice,
        },
      );

      final result = response as Map<String, dynamic>;
      
      if (result['success'] == true) {
        return PriceDropAlertResult.success(
          alertId: result['alert_id'] as String,
        );
      } else {
        final error = result['error'] as String?;
        if (error == 'SUBSCRIPTION_REQUIRED') {
          return PriceDropAlertResult.subscriptionRequired(
            message: result['message'] as String,
          );
        }
        return PriceDropAlertResult.error(
          message: result['message'] as String? ?? 'Failed to create alert',
        );
      }
    } catch (e) {
      debugPrint('Error creating price drop alert: $e');
      return PriceDropAlertResult.error(
        message: 'An error occurred: ${e.toString()}',
      );
    }
  }

  /// Get all alerts for a user
  Future<List<PriceDropAlert>> getUserAlerts(String userId) async {
    try {
      final response = await _supabase
          .from('price_drop_alerts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PriceDropAlert.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user alerts: $e');
      return [];
    }
  }

  /// Get active alerts for a user
  Future<List<PriceDropAlert>> getActiveAlerts(String userId) async {
    try {
      final response = await _supabase
          .from('price_drop_alerts')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PriceDropAlert.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching active alerts: $e');
      return [];
    }
  }

  /// Get alert for a specific property
  Future<PriceDropAlert?> getAlertForProperty({
    required String userId,
    required String propertyId,
  }) async {
    try {
      final response = await _supabase
          .from('price_drop_alerts')
          .select()
          .eq('user_id', userId)
          .eq('property_id', propertyId)
          .maybeSingle();

      if (response == null) return null;
      
      return PriceDropAlert.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching property alert: $e');
      return null;
    }
  }

  /// Update alert threshold
  Future<bool> updateAlertThreshold({
    required String alertId,
    required double newThreshold,
  }) async {
    try {
      await _supabase
          .from('price_drop_alerts')
          .update({'alert_threshold': newThreshold})
          .eq('id', alertId);
      
      return true;
    } catch (e) {
      debugPrint('Error updating alert threshold: $e');
      return false;
    }
  }

  /// Toggle alert active status
  Future<bool> toggleAlert({
    required String alertId,
    required bool isActive,
  }) async {
    try {
      await _supabase
          .from('price_drop_alerts')
          .update({'is_active': isActive})
          .eq('id', alertId);
      
      return true;
    } catch (e) {
      debugPrint('Error toggling alert: $e');
      return false;
    }
  }

  /// Delete an alert
  Future<bool> deleteAlert(String alertId) async {
    try {
      await _supabase
          .from('price_drop_alerts')
          .delete()
          .eq('id', alertId);
      
      return true;
    } catch (e) {
      debugPrint('Error deleting alert: $e');
      return false;
    }
  }

  /// Get price drop notifications for user
  Future<List<PriceDropNotification>> getNotifications({
    required String userId,
    bool unreadOnly = false,
  }) async {
    try {
      var query = _supabase
          .from('notification_queue')
          .select()
          .eq('user_id', userId)
          .eq('notification_type', 'price_drop');

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => PriceDropNotification.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notification_queue')
          .update({'is_read': true})
          .eq('id', notificationId);
      
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read for user
  Future<bool> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notification_queue')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('notification_type', 'price_drop')
          .eq('is_read', false);
      
      return true;
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      return false;
    }
  }

  /// Stream of price drop alerts for a user
  Stream<List<PriceDropAlert>> alertsStream(String userId) {
    return _supabase
        .from('price_drop_alerts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          // Filter in-memory since stream doesn't support eq() in newer versions
          return data
              .where((json) => json['user_id'] == userId)
              .map((json) => PriceDropAlert.fromJson(json))
              .toList();
        });
  }

  /// Stream of price drop notifications for a user
  Stream<List<PriceDropNotification>> notificationsStream(String userId) {
    return _supabase
        .from('notification_queue')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          // Filter in-memory since stream doesn't support eq() in newer versions
          return data
              .where((json) => 
                  json['user_id'] == userId && 
                  json['notification_type'] == 'price_drop')
              .map((json) => PriceDropNotification.fromJson(json))
              .toList();
        });
  }

  /// Get count of unread notifications
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notification_queue')
          .select('id')
          .eq('user_id', userId)
          .eq('notification_type', 'price_drop')
          .eq('is_read', false);

      // Response is a List, so we just count the items
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
      return 0;
    }
  }

  /// Alternative: Get count using RPC function (more efficient for large datasets)
  Future<int> getUnreadCountOptimized(String userId) async {
    try {
      // You can create this RPC function in Supabase:
      // CREATE OR REPLACE FUNCTION get_unread_price_drop_count(p_user_id UUID)
      // RETURNS INTEGER AS $$
      // BEGIN
      //   RETURN (SELECT COUNT(*) FROM notification_queue 
      //           WHERE user_id = p_user_id 
      //           AND notification_type = 'price_drop' 
      //           AND is_read = false)::INTEGER;
      // END;
      // $$ LANGUAGE plpgsql SECURITY DEFINER;
      
      final response = await _supabase.rpc(
        'get_unread_price_drop_count',
        params: {'p_user_id': userId},
      );
      
      return response as int? ?? 0;
    } catch (e) {
      debugPrint('Error fetching unread count (optimized): $e');
      // Fallback to regular method
      return await getUnreadCount(userId);
    }
  }
}

/// Result model for price drop alert creation
class PriceDropAlertResult {
  final bool success;
  final String? alertId;
  final String? message;
  final PriceDropAlertError? error;

  PriceDropAlertResult._({
    required this.success,
    this.alertId,
    this.message,
    this.error,
  });

  factory PriceDropAlertResult.success({required String alertId}) {
    return PriceDropAlertResult._(
      success: true,
      alertId: alertId,
    );
  }

  factory PriceDropAlertResult.subscriptionRequired({required String message}) {
    return PriceDropAlertResult._(
      success: false,
      message: message,
      error: PriceDropAlertError.subscriptionRequired,
    );
  }

  factory PriceDropAlertResult.error({required String message}) {
    return PriceDropAlertResult._(
      success: false,
      message: message,
      error: PriceDropAlertError.general,
    );
  }
}

enum PriceDropAlertError {
  subscriptionRequired,
  general,
}