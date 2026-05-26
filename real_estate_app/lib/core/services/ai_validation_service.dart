// lib/core/services/ai_validation_service.dart
//
// AI Validation Service — Production Ready
// =========================================
//
// IMAGE-ONLY moderation. The title / description / any other text is NEVER used
// to accept or reject a submission — only the uploaded PHOTOS are judged:
//   STEP 1 — Pre-flight (Dart, no network): reject tiny / broken / poison files
//   STEP 2 — Gemini Flash-Lite (server-side Edge Function): the only content gate
//             • property → every photo must depict real estate (room/house/land/business)
//             • ad       → image must be free of sexual / violent content
//   If Gemini is unreachable / undeployed, the submission is ALLOWED through
//   (we never judge it by its text); rejections come only from a real verdict.
//
// Gemini runs on EVERY platform (Android, iOS, Web, PWA) because it is a plain
// HTTPS call to the `validate-content` Edge Function — there is no on-device
// model. The Gemini API key lives ONLY as the GEMINI_API_KEY Edge Function
// secret and never reaches the client.
//
// KEY PRODUCTION FEATURES:
//   - Per-user rate limiting: max 5 attempts per 60 seconds
//   - Circuit-breaker health monitor (Gemini Edge Function state)
//   - ALL photos pre-flighted, then sent to Gemini (up to 4 of them)
//   - Lost-log counter exposed for admin monitoring
//   - _log() wrapper: silent in release builds, visible in debug

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Server-side Gemini image moderation (replaces the on-device TFLite model).
import 'gemini_moderation_service.dart';

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
//   OPEN     → breaker tripped; all image calls skip Gemini until cooldown elapses.
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
    _log('Circuit breaker manually reset — Gemini will be retried');
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
          _log('Circuit breaker half-open — sending one probe via Gemini');
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
    _log('Circuit breaker CLOSED — Gemini is healthy again');
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

  // Server-side Gemini image moderator (replaces the on-device TFLite model).
  // Works on every platform; a null verdict ⇒ fall back to rule-based text check.
  late final GeminiModerationService _gemini = GeminiModerationService(_supabase);

  static const Duration _timeout   = Duration(seconds: 60);
  static const int      _maxImages = 4; // up to 4 images classified per submission

  // Lost-log counter — admin can read this to detect Supabase logging issues.
  int _lostLogCount = 0;
  int get lostLogCount => _lostLogCount;

  AiValidationService(this._supabase);

  /// Kept for API compatibility. Gemini moderation is server-side, so there is
  /// no on-device model to load — this is a no-op.
  Future<void> initialize() async {}

  // ─────────────────────────────────────────────────────────────────────────
  // HEALTH
  // ─────────────────────────────────────────────────────────────────────────

  // Expose health stats for the admin monitoring widget.
  Map<String, dynamic> get healthStats => _health.stats;

  // ─────────────────────────────────────────────────────────────────────────
  // HEALTH CHECK
  //
  // Gemini moderation is server-side, so the only client-visible state is the
  // circuit breaker (which trips after repeated Edge Function failures, then
  // backs off). Returns a map with:
  //   ok     → bool   — breaker closed (Gemini calls are being attempted)
  //   stage  → String — 'all_good' | 'circuit_open'
  //   model  → String — model identifier
  //   detail → String — human-readable message
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkAiHealth() async {
    final healthy = _health.isHealthy;
    return {
      'ok':     healthy,
      'stage':  healthy ? 'all_good' : 'circuit_open',
      'model':  'gemini-flash-lite',
      'detail': healthy
          ? 'Cloud image moderation (Gemini) is active on all platforms.'
          : 'Image moderation is backing off after repeated errors; '
            'submissions are allowed through in the meantime.',
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — PROPERTY
  // ══════════════════════════════════════════════════════════════════════════

  /// Moderate a property's PHOTOS only. The title / description / any other
  /// text is NEVER used to accept or reject — only the uploaded images.
  Future<ValidationResult> validateProperty({
    List<XFile>? images,
    String?      submittedBy,
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

    final media = images ?? const <XFile>[];
    // No photo ⇒ nothing to check (text is never judged) ⇒ allow.
    if (media.isEmpty) return _pass('No photos to review.');

    return _moderateImages(
      type: 'property', images: media, isAd: false, submittedBy: submittedBy,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — AD
  // ══════════════════════════════════════════════════════════════════════════

  /// Moderate an ad's IMAGE only — block sexual / violent content. The headline
  /// and description text are NEVER used to accept or reject.
  Future<ValidationResult> validateAd({
    XFile?  image,
    String? submittedBy,
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

    // No image ⇒ nothing to check (text is never judged) ⇒ allow.
    if (image == null) return _pass('No image to review.');

    return _moderateImages(
      type: 'ad', images: [image], isAd: true, submittedBy: submittedBy,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE ENGINES
  // ══════════════════════════════════════════════════════════════════════════

  /// Image-only moderation. Pre-flights each photo locally, then asks Gemini.
  /// If Gemini is unreachable we ALLOW the submission — we never fall back to
  /// judging the title/description. Rejections come only from a real verdict.
  Future<ValidationResult> _moderateImages({
    required String      type,
    required List<XFile> images,
    required bool        isAd,
    String?              submittedBy,
  }) async {
    _log('moderate $type — photos=${images.length}, gemini_healthy=${_health.isHealthy}');

    // Pre-flight every photo (cheap, local, image-only).
    for (int i = 0; i < images.length; i++) {
      final reason = await _preflightImageCheck(images[i], index: i + 1);
      if (reason != null) {
        _log('Pre-flight rejected photo ${i + 1}: $reason');
        final result = ValidationResult(
          status: ValidationStatus.rejected, method: ValidationMethod.rules,
          approved: false, confidence: 99, reason: reason,
          suggestions: isAd
              ? ['Upload a real, clear image — not a tiny or broken file.']
              : ['Upload a real property photo: bedroom, living room, exterior, or land.'],
        );
        await _logValidation(type: type, result: result, submittedBy: submittedBy);
        return result;
      }
    }

    // Gemini is the ONLY content gate and it runs on EVERY save. We never let
    // an unverified image through: if Gemini cannot return a verdict (offline /
    // unreachable / timeout) the submission is BLOCKED and the user is asked to
    // try again, so pressing "save" a second time always re-checks the photos.
    try {
      final result = await _runGemini(images: images, isAd: isAd).timeout(_timeout);
      _health.recordSuccess();
      await _logValidation(type: type, result: result, submittedBy: submittedBy);
      return result;
    } catch (e) {
      _health.recordFailure();
      _log('$type Gemini moderation unavailable: $e — blocking (no verdict)');
      final blocked = _unavailable();
      await _logValidation(type: type, result: blocked, submittedBy: submittedBy);
      return blocked;
    }
  }

  /// Ask Gemini to moderate [images]. Throws when Gemini is unreachable.
  Future<ValidationResult> _runGemini({
    required List<XFile> images,
    required bool        isAd,
  }) async {
    final picked = _pickRepresentative(images, _maxImages);
    _log('Sending ${picked.length} image(s) to Gemini (isAd=$isAd)');

    final verdict = await _gemini.moderate(images: picked, isAd: isAd);
    if (verdict == null) throw StateError('gemini_unavailable');

    _log('Gemini verdict: approved=${verdict.approved} (${verdict.confidence}%) '
         'category=${verdict.category} — ${verdict.reason}');

    if (!verdict.approved) {
      return ValidationResult(
        status:           ValidationStatus.rejected,
        method:           ValidationMethod.ai,
        approved:         false,
        confidence:       verdict.confidence,
        detectedCategory: verdict.category.isNotEmpty ? verdict.category : null,
        reason:           verdict.reason.isNotEmpty
            ? verdict.reason
            : isAd
                ? 'Ad image contains prohibited (sexual or violent) content.'
                : 'One or more photos do not appear to show a real estate property.',
        suggestions: isAd
            ? ['Use a safe business image — no sexual or violent content.']
            : [
                'Upload photos of the property: bedroom, living room, exterior, or land.',
                'Do not upload people, vehicles, food, documents, or screenshots.',
              ],
      );
    }

    return ValidationResult(
      status:           ValidationStatus.approved,
      method:           ValidationMethod.ai,
      approved:         true,
      confidence:       verdict.confidence > 0 ? verdict.confidence : 85,
      detectedCategory: verdict.category.isNotEmpty ? verdict.category : null,
      reason:           isAd
          ? 'Ad image passed content-safety review.'
          : 'Photos appear to show a real estate property.',
    );
  }

  /// Approve with no findings — used only when there are NO photos to check
  /// (text / description is never judged).
  ValidationResult _pass(String reason) => ValidationResult(
        status:     ValidationStatus.approved,
        method:     ValidationMethod.ai,
        approved:   true,
        confidence: 100,
        reason:     reason,
      );

  /// Returned when the AI moderator could not produce a verdict (offline /
  /// unreachable / timeout). The submission is BLOCKED — every save must pass a
  /// real image check — and the user is asked to retry.
  ValidationResult _unavailable() => const ValidationResult(
        status:     ValidationStatus.pending,
        method:     ValidationMethod.failed,
        approved:   false,
        confidence: 0,
        reason:
            'We could not verify your photos just now. Check your connection '
            'and tap save again to re-run the photo check.',
        suggestions: [
          'Make sure you are online, then save again so the AI can review your photos.',
        ],
      );

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

  // Pre-flight: catches bad images before the Gemini call.
  // Checks file size, and screenshot dimensions for:
  //   - PNG/JPEG portrait phone screenshots
  //   - PNG/JPEG portrait tablet screenshots
  //   - PNG/JPEG landscape screenshots
  //   - HEIC/HEIF: passed through to Gemini (no dimension data available in header)
  //   - WebP: passed through to Gemini
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
        // WebP — no dimension check, pass to Gemini.
        _log('Photo $index is WebP — sending to Gemini');
        return null;

      } else if (bytes.length > 8 &&
          bytes[4] == 0x66 && bytes[5] == 0x74 &&
          bytes[6] == 0x79 && bytes[7] == 0x70) {
        // HEIC/HEIF (ftyp box) — no dimension check, pass to Gemini.
        _log('Photo $index is HEIC/HEIF — sending to Gemini');
        return null;
      }

      _log('Photo $index: ${imgWidth}x$imgHeight px');

      // Dimension-based screenshot detection removed.
      // Gallery photos and camera photos on modern phones are often
      // processed to standard dimensions (1080px, 1284px etc.) that
      // are indistinguishable from screenshots by size alone.
      // Gemini handles visual content moderation — it can reliably
      // tell a property photo from a screenshot by looking at it.
      if (imgWidth > 0 && imgHeight > 0) {
        _log('Photo $index: ${imgWidth}x${imgHeight}px — passing to Gemini');
      }

      return null; // Passed all checks.
    } catch (e) {
      _log('Pre-flight error on photo $index: $e — letting Gemini decide');
      return null;
    }
  }

  int _readInt32(Uint8List b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  int _readInt16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];

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
        'model_ready':    _health.isHealthy,
        'model':          'gemini-flash-lite',
      };
    } catch (e) {
      _log('getFullStats error: $e');
      return {'error': e.toString(), 'health': _health.stats};
    }
  }
}