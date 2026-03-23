// lib/core/services/photo_similarity_service_stub.dart
//
// Web implementation using pure-Dart perceptual hashing (average hash).
// The `image` package (^4.1.7) is web-safe — no TFLite required.
//
// Score mapping:
//   50% bit match (random noise) → 0 pts
//   100% bit match (identical)   → 60 pts
//   Formula: ((similarity - 0.5) * 2 * 60).clamp(0, 60).round()

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class PhotoSimilarityService {
  /// Compares [livePhoto] against each of [listingPhotos] using average
  /// perceptual hashing and returns the best score (0–60).
  Future<int> comparePhotos({
    required XFile livePhoto,
    required List<XFile> listingPhotos,
  }) async {
    if (listingPhotos.isEmpty) return 0;

    final liveHash = await _computeHash(livePhoto);
    if (liveHash == null) return 0;

    int best = 0;
    for (final listing in listingPhotos) {
      final listingHash = await _computeHash(listing);
      if (listingHash == null) continue;
      final similarity = _hashSimilarity(liveHash, listingHash);
      final score = ((similarity - 0.5) * 2 * 60).clamp(0.0, 60.0).round();
      if (score > best) best = score;
    }
    return best;
  }

  void dispose() {}

  /// Reads [imageFile] bytes, decodes with the `image` package, resizes to 8×8,
  /// and returns a 64-element average-hash bit list. Returns null on failure.
  Future<List<bool>?> _computeHash(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Resize to 8×8 for the average hash
      final small = img.copyResize(decoded, width: 8, height: 8);

      // Compute grayscale luma for each pixel manually (r*0.299 + g*0.587 + b*0.114)
      final lumas = <double>[];
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = small.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();
          lumas.add(r * 0.299 + g * 0.587 + b * 0.114);
        }
      }

      // Average luma threshold
      final avg = lumas.fold(0.0, (sum, v) => sum + v) / lumas.length;

      // Hash: true if pixel luma >= average
      return lumas.map((l) => l >= avg).toList();
    } catch (_) {
      return null;
    }
  }

  /// Jaccard-style bit match: fraction of bits that agree.
  double _hashSimilarity(List<bool> a, List<bool> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    int matching = 0;
    for (int i = 0; i < a.length; i++) {
      if (a[i] == b[i]) matching++;
    }
    return matching / a.length;
  }
}
