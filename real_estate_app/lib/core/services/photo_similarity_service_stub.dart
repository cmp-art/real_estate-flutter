// lib/core/services/photo_similarity_service_stub.dart
//
// Web stub — TFLite is not available on Flutter Web.
// Always returns a score of 0 so verification falls back to other signals.

import 'package:image_picker/image_picker.dart';

class PhotoSimilarityService {
  /// Always returns 0 on web (TFLite not available).
  Future<int> comparePhotos({
    required XFile       livePhoto,
    required List<XFile> listingPhotos,
  }) async => 0;

  void dispose() {}
}
