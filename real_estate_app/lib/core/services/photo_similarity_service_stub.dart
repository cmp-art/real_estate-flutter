// lib/core/services/photo_similarity_service_stub.dart
//
// Web implementation.
// TFLite is not available on Flutter Web, and perceptual hashing of 8×8
// thumbnails produces ~50% similarity for any two different images, which
// maps to a score of 0 — so we no longer use it.
//
// Score (0–50):
//   25 pts — live photo was uploaded and decoded successfully.
//    0 pts — photo could not be decoded (corrupt / unsupported format).
//
// GPS (0–50) + Photo (0–50), threshold 60/100.
// Neither GPS nor Photo alone reaches 60 — both are required.
//
// GPS scoring (0–70) is the primary signal on all platforms; photo on web
// is a secondary confirmation that the user submitted some image.

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class PhotoSimilarityService {
  /// Returns 20 if [livePhoto] can be decoded, 0 otherwise.
  /// [listingPhotos] is accepted for API compatibility but not used on web.
  Future<int> comparePhotos({
    required XFile livePhoto,
    required List<XFile> listingPhotos,
  }) async {
    try {
      final bytes   = await livePhoto.readAsBytes();
      final decoded = img.decodeImage(bytes);
      // Award 25 pts if the photo is a valid image file.
      return decoded != null ? 25 : 0;
    } catch (_) {
      return 0;
    }
  }

  void dispose() {}
}
