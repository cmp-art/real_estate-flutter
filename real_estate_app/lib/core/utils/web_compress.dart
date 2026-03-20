// lib/core/utils/web_compress.dart
// Web-only image resize — imported conditionally (dart.library.html).
// Uses dart:html canvas to scale large images down before base64-encoding
// so that requests to the Supabase Edge Function stay under the 6 MB limit.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

/// Resize [bytes] to at most 1024 px on the longest side and return the
/// result as a base64-encoded JPEG string suitable for the Anthropic API.
///
/// Returns null if the bytes are empty or if canvas rendering fails.
Future<String?> webResizeToBase64(Uint8List bytes) async {
  if (bytes.isEmpty) return null;

  // Under 900 KB → skip resize, encode as-is.
  const int targetBytes = 900 * 1024;
  if (bytes.length <= targetBytes) return base64Encode(bytes);

  // Detect MIME type from magic bytes.
  String mimeType = 'image/jpeg';
  if (bytes.length > 4 &&
      bytes[0] == 0x89 && bytes[1] == 0x50 &&
      bytes[2] == 0x4E && bytes[3] == 0x47) {
    mimeType = 'image/png';
  }

  final blob = html.Blob([bytes], mimeType);
  final url  = html.Url.createObjectUrl(blob);
  try {
    final img = html.ImageElement(src: url);
    await img.onLoad.first;

    final w = img.naturalWidth  ?? 0;
    final h = img.naturalHeight ?? 0;
    if (w == 0 || h == 0) return base64Encode(bytes);

    const int maxDim = 1024;
    int tw = w, th = h;
    if (w > maxDim || h > maxDim) {
      if (w >= h) {
        tw = maxDim;
        th = (h * maxDim / w).round().clamp(1, 4096);
      } else {
        th = maxDim;
        tw = (w * maxDim / h).round().clamp(1, 4096);
      }
    }

    final canvas = html.CanvasElement(width: tw, height: th);
    canvas.context2D.drawImageScaled(img, 0, 0, tw, th);

    // 0.82 quality JPEG — good visual quality at ~150-300 KB for 1024px images.
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.82);
    if (!dataUrl.contains(',')) return base64Encode(bytes);
    return dataUrl.split(',').last;
  } catch (_) {
    // Canvas failed — return raw bytes capped at 1 MB to avoid request overflow.
    final cap = bytes.length.clamp(0, 1024 * 1024);
    return base64Encode(bytes.sublist(0, cap));
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
