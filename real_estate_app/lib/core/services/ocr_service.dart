// lib/core/services/ocr_service.dart
//
// Platform-conditional export.
//   • Native (Android / iOS): uses ocr_service_native.dart which imports
//     google_mlkit_text_recognition and runs real on-device OCR.
//   • Web: uses ocr_service_stub.dart — OcrService.extractName always returns
//     null; fuzzyNameMatch is pure Dart and works on all platforms.
//
// All consumers import THIS file and never the _native / _stub variants directly.

export 'ocr_service_stub.dart'
    if (dart.library.io) 'ocr_service_native.dart';
