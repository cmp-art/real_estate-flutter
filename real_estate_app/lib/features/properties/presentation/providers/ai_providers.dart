// lib/core/providers/ai_providers.dart
//
// Riverpod providers for AI Validation and AI Search.
//
// The Anthropic API key is stored ONLY as a Supabase Edge Function secret.
// It is NEVER fetched to the client device.
// All AI calls go through the validate-content Edge Function (server-side proxy).
//
// To set/update the key:
//   Supabase Dashboard → Edge Functions → Secrets → ANTHROPIC_API_KEY

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/ai_search_service.dart';
import '../../../../core/services/ai_validation_service.dart';

// ── Supabase client ──────────────────────────────────────────────────────────
final _supabaseProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ── AI Validation Service ────────────────────────────────────────────────────
// Simple synchronous Provider — the service fetches its own API key lazily
// from Supabase on the first validateProperty/validateAd call.
// No async provider needed, no race condition possible.
final aiValidationServiceProvider = Provider<AiValidationService>((ref) {
  final supabase = ref.watch(_supabaseProvider);
  return AiValidationService(supabase);
});

// ── AI Search Service (on-device, free) ─────────────────────────────────────
final aiSearchServiceProvider = Provider<AiSearchService>(
  (_) => AiSearchService(),
);