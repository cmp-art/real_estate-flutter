// web_push_stub.dart — no-op for non-web platforms (Android, iOS)
// Imported automatically on native builds via conditional import in
// push_notification_service.dart.

/// No-op on native platforms — flutter_local_notifications handles banners.
void showWebNotification(String title, String body) {}
