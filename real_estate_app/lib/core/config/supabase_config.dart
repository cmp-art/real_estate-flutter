// lib/core/config/supabase_config.dart
//
// BUG THAT WAS HERE (now fixed):
//   dotenv.env['https://qeddjlmexurmeiuslgqn.supabase.co']
//   ↑ This uses the URL itself as the env-var KEY — always returns null!
//   The fallback was '' so SupabaseConfig.supabaseUrl always returned ''
//   while only main.dart's direct dotenv.env['SUPABASE_URL'] worked.
//
// FIX: Use the correct keys that match what is in assets/.env

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // ── Supabase credentials ─────────────────────────────────────────────────
  // Keys must match those in assets/.env exactly:
  //   SUPABASE_URL=https://qeddjlmexurmeiuslgqn.supabase.co
  //   SUPABASE_ANON_KEY=sb_publishable_...
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // ── Storage bucket names ─────────────────────────────────────────────────
  static const String propertyImagesBucket = 'property-images';
  static const String profileImagesBucket = 'profile-images';

  // ── Deep-link scheme for auth callbacks ──────────────────────────────────
  // Must match the <data android:scheme="realestateapp" /> intent-filter
  // and the Supabase Dashboard → Auth → URL Configuration redirect URL.
  static const String deepLinkScheme = 'realestateapp';
  static const String resetPasswordPath = 'reset-password';
  static const String resetCallbackPath = 'reset-callback';

  static String get resetPasswordRedirectUrl =>
      '$deepLinkScheme://$resetPasswordPath';

  static String get resetCallbackRedirectUrl =>
      '$deepLinkScheme://$resetCallbackPath';

  // ── Supabase built-in image transformation URL ───────────────────────────
  // Supabase Storage provides a free image-resize CDN endpoint at:
  //   /storage/v1/render/image/public/<bucket>/<path>?width=W&height=H&quality=Q
  // No external CDN is required — use this for all thumbnail generation.
  static String renderImageUrl(
    String storagePath, {
    int? width,
    int? height,
    int quality = 75,
  }) {
    if (storagePath.isEmpty || supabaseUrl.isEmpty) return storagePath;
    final params = <String, String>{};
    if (width != null) params['width'] = '$width';
    if (height != null) params['height'] = '$height';
    params['quality'] = '$quality';
    final base = '$supabaseUrl/storage/v1/render/image/public/$storagePath';
    return Uri.parse(base).replace(queryParameters: params).toString();
  }
}
