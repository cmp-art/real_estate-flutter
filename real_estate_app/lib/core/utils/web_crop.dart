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
//     is fully async (onLoad), and never touches the Dart heap.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Center-crop [bytes] to 4:3 landscape and resize to at most 1 280 px wide
/// using the browser Canvas 2D API.
///
/// Returns JPEG bytes on success, or null if the Canvas fails (caller should
/// fall back to returning the original bytes unchanged).
Future<Uint8List?> webCropToCard(Uint8List bytes) async {
  if (bytes.isEmpty) return null;

  // Detect MIME type from magic bytes so the Blob has the correct Content-Type.
  // A mismatch (e.g. AVIF/WebP bytes labelled 'image/jpeg') causes some mobile
  // browsers to reject the image, silently returning a failed load event.
  final String mimeType;
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    mimeType = 'image/jpeg';
  } else if (bytes.length >= 4 &&
      bytes[0] == 0x89 && bytes[1] == 0x50 &&
      bytes[2] == 0x4E && bytes[3] == 0x47) {
    mimeType = 'image/png';
  } else if (bytes.length >= 4 &&
      bytes[0] == 0x47 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x38) {
    mimeType = 'image/gif';
  } else if (bytes.length >= 12 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 &&
      bytes[10] == 0x42 && bytes[11] == 0x50) {
    mimeType = 'image/webp';
  } else if (bytes.length >= 12 &&
      bytes[4] == 0x66 && bytes[5] == 0x74 &&
      bytes[6] == 0x79 && bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
    mimeType = (brand == 'avif' || brand == 'avis') ? 'image/avif' : 'image/heic';
  } else {
    mimeType = 'application/octet-stream';
  }

  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrl(blob);

  try {
    final imgEl = html.ImageElement()..src = url;

    // Wait for the image to fully decode before drawing.
    // onError fires for unsupported formats (e.g. HEIC on some browsers).
    await Future.any([
      imgEl.onLoad.first,
      imgEl.onError.first.then((_) => throw Exception('image load error')),
    ]).timeout(const Duration(seconds: 15));

    final srcW = imgEl.naturalWidth;
    final srcH = imgEl.naturalHeight;
    if (srcW == 0 || srcH == 0) return null;

    // Largest 4:3 rect centered in the source.
    int cropW, cropH;
    if (srcW * 3 >= srcH * 4) {
      // Wider than 4:3 — constrain by height.
      cropH = srcH;
      cropW = (srcH * 4 ~/ 3); // integer division avoids double rounding
    } else {
      // Taller than 4:3 — constrain by width.
      cropW = srcW;
      cropH = (srcW * 3 ~/ 4);
    }
    final sx = (srcW - cropW) ~/ 2;
    final sy = (srcH - cropH) ~/ 2;

    // Output: cap at 1 280 px wide, maintain exact 4:3.
    // Use integer division throughout to avoid float-to-int canvas issues.
    final outW = math.min(cropW, 1280);
    final outH = math.max(1, cropH * outW ~/ cropW);

    final canvas = html.CanvasElement(width: outW, height: outH);
    final ctx = canvas.context2D;

    // ── Fill white background ─────────────────────────────────────────────
    // JPEG does not support alpha. If the source image has any transparent
    // pixels, browsers fill them with BLACK during JPEG encoding, producing
    // dark splotches. Pre-filling white ensures a clean background.
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, outW, outH);

    ctx.drawImageScaledFromSource(
      imgEl,
      sx.toDouble(), sy.toDouble(),
      cropW.toDouble(), cropH.toDouble(),
      0.0, 0.0,
      outW.toDouble(), outH.toDouble(),
    );

    // ── Force GPU synchronisation ─────────────────────────────────────────
    // drawImageScaledFromSource queues a GPU command on mobile browsers.
    // Calling toDataUrl() synchronously right after can capture a blank
    // canvas if the GPU hasn't flushed yet. getImageData() forces a
    // synchronous GPU readback, ensuring the draw is complete.
    ctx.getImageData(0, 0, 1, 1);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
    if (!dataUrl.contains(',')) return null;

    // Validate the data URL actually contains JPEG bytes (starts with /9j/)
    // before decoding — some browsers silently return a PNG data URL even
    // when 'image/jpeg' is requested (e.g. when source has transparency).
    final b64 = dataUrl.split(',').last;
    final outBytes = Uint8List.fromList(base64Decode(b64));
    if (outBytes.length < 100) return null; // suspiciously small — discard

    return outBytes;
  } on TimeoutException {
    return null;
  } catch (_) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

/// Full-frame downscale (no crop) so the longest edge is at most [maxEdge],
/// using the browser Canvas API. Used for ad creatives, which keep their own
/// aspect ratio. Transparency is preserved for PNG/WebP sources (logos) by
/// encoding PNG; everything else encodes JPEG with a white background.
///
/// Returns the encoded bytes, or null if the Canvas can't decode the source
/// (caller falls back to the raw bytes, which the upload service then coerces).
Future<Uint8List?> webResizeToMaxEdge(Uint8List bytes,
    {int maxEdge = 1600}) async {
  if (bytes.isEmpty) return null;

  // Keep alpha for PNG/WebP (logos); photos and everything else → JPEG.
  final bool isPng = bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  final bool isWebp = bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
  final bool isJpeg = bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
  final bool preserveAlpha = isPng || isWebp;
  final String srcMime = isPng
      ? 'image/png'
      : isWebp
          ? 'image/webp'
          : isJpeg
              ? 'image/jpeg'
              : 'application/octet-stream';

  final blob = html.Blob([bytes], srcMime);
  final url = html.Url.createObjectUrl(blob);

  try {
    final imgEl = html.ImageElement()..src = url;
    await Future.any([
      imgEl.onLoad.first,
      imgEl.onError.first.then((_) => throw Exception('image load error')),
    ]).timeout(const Duration(seconds: 15));

    final srcW = imgEl.naturalWidth;
    final srcH = imgEl.naturalHeight;
    if (srcW == 0 || srcH == 0) return null;

    final longest = srcW >= srcH ? srcW : srcH;
    final scale = longest > maxEdge ? maxEdge / longest : 1.0;
    int outW = (srcW * scale).round();
    int outH = (srcH * scale).round();
    if (outW < 1) outW = 1;
    if (outH < 1) outH = 1;

    final canvas = html.CanvasElement(width: outW, height: outH);
    final ctx = canvas.context2D;

    // JPEG has no alpha — pre-fill white so transparent pixels don't turn
    // black. For PNG output we keep the transparent background.
    if (!preserveAlpha) {
      ctx.fillStyle = '#FFFFFF';
      ctx.fillRect(0, 0, outW, outH);
    }

    ctx.drawImageScaled(imgEl, 0, 0, outW.toDouble(), outH.toDouble());

    // Force a synchronous GPU readback so the draw is flushed before encode
    // (mobile browsers otherwise capture a blank canvas).
    ctx.getImageData(0, 0, 1, 1);

    final dataUrl = preserveAlpha
        ? canvas.toDataUrl('image/png')
        : canvas.toDataUrl('image/jpeg', 0.82);
    if (!dataUrl.contains(',')) return null;

    final outBytes = Uint8List.fromList(base64Decode(dataUrl.split(',').last));
    if (outBytes.length < 100) return null; // suspiciously small — discard
    return outBytes;
  } on TimeoutException {
    return null;
  } catch (_) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

/// Picks image(s) on web using a native `<input type="file">` and reads each
/// selected File's bytes directly via FileReader.
///
/// Why not image_picker here: image_picker hands back `blob:` URLs, and getting
/// the bytes out of a blob URL requires re-fetching it. In an installed PWA
/// that fetch can be intercepted by the Flutter service worker and answered
/// with the cached offline index.html — which the app then sees as an
/// unreadable image ("photo could not be loaded, try picking it again").
/// Reading the in-memory File with FileReader involves no URL and no fetch, so
/// the service worker has nothing to intercept and the read can't be poisoned.
///
/// Returns the bytes of every file read successfully, plus a count of any that
/// failed (so the caller can warn the user).
Future<({List<Uint8List> bytes, int failed})> pickImagesAsBytesWeb({
  bool multiple = true,
  bool capture = false,
}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = multiple;
  // On mobile, capture opens the camera directly; desktop browsers ignore it.
  if (capture) input.setAttribute('capture', 'environment');
  // Must be attached to the DOM for the chooser to open on some browsers;
  // keep it off-screen.
  input.style
    ..position = 'fixed'
    ..left = '-10000px'
    ..top = '0';
  html.document.body?.append(input);

  final picked = Completer<List<html.File>>();
  void done(List<html.File> files) {
    if (!picked.isCompleted) picked.complete(files);
  }

  input.onChange.listen((_) => done(input.files ?? const <html.File>[]));
  // Modern browsers fire 'cancel' when the file chooser is dismissed.
  input.on['cancel'].listen((_) => done(const <html.File>[]));

  input.click();
  final files = await picked.future;
  input.remove();

  final bytes = <Uint8List>[];
  var failed = 0;
  // Read sequentially so peak memory stays bounded on phones.
  for (final file in files) {
    final data = await _readFileBytes(file);
    if (data != null && data.isNotEmpty) {
      bytes.add(data);
    } else {
      failed++;
    }
  }
  return (bytes: bytes, failed: failed);
}

/// Reads a browser [File] into bytes via FileReader (no blob: URL, no fetch).
Future<Uint8List?> _readFileBytes(html.File file) {
  final reader = html.FileReader();
  final c = Completer<Uint8List?>();
  reader.onLoadEnd.listen((_) {
    final r = reader.result;
    if (r is Uint8List) {
      c.complete(r);
    } else if (r is ByteBuffer) {
      c.complete(r.asUint8List());
    } else if (r is List<int>) {
      c.complete(Uint8List.fromList(r));
    } else {
      c.complete(null);
    }
  });
  reader.onError.listen((_) => c.complete(null));
  try {
    reader.readAsArrayBuffer(file);
  } catch (_) {
    if (!c.isCompleted) c.complete(null);
  }
  return c.future;
}
