// web_push_js.dart — web-only implementation using dart:js_interop
// Imported automatically on Flutter web builds (dart.library.io is absent).
//
// Calls window.patamjengoShowNotification() defined in web/index.html to show
// a browser Notification banner when the tab is in the foreground.
// Background / PWA-closed push is handled by FCM (firebase-messaging-sw.js).

import 'dart:js_interop';

@JS('patamjengoShowNotification')
external void _patamjengoShowNotification(String title, String body);

/// Show a browser Notification banner while the tab is focused.
void showWebNotification(String title, String body) {
  try {
    _patamjengoShowNotification(title, body);
  } catch (_) {}
}
