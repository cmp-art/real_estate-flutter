// lib/core/services/tflite_classifier.dart
//
// Platform-conditional export.
//   • Native (Android / iOS / desktop): uses tflite_classifier_native.dart
//     which imports tflite_flutter and runs real on-device inference.
//   • Web: uses tflite_classifier_stub.dart — same public API, all no-ops,
//     classifier always reports as uninitialized so callers fall back to
//     rule-based image validation.
//
// All consumers import THIS file and never the _native / _stub variants directly.

export 'tflite_classifier_stub.dart'
    if (dart.library.io) 'tflite_classifier_native.dart';
