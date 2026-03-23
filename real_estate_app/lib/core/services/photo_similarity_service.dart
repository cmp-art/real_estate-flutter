// lib/core/services/photo_similarity_service.dart
//
// Platform-conditional export.
//   • Native (Android / iOS / desktop): uses photo_similarity_service_native.dart
//     which imports tflite_flutter and computes cosine similarity on-device.
//   • Web: uses photo_similarity_service_stub.dart — always returns score 0.
//
// All consumers import THIS file and never the _native / _stub variants directly.

export 'photo_similarity_service_stub.dart'
    if (dart.library.io) 'photo_similarity_service_native.dart';
