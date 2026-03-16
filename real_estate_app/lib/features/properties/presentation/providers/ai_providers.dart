// lib/core/providers/ai_providers.dart
//
// Riverpod providers for AI Validation and AI Search.
//
// The Claude API key is stored in Supabase `app_config` table.
// AiValidationService now fetches the key itself on first use (lazy load),
// eliminating the race condition where the key wasn't ready at construction.
//
// To set your key, run in the Supabase SQL Editor:
//   UPDATE app_config
//   SET value = 'sk-ant-api03-YOUR-KEY-HERE'
//   WHERE key = 'claude_api_key';

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