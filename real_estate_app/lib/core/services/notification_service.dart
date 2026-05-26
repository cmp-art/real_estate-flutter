// lib/core/services/notification_service.dart
//
// In-app notification service — backed entirely by Supabase.
// No push / Firebase / FCM required.
//
// Delivery model:
//   Write  → INSERT into user_notifications (done by SQL triggers or this service)
//   Read   → SELECT from user_notifications
//   Live   → Supabase Realtime stream — the app receives new rows instantly
//             without polling, as long as user_notifications is in the
//             supabase_realtime publication (sql5_notifications.sql does this).
//
// Usage in your widget tree:
//   1. Call NotificationService(supabase).streamNotifications(userId)
//      to get a live Stream<List<UserNotification>>.
//   2. The NotificationsNotifier in notifications_screen.dart already does this.
//   3. Call the typed helpers (notifyPropertyApproved, etc.) from admin_service.dart
//      or ai_validation_service.dart right after the relevant event fires.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TYPE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum NotificationType {
  priceChange,
  newProperty,
  priceDrop,
  message,
  propertyUpdate,
  propertyApproved,
  propertyRejected,
  adApproved,
  adRejected,
  system;

  String get value {
    switch (this) {
      case NotificationType.priceChange:      return 'price_change';
      case NotificationType.newProperty:      return 'new_property';
      case NotificationType.priceDrop:        return 'price_drop';
      case NotificationType.message:          return 'message';
      case NotificationType.propertyUpdate:   return 'property_update';
      case NotificationType.propertyApproved: return 'property_approved';
      case NotificationType.propertyRejected: return 'property_rejected';
      case NotificationType.adApproved:       return 'ad_approved';
      case NotificationType.adRejected:       return 'ad_rejected';
      case NotificationType.system:           return 'system';
    }
  }

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class UserNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;   // deep-link payload: property_id, ad_id, etc.
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const UserNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id:        json['id']      as String,
      userId:    json['user_id'] as String,
      type:      NotificationType.fromString(json['type'] as String? ?? 'system'),
      title:     json['title']   as String? ?? '',
      message:   json['message'] as String? ?? '',
      data:      json['data'] != null
                     ? Map<String, dynamic>.from(json['data'] as Map)
                     : null,
      isRead:    json['is_read'] as bool? ?? false,
      readAt:    json['read_at'] != null
                     ? DateTime.tryParse(json['read_at'] as String)
                     : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  UserNotification copyWith({bool? isRead, DateTime? readAt}) {
    return UserNotification(
      id: id, userId: userId, type: type,
      title: title, message: message, data: data,
      isRead:    isRead    ?? this.isRead,
      readAt:    readAt    ?? this.readAt,
      createdAt: createdAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  // ══════════════════════════════════════════════════════════════════════════
  // REALTIME STREAM
  // ══════════════════════════════════════════════════════════════════════════

  /// Live stream of all notifications for [userId], newest first.
  ///
  /// Powered by Supabase Realtime — the stream emits a new list every time
  /// a row is inserted, updated, or deleted in user_notifications for this user.
  ///
  /// Prerequisite: user_notifications must be in the supabase_realtime
  /// publication. sql5_notifications.sql takes care of this.
  ///
  /// Usage:
  /// ```dart
  /// final stream = NotificationService(supabase).streamNotifications(userId);
  /// StreamBuilder<List<UserNotification>>(
  ///   stream: stream,
  ///   builder: (context, snapshot) { ... },
  /// );
  /// ```
  Stream<List<UserNotification>> streamNotifications(String userId) {
    if (userId.isEmpty) return const Stream.empty();

    return _supabase
        .from('user_notifications')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final list = rows
              .where((r) => r['user_id'] == userId)
              .map((r) => UserNotification.fromJson(r))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Live unread count stream — use this to drive the badge in the nav bar.
  Stream<int> streamUnreadCount(String userId) {
    return streamNotifications(userId)
        .map((list) => list.where((n) => !n.isRead).length);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ONE-SHOT READS (for initial load / pull-to-refresh)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<UserNotification>> getNotifications(String userId, {int limit = 100}) async {
    if (userId.isEmpty) return [];
    try {
      final response = await _supabase
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((e) => UserNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NotificationService] getNotifications: $e');
      return [];
    }
  }

  Future<int> getUnreadCount(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final r = await _supabase
          .from('user_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (r as List).length;
    } catch (_) { return 0; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WRITES — in-app notification creation
  // ══════════════════════════════════════════════════════════════════════════

  /// Insert a single in-app notification.
  ///
  /// Push delivery is handled SERVER-SIDE and DECOUPLED from this INSERT: the
  /// process_push_queue() pg_cron worker (sql5) POSTs every unpushed
  /// user_notifications row to the send-push-notification Edge Function every
  /// ~10s, then stamps pushed_at. That worker is the single push path — it also
  /// covers server-generated notifications (price alerts, admin actions) that
  /// never pass through this client. We must NOT invoke the function from here,
  /// or every app-created notification would be delivered twice.
  Future<bool> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (userId.isEmpty) return false;
    try {
      await _supabase.from('user_notifications').insert({
        'user_id': userId,
        'type':    type.value,
        'title':   title,
        'message': message,
        'data':    data,
        'is_read': false,
      });
      return true;
    } catch (e) {
      debugPrint('[NotificationService] createNotification: $e');
      return false;
    }
  }

  // ── Typed convenience methods — called from admin_service.dart / ai_validation_service.dart ──

  Future<bool> notifyPropertyApproved(String userId, String propertyId, String propertyTitle) =>
      createNotification(
        userId: userId, type: NotificationType.propertyApproved,
        title:   '✅ Listing approved',
        message: '"$propertyTitle" is now live on the platform.',
        data:    {'property_id': propertyId},
      );

  Future<bool> notifyPropertyRejected(
      String userId, String propertyId, String propertyTitle, String reason) =>
      createNotification(
        userId: userId, type: NotificationType.propertyRejected,
        title:   '❌ Listing not approved',
        message: '"$propertyTitle" was not approved: $reason',
        data:    {'property_id': propertyId, 'reason': reason},
      );

  Future<bool> notifyAdApproved(String userId, String adId, String adName) =>
      createNotification(
        userId: userId, type: NotificationType.adApproved,
        title:   '✅ Ad approved',
        message: '"$adName" is now running.',
        data:    {'ad_id': adId},
      );

  Future<bool> notifyAdRejected(String userId, String adId, String adName, String reason) =>
      createNotification(
        userId: userId, type: NotificationType.adRejected,
        title:   '❌ Ad not approved',
        message: '"$adName": $reason',
        data:    {'ad_id': adId, 'reason': reason},
      );

  /// Price drop alerts — Pro users only, max 1 notification per property per 24h.
  Future<bool> notifyPriceDrop(
      String userId, String propertyId, String propertyTitle,
      double oldPrice, double newPrice) async {
    // Pro-only: free users don't get price drop alerts
    try {
      final sub = await _supabase
          .from('user_subscriptions')
          .select('subscription_tiers(name)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();
      final tier = sub?['subscription_tiers']?['name'] as String?;
      if (tier == null || tier == 'free') return false;
    } catch (_) {
      return false;
    }

    // Rate limit: max 1 price-drop notification per property per 24h
    try {
      final recent = await _supabase
          .from('user_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('type', 'price_drop')
          .filter('data->>property_id', 'eq', propertyId)
          .gte('created_at',
              DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String())
          .limit(1)
          .maybeSingle();
      if (recent != null) return false; // already notified today
    } catch (_) { /* proceed */ }

    return createNotification(
      userId: userId, type: NotificationType.priceDrop,
      title:   '📉 Price drop!',
      message: '"$propertyTitle" dropped to TZS ${newPrice.toStringAsFixed(0)}',
      data:    {'property_id': propertyId, 'old_price': oldPrice, 'new_price': newPrice},
    );
  }

  Future<bool> notifyNewMessage(String userId, String conversationId, String senderName) =>
      createNotification(
        userId: userId, type: NotificationType.message,
        title:   '💬 New message',
        message: '$senderName sent you a message.',
        data:    {'conversation_id': conversationId},
      );

  Future<bool> notifyManualReviewComplete(
      String userId, String contentId, String contentType,
      bool approved, String? reason) =>
      createNotification(
        userId: userId,
        type:   approved ? NotificationType.propertyApproved : NotificationType.propertyRejected,
        title:  approved ? '✅ Review complete' : '❌ Review complete',
        message: approved
            ? 'Your $contentType has been approved and is now live.'
            : 'Your $contentType was not approved${reason != null ? ': $reason' : '.'}',
        data:   {'content_id': contentId, 'content_type': contentType},
      );

  // ══════════════════════════════════════════════════════════════════════════
  // MARK AS READ / DELETE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markRead(String notificationId, String userId) async {
    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[NotificationService] markRead: $e');
    }
  }

  Future<void> markAllRead(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationService] markAllRead: $e');
    }
  }

  Future<void> deleteNotification(String notificationId, String userId) async {
    try {
      await _supabase
          .from('user_notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[NotificationService] deleteNotification: $e');
    }
  }

  Future<void> deleteAllRead(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _supabase
          .from('user_notifications')
          .delete()
          .eq('user_id', userId)
          .eq('is_read', true);
    } catch (e) {
      debugPrint('[NotificationService] deleteAllRead: $e');
    }
  }
}