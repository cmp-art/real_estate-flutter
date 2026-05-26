// lib/core/utils/app_navigator.dart
//
// Global navigator key + notification-tap routing.
//
// Lets non-widget code (push notifications, deep links) drive navigation on the
// root navigator without a BuildContext.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/properties/presentation/screens/property_detail_screen.dart';
import '../../features/settings/presentation/screens/notifications_screen.dart';
import 'logger.dart';

/// Root navigator key — wired into [MaterialApp.navigatorKey] in app.dart.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes the user to the screen referenced by a notification's data payload.
///
/// Accepts the FCM `data` map (background / killed-state taps) or the decoded
/// payload of a foreground local banner. Understood keys: `property_id` →
/// property detail; `conversation_id` → conversation list; anything else →
/// the in-app notifications inbox.
///
/// On a cold start the navigator isn't mounted yet when the tap is delivered,
/// so this retries briefly until it becomes available.
Future<void> navigateFromNotificationData(Map<String, dynamic> data) async {
  final destination = _destinationFor(data);
  if (destination == null) return;

  for (var attempt = 0; attempt < 20; attempt++) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator != null) {
      navigator.push(MaterialPageRoute(builder: (_) => destination));
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  logger.w('navigateFromNotificationData: navigator never became available');
}

Widget? _destinationFor(Map<String, dynamic> data) {
  final propertyId = data['property_id']?.toString();
  if (propertyId != null && propertyId.isNotEmpty) {
    return PropertyDetailScreen(propertyId: propertyId);
  }

  final isSignedIn = Supabase.instance.client.auth.currentUser != null;

  // ChatScreen needs participant details the push payload doesn't carry, so a
  // message tap lands on the conversation list (only meaningful when signed in).
  final conversationId = data['conversation_id']?.toString();
  if (conversationId != null && conversationId.isNotEmpty) {
    return isSignedIn ? const ConversationsScreen() : null;
  }

  // Any other type (system alerts, approvals without a property_id, etc.) →
  // open the inbox so the tap always goes somewhere sensible.
  return isSignedIn ? const NotificationsScreen() : null;
}
