// lib/features/notifications/presentation/screens/notifications_screen.dart
// User notification inbox — reads from user_notifications Supabase table

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/app_navigator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class UserNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const UserNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  UserNotification copyWith({bool? isRead}) => UserNotification(
        id: id, type: type, title: title, message: message,
        data: data, isRead: isRead ?? this.isRead, createdAt: createdAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE + NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsState {
  final List<UserNotification> notifications;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<UserNotification>? notifications,
    bool? isLoading,
    String? error,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final SupabaseClient _supabase;
  final String _userId;
  RealtimeChannel? _channel;
  StreamSubscription<void>? _pushSub;

  NotificationsNotifier(this._supabase, this._userId)
      : super(const NotificationsState()) {
    if (_userId.isNotEmpty) {
      loadNotifications();
      _subscribeRealtime();
      // Belt-and-braces: also reload when a push is shown, so the inbox updates
      // even if the postgres-changes subscription above misses or lags the row.
      _pushSub = PushNotificationService.instance.onNotificationReceived
          .listen((_) => loadNotifications());
    }
  }

  /// Subscribe to Supabase Realtime so the inbox refreshes instantly
  /// whenever another part of the system (trigger, admin action, etc.)
  /// inserts a new row into user_notifications for this user.
  void _subscribeRealtime() {
    _channel = _supabase
        .channel('user_notifications:$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (_) => loadNotifications(), // reload on any change
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _pushSub?.cancel();
    super.dispose();
  }

  Future<void> loadNotifications() async {
    if (_userId.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _supabase
          .from('user_notifications')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(100);

      final notifications = (response as List)
          .map((json) => UserNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(notifications: notifications, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_userId.isEmpty) return;
    // Optimistic update — feel instant to the user
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
          .toList(),
    );
    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId)
          .eq('user_id', _userId);
    } catch (_) {
      // Revert optimistic update on failure
      await loadNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    if (_userId.isEmpty) return;
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );
    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', _userId)
          .eq('is_read', false);
    } catch (_) {
      await loadNotifications();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    if (_userId.isEmpty) return;
    final previous = state.notifications;
    // Optimistic removal
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != notificationId).toList(),
    );
    try {
      await _supabase
          .from('user_notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', _userId);
    } catch (_) {
      // Restore on failure
      state = state.copyWith(notifications: previous);
    }
  }

  Future<void> deleteAllRead() async {
    if (_userId.isEmpty) return;
    final previous = state.notifications;
    state = state.copyWith(
      notifications: state.notifications.where((n) => !n.isRead).toList(),
    );
    try {
      await _supabase
          .from('user_notifications')
          .delete()
          .eq('user_id', _userId)
          .eq('is_read', true);
    } catch (_) {
      state = state.copyWith(notifications: previous);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  // Use Supabase.instance.client directly — matches pattern used across the app
  final supabase = Supabase.instance.client;
  final userId = ref.watch(authNotifierProvider).value?.id ?? '';
  return NotificationsNotifier(supabase, userId);
});

