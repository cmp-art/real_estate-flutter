// lib/core/services/ocr_service_stub.dart
//
// Web stub — ML Kit OCR is not available on Flutter Web.
// OcrService always returns null; fuzzyNameMatch is pure Dart and works on all platforms.

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

// ── Document OCR result ──────────────────────────────────────────────────────

class DocumentOcrResult {
  final String? name;
  final bool isTanzanian;
  const DocumentOcrResult({this.name, required this.isTanzanian});
}

class OcrService {
  /// Always returns a result with null name and isTanzanian=false on web (ML Kit not available).
  Future<DocumentOcrResult> processDocument(XFile imageFile) async =>
      const DocumentOcrResult(name: null, isTanzanian: false);

  /// Always returns null on web (ML Kit not available).
  Future<String?> extractName(XFile imageFile) async => null;

  Future<void> dispose() async {}
}

// ── Fuzzy name matching ──────────────────────────────────────────────────────
// Pure Dart — safe on all platforms including web.

double fuzzyNameMatch(String a, String b) {
  final Set<String> tokensA = _nameTokens(a);
  final Set<String> tokensB = _nameTokens(b);

  if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

  final intersection = tokensA.intersection(tokensB).length;
  final union        = tokensA.union(tokensB).length;

  final score = (intersection / union) * 100.0;
  if (kDebugMode) {
    debugPrint('[OCR] fuzzyNameMatch: "$a" vs "$b" → '
        '$intersection/$union = ${score.toStringAsFixed(1)}%');
  }
  return score;
}

Set<String> _nameTokens(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z\s]"), '')
    .split(RegExp(r'\s+'))
    .where((t) => t.length >= 2)
    .toSet();
