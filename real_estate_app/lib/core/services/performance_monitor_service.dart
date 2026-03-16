// lib/core/services/performance_monitor_service.dart
// Performance monitoring using ONLY Supabase (replaces Firebase Performance)
//
// SCALE DESIGN (1M+ users):
//   • Only 5 % of operations are sampled (configurable per metric type).
//   • Slow operations (>2 s) are always captured regardless of sample rate.
//   • Metrics are batched (up to 30) and flushed every 60 s.
//   • Image-load metrics are sampled at 1 % to cap egress from high-traffic screens.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerformanceMonitorService {
  final _supabase = Supabase.instance.client;
  final _random = Random();

  // ── Sampling rates per metric type ────────────────────────────────────────
  static const Map<String, double> _sampleRates = {
    'screen_load': 0.05,   //  5 %  – enough for p50/p95 percentiles
    'api_call': 0.05,      //  5 %
    'image_load': 0.01,    //  1 %  – very high-volume; minimal data needed
    'password_recovery': 1.00, // 100 % – rare, always capture
    'default': 0.05,
  };

  // ── Slow-operation threshold (always captured) ────────────────────────────
  static const int _slowThresholdMs = 2000;

  // ── Batching ───────────────────────────────────────────────────────────────
  static const Duration _flushInterval = Duration(seconds: 60);
  static const int _batchSize = 30;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;

  PerformanceMonitorService() {
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> recordMetric({
    required String metricName,
    required int durationMs,
    String? screenName,
    Map<String, dynamic>? metadata,
  }) async {
    // Always capture genuinely slow operations; otherwise apply sampling
    final isSlow = durationMs >= _slowThresholdMs;
    final rate = _sampleRates[metricName] ?? _sampleRates['default']!;
    if (!isSlow && _random.nextDouble() > rate) return;

    final user = _supabase.auth.currentUser;
    final row = {
      'user_id': user?.id,
      'metric_name': metricName,
      'duration_ms': durationMs,
      'screen_name': screenName,
      'metadata': metadata,
      'is_slow': isSlow,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (kDebugMode && isSlow) {
      debugPrint('⚠️ Slow op: $metricName took ${durationMs}ms');
    }

    _queue.add(row);
    if (_queue.length >= _batchSize) await _flush();
  }

  /// Wraps any async operation with timing. Only the result is returned;
  /// the metric is queued asynchronously to avoid blocking the UI.
  Future<T> trace<T>({
    required String name,
    required Future<T> Function() operation,
    String? screenName,
  }) async {
    final start = DateTime.now();
    try {
      final result = await operation();
      unawaited(recordMetric(
        metricName: name,
        durationMs: DateTime.now().difference(start).inMilliseconds,
        screenName: screenName,
      ));
      return result;
    } catch (e) {
      unawaited(recordMetric(
        metricName: name,
        durationMs: DateTime.now().difference(start).inMilliseconds,
        screenName: screenName,
        metadata: {'error': e.toString()},
      ));
      rethrow;
    }
  }

  Future<void> recordApiCall({
    required String endpoint,
    required int durationMs,
    bool success = true,
  }) =>
      recordMetric(
        metricName: 'api_call',
        durationMs: durationMs,
        metadata: {'endpoint': endpoint, 'success': success},
      );

  Future<void> recordImageLoad({
    required String imageUrl,
    required int durationMs,
  }) =>
      recordMetric(
        metricName: 'image_load',
        durationMs: durationMs,
        // Strip query params from URL before storing — avoids leaking CDN tokens
        metadata: {'url': Uri.parse(imageUrl).replace(query: '').toString()},
      );

  Future<void> recordScreenLoad({
    required String screenName,
    required int durationMs,
  }) =>
      recordMetric(
        metricName: 'screen_load',
        durationMs: durationMs,
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
      await _supabase.from('performance_metrics').insert(batch);
      if (kDebugMode) debugPrint('⚡ Flushed ${batch.length} perf metrics');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Perf flush failed: $e');
      if (_queue.length < _batchSize) _queue.insertAll(0, batch);
    }
  }
}

// Silence the unawaited_futures lint for fire-and-forget calls
void unawaited(Future<void> future) {}
