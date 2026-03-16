// lib/core/services/error_logging_service.dart
// Error logging using ONLY Supabase (replaces Sentry/Firebase Crashlytics)
//
// SCALE DESIGN (1M+ users):
//   • Sampling rates prevent a single error from creating 1M DB rows:
//       critical → 100 %  (always recorded)
//       error    →  10 %  (1-in-10 devices sampled)
//       warning  →   5 %  (1-in-20)
//       info     →   1 %  (1-in-100)
//   • Identical errors are de-duped within a 5-minute window.
//   • Non-critical errors are batched (up to 50) and flushed every 60 s.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorLoggingService {
  final _supabase = Supabase.instance.client;
  final _random = Random();

  // ── Sampling rates ─────────────────────────────────────────────────────────
  static const Map<String, double> _sampleRates = {
    'critical': 1.00,
    'error': 0.10,
    'warning': 0.05,
    'info': 0.01,
  };

  // ── De-duplication ─────────────────────────────────────────────────────────
  static const Duration _dedupWindow = Duration(minutes: 5);
  final Map<String, DateTime> _recentErrors = {};

  // ── Batching ───────────────────────────────────────────────────────────────
  static const Duration _flushInterval = Duration(seconds: 60);
  static const int _batchSize = 50;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;

  ErrorLoggingService() {
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    String? screenName,
    String severity = 'error',
    String? appVersion,
  }) async {
    // 1. Sampling gate
    final rate = _sampleRates[severity] ?? 0.10;
    if (_random.nextDouble() > rate) return;

    // 2. De-duplication gate
    final key = '$severity:$errorType:${errorMessage.hashCode}';
    final now = DateTime.now();
    final lastSeen = _recentErrors[key];
    if (lastSeen != null && now.difference(lastSeen) < _dedupWindow) return;
    _recentErrors[key] = now;

    // 3. Prune old dedup entries (prevent unbounded map growth)
    if (_recentErrors.length > 200) {
      _recentErrors.removeWhere((_, t) => now.difference(t) > _dedupWindow);
    }

    final user = _supabase.auth.currentUser;
    final row = {
      'user_id': user?.id,
      'error_type': errorType,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
      'screen_name': screenName,
      'severity': severity,
      'app_version': appVersion ?? '1.0.0',
      'device_info': {'platform': defaultTargetPlatform.toString()},
      'created_at': now.toUtc().toIso8601String(),
    };

    if (kDebugMode) debugPrint('🔴 Error [$severity] $errorType: $errorMessage');

    // 4. Critical → immediate write; others → batched
    if (severity == 'critical') {
      try {
        await _supabase.from('app_errors').insert(row);
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Failed to log critical error: $e');
      }
    } else {
      _queue.add(row);
      if (_queue.length >= _batchSize) await _flush();
    }
  }

  Future<void> logCritical({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    String? screenName,
  }) =>
      logError(
        errorType: errorType,
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        screenName: screenName,
        severity: 'critical',
      );

  Future<void> logWarning({
    required String errorType,
    required String errorMessage,
    String? screenName,
  }) =>
      logError(
        errorType: errorType,
        errorMessage: errorMessage,
        screenName: screenName,
        severity: 'warning',
      );

  Future<void> logInfo({required String message, String? screenName}) =>
      logError(
        errorType: 'info',
        errorMessage: message,
        screenName: screenName,
        severity: 'info',
      );

  Future<void> catchException(
    dynamic exception,
    StackTrace stackTrace, {
    String? screenName,
  }) =>
      logError(
        errorType: exception.runtimeType.toString(),
        errorMessage: exception.toString(),
        stackTrace: stackTrace.toString(),
        screenName: screenName,
      );

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _flush();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<void> _flush() async {
    if (_queue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      await _supabase.from('app_errors').insert(batch);
      if (kDebugMode) debugPrint('🔴 Flushed ${batch.length} error rows');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error flush failed: $e');
      if (_queue.length < _batchSize) _queue.insertAll(0, batch);
    }
  }
}
