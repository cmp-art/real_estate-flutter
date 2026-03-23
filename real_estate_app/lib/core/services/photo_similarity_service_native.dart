// lib/core/services/photo_similarity_service_native.dart
//
// Native (Android / iOS / desktop) implementation.
// Compares a live camera photo against a list of listing photos using
// MobileNet V3 TFLite.  NOT compiled on web.
// Imported only via the conditional export in photo_similarity_service.dart.
//
// Score (0–50):
//   25 pts base  — photo was uploaded and the model processed it successfully.
//   +25 pts bonus — cosine similarity of feature vectors (best match).
//
// NOTE: MobileNet V3 softmax vectors are sparse (one class dominates), so
// cosine similarity is often near-zero even for visually similar scenes.
// The 25-pt base score ensures that users who upload a real photo are not
// penalised by this limitation.  GPS (0–50) + Photo (0–50), threshold 60/100,
// so BOTH signals are required — neither alone reaches the threshold.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void _plog(String msg) {
  if (kDebugMode) debugPrint('[PhotoSim] $msg');
}

class PhotoSimilarityService {
  static const String _modelPath = 'assets/ml/mobilenet_v3.tflite';
  static const int    _inputSize = 224;

  Interpreter? _interpreter;
  bool         _ready = false;

  // ── Initialise ───────────────────────────────────────────────────────────

  Future<void> _ensureReady() async {
    if (_ready || kIsWeb) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _ready = true;
      _plog('PhotoSimilarityService: model loaded');
    } catch (e) {
      _plog('PhotoSimilarityService: model load failed — $e');
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Compare [livePhoto] against [listingPhotos].
  /// Returns a photo similarity score in [0, 60].
  Future<int> comparePhotos({
    required XFile       livePhoto,
    required List<XFile> listingPhotos,
  }) async {
    await _ensureReady();

    if (!_ready) {
      _plog('Model not ready — photo score = 0');
      return 0;
    }
    if (listingPhotos.isEmpty) {
      _plog('No listing photos to compare against — photo score = 0');
      return 0;
    }

    final liveVector = await _extractVector(livePhoto);
    if (liveVector == null) {
      _plog('Could not extract feature vector from live photo — photo score = 0');
      return 0;
    }

    // Base 25 pts: photo was uploaded and the model extracted a vector.
    const int baseScore = 25;

    double bestSimilarity = 0.0;
    for (final listingPhoto in listingPhotos) {
      final listingVector = await _extractVector(listingPhoto);
      if (listingVector == null) continue;
      final sim = _cosineSimilarity(liveVector, listingVector);
      _plog('Similarity vs ${listingPhoto.name}: ${(sim * 100).toStringAsFixed(1)}%');
      if (sim > bestSimilarity) bestSimilarity = sim;
    }

    // Bonus 0–25 pts based on cosine similarity.
    // MobileNet softmax vectors are sparse so similarity is often near-zero;
    // even a small bonus rewards visually similar content.
    final bonusScore = (bestSimilarity * 25).clamp(0, 25).round();
    final score      = baseScore + bonusScore;
    _plog('Best similarity: ${(bestSimilarity * 100).toStringAsFixed(1)}% → bonus=$bonusScore → photo score = $score/50');
    return score;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _ready = false;
  }

  // ── Internal: extract TFLite feature vector ──────────────────────────────

  Future<Float32List?> _extractVector(XFile imageFile) async {
    if (_interpreter == null) return null;
    try {
      final bytes   = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final resized   = img.copyResize(decoded, width: _inputSize, height: _inputSize);
      final inputData = Float32List(_inputSize * _inputSize * 3);

      for (final pixel in resized) {
        final idx = (pixel.y * _inputSize + pixel.x) * 3;
        inputData[idx]     = (pixel.r.toDouble() / 127.5) - 1.0;
        inputData[idx + 1] = (pixel.g.toDouble() / 127.5) - 1.0;
        inputData[idx + 2] = (pixel.b.toDouble() / 127.5) - 1.0;
      }

      final outputSize = _interpreter!.getOutputTensor(0).shape.reduce((a, b) => a * b);
      final outputData = Float32List(outputSize);

      _interpreter!.run(
        inputData.reshape([1, _inputSize, _inputSize, 3]),
        outputData.reshape([1, outputSize]),
      );
      return outputData;
    } catch (e) {
      _plog('Feature extraction error for ${imageFile.name}: $e');
      return null;
    }
  }

  // ── Internal: cosine similarity ──────────────────────────────────────────

  double _cosineSimilarity(Float32List a, Float32List b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot   += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    if (denom == 0.0) return 0.0;
    return (dot / denom).clamp(0.0, 1.0);
  }
}
