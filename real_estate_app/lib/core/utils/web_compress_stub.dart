// lib/core/utils/web_compress_stub.dart
// Native stub — flutter_image_compress handles compression on native builds.
// This function is imported only on non-web platforms; it is never called.

import 'dart:convert';
import 'dart:typed_data';

/// Stub: returns raw base64.  On native the caller uses flutter_image_compress
/// before reaching this function, so this path is not exercised in practice.
Future<String?> webResizeToBase64(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  return base64Encode(bytes);
}
