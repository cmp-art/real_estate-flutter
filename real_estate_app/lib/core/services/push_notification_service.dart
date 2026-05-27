// lib/core/services/push_notification_service.dart
//
// Unified push notification service — Supabase + Firebase Cloud Messaging (FCM).
//
// FCM is 100% free (no cost per message, no limits):
//   https://firebase.google.com/pricing
//
// Delivery strategy:
//   ┌─────────────────────────┬──────────────────────────────────────────────┐
//   │ Situation               │ Mechanism                                    │
//   ├─────────────────────────┼──────────────────────────────────────────────┤
//   │ App open (all platforms)│ Supabase Realtime → local banner (instant)   │
//   │ Android background/kill │ FCM → OS shows push banner                   │
//   │ iOS background/killed   │ FCM → APNs → OS shows push banner            │
//   │ Web tab open            │ Browser Notification API (JS interop)        │
//   │ Web tab closed / PWA    │ FCM → firebase-messaging-sw.js shows banner  │
//   └─────────────────────────┴──────────────────────────────────────────────┘

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/app_navigator.dart';
import '../utils/logger.dart';

// Conditional import: web_push_js.dart on Flutter web (dart:js_interop),
// web_push_stub.dart (no-ops) on Android / iOS.
// dart.library.io is available on native but NOT on Flutter web.
import 'web_push_js.dart' if (dart.library.io) 'web_push_stub.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _realtimeChannel;
  bool _initialized = false;

  // Fires whenever a notification is shown (Supabase Realtime banner or FCM
  // push). In-app screens — chiefly the notifications inbox — listen to this so
  // they refresh live even when their own postgres-changes Realtime stream is
  // slow or not delivering. Broadcast so multiple screens can subscribe.
  final StreamController<void> _arrivals = StreamController<void>.broadcast();
  Stream<void> get onNotificationReceived => _arrivals.stream;

  // ── Initialise ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;

    if (!kIsWeb) {
      // Android / iOS: set up flutter_local_notifications for foreground banners
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
        const InitializationSettings(
            android: android, iOS: darwin, macOS: darwin),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      // Android 13+ explicit permission request
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();

      // Diagnostic: if this logs `false`, the OS is blocking ALL tray banners
      // (foreground local + background FCM) — the app can't re-prompt once the
      // user has denied, so they must enable it in system Settings.
      final enabled = await androidPlugin?.areNotificationsEnabled();
      debugPrint('🔔 Android notifications enabled: $enabled');

      // Create the high-importance channel up-front so OS-rendered background /
      // killed FCM notifications use it (heads-up banner) instead of a
      // default-importance fallback. Must match the id used in show() and the
      // manifest's default_notification_channel_id meta-data.
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'patamjengo_main',
          'Patamjengo Alerts',
          description:
              'Property price drops, new listings, messages, and system alerts',
          importance: Importance.high,
        ),
      );
    }

    // Local-notification setup above is the critical path for showing banners
    // while the app is open. Mark the service ready NOW so show() can render
    // even if the FCM block below throws (e.g. Firebase failed to init on this
    // device). Previously a single FCM failure left _initialized = false, and
    // every later show() call re-ran initialize(), re-threw, and rendered
    // nothing — so no banner appeared in the tray on either platform.
    _initialized = true;

    // ── FCM permission + foreground / tap handlers (best-effort) ────────────
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground FCM message → render it ourselves via the local-notifications
      // plugin so it lands in the system tray on BOTH Android and iOS (iOS does
      // not display notification messages while the app is foregrounded). The
      // Supabase Realtime banner may also fire for the same row; both use the
      // notification's row id as the integer id, so the OS collapses them into a
      // single tray entry (a same-id show() updates instead of duplicating).
      FirebaseMessaging.onMessage.listen(_showFromRemote);

      // User tapped a notification while the app was in the background (not killed)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification tapped from background: ${message.data}');
        navigateFromNotificationData(message.data);
      });

      // Check if app was launched by tapping a notification (killed state)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            '[FCM] App launched from notification: ${initialMessage.data}');
        navigateFromNotificationData(initialMessage.data);
      }

      debugPrint('✅ PushNotificationService initialized (FCM + Realtime)');
    } catch (e) {
      debugPrint('⚠️  FCM setup failed (local foreground banners still work): $e');
    }
  }

  // Render a foreground FCM message as a real system-tray notification.
  void _showFromRemote(RemoteMessage message) {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] ?? 'Patamjengo';
    final body = n?.body ?? message.data['message'] ?? '';
    final notifId = message.data['notification_id'] ?? '';
    show(
      title: title,
      body: body,
      payload: jsonEncode(message.data),
      id: notifId.isNotEmpty ? notifId.hashCode : title.hashCode,
    );
  }

  // ── Subscribe to Supabase Realtime (foreground banners) ──────────────────
  void subscribeToNotifications(String userId) {
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = Supabase.instance.client
        .channel('push:user_notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final title = row['title'] as String? ?? 'New Notification';
            final message = row['message'] as String? ?? '';
            final id = row['id'] as String? ?? '';
            // Encode routing data (type + the notification's data map) so a tap
            // on this foreground banner deep-links the same way a background FCM
            // tap does. _onNotificationTap decodes it.
            final data = row['data'];
            final routeData = <String, dynamic>{
              'type': row['type'],
              'notification_id': id,
              if (data is Map) ...Map<String, dynamic>.from(data),
            };
            show(
              title: title,
              body: message,
              payload: jsonEncode(routeData),
              id: id.hashCode,
            );
          },
        )
        .subscribe();

    // Register FCM token so the Edge Function can deliver background pushes
    _registerFcmToken(userId);

    debugPrint('📡 PushNotificationService subscribed for user $userId');
  }

  void unsubscribe() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  // ── Register FCM token in Supabase device_push_tokens ────────────────────
  Future<void> _registerFcmToken(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      String? token;

      if (kIsWeb) {
        // Web: use custom VAPID key if set, otherwise Firebase uses its default key.
        // VAPID key: Firebase Console → Project Settings → Cloud Messaging →
        // Web configuration → Generate key pair → add to .env as FIREBASE_VAPID_KEY
        final vapidKey = dotenv.env['FIREBASE_VAPID_KEY'] ?? '';
        token = vapidKey.isNotEmpty
            ? await messaging.getToken(vapidKey: vapidKey)
            : await messaging.getToken();
      } else {
        token = await messaging.getToken();
      }

      if (token == null || token.isEmpty) return;

      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'ios';

      await _upsertToken(userId: userId, token: token, platform: platform);

      // Keep token fresh on refresh
      messaging.onTokenRefresh.listen((newToken) {
        _upsertToken(userId: userId, token: newToken, platform: platform);
      });

      debugPrint('✅ FCM token registered ($platform)');
    } catch (e) {
      debugPrint('⚠️  FCM token registration failed: $e');
    }
  }

  Future<void> _upsertToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    await Supabase.instance.client.from('device_push_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': platform,
        'is_active': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,platform',
    );
  }

  // ── Deregister token on logout ────────────────────────────────────────────
  Future<void> deregisterDeviceToken(String userId, String platform) async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      await Supabase.instance.client
          .from('device_push_tokens')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('platform', platform);
    } catch (e) {
      logger.w('Failed to deregister push token', error: e);
    }
  }

  // ── Show a local notification banner ─────────────────────────────────────
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    // Tell any open in-app screen (e.g. the inbox) that a notification arrived,
    // so it can reload immediately even if its Realtime stream missed the row.
    _arrivals.add(null);

    if (kIsWeb) {
      // Web foreground: use browser Notification API via JS interop
      showWebNotification(title, body);
      return;
    }
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'patamjengo_main',
      'Patamjengo Alerts',
      channelDescription:
          'Property price drops, new listings, messages, and system alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      // A foreground push can arrive twice (Supabase Realtime + FCM onMessage).
      // Both use the same row-id-derived integer id, so the second show() just
      // updates the first; onlyAlertOnce stops that update from buzzing again.
      onlyAlertOnce: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // iOS 14+: `alert` is split into banner + list. Without presentList,
          // a foreground notification flashes as a banner but never lands in
          // Notification Center, so it "doesn't stay" in the panel. presentList
          // keeps it there; presentBanner ensures the heads-up still shows.
          presentBanner: true,
          presentList: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      payload: payload,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        navigateFromNotificationData(decoded);
      }
    } catch (_) {
      // Plain/legacy payload (not JSON) — nothing to route to.
    }
  }
}