/// Lightweight unread count — used by navigation badges
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // The provider is kept alive app-wide (the nav badge watches it), so opening
    // this screen does not re-run its constructor. Force a fresh load on open so
    // notifications received while away are shown without waiting for an event.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).loadNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allNotifications = state.notifications;
    final unreadNotifications = allNotifications.where((n) => !n.isRead).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ThemeConfig.getPrimaryColor(context),
          labelColor: isDark ? Colors.white : Colors.black87,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'All (${allNotifications.length})'),
            Tab(text: 'Unread (${unreadNotifications.length})'),
          ],
        ),
        actions: [
          // Mark all read
          if (unreadNotifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () => _showMarkAllReadDialog(notifier),
              tooltip: 'Mark all as read',
            ),
          // Delete read notifications
          if (allNotifications.any((n) => n.isRead))
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () => _showDeleteReadDialog(notifier),
              tooltip: 'Delete read',
            ),
        ],
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildError(state.error!)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // All notifications
                    _buildNotificationsList(
                      allNotifications,
                      notifier,
                      emptyMessage: 'No notifications yet',
                      emptyIcon: Icons.notifications_none_rounded,
                    ),
                    // Unread notifications
                    _buildNotificationsList(
                      unreadNotifications,
                      notifier,
                      emptyMessage: 'All caught up!',
                      emptyIcon: Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.red),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
        Text('Error loading notifications',
            style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), color: Colors.grey.shade700)),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        Text(error, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.grey)),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
        ElevatedButton.icon(
          onPressed: () => ref.read(notificationsProvider.notifier).loadNotifications(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ]),
    );
  }

  void _showMarkAllReadDialog(NotificationsNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark all as read?'),
        content: const Text('This will mark all notifications as read.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              notifier.markAllAsRead();
              Navigator.of(ctx).pop();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
    );
  }

  void _showDeleteReadDialog(NotificationsNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete read notifications?'),
        content: const Text('This will permanently delete all read notifications.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              notifier.deleteAllRead();
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    List<UserNotification> notifications,
    NotificationsNotifier notifier, {
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(emptyIcon, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.grey.shade400),
          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          Text(emptyMessage,
              style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.loadNotifications,
      color: ThemeConfig.getPrimaryColor(context),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return _NotificationTile(
            notification: notif,
            onTap: () {
              // Mark read first, then navigate
              notifier.markAsRead(notif.id);
              _handleTap(notif);
            },
            onDelete: () => notifier.deleteNotification(notif.id),
          );
        },
      ),
    );
  }

  /// Route to the relevant screen via the shared notification router, so taps
  /// inside the inbox behave exactly like push / banner taps on native, web and
  /// PWA. fallbackToInbox:false means a notification with no specific target
  /// just stays here instead of re-opening the inbox on top of itself.
  void _handleTap(UserNotification notif) {
    if (!context.mounted) return;
    navigateFromNotificationData(
      <String, dynamic>{
        'type': notif.type,
        if (notif.data != null) ...notif.data!,
      },
      fallbackToInbox: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final UserNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !notification.isRead;
    final primary = ThemeConfig.getPrimaryColor(context);

    final bgColor = isUnread
        ? (isDark ? primary.withOpacity(0.08) : primary.withOpacity(0.04))
        : (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      // Use InkWell instead of GestureDetector — supports ripple and semantics
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: _iconBgColor(notification.type), shape: BoxShape.circle),
                child: Icon(_iconFor(notification.type), color: Colors.white, size: ResponsiveHelper.getResponsiveIconSize(context)),
              ),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              // Content
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(notification.title,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          )),
                    ),
                    if (isUnread) ...[
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(notification.message,
                      style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.4),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(_formatTime(notification.createdAt),
                      style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                          color: isDark ? Colors.white38 : Colors.black38)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'property_deleted':       return Icons.home_outlined;
      case 'property_restored':      return Icons.home_rounded;
      case 'property_featured':      return Icons.star_rounded;
      case 'property_unfeatured':    return Icons.star_border_rounded;
      case 'property_verified':      return Icons.verified_rounded;
      case 'property_unverified':    return Icons.verified_outlined;
      case 'property_media_removed': return Icons.image_not_supported_outlined;
      case 'ad_approved':            return Icons.check_circle_rounded;
      case 'ad_rejected':            return Icons.cancel_rounded;
      case 'ad_removed':             return Icons.campaign_outlined;
      case 'ad_restored':            return Icons.campaign_rounded;
      case 'account_banned':         return Icons.block_rounded;
      case 'account_unbanned':       return Icons.check_circle_outline_rounded;
      case 'price_drop':             return Icons.trending_down_rounded;
      case 'payment_confirmed':      return Icons.payments_rounded;
      case 'message':
      case 'new_message':            return Icons.chat_bubble_outline_rounded;
      default:                       return Icons.notifications_outlined;
    }
  }

  Color _iconBgColor(String type) {
    switch (type) {
      case 'property_deleted':
      case 'ad_removed':
      case 'ad_rejected':
      case 'account_banned':
      case 'property_media_removed':  return Colors.red.shade400;
      case 'property_restored':
      case 'ad_approved':
      case 'ad_restored':
      case 'account_unbanned':
      case 'property_verified':
      case 'payment_confirmed':       return Colors.green.shade500;
      case 'property_featured':       return Colors.amber.shade600;
      case 'price_drop':              return Colors.orange.shade500;
      case 'message':
      case 'new_message':             return Colors.blue.shade500;
      default:                        return Colors.blueGrey.shade400;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}