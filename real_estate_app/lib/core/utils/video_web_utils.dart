// lib/core/utils/video_web_utils.dart
// Web-only implementation — imported conditionally via video_utils.dart

// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Captures a JPEG thumbnail from a video blob URL using the browser canvas API.
/// Returns null if anything fails.
Future<Uint8List?> captureVideoThumbnailWeb(String videoUrl) async {
  try {
    final completer = Completer<Uint8List?>();

    final video = html.VideoElement()
      ..src = videoUrl
      ..muted = true
      ..preload = 'metadata';

    // Wait for enough data to seek
    video.onLoadedData.first.then((_) async {
      video.currentTime = 0;
      await video.onSeeked.first.timeout(const Duration(seconds: 5));

      final w = video.videoWidth.clamp(1, 480);
      final h = video.videoHeight.clamp(1, 360);
      final canvas = html.CanvasElement(width: w, height: h);
      canvas.context2D.drawImageScaled(video, 0, 0, w, h);

      final dataUrl   = canvas.toDataUrl('image/jpeg', 0.75);
      final base64Str = dataUrl.split(',').last;
      completer.complete(base64Decode(base64Str));
    }).catchError((_) => completer.complete(null));

    // Timeout safety
    return await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}
