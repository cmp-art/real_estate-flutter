// lib/core/providers/ip_country_provider.dart
//
// Detects the user's country via IP using the Supabase Edge Function
// `get-user-country`, which reads Cloudflare's CF-IPCountry header.
//
// - Cannot be spoofed by changing a profile setting.
// - Called ONCE per app session; Riverpod caches the result.
// - Used by ad targeting (getEligibleAds) and as the default property filter.
// - Returns null when country is unknown (local dev, edge function not deployed).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ipCountryProvider = FutureProvider<String?>((ref) async {
  try {
    final response = await Supabase.instance.client.functions
        .invoke('get-user-country');
    final data = response.data as Map<String, dynamic>?;
    final country = data?['country'] as String?;
    // 'XX' = Cloudflare couldn't determine country (local dev, VPN, etc.)
    if (country == null || country == 'XX') return null;
    debugPrint('🌍 IP country: $country');
    return country;
  } catch (e) {
    debugPrint('⚠️ IP country detection failed: $e');
    return null;
  }
});
