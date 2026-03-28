// lib/core/utils/web_crop.dart
// Web-only 4:3 center-crop using browser Canvas API.
// Imported conditionally — native platforms use web_crop_stub.dart instead.
//
// Why Canvas instead of the Dart `image` package on web:
//   • Dart `image` decodes/encodes synchronously on the main thread.
//     A 12 MP photo allocates ~100 MB of Dart heap and blocks the UI for
//     3–5 s on mid-range phones, risking a "Page Unresponsive" kill on
//     mobile Chrome / Safari PWA.
//   • Canvas uses hardware-accelerated compositing in browser GPU memory,
//     is fully async (onLoad/toBlob), and never touches the Dart heap.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Center-crop [bytes] to 4:3 landscape and resize to at most 1 280 px wide
/// using the browser Canvas 2D API.
///
/// Returns JPEG bytes on success, or null if the Canvas fails (caller should
/// fall back to returning the original bytes unchanged).
Future<Uint8List?> webCropToCard(Uint8List bytes) async {
  if (bytes.isEmpty) return null;

  // Detect MIME from magic bytes (JPEG vs PNG).
  String mimeType = 'image/jpeg';
  if (bytes.length > 3 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    mimeType = 'image/png';
  }

  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrl(blob);

  try {
    final imgEl = html.ImageElement()..src = url;
    // Wait for decode — throws if the format is unsupported.
    await imgEl.onLoad.first.timeout(const Duration(seconds: 15));

    final srcW = imgEl.naturalWidth;
    final srcH = imgEl.naturalHeight;
    if (srcW == 0 || srcH == 0) return null;

    // Largest 4:3 rect centered in the source.
    int cropW, cropH;
    if (srcW * 3 >= srcH * 4) {
      // Wider than 4:3 — constrain by height.
      cropH = srcH;
      cropW = (srcH * 4 / 3).round();
    } else {
      // Taller than 4:3 — constrain by width.
      cropW = srcW;
      cropH = (srcW * 3 / 4).round();
    }
    final sx = (srcW - cropW) ~/ 2;
    final sy = (srcH - cropH) ~/ 2;

    // Output: cap at 1 280 px wide (matches image_picker maxWidth).
    final outW = cropW > 1280 ? 1280 : cropW;
    final outH = (cropH * outW / cropW).round().clamp(1, 4096);

    final canvas = html.CanvasElement(width: outW, height: outH);
    canvas.context2D.drawImageScaledFromSource(
      imgEl,
      sx.toDouble(), sy.toDouble(), cropW.toDouble(), cropH.toDouble(),
      0, 0, outW.toDouble(), outH.toDouble(),
    );

    // Export as JPEG data-URL (quality 0.88 matches encodeJpg quality: 88).
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
    if (!dataUrl.contains(',')) return null;

    return Uint8List.fromList(base64Decode(dataUrl.split(',').last));
  } on TimeoutException {
    return null;
  } catch (_) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
