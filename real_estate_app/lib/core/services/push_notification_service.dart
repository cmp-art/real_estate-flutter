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

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // ── FCM permission + foreground / tap handlers ──────────────────────────
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground FCM message: Supabase Realtime already shows a banner faster,
    // so we intentionally skip here to prevent duplicate notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          '[FCM] Foreground message (handled by Realtime): ${message.notification?.title}');
    });

    // User tapped a notification while the app was in the background (not killed)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification tapped from background: ${message.data}');
      // The app's router can listen to this stream for navigation.
    });

    // Check if app was launched by tapping a notification (killed state)
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          '[FCM] App launched from notification: ${initialMessage.data}');
    }

    _initialized = true;
    debugPrint('✅ PushNotificationService initialized (FCM + Realtime)');
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
            show(title: title, body: message, payload: id, id: id.hashCode);
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
    } catch (_) {}
  }

  // ── Show a local notification banner ─────────────────────────────────────
  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
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
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }
}
