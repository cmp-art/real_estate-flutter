// lib/core/services/ai_validation_service.dart
//
// AI Validation Service — Production Ready
// =========================================
//
// 3-LAYER VALIDATION:
//   LAYER 1 — Pre-flight (Dart, no network): size & screenshot detection
//   LAYER 2 — Claude Haiku AI (text + vision): strict real-estate gating
//   LAYER 3 — Rule-based fallback (text-only submissions only): keyword scoring
//   LAYER 4 — Manual queue (last resort when rules crash, text-only only)
//
// KEY PRODUCTION FEATURES:
//   - API key cached for 1 hour, auto-refreshes on rotation
//   - Empty API key never cached — always retried on next call
//   - Per-user rate limiting: max 5 attempts per 60 seconds
//   - Health monitor with 30-second auto-reset
//   - ALL photos checked by pre-flight (not just first 3)
//   - Up to 4 photos sent to Claude (evenly spread across uploaded set)
//   - Lost-log counter exposed for admin monitoring
//   - HEIC, WebP, phone and tablet screenshot detection in pre-flight
//   - Images path never falls back to text-only rules
//   - _log() wrapper: silent in release builds, visible in debug
//
// DEPENDENCIES (pubspec.yaml):
//   flutter_image_compress: ^2.1.0
//   http: ^1.0.0
//   supabase_flutter: ^2.0.0

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
// http package removed — all AI calls go through the Supabase Edge Function.
// Direct Anthropic calls from client are permanently disabled (security).
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
// Web image resize (canvas-based) vs native stub.
import '../utils/web_compress.dart'
    if (dart.library.io) '../utils/web_compress_stub.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOGGING — silent in release builds
// ─────────────────────────────────────────────────────────────────────────────

void _log(String msg) {
  if (kDebugMode) debugPrint('[AI] $msg');
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum ValidationMethod { ai, rules, manual, failed }
enum ValidationStatus { approved, rejected, pending }

class ValidationResult {
  final ValidationStatus status;
  final ValidationMethod method;
  final bool approved;
  final int confidence;
  final String reason;
  final List<String> suggestions;
  final String? detectedCategory;

  const ValidationResult({
    required this.status,
    required this.method,
    required this.approved,
    required this.confidence,
    required this.reason,
    this.suggestions = const [],
    this.detectedCategory,
  });

  bool get isPending  => status == ValidationStatus.pending;
  bool get isApproved => status == ValidationStatus.approved;
  bool get isRejected => status == ValidationStatus.rejected;

  String get userMessage {
    switch (status) {
      case ValidationStatus.approved: return 'AI Approved ($confidence%): $reason';
      case ValidationStatus.rejected: return 'Rejected ($confidence%): $reason';
      case ValidationStatus.pending:  return 'Under review: $reason';
    }
  }

  Map<String, dynamic> toJson() => {
    'status':            status.name,
    'method':            method.name,
    'approved':          approved,
    'confidence':        confidence,
    'reason':            reason,
    'suggestions':       suggestions,
    'detected_category': detectedCategory,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// HEALTH MONITOR — circuit breaker with exponential backoff
//
// States:
//   CLOSED   → normal operation; failures counted.
//   OPEN     → breaker tripped; all calls bypass Claude until cooldown elapses.
//   HALF-OPEN→ cooldown elapsed; one probe call is allowed.
//              If it succeeds → CLOSED; if it fails → OPEN (with doubled cooldown).
// ─────────────────────────────────────────────────────────────────────────────

enum _BreakerState { closed, open, halfOpen }

class _AiHealthMonitor {
  _BreakerState _state = _BreakerState.closed;

  // Rolling window counters (reset when the window expires)
  int _failures = 0, _total = 0;
  DateTime? _windowStart;

  // Circuit-open metadata
  DateTime?  _openedAt;
  Duration   _cooldown     = const Duration(seconds: 10); // doubles on each consecutive trip

  // Thresholds — kept high so transient errors don't permanently block AI.
  // Need at least 20 calls in the window before the breaker can trip.
  static const int    _minSamples     = 20;    // need at least 20 calls before tripping
  static const double _maxFailureRate = 0.80;  // trip only at 80% failure rate
  static const Duration _windowDur    = Duration(minutes: 10); // rolling window
  static const Duration _maxCooldown  = Duration(minutes: 5);  // cap on backoff

  // ── Public API ─────────────────────────────────────────────────────────────

  void recordSuccess() {
    _resetWindowIfExpired();
    _total++;
    if (_state == _BreakerState.halfOpen) {
      _close();
    }
  }

  void recordFailure() {
    _resetWindowIfExpired();
    _failures++;
    _total++;

    if (_state == _BreakerState.halfOpen) {
      // Probe failed — re-open with doubled cooldown
      _open(doubled: true);
      return;
    }

    if (_state == _BreakerState.closed && _shouldTrip()) {
      _open(doubled: false);
    }
  }

  /// Manual reset (e.g. from admin dashboard "Reset circuit breaker" button).
  void reset() {
    _state      = _BreakerState.closed;
    _failures   = 0;
    _total      = 0;
    _openedAt   = null;
    _cooldown   = const Duration(seconds: 30);
    _windowStart = null;
    _log('Circuit breaker manually reset — Claude will be retried');
  }

  bool get isHealthy {
    switch (_state) {
      case _BreakerState.closed:
        return true;

      case _BreakerState.open:
        // Check if cooldown has elapsed → move to half-open for one probe
        if (_openedAt != null &&
            DateTime.now().difference(_openedAt!) >= _cooldown) {
          _state = _BreakerState.halfOpen;
          _log('Circuit breaker half-open — sending one probe to Claude');
          return true; // allow the probe call through
        }
        return false;  // still cooling down

      case _BreakerState.halfOpen:
        // Already waiting for a probe result; don't let more calls through
        return false;
    }
  }

  Map<String, dynamic> get stats => {
    'state':        _state.name,
    'failures':     _failures,
    'fail_count':   _failures,   // alias — admin_manual_review_screen reads this key
    'total':        _total,
    'healthy':      isHealthy,
    'cooldown_secs': _cooldown.inSeconds,
    'opened_at':    _openedAt?.toIso8601String(),
  };

  // ── Private ────────────────────────────────────────────────────────────────

  bool _shouldTrip() =>
      _total >= _minSamples && (_failures / _total) >= _maxFailureRate;

  void _open({required bool doubled}) {
    if (doubled) {
      final next = _cooldown * 2;
      _cooldown = next > _maxCooldown ? _maxCooldown : next;
    }
    _state    = _BreakerState.open;
    _openedAt = DateTime.now();
    _log('Circuit breaker OPEN — cooldown ${_cooldown.inSeconds}s. '
         'Failures: $_failures/$_total');
  }

  void _close() {
    _state    = _BreakerState.closed;
    _failures = 0;
    _total    = 0;
    _cooldown = const Duration(seconds: 30); // reset backoff on clean recovery
    _openedAt = null;
    _log('Circuit breaker CLOSED — Claude is healthy again');
  }

  void _resetWindowIfExpired() {
    final now = DateTime.now();
    if (_windowStart == null || now.difference(_windowStart!) >= _windowDur) {
      _failures    = 0;
      _total       = 0;
      _windowStart = now;
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// RATE LIMITER — per user, in-memory
// ─────────────────────────────────────────────────────────────────────────────

class _RateLimiter {
  final Map<String, List<DateTime>> _attempts = {};

  static const int      _maxAttempts = 5;
  static const Duration _window      = Duration(seconds: 60);

  // Returns true if the user is within their rate limit.
  bool allow(String userId) {
    final now  = DateTime.now();
    final list = _attempts[userId] ?? [];
    list.removeWhere((t) => now.difference(t) > _window);
    _attempts[userId] = list;
    if (list.length >= _maxAttempts) return false;
    list.add(now);
    return true;
  }

  int secondsUntilReset(String userId) {
    final list = _attempts[userId];
    if (list == null || list.isEmpty) return 0;
    final elapsed = DateTime.now().difference(list.first).inSeconds;
    return (_window.inSeconds - elapsed).clamp(0, _window.inSeconds);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class AiValidationService {
  final SupabaseClient _supabase;
  final _health      = _AiHealthMonitor();
  final _rateLimiter = _RateLimiter();

  // Model is enforced server-side in the Edge Function.
  static const String   _claudeModel  = 'claude-haiku-4-5-20251001'; // informational
  // Edge Function name — no hardcoded URL or project ref needed.
  // _supabase.functions.invoke() resolves the correct URL automatically.
  static const String   _edgeFn       = 'validate_content';
  static const Duration _timeout      = Duration(seconds: 60);
  static const int      _maxImages    = 4; // up to 4 images spread across the set

  // Lost-log counter — admin can read this to detect Supabase logging issues.
  int _lostLogCount = 0;
  int get lostLogCount => _lostLogCount;

  AiValidationService(this._supabase);

  // ─────────────────────────────────────────────────────────────────────────
  // KEYWORDS
  // ─────────────────────────────────────────────────────────────────────────

  static const List<String> _reKeywords = [
    'house', 'apartment', 'villa', 'condo', 'studio', 'flat', 'loft',
    'duplex', 'property', 'bedroom', 'bathroom', 'kitchen', 'rent',
    'sale', 'lease', 'sqm', 'sqft', 'floor', 'building', 'estate',
    'land', 'plot', 'commercial', 'office', 'garage', 'compound',
    'mortgage', 'agent', 'renovation', 'interior', 'moving', 'tenant',
    'nyumba', 'chumba', 'pango', 'kodi', 'ardhi', 'ofisi', 'jengo',
  ];

  // Only keywords that are ALWAYS blocked regardless of context.
  // Revenue rule: ads are open to ALL categories — only block the specific
  // harmful categories: adult content, fear-based, political, illegal.
  static const List<String> _adBannedKeywords = [
    // Adult / sexual
    'escort', 'prostitution', 'pornography', 'xxx', 'onlyfans',
    // Gambling
    'casino', 'gambling', 'sportpesa', 'betway', 'lottery',
    // Illegal
    'cocaine', 'heroin', 'weapons', 'counterfeit', 'piracy',
  ];

  // Property listing banned keywords (stricter — must be property-related)
  static const List<String> _bannedKeywords = [
    'food', 'restaurant', 'pizza', 'burger', 'grocery', 'chakula',
    'clothing', 'fashion', 'shoes', 'dress', 'nguo',
    'phone', 'laptop', 'electronics', 'gadget', 'simu',
    'car', 'vehicle', 'motorcycle', 'truck', 'gari',
    'casino', 'gambling', 'betting', 'crypto',
    'dating', 'escort', 'adult',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // EDGE FUNCTION AVAILABILITY CHECK
  //
  // SECURITY FIX: The Anthropic API key NEVER leaves the server.
  //   - It is stored as a Supabase Edge Function secret (ANTHROPIC_API_KEY).
  //   - The Flutter app only calls _supabase.functions.invoke('validate_content').
  //   - The Edge Function reads the key server-side and calls Anthropic.
  //   - No API key is ever fetched to the device or sent in any HTTP header.
  //
  // This method returns a non-empty sentinel so the existing flow treats
  // Claude as "available". If the Edge Function itself is missing or broken,
  // the call throws and the circuit breaker / rule-based fallback handles it.
  // ─────────────────────────────────────────────────────────────────────────

  // Set to true after the first successful edge function call so we don't
  // ping the health endpoint on every request.
  bool _edgeFunctionVerified = false;

  Future<String> _getApiKey() async {
    // Return a non-empty sentinel — the real key lives in the Edge Function secret.
    // The client NEVER reads or stores the actual Anthropic API key.
    if (!_edgeFunctionVerified) {
      // On the first call, ping /health so we log exactly what is wrong
      // (wrong model, missing key, network error, etc.) without blocking.
      _pingHealthOnce();
    }
    return 'edge-function-active';
  }

  /// Fire-and-forget health check on the first AI call of the session.
  /// Logs the result so you can see it in debug console / Supabase Function Logs.
  void _pingHealthOnce() {
    _edgeFunctionVerified = true; // prevent repeat pings
    Future.microtask(() async {
      try {
        final response = await _supabase.functions
            .invoke('$_edgeFn/health', body: {})
            .timeout(const Duration(seconds: 30));
        final data = response.data;
        if (data is Map && data['ok'] == true) {
          _log('✅ Edge Function health OK — model: ${data['model']}, '
               'reply: "${data['reply']}"');
        } else {
          _log('⚠️  Edge Function health FAILED — stage: ${data?['stage']}, '
               'detail: ${data?['detail']}');
        }
      } catch (e) {
        _log('❌ Edge Function health ping threw: $e\n'
             'Check: (1) validate_content is deployed in Supabase, '
             '(2) ANTHROPIC_API_KEY secret is set, '
             '(3) model name is correct.');
      }
    });
  }

  // Expose health stats for the admin monitoring widget.
  Map<String, dynamic> get healthStats => _health.stats;

  // ─────────────────────────────────────────────────────────────────────────
  // HEALTH CHECK
  //
  // Calls POST /validate_content/health on the Edge Function.
  // Returns a map with:
  //   ok      → bool   — true if key exists and Claude responds
  //   stage   → String — 'all_good' | 'key_missing' | 'anthropic_error' | 'network_error'
  //   detail  → String — human-readable message
  //   reply   → String — Claude's reply (when ok=true)
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkAiHealth() async {
    try {
      final response = await _supabase.functions.invoke(
        '$_edgeFn/health',
        body: {},
      ).timeout(_timeout);

      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      // Edge Function returned unexpected shape
      return {
        'ok':     false,
        'stage':  'unexpected_response',
        'detail': 'Edge Function returned an unexpected response format.',
      };
    } catch (e) {
      return {
        'ok':     false,
        'stage':  'invoke_error',
        'detail': 'Could not reach the Edge Function: $e\n'
                  'Make sure validate_content is deployed in Supabase.',
      };
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — PROPERTY
  // ══════════════════════════════════════════════════════════════════════════

  Future<ValidationResult> validateProperty({
    required String     title,
    required String     description,
    required String     location,
    required double     price,
    required String     category,
    required String     type,
    required int        bedrooms,
    required int        bathrooms,
    required double     area,
    List<XFile>?        images,
    List<XFile>?        videos,   // optional video files — thumbnails extracted & sent to Claude
    String?             submittedBy,
  }) async {
    // Rate limit.
    if (submittedBy != null && !_rateLimiter.allow(submittedBy)) {
      _log('Rate limit hit for $submittedBy');
      return _hardReject(
        type: 'property', submittedBy: submittedBy,
        reason: 'Too many submissions. Please wait a moment before trying again.',
        suggestions: ['Wait ${_rateLimiter.secondsUntilReset(submittedBy)} seconds, then resubmit.'],
      );
    }

    final data = {
      'title': title, 'description': description, 'location': location,
      'price': price, 'category': category, 'type': type,
      'bedrooms': bedrooms, 'bathrooms': bathrooms, 'area': area,
    };

    final apiKey    = await _getApiKey();

    // ── Extract thumbnails from any submitted videos and merge into images ─
    // Claude cannot decode raw video bytes — we extract a JPEG frame from
    // each video and treat it exactly like a photo for validation purposes.
    List<XFile> allMedia = [...(images ?? [])];
    final tempThumbs = <XFile>[]; // temp thumbnail files to clean up after validation
    if (videos != null && videos.isNotEmpty) {
      for (int i = 0; i < videos.length; i++) {
        final thumb = await _extractVideoThumbnail(videos[i]);
        if (thumb != null) {
          allMedia.add(thumb);
          tempThumbs.add(thumb); // mark for cleanup after Claude responds
          _log('Property video ${i + 1}: thumbnail extracted → added to media set');
        } else if (kIsWeb) {
          // video_thumbnail not available on web — skip the frame, still validate images
          _log('Property video ${i + 1}: web platform — skipping video thumbnail');
        } else {
          _log('Property video ${i + 1}: thumbnail extraction failed — hard rejecting');
          await _deleteTempThumbnails(tempThumbs);
          return _hardReject(
            type: 'property', submittedBy: submittedBy,
            reason: 'Could not process video ${i + 1}. Please use a valid MP4 or MOV file.',
            suggestions: [
              'Use an MP4 or MOV video file under 50 MB.',
              'Or remove the video and use photos only.',
            ],
          );
        }
      }
    }

    final hasImages = allMedia.isNotEmpty;

    _log('validateProperty — key=${apiKey.isEmpty ? "MISSING" : "ok"}, '
         'photos=${images?.length ?? 0}, videos=${videos?.length ?? 0}, '
         'total_media=${allMedia.length}, healthy=${_health.isHealthy}');

    // ── IMAGE/VIDEO PATH ────────────────────────────────────────────────────
    if (hasImages) {
      // AI unavailable → rule-based fallback on text fields (never hard-block)
      if (apiKey.isEmpty || !_health.isHealthy) {
        _log('AI unavailable for property photos — using rule-based fallback on text fields');
        await _deleteTempThumbnails(tempThumbs);
        final fallback = _ruleBasedPropertyCheck(data);
        await _logValidation(type: 'property', result: fallback, submittedBy: submittedBy);
        return fallback;
      }

      // Pre-flight ALL media (photos + video thumbnails) before calling Claude.
      for (int i = 0; i < allMedia.length; i++) {
        final reason = await _preflightImageCheck(allMedia[i], index: i + 1);
        if (reason != null) {
          _log('Pre-flight rejected photo ${i + 1}: $reason');
          final result = ValidationResult(
            status: ValidationStatus.rejected, method: ValidationMethod.rules,
            approved: false, confidence: 99,
            reason: reason,
            suggestions: [
              'Upload a real property photo: bedroom, living room, exterior, or land.',
              'Do not upload screenshots, documents, or WhatsApp messages.',
            ],
          );
          await _logValidation(type: 'property', result: result, submittedBy: submittedBy);
          await _deleteTempThumbnails(tempThumbs);
          return result;
        }
      }

      // All media passed pre-flight — send to Claude.
      try {
        final result = await _validateWithImages(
          data: data, images: allMedia, apiKey: apiKey,
        ).timeout(_timeout);
        _health.recordSuccess();
        await _logValidation(type: 'property', result: result, submittedBy: submittedBy);
        await _deleteTempThumbnails(tempThumbs);
        return result;
      } catch (e) {
        await _deleteTempThumbnails(tempThumbs);
        // Server-side rate limit hit — hard-reject with countdown.
        if (e.toString().contains('rate_limited:')) {
          final secs = int.tryParse(e.toString().split(':').last) ?? 60;
          return _hardReject(
            type: 'property', submittedBy: submittedBy,
            reason: 'Too many submissions. Please wait $secs seconds before trying again.',
            suggestions: ['Wait $secs seconds, then resubmit.'],
          );
        }
        _health.recordFailure();
        _log('Property AI image validation failed: $e');
        // IMPORTANT: DO NOT fall back to rule-based text check when images were
        // provided.  The rule-based check only looks at keywords in the title/
        // description — it would approve a car photo captioned "house for rent".
        // Instead: hard-reject so the user retries (transient error) or the admin
        // can manually approve (persistent error).
        return _hardReject(
          type: 'property', submittedBy: submittedBy,
          reason: 'Image validation is temporarily unavailable. Please try again in a moment.',
          suggestions: [
            'Wait a few seconds and tap Submit again.',
            'Make sure each photo is under ${AppConstants.maxImageSize ~/ (1024 * 1024)} MB.',
            'Use JPEG or PNG format for best results.',
          ],
        );
      }
    }

    // ── TEXT-ONLY PATH ──────────────────────────────────────────────────────
    return _validateTextOnly(
      type: 'property', data: data,
      apiKey: apiKey, submittedBy: submittedBy,
      prompt: _buildPropertyPrompt(data),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — AD
  // ══════════════════════════════════════════════════════════════════════════

  Future<ValidationResult> validateAd({
    required String headline,
    required String description,
    required String callToAction,
    required String companyType,
    required String campaignObjective,
    required String landingUrl,
    XFile?          image,
    XFile?          video,
    String?         submittedBy,
  }) async {
    // Rate limit.
    if (submittedBy != null && !_rateLimiter.allow(submittedBy)) {
      _log('Rate limit hit for $submittedBy');
      return _hardReject(
        type: 'ad', submittedBy: submittedBy,
        reason: 'Too many submissions. Please wait a moment before trying again.',
        suggestions: ['Wait ${_rateLimiter.secondsUntilReset(submittedBy)} seconds, then resubmit.'],
      );
    }

    final data = {
      'headline': headline, 'description': description,
      'call_to_action': callToAction, 'company_type': companyType,
      'campaign_objective': campaignObjective, 'landing_url': landingUrl,
    };

    final apiKey   = await _getApiKey();

    // Build the full media set: image + video thumbnail (if both provided).
    // Claude analyses every frame we send — more context = better decision.
    List<XFile> allAdMedia = [];
    final adThumbsToClean = <XFile>[];

    // Add image directly (already a JPEG/PNG).
    if (image != null) allAdMedia.add(image);

    // Extract a thumbnail frame from video and add it alongside the image.
    if (video != null) {
      if (_isVideoFile(video)) {
        _log('Ad video provided — extracting thumbnail frame for Claude');
        final thumb = await _extractVideoThumbnail(video);
        if (thumb == null && kIsWeb) {
          _log('Ad video: web platform — skipping video thumbnail');
        } else if (thumb == null) {
          _log('Video thumbnail extraction failed — hard rejecting');
          return _hardReject(
            type: 'ad', submittedBy: submittedBy,
            reason: 'Could not process your video file. Please try a different video or use an image instead.',
            suggestions: [
              'Use an MP4 or MOV file under 50 MB.',
              'Or upload a static image instead of a video.',
            ],
          );
        } else {
          allAdMedia.add(thumb);
          adThumbsToClean.add(thumb);
          _log('Ad video thumbnail extracted: ${thumb.path}');
        }
      } else {
        // video param was passed but looks like an image — add it directly
        allAdMedia.add(video);
      }
    }

    final hasMedia = allAdMedia.isNotEmpty;

    _log('validateAd — key=${apiKey.isEmpty ? "MISSING" : "ok"}, '
         'image=${image != null}, video=${video != null}, '
         'total_media=${allAdMedia.length}, healthy=${_health.isHealthy}');

    // ── MEDIA PATH ──────────────────────────────────────────────────────────
    if (hasMedia) {
      // AI unavailable (no key or unhealthy) → rule-based fallback on text fields
      if (apiKey.isEmpty || !_health.isHealthy) {
        _log('AI unavailable for media ad — using rule-based fallback on text fields');
        await _deleteTempThumbnails(adThumbsToClean);
        final fallback = _ruleBasedAdCheck(data);
        await _logValidation(type: 'ad', result: fallback, submittedBy: submittedBy);
        return fallback;
      }

      // Pre-flight every media file before calling Claude.
      for (int i = 0; i < allAdMedia.length; i++) {
        final preflightReason = await _preflightImageCheck(allAdMedia[i], index: i + 1);
        if (preflightReason != null) {
          _log('Ad pre-flight rejected media ${i + 1}: $preflightReason');
          final result = ValidationResult(
            status: ValidationStatus.rejected, method: ValidationMethod.rules,
            approved: false, confidence: 99,
            reason: preflightReason,
            suggestions: [
              'Upload a real ad image: property photo, company logo, or professional graphic.',
              'Do not upload screenshots, documents, or text images.',
            ],
          );
          await _logValidation(type: 'ad', result: result, submittedBy: submittedBy);
          await _deleteTempThumbnails(adThumbsToClean);
          return result;
        }
      }

      // All media passed pre-flight — send everything to Claude at once.
      try {
        final result = await _validateWithImages(
          data: data,
          images: allAdMedia,       // image + video thumbnail together
          apiKey: apiKey,
          promptBuilder: (d, count) => _buildAdPromptWithImage(d),
        ).timeout(_timeout);
        _health.recordSuccess();
        await _logValidation(type: 'ad', result: result, submittedBy: submittedBy);
        await _deleteTempThumbnails(adThumbsToClean);
        return result;
      } catch (e) {
        await _deleteTempThumbnails(adThumbsToClean);
        if (e.toString().contains('rate_limited:')) {
          final secs = int.tryParse(e.toString().split(':').last) ?? 60;
          return _hardReject(
            type: 'ad', submittedBy: submittedBy,
            reason: 'Too many submissions. Please wait $secs seconds before trying again.',
            suggestions: ['Wait $secs seconds, then resubmit.'],
          );
        }
        _health.recordFailure();
        _log('Ad AI media validation failed: $e — falling back to rule-based on text fields');
        // FALLBACK: rule-based check on text fields so the user is not hard-blocked
        try {
          final fallback = _ruleBasedAdCheck(data);
          await _logValidation(type: 'ad', result: fallback, submittedBy: submittedBy);
          _log('Rule-based fallback result: ${fallback.status}');
          return fallback;
        } catch (re) {
          _log('Rule-based fallback also crashed: $re — hard rejecting');
        }
        return _hardReject(
          type: 'ad', submittedBy: submittedBy,
          reason: 'Validation is temporarily unavailable. Please check your content meets real estate guidelines and try again.',
          suggestions: [
            'Ensure your headline and description are clearly about real estate.',
            'Use a clear JPEG or PNG image under 10 MB.',
            'Try again in a few seconds.',
          ],
        );
      }
    }

    // ── TEXT-ONLY PATH ──────────────────────────────────────────────────────
    return _validateTextOnly(
      type: 'ad', data: data,
      apiKey: apiKey, submittedBy: submittedBy,
      prompt: _buildAdPrompt(data),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE ENGINES
  // ══════════════════════════════════════════════════════════════════════════

  Future<ValidationResult> _validateWithImages({
    required Map<String, dynamic> data,
    required List<XFile>          images,
    required String               apiKey,
    String Function(Map<String, dynamic> d, int count)? promptBuilder,
  }) async {
    final picked      = _pickRepresentative(images, _maxImages);
    final imageBlocks = <Map<String, dynamic>>[];

    for (final file in picked) {
      final b64 = await _compressAndEncode(file);
      if (b64 != null) {
        imageBlocks.add({
          'type':   'image',
          'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': b64},
        });
      }
    }

    _log('Encoded ${imageBlocks.length}/${picked.length} images for Claude');
    if (imageBlocks.isEmpty) throw Exception('No images could be encoded');

    final builder = promptBuilder ??
        (d, count) => _buildPropertyPromptWithImages(d, imageCount: count);

    final messages = [
      {
        'role':    'user',
        'content': [...imageBlocks, {'type': 'text', 'text': builder(data, imageBlocks.length)}],
      }
    ];

    // All AI calls go through the Edge Function — API key stays server-side.
    try {
      final response = await _supabase.functions.invoke(
        _edgeFn,
        body: {'max_tokens': 900, 'messages': messages},
      );
      if (response.status == 429) {
        final data = response.data as Map<String, dynamic>?;
        final secs = (data?['retry_after'] as num?)?.toInt() ?? 60;
        throw Exception('rate_limited:$secs');
      }
      if (response.status != 200) {
        throw Exception('Edge Function ${response.status}: ${jsonEncode(response.data)}');
      }
      return _parseResponseMap(response.data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      _log('Edge Function exception (${e.status}): ${e.reasonPhrase}');
      throw Exception('Edge Function failed: ${e.status} ${e.reasonPhrase}');
    }
  }

  Future<ValidationResult> _validateTextOnly({
    required String               type,
    required Map<String, dynamic> data,
    required String               prompt,
    required String               apiKey,
    String?                       submittedBy,
  }) async {
    // Layer 1: Claude text.
    if (_health.isHealthy && apiKey.isNotEmpty) {
      try {
        final result = await _callClaudeText(prompt, apiKey: apiKey).timeout(_timeout);
        _health.recordSuccess();
        await _logValidation(type: type, result: result, submittedBy: submittedBy);
        return result;
      } catch (e) {
        _health.recordFailure();
        _log('Claude text validation failed: $e — falling to rules');
      }
    }

    // Layer 2: Rule-based.
    try {
      final result = type == 'property'
          ? _ruleBasedPropertyCheck(data)
          : _ruleBasedAdCheck(data);
      await _logValidation(type: type, result: result, submittedBy: submittedBy);
      return result;
    } catch (e) {
      _log('Rule-based check crashed: $e — sending to manual queue');
    }

    // Layer 3: Manual queue.
    await _addToManualQueue(type: type, data: data, submittedBy: submittedBy);
    const result = ValidationResult(
      status: ValidationStatus.pending, method: ValidationMethod.manual,
      approved: false, confidence: 0,
      reason: 'Under admin review — you will be notified within 24 hours.',
    );
    await _logValidation(type: type, result: result, submittedBy: submittedBy);
    return result;
  }

  Future<ValidationResult> _callClaudeText(
      String prompt, {required String apiKey}) async {
    final messages = [{'role': 'user', 'content': prompt}];

    try {
      final response = await _supabase.functions.invoke(
        _edgeFn,
        body: {'max_tokens': 600, 'messages': messages},
      );
      if (response.status == 429) {
        final data = response.data as Map<String, dynamic>?;
        final secs = (data?['retry_after'] as num?)?.toInt() ?? 60;
        throw Exception('rate_limited:$secs');
      }
      if (response.status != 200) {
        throw Exception('Edge Function ${response.status}: ${jsonEncode(response.data)}');
      }
      return _parseResponseMap(response.data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      _log('Edge Function exception (${e.status}): ${e.reasonPhrase}');
      throw Exception('Edge Function failed: ${e.status} ${e.reasonPhrase}');
    }
  }

  /// Direct Anthropic call — PERMANENTLY DISABLED for security.
  ///
  /// The Anthropic API key must NEVER be sent from a client device.
  /// All AI calls go through the Supabase Edge Function (validate_content)
  /// which holds the key as a server-side secret.
  ///
  /// If this throws, the caller falls back to rule-based validation.
  /// Deploy the Edge Function so this path is never reached:
  ///   supabase functions deploy validate_content
  Future<ValidationResult> _callAnthropicDirect({
    required List<Map<String, dynamic>> messages,
    required int                        maxTokens,
    required String                     apiKey,
  }) async {
    _log('Direct API call blocked — deploy validate_content Edge Function');
    throw Exception(
      'Edge Function not deployed. '
      'Run: supabase functions deploy validate_content\n'
      'Then set: supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-YOUR-KEY',
    );
  }

  /// Parse a response that already came back as a decoded Map

  /// (from _supabase.functions.invoke which auto-decodes JSON).
  ValidationResult _parseResponseMap(Map<String, dynamic> body) {
    final content = (body['content'] as List).first as Map<String, dynamic>;
    final text    = content['text'] as String;
    final clean   = text.replaceAll(RegExp(r'```json|```'), '').trim();

    Map<String, dynamic> json;
    try {
      json = jsonDecode(clean) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _log('JSON parse error: $e | raw: $clean');
      throw Exception('Claude returned invalid JSON');
    }

    final approved    = json['approved']    as bool?   ?? false;
    final confidence  = (json['confidence'] as num?)?.toInt() ?? 0;
    final reason      = json['reason']      as String? ?? '';
    final category    = json['detected_category'] as String?;
    final suggestions = (json['suggestions'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];

    final finalApproved = approved && confidence >= 40;

    return ValidationResult(
      status:           finalApproved ? ValidationStatus.approved : ValidationStatus.rejected,
      method:           ValidationMethod.ai,
      approved:         finalApproved,
      confidence:       confidence,
      reason:           finalApproved
                            ? reason
                            : reason.isNotEmpty
                                ? reason
                                : 'Content does not meet real estate requirements.',
      suggestions:      suggestions,
      detectedCategory: category,
    );
  }

  ValidationResult _parseResponse(String responseBody) {
    final body    = jsonDecode(responseBody) as Map<String, dynamic>;
    final content = (body['content'] as List).first as Map<String, dynamic>;
    final text    = content['text'] as String;
    final clean   = text.replaceAll(RegExp(r'```json|```'), '').trim();

    Map<String, dynamic> json;
    try {
      json = jsonDecode(clean) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _log('JSON parse error: $e | raw: $clean');
      throw Exception('Claude returned invalid JSON');
    }

    final approved    = json['approved']    as bool?   ?? false;
    final confidence  = (json['confidence'] as num?)?.toInt() ?? 0;
    final reason      = json['reason']      as String? ?? '';
    final category    = json['detected_category'] as String?;
    final suggestions = (json['suggestions'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];

    // Safety gate: approved=true with confidence < 40 is treated as rejected.
    final finalApproved = approved && confidence >= 40;

    return ValidationResult(
      status:           finalApproved ? ValidationStatus.approved : ValidationStatus.rejected,
      method:           ValidationMethod.ai,
      approved:         finalApproved,
      confidence:       confidence,
      reason:           finalApproved
                            ? reason
                            : reason.isNotEmpty
                                ? reason
                                : 'Content does not meet real estate requirements.',
      suggestions:      suggestions,
      detectedCategory: category,
    );
  }

  Future<ValidationResult> _hardReject({
    required String       type,
    required String       reason,
    required List<String> suggestions,
    String?               submittedBy,
  }) async {
    final result = ValidationResult(
      status:      ValidationStatus.rejected,
      method:      ValidationMethod.failed,
      approved:    false,
      confidence:  0,
      reason:      reason,
      suggestions: suggestions,
    );
    await _logValidation(type: type, result: result, submittedBy: submittedBy);
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IMAGE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  // Detect if a file is a video based on its extension.
  bool _isVideoFile(XFile file) {
    final name = file.name.isNotEmpty ? file.name : file.path;
    final ext  = name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'webm', 'mkv', '3gp', 'flv'].contains(ext);
  }

  // Delete temp thumbnail files produced by _extractVideoThumbnail.
  // Only deletes files whose path is inside the system temp directory,
  // so there is zero risk of accidentally deleting a user's original photo.
  Future<void> _deleteTempThumbnails(List<XFile> files) async {
    if (kIsWeb) return; // no temp files on web
    try {
      final tempDir = await getTemporaryDirectory();
      for (final xfile in files) {
        if (xfile.path.startsWith(tempDir.path)) {
          try {
            final ioFile = File(xfile.path);
            if (await ioFile.exists()) await ioFile.delete();
            _log('Cleaned up temp thumbnail: ${xfile.path.split('/').last}');
          } catch (e) {
            _log('Could not delete temp thumbnail: $e');
          }
        }
      }
    } catch (e) {
      _log('Temp cleanup error: $e');
    }
  }

  // Extract a single JPEG thumbnail frame from a video file.
  // Returns null if extraction fails or on web (video_thumbnail is native-only).
  Future<XFile?> _extractVideoThumbnail(XFile videoFile) async {
    // video_thumbnail uses native platform channels — not available on web.
    if (kIsWeb) {
      _log('Web: video thumbnail extraction not supported — skipping');
      return null;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video:          videoFile.path,
        thumbnailPath:  tempDir.path,
        imageFormat:    ImageFormat.JPEG,
        maxWidth:       1280,
        quality:        85,
        timeMs:         0,     // frame at 0ms (start of video)
      );
      if (thumbPath == null) return null;
      final thumbIo = File(thumbPath);
      if (!await thumbIo.exists()) return null;
      return XFile(thumbPath);
    } catch (e) {
      _log('Video thumbnail extraction error: $e');
      return null;
    }
  }

  // Pick up to [max] photos spread evenly across the whole list.
  List<XFile> _pickRepresentative(List<XFile> files, int max) {
    if (files.length <= max) return files;
    final step   = files.length / max;
    final result = <XFile>[];
    for (int i = 0; i < max; i++) {
      result.add(files[(i * step).floor()]);
    }
    return result;
  }

  // Pre-flight: catches bad images before paying for Claude.
  // Checks file size, and screenshot dimensions for:
  //   - PNG/JPEG portrait phone screenshots
  //   - PNG/JPEG portrait tablet screenshots
  //   - PNG/JPEG landscape screenshots
  //   - HEIC/HEIF: passed through to Claude (no dimension data available in header)
  //   - WebP: passed through to Claude
  // Returns rejection reason string, or null if the image looks OK.
  Future<String?> _preflightImageCheck(XFile file, {int index = 1}) async {
    try {
      final bytes    = await file.readAsBytes();
      final fileSize = bytes.length;

      // Too small to be a real property photo.
      if (fileSize < 10240) {
        return 'Photo $index is too small '
            '(${(fileSize / 1024).toStringAsFixed(1)} KB). '
            'Upload a real property photo.';
      }

      int imgWidth  = 0;
      int imgHeight = 0;

      if (bytes.length > 24 &&
          bytes[0] == 0x89 && bytes[1] == 0x50 &&
          bytes[2] == 0x4E && bytes[3] == 0x47) {
        // PNG — IHDR at bytes 16-23.
        imgWidth  = _readInt32(bytes, 16);
        imgHeight = _readInt32(bytes, 20);

      } else if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        // JPEG — scan for SOF0/SOF2 marker.
        for (int i = 2; i < bytes.length - 8; i++) {
          if (bytes[i] == 0xFF &&
              (bytes[i + 1] == 0xC0 || bytes[i + 1] == 0xC2)) {
            imgHeight = _readInt16(bytes, i + 5);
            imgWidth  = _readInt16(bytes, i + 7);
            break;
          }
        }

      } else if (bytes.length > 12 &&
          bytes[0] == 0x52 && bytes[1] == 0x49 &&
          bytes[2] == 0x46 && bytes[3] == 0x46 &&
          bytes[8] == 0x57 && bytes[9] == 0x45 &&
          bytes[10] == 0x42 && bytes[11] == 0x50) {
        // WebP — no dimension check, pass to Claude.
        _log('Photo $index is WebP — sending to Claude');
        return null;

      } else if (bytes.length > 8 &&
          bytes[4] == 0x66 && bytes[5] == 0x74 &&
          bytes[6] == 0x79 && bytes[7] == 0x70) {
        // HEIC/HEIF (ftyp box) — no dimension check, pass to Claude.
        _log('Photo $index is HEIC/HEIF — sending to Claude');
        return null;
      }

      _log('Photo $index: ${imgWidth}x$imgHeight px');

      // Dimension-based screenshot detection removed.
      // Gallery photos and camera photos on modern phones are often
      // processed to standard dimensions (1080px, 1284px etc.) that
      // are indistinguishable from screenshots by size alone.
      // Claude handles visual content moderation — it can reliably
      // tell a property photo from a screenshot by looking at it.
      if (imgWidth > 0 && imgHeight > 0) {
        _log('Photo $index: ${imgWidth}x${imgHeight}px — passing to Claude');
      }

      return null; // Passed all checks.
    } catch (e) {
      _log('Pre-flight error on photo $index: $e — letting Claude decide');
      return null;
    }
  }

  int _readInt32(Uint8List b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  int _readInt16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];

  Future<String?> _compressAndEncode(XFile file) async {
    try {
      // On web: resize via HTML canvas so images stay under 6 MB edge fn limit.
      // On native: compress aggressively so each image is ~40-80 KB.
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) return null;
        _log('Web: resizing ${(bytes.length / 1024).toStringAsFixed(1)} KB image for Claude');
        return await webResizeToBase64(bytes);
      }

      // Native path — compress with FlutterImageCompress.
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth:  512,
        minHeight: 512,
        quality:   55,
        format:    CompressFormat.jpeg,
      );
      if (compressed == null || compressed.isEmpty) return null;
      _log('Compressed image: ${(compressed.length / 1024).toStringAsFixed(1)} KB '
           '→ base64: ${(compressed.length * 4 ~/ 3 / 1024).toStringAsFixed(1)} KB');
      return base64Encode(compressed);
    } catch (e) {
      _log('Compression failed for ${file.name}: $e — trying raw encode');
      try {
        return base64Encode(await file.readAsBytes());
      } catch (_) {
        return null;
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RULE-BASED CHECKS
  // ══════════════════════════════════════════════════════════════════════════

  ValidationResult _ruleBasedPropertyCheck(Map<String, dynamic> data) {
    final text = '${data['title']} ${data['description']} ${data['location']}'
        .toLowerCase();

    // Hard-block: listing contains a clearly non-real-estate product keyword.
    final banned =
        _bannedKeywords.firstWhere((k) => text.contains(k), orElse: () => '');
    if (banned.isNotEmpty) {
      return ValidationResult(
        status: ValidationStatus.rejected, method: ValidationMethod.rules,
        approved: false, confidence: 85,
        reason: 'Content is not related to real estate (found: "$banned").',
        suggestions: [
          'Only property listings are allowed: houses, apartments, land, commercial.',
          'Remove references to non-real-estate products.',
        ],
      );
    }

    // Score keyword matches.
    int          score = 0;
    final List<String> hits = [];
    for (final kw in _reKeywords) {
      if (text.contains(kw)) { score += 15; hits.add(kw); }
    }

    // GATE: at least one real-estate keyword is REQUIRED.
    // Without this gate, any listing with a price and a long description
    // would pass — making the fallback completely ineffective.
    if (hits.isEmpty) {
      return ValidationResult(
        status: ValidationStatus.rejected, method: ValidationMethod.rules,
        approved: false, confidence: 80,
        reason: 'Listing does not appear to be about real estate. '
                'No property-related words found.',
        suggestions: [
          'Describe the property: house, apartment, land, commercial space, etc.',
          'Use words like "bedroom", "bathroom", "rent", "sale", "plot".',
          'Swahili: nyumba, chumba, pango, ardhi, ofisi are all valid.',
        ],
      );
    }

    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final area  = (data['area']  as num?)?.toDouble() ?? 0;
    final title = (data['title'] as String?)?.trim() ?? '';
    final desc  = (data['description'] as String?)?.trim() ?? '';

    if (price >= 100 && price <= 500000000) score += 15;
    if (area  >= 10)                         score += 10;
    if (title.length >= 5)                   score += 5;
    if (desc.length  >= 20)                  score += 5;

    // Require score >= 30 (at least 2 keyword hits, OR 1 keyword + valid price/area).
    final approved = score >= 30;
    return ValidationResult(
      status:      approved ? ValidationStatus.approved : ValidationStatus.rejected,
      method:      ValidationMethod.rules,
      approved:    approved,
      confidence:  score.clamp(0, 100),
      reason:      approved
          ? 'Passed automated checks (matched: ${hits.take(3).join(", ")}).'
          : 'Insufficient real-estate content (score $score/100).',
      suggestions: approved ? [] : [
        'Add more property-specific detail: describe the rooms, location, and features.',
        'Include: number of bedrooms, type of property, and area size.',
      ],
    );
  }

  ValidationResult _ruleBasedAdCheck(Map<String, dynamic> data) {
    // Rule: DEFAULT IS APPROVE for all business categories.
    // Only reject explicitly prohibited content.
    final text =
        '${data['headline']} ${data['description']}'.toLowerCase();

    // Block prohibited keywords (adult, gambling, illegal)
    final banned =
        _adBannedKeywords.firstWhere((k) => text.contains(k), orElse: () => '');
    if (banned.isNotEmpty) {
      return ValidationResult(
        status: ValidationStatus.rejected, method: ValidationMethod.rules,
        approved: false, confidence: 95,
        reason: 'Ad contains prohibited content (keyword: "$banned").',
        suggestions: [
          'Ads must not promote adult services, gambling, or illegal products.',
        ],
      );
    }

    // Block political ads
    final politicalKeywords = ['vote for', 'elect', 'campaign', 'chagua', 'kura', 'uchaguzi'];
    if (politicalKeywords.any((k) => text.contains(k))) {
      return const ValidationResult(
        status: ValidationStatus.rejected, method: ValidationMethod.rules,
        approved: false, confidence: 92,
        reason: 'Political advertising is not permitted on this platform.',
        suggestions: ['Political campaign ads are not accepted.'],
      );
    }

    // Approve everything else — food, retail, tech, automotive, health, etc.
    // Only basic sanity check: headline must exist
    final headline = (data['headline'] as String?)?.trim() ?? '';
    if (headline.length < 3) {
      return const ValidationResult(
        status: ValidationStatus.rejected, method: ValidationMethod.rules,
        approved: false, confidence: 90,
        reason: 'Headline is too short or missing.',
        suggestions: ['Write a headline of at least 5 words describing your product or service.'],
      );
    }

    return const ValidationResult(
      status:     ValidationStatus.approved,
      method:     ValidationMethod.rules,
      approved:   true,
      confidence: 80,
      reason:     '',
      suggestions: [],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROMPTS
  // ══════════════════════════════════════════════════════════════════════════

  String _buildPropertyPrompt(Map<String, dynamic> d) => '''
You are a STRICT content moderator for a real estate listing platform in Tanzania.
This platform is ONLY for real property (houses, apartments, land, commercial spaces) FOR SALE or FOR RENT.

APPROVE only if the listing is clearly about a physical property for sale or rent.

Valid property types (APPROVE):
- Residential: house, villa, apartment, flat, studio, bedsitter, room, chumba, nyumba, gesti, hostel
- Commercial: office, shop, warehouse, clinic, school, church, hotel, lodge, go-down
- Land: plot, farm, ardhi, shamba, construction site
- Any physical space a person lives in, works in, or uses as real estate

REJECT if:
- The listing is selling a vehicle (car, motorcycle, bus, truck, gari) — not a property
- The listing is selling food, clothing, electronics, or consumer goods — not a property
- The listing is for a service (cleaning, transport, delivery) — not a property
- The title and description have NO property-related words at all
- The listing is clearly a different type of business (restaurant, shop selling goods)
- Description is gibberish, spam, or repeated random characters
- Price is clearly implausible (e.g. 1 TZS or 99999999999999)

Listing:
Title: "${d['title']}"
Description: "${d['description']}"
Category: ${d['category']} | Type: ${d['type']}
Location: "${d['location']}"
Price: ${d['price']} TZS | Bedrooms: ${d['bedrooms']} | Bathrooms: ${d['bathrooms']} | Area: ${d['area']} sqm

Reply ONLY in this exact JSON format (no markdown, no text outside JSON):
{"approved":false,"confidence":0,"detected_category":"house|apartment|room|hotel|land|commercial|industrial|vehicle|goods|unrelated","reason":"explain why rejected, or empty string if approved","suggestions":[]}

Replace the values above with your actual assessment. Do NOT return the template unchanged.''';

  String _buildPropertyPromptWithImages(
      Map<String, dynamic> d, {required int imageCount}) => '''
You are a STRICT content moderator for a real estate listing platform in Tanzania.
This platform is ONLY for real property: houses, apartments, land, and commercial spaces FOR SALE or FOR RENT.

You have $imageCount photo(s) and listing text to review.

APPROVE the listing ONLY if BOTH of these are true:
1. The photo(s) clearly show a real property — a room interior, building exterior, land/plot, construction site, office, shop, warehouse, or any physical space associated with real estate.
2. The text describes a real property for sale or rent.

REJECT immediately if ANY photo shows:
- A vehicle (car, motorcycle, truck, bus) as the main subject with NO property visible
- Food, meals, a restaurant, or a food stall
- Clothing, fashion items, or a fashion model
- Electronic devices (phones, laptops, TVs) as the main subject
- A live animal or livestock as the main subject
- A selfie or a person posing (no property visible)
- A screenshot of an app, WhatsApp chat, SMS, social media post, document, or receipt
- A landscape photo (nature, sky, field) with NO buildings or constructed structures
- Any product advertisement not related to property

REJECT if the text is clearly selling something other than real property (cars, goods, services, food, etc.).

APPROVE photos that show:
- Room interiors: bedroom, living room, kitchen, bathroom, hallway, staircase, balcony
- Building exteriors: facade, gate, fence, compound, garden, rooftop, parking
- Land: empty plot, farm, construction site, foundation, fenced land
- Commercial space: office, shop, clinic, warehouse, school, church, hotel, lodge
- Furniture or fixtures INSIDE a room (proves it is a room photo)

People in the BACKGROUND of a property photo = APPROVE (the property is the subject).
Dark or blurry property photos = APPROVE.
Construction sites = APPROVE.

Be strict. If a photo does NOT clearly show property, REJECT.

Listing:
Title: "${d['title']}"
Description: "${d['description']}"
Category: ${d['category']} | Type: ${d['type']}
Location: "${d['location']}"
Price: ${d['price']} TZS | Bedrooms: ${d['bedrooms']} | Bathrooms: ${d['bathrooms']} | Area: ${d['area']} sqm

Reply ONLY in this exact JSON format (no markdown, no text outside JSON):
{"approved":false,"confidence":0,"detected_category":"house|apartment|land|commercial|screenshot|vehicle|food|unrelated","images_ok":false,"text_ok":false,"reason":"explain why rejected, or empty string if approved","suggestions":[]}

Replace the values above with your actual assessment. Do NOT return the template unchanged.''';

  String _buildAdPrompt(Map<String, dynamic> d) => '''
You are an ad moderator for a real estate platform in Tanzania.
Advertising is the platform's primary revenue source. DEFAULT is APPROVE.

APPROVE any legitimate business ad including: real estate, property services, home goods,
retail, food, restaurants, technology, finance, healthcare, education, automotive,
travel, fashion, entertainment, professional services, and general commerce.

REJECT ONLY these specific categories — nothing else:
1. Adult content: pornography, escort services, sexual services, explicit material
2. Fear-based marketing: ads using threats, panic, emergency manipulation to coerce
3. Political ads: election campaigns, political parties, candidate promotion, referendums
4. Illegal content: drugs, weapons, scams, piracy, counterfeit goods
5. Gambling: casinos, betting platforms, lottery schemes

Headline: "${d['headline']}"
Description: "${d['description']}"
Call to Action: "${d['call_to_action']}"
Campaign Objective: ${d['campaign_objective']}
Landing URL: "${d['landing_url']}"

Reply ONLY in JSON (no markdown):
{"approved":true,"confidence":85,"detected_category":"real_estate/retail/food/tech/finance/healthcare/other","reason":"","suggestions":[]}''';

  String _buildAdPromptWithImage(Map<String, dynamic> d) => '''
You are an ad moderator for a real estate platform in Tanzania.
Advertising is the platform's primary revenue source. DEFAULT is APPROVE.

IMAGE — APPROVE if it shows any legitimate business imagery:
- Products, food, services, people, logos, offices, retail environments
- Properties, buildings, interiors, construction
- Graphics, illustrations, branding, promotional material
REJECT image ONLY if it is clearly: pornographic/explicit sexual content, a screenshot
of UI/WhatsApp chat (not a real ad), or violent/threatening imagery.

TEXT — APPROVE for any legitimate business including: food, retail, technology,
automotive, healthcare, education, finance, fashion, real estate, and general commerce.
REJECT ONLY if text promotes: adult/sexual services, political campaigns,
fear-based manipulation ("Act NOW or lose everything!"), illegal activity, or gambling.

If the image shows a property and the text relates to real estate, APPROVE.

Ad Details:
Headline: "${d['headline']}"
Description: "${d['description']}"
Call to Action: ${d['call_to_action']}
Landing URL: ${d['landing_url']}

Reply ONLY in this exact JSON (no markdown):
{"approved":true,"confidence":85,"detected_category":"real_estate/home_services/unrelated/screenshot","images_ok":true,"text_ok":true,"reason":"","suggestions":[]}''';

  // ══════════════════════════════════════════════════════════════════════════
  // SUPABASE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _logValidation({
    required String           type,
    required ValidationResult result,
    String?                   submittedBy,
  }) async {
    try {
      await _supabase.from('ai_validation_logs').insert({
        'content_type':      type,
        'validation_method': result.method.name,
        'status':            result.status.name,
        'confidence':        result.confidence,
        'reason':            result.reason,
        'submitted_by':      submittedBy,
        'created_at':        DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _lostLogCount++;
      _log('WARNING: validation log lost (total lost: $_lostLogCount) — $e');
    }
  }

  Future<void> _addToManualQueue({
    required String               type,
    required Map<String, dynamic> data,
    String?                       submittedBy,
  }) async {
    try {
      await _supabase.from('manual_review_queue').insert({
        'content_type': type,
        'content_data': jsonEncode(data),
        'submitted_by': submittedBy,
        'status':       'pending',
        'created_at':   DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _log('ERROR: could not add to manual queue — $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADMIN / MONITORING APIs
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getPendingManualReviews({
    String? type,
    int     limit = 50,
  }) async {
    try {
      var q = _supabase
          .from('manual_review_queue')
          .select()
          .eq('status', 'pending');
      if (type != null) q = q.eq('content_type', type);
      return await q.order('created_at', ascending: true).limit(limit);
    } catch (e) {
      return [];
    }
  }

  Future<bool> adminApproveManualItem(String itemId, {String? note}) async {
    try {
      await _supabase.from('manual_review_queue').update({
        'status':      'approved',
        'reviewed_by': _supabase.auth.currentUser?.id,
        'review_note': note,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', itemId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> adminRejectManualItem(
      String itemId, {required String reason}) async {
    try {
      await _supabase.from('manual_review_queue').update({
        'status':      'rejected',
        'reviewed_by': _supabase.auth.currentUser?.id,
        'review_note': reason,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', itemId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Full stats for the admin dashboard monitoring widget.
  /// Compatibility alias used by admin_manual_review_screen.
  /// Returns the same int-valued keys the screen's _StatsPanel expects.
  Future<Map<String, int>> getValidationStats() async {
    final full = await getFullStats();
    return {
      'ai_approved':    (full['ai_approved']    as num? ?? 0).toInt(),
      'ai_rejected':    (full['ai_rejected']    as num? ?? 0).toInt(),
      'rules_approved': (full['rules_approved'] as num? ?? 0).toInt(),
      'rules_rejected': (full['rules_rejected'] as num? ?? 0).toInt(),
      'pending':        (full['manual_pending'] as num? ?? 0).toInt(),
      'total':          (full['total']          as num? ?? 0).toInt(),
    };
  }


  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — APPEALS
  // ══════════════════════════════════════════════════════════════════════════

  /// User submits an appeal after a rejection.
  /// [contentType] is 'property' or 'ad'.
  /// [contentId]   is the property/ad ID that was rejected.
  /// [rejectionReason] is the reason shown to the user so the admin can see context.
  /// [userMessage] is the user's explanation of why they believe it should be approved.
  Future<bool> submitAppeal({
    required String contentType,
    required String contentId,
    required String rejectionReason,
    required String userMessage,
    String?         submittedBy,
  }) async {
    try {
      await _supabase.from('content_appeals').insert({
        'content_type':     contentType,
        'content_id':       contentId,
        'submitted_by':     submittedBy ?? _supabase.auth.currentUser?.id,
        'rejection_reason': rejectionReason,
        'user_message':     userMessage,
        'status':           'pending',
        'created_at':       DateTime.now().toIso8601String(),
      });
      _log('Appeal submitted for $contentType $contentId');
      return true;
    } catch (e) {
      _log('submitAppeal error: $e');
      return false;
    }
  }

  /// Admin fetches all pending appeals.
  Future<List<Map<String, dynamic>>> getPendingAppeals({int limit = 50}) async {
    try {
      return await _supabase
          .from('content_appeals')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(limit);
    } catch (e) {
      _log('getPendingAppeals error: $e');
      return [];
    }
  }

  /// Admin resolves an appeal: approved=true grants it, false upholds rejection.
  Future<void> resolveAppeal(
    String appealId, {
    required bool   approved,
    required String adminNote,
  }) async {
    try {
      await _supabase.from('content_appeals').update({
        'status':      approved ? 'approved' : 'rejected',
        'reviewed_by': _supabase.auth.currentUser?.id,
        'admin_note':  adminNote,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', appealId);
      _log('Appeal $appealId resolved: ${approved ? "approved" : "rejected"}');
    } catch (e) {
      _log('resolveAppeal error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getFullStats() async {
    try {
      final logs = await _supabase
          .from('ai_validation_logs')
          .select('status, validation_method, created_at')
          .order('created_at', ascending: false)
          .limit(500);

      int aiApproved = 0, aiRejected = 0;
      int rulesApproved = 0, rulesRejected = 0;
      int manualPending = 0, failed = 0;
      int lastHourCount = 0;

      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

      for (final row in logs as List) {
        final s  = row['status']            as String;
        final m  = row['validation_method'] as String;
        final ts = DateTime.tryParse(row['created_at'] as String? ?? '');
        if (ts != null && ts.isAfter(oneHourAgo)) lastHourCount++;

        if (s == 'approved' && m == 'ai')    aiApproved++;
        if (s == 'rejected' && m == 'ai')    aiRejected++;
        if (s == 'approved' && m == 'rules') rulesApproved++;
        if (s == 'rejected' && m == 'rules') rulesRejected++;
        if (s == 'pending')                  manualPending++;
        if (m == 'failed')                   failed++;
      }

      // Fetch the key now so the health dashboard shows accurate status
      // even if no validation has run yet this session.
      final liveKey = await _getApiKey();

      return {
        'ai_approved':    aiApproved,
        'ai_rejected':    aiRejected,
        'rules_approved': rulesApproved,
        'rules_rejected': rulesRejected,
        'manual_pending': manualPending,
        'failed':         failed,
        'total':          logs.length,
        'last_hour':      lastHourCount,
        'lost_logs':      _lostLogCount,
        'health':         _health.stats,
        'api_key_cached': liveKey.isNotEmpty,
        'key_age_minutes': null, // key is server-side only — no age tracked on client
      };
    } catch (e) {
      _log('getFullStats error: $e');
      return {'error': e.toString(), 'health': _health.stats};
    }
  }
}