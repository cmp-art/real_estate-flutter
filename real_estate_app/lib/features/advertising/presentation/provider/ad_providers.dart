// lib/core/providers/ad_providers.dart
//
// SINGLE SOURCE OF TRUTH for all advertising-related Riverpod providers.
// Import this file anywhere you need ad services — NEVER redefine these
// providers in other files (add_funds_screen, advertiser_dashboard, etc.)
// Doing so creates duplicate Riverpod provider identities and breaks state sharing.
//
// Frequency / placement constants live in:
//   lib/core/config/ad_config.dart  ← single source of truth for numbers
// Both DirectAdService and DirectAdAlgorithm read from there.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
export '../../../../core/config/ad_config.dart' show AdConfig;
import '../../../../core/algorithm/ad_display_algorithm.dart';
// production constants
import '../../../../core/services/direct_ad_service.dart';
import '../../../../core/services/subscription_service.dart';


// ── Supabase client ──────────────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ── Subscription service ─────────────────────────────────────────────────────
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SubscriptionService(supabase);
});

// ── Direct ad service ────────────────────────────────────────────────────────
final directAdServiceProvider = Provider<DirectAdService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return DirectAdService(supabase, subscriptionService);
});

// ── Direct ad algorithm ───────────────────────────────────────────────────────
// Used by CreateCampaignScreen for revenue estimates (estimateCampaignRevenue,
// getRecommendedBid) and ad placement config. Does NOT replace the SQL-based
// get_eligible_ads — it wraps DirectAdService for client-side logic only.
final directAdAlgorithmProvider = Provider<DirectAdAlgorithm>((ref) {
  final adService = ref.watch(directAdServiceProvider);
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return DirectAdAlgorithm(adService, subscriptionService);
});

// ── Ad display config ─────────────────────────────────────────────────────────
// AdConfig.adFrequencyFree / adFrequencyBasic / adFrequencyPro are read by
// DirectAdService.getAdFrequencyForUser() and PropertyListScreen.
// This re-export makes it available to any screen that imports ad_providers.dart.
// ignore: unused_import
