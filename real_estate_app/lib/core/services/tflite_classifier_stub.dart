// lib/core/services/tflite_classifier_stub.dart
//
// Web stub — TFLite is not supported on Flutter Web.
// Exposes the same public API as the native implementation so all callers
// compile without changes. All methods are no-ops; the classifier always
// reports as uninitialized so callers fall back to rule-based logic.

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RESULT MODELS  (must match native file exactly)
// ─────────────────────────────────────────────────────────────────────────────

class LabelScore {
  final String label;
  final double score;
  const LabelScore(this.label, this.score);

  @override
  String toString() => '$label: ${(score * 100).toStringAsFixed(1)}%';
}

enum ImageCategory { realEstate, rejected, neutral }

class ImageClassificationResult {
  final List<LabelScore> topPredictions;
  final ImageCategory category;
  final String reason;
  final int confidence;

  const ImageClassificationResult({
    required this.topPredictions,
    required this.category,
    required this.reason,
    required this.confidence,
  });

  bool get isRealEstate => category == ImageCategory.realEstate;
  bool get isRejected   => category == ImageCategory.rejected;
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSIFIER STUB
// ─────────────────────────────────────────────────────────────────────────────

class TFLiteClassifier {
  bool    get isInitialized => false;
  String? get initError     => 'TFLite is not supported on web';

  Future<void> initialize() async {}

  /// Always returns null on web — callers must handle null gracefully.
  Future<ImageClassificationResult?> classify(XFile imageFile) async => null;

  /// Always returns null on web.
  Future<Float32List?> extractFeatureVector(XFile imageFile) async => null;

  void dispose() {}
}
