// lib/core/services/tflite_classifier.dart
//
// Platform router — conditionally exports the native TFLite implementation
// on Android/iOS/desktop, and a no-op stub on web.
//
// All callers import THIS file only. They never reference _native or _stub
// directly, so the build system only compiles the right implementation.

export 'tflite_classifier_stub.dart'
    if (dart.library.io) 'tflite_classifier_native.dart';
