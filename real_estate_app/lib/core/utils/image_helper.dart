import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../config/theme_config.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import 'image_format.dart';
import 'web_crop.dart' if (dart.library.io) 'web_crop_stub.dart';

class ImageHelper {
  final ImagePicker _picker = ImagePicker();

  // ── Concurrent-call guard ──────────────────────────────────────────────────
  // The native image picker throws PlatformException(already_active, ...) if
  // it's opened a second time while it's still running (double-tap, screen
  // re-entry after navigation, etc.).  This flag prevents that.
  bool _isPickerActive = false;

  // Pick single image from gallery
  Future<File?> pickImageFromGallery() async {
    if (_isPickerActive) return null;   // already open — silently ignore
    _isPickerActive = true;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;

      final File imageFile = File(image.path);
      
      // Check file size
      if (await _isFileSizeValid(imageFile)) {
        return imageFile;
      } else {
        throw ValidationException('Image size must be less than ${AppConstants.maxImageSize / (1024 * 1024)}MB');
      }
    } on ValidationException {
      rethrow;                          // our own errors pass through as-is
    } catch (e) {
      // PlatformException(already_active) means the picker was already open.
      // Swallow it silently — the user will see the existing picker session.
      if (e.toString().contains('already_active')) return null;
      throw ValidationException(e.toString());
    } finally {
      _isPickerActive = false;          // always release the lock
    }
  }

  // Pick single image from camera
  Future<File?> pickImageFromCamera() async {
    if (_isPickerActive) return null;   // already open — silently ignore
    _isPickerActive = true;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;

      final File imageFile = File(image.path);
      
      // Check file size
      if (await _isFileSizeValid(imageFile)) {
        return imageFile;
      } else {
        throw ValidationException('Image size must be less than ${AppConstants.maxImageSize / (1024 * 1024)}MB');
      }
    } on ValidationException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('already_active')) return null;
      throw ValidationException(e.toString());
    } finally {
      _isPickerActive = false;
    }
  }

  // Pick multiple images from gallery — returns XFile (works on web + native).
  // Any picked image is accepted regardless of size — the normalize/upload
  // step downscales it to a small target, so large originals are never skipped.
  //
  // On web (PWA / mobile browser) we intentionally pick ONE image at a time
  // using pickImage() instead of pickMultiImage().  pickMultiImage decodes all
  // selected photos in parallel on the browser canvas — each full JPEG decode
  // costs 48–434 MB RAM depending on camera resolution.  Mobile browsers kill
  // the tab if this exceeds ~300 MB.  Picking sequentially lets the browser GC
  // between picks and stays safely within the memory budget.
  Future<List<XFile>> pickMultipleImages({
    int maxImages = 10,
    ImageSource source = ImageSource.gallery,
    // Called when one or more images could not be read at the browser level
    // (service-worker HTML poison or expired blob URL). The count is how many
    // were silently unreadable so the caller can show a user-facing warning.
    void Function(int count)? onUnreadable,
  }) async {
    if (_isPickerActive) return [];     // already open — silently ignore
    _isPickerActive = true;
    try {
      // Web/PWA (gallery + camera): pick via a native <input type="file"> and
      // read each File's bytes directly with FileReader (pickImagesAsBytesWeb).
      // This avoids image_picker's blob: URLs entirely — a blob URL must be
      // re-fetched to read it, and in an installed PWA that fetch can be
      // intercepted by the service worker and answered with the offline HTML
      // page (the "photo could not be loaded" failure). Reading the File object
      // directly leaves nothing for the service worker to poison; capture opens
      // the device camera on mobile.
      if (kIsWeb) {
        final result = await pickImagesAsBytesWeb(
          multiple: source != ImageSource.camera,
          capture: source == ImageSource.camera,
        );
        if (result.failed > 0) onUnreadable?.call(result.failed);
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final picked = <XFile>[];
        for (var i = 0; i < result.bytes.length && i < maxImages; i++) {
          picked.add(XFile.fromData(
            result.bytes[i],
            name: 'photo_${stamp}_$i.jpg',
            mimeType: 'image/jpeg',
          ));
        }
        return picked;
      }

      // ── Android / iOS (native) ──────────────────────────────────────────
      final List<XFile> images;
      if (source == ImageSource.camera) {
        final XFile? shot = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        images = shot != null ? [shot] : [];
      } else {
        images = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      }

      if (images.isEmpty) return [];

      // Accept any size: never reject a photo for being large. The normalize
      // step downscales every image to a small target before upload, so big
      // originals are handled rather than skipped. Only the count is capped.
      return images.take(maxImages).toList();
    } catch (e) {
      if (e.toString().contains('already_active')) return [];
      throw ValidationException(e.toString());
    } finally {
      _isPickerActive = false;
    }
  }

  // Crop image (free-form, legacy use)
  Future<File?> cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: ThemeConfig.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
        ],
      );
      if (croppedFile != null) return File(croppedFile.path);
      return null;
    } catch (e) {
      throw ValidationException(e.toString());
    }
  }

  // ── Normalise any picked image into a safe-to-upload file ─────────────────
  // Optional local optimisation for UX before the direct upload:
  //   • Web: tries Canvas crop-to-4:3 for common formats (JPEG/PNG/WebP); falls
  //     back to raw bytes for HEIC/AVIF/unknown (ImageUploadService coerces
  //     those to a servable JPEG at upload time).
  //   • Native: uses image_picker's built-in HEIC→JPEG transcoding + runs the
  //     crop in a background isolate for consistent card display.
  //
  // RETURN CONTRACT:
  //   • non-null XFile → bytes ready to upload.
  //   • null ONLY for empty bytes or an HTML service-worker poison page.
  //     HEIC / AVIF / unknown formats are NEVER dropped — ImageUploadService
  //     coerces them to a servable JPEG at upload time.
  Future<XFile?> normalizeForUpload(
    BuildContext context,
    XFile image, {
    bool card = true,
  }) async {
    final tag = DateTime.now().millisecondsSinceEpoch;

    if (kIsWeb) {
      // ── Web / PWA ──────────────────────────────────────────────────────────
      // readAsBytes() is the critical PWA / Scoped Storage fix: it forces the
      // OS to resolve the file stream into raw bytes immediately, bypassing the
      // service worker and Android's content:// URI routing that turns
      // screenshots and WhatsApp photos into empty or HTML responses.
      try {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) return null;

        final fmt = detectImageFormat(bytes);

        // Service-worker offline page masquerading as an image — cannot recover.
        if (fmt == DetectedImageFormat.html) return null;

        // Canvas: hardware-accelerated decode/resize that never touches the
        // Dart heap, so even a 48 MP photo can't OOM the browser tab.
        if (card) {
          // Property card: center-crop to 4:3 and downscale to 1 280 px JPEG.
          final cropped = await webCropToCard(bytes);
          if (cropped != null && cropped.isNotEmpty) {
            return XFile.fromData(cropped,
                name: 'crop_$tag.jpg', mimeType: 'image/jpeg');
          }
        } else {
          // Ad creative: full-frame downscale to 1 600 px so the stored file is
          // small (~300 KB), keeping PNG/WebP transparency for logos.
          final resized = await webResizeToMaxEdge(bytes, maxEdge: 1600);
          if (resized != null && resized.isNotEmpty) {
            final outFmt = detectImageFormat(resized);
            return XFile.fromData(resized,
                name: 'ad_$tag.${outFmt.fileExtension}',
                mimeType: outFmt.mimeType);
          }
        }

        // Canvas could not decode this (HEIC/AVIF on a desktop browser, or a
        // decode failure). Upload the raw bytes — the upload service coerces
        // them to a servable, right-sized JPEG on a background isolate.
        return XFile.fromData(bytes,
            name: 'photo_$tag.${fmt.fileExtension}', mimeType: fmt.mimeType);
      } catch (_) {
        return null;
      }
    }

    // ── Android / iOS ──────────────────────────────────────────────────────
    // Decode/resize/encode runs on a background isolate via compute() so a
    // batch of large photos can't block the UI thread and trigger an ANR ("app
    // not responding") on low-end devices. Best-effort — fall back to the
    // original picked image on any error.
    try {
      final bytes = await image.readAsBytes();
      final outBytes = card
          ? await compute(_cropToCardJpg, bytes)
          : await compute(_resizeToServable, _ResizeRequest(bytes, 1600));
      if (outBytes == null || outBytes.isEmpty) return image;

      final outFmt = detectImageFormat(outBytes);
      final tmpDir = await getTemporaryDirectory();
      final outPath = '${tmpDir.path}/norm_$tag.${outFmt.fileExtension}';
      await File(outPath).writeAsBytes(outBytes);
      return XFile(outPath);
    } catch (_) {
      return image;
    }
  }

  // 4:3 center-crop for property cards — thin wrapper over [normalizeForUpload].
  Future<XFile?> cropToCard(BuildContext context, XFile image) =>
      normalizeForUpload(context, image, card: true);

  // ── Avatar-ready bytes (small square JPEG) ────────────────────────────────
  // The profile-images bucket only accepts image/jpeg|png|webp and caps files
  // at 5 MB (see sql3). A full-resolution phone photo (3–8 MB), a GIF, or an
  // octet-stream therefore gets rejected server-side — the source of the
  // "upload failed, try again" errors. Re-encoding every avatar to a 512 px
  // square JPEG makes the payload tiny (~40–120 KB) and always an accepted
  // type, so the upload succeeds regardless of what the user picked.
  //
  // Decoding/cropping runs on a background isolate via compute() so a large
  // photo can't jank the UI. Returns null ONLY when the bytes are unreadable
  // (empty / service-worker HTML poison) or an undecodable format such as raw
  // HEIC from a desktop browser (the pure-Dart `image` package can't decode
  // HEIC; on phones image_picker has already transcoded it to JPEG).
  Future<Uint8List?> normalizeAvatar(XFile image) async {
    Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (_) {
      return null;
    }
    if (bytes.isEmpty) return null;

    final fmt = detectImageFormat(bytes);
    if (fmt == DetectedImageFormat.html) return null; // offline page, not an image

    try {
      final out = await compute(_avatarToSquareJpg, bytes);
      if (out != null && out.isNotEmpty) return out;
    } catch (_) {
      // fall through to the passthrough fallback below
    }

    // Could not decode (e.g. HEIC/AVIF from a desktop browser). If the bytes
    // are already a small, bucket-servable format, upload them as-is; otherwise
    // refuse so the caller can ask the user for a JPEG/PNG.
    final servable = fmt == DetectedImageFormat.jpeg ||
        fmt == DetectedImageFormat.png ||
        fmt == DetectedImageFormat.webp;
    if (servable && bytes.lengthInBytes <= 5 * 1024 * 1024) return bytes;
    return null;
  }

  // ── Pick a single image as an XFile (web + native) ────────────────────────
  // Unlike [pickImageFromGallery]/[pickImageFromCamera] (which return a
  // dart:io File and so only work on native), this returns an XFile usable on
  // every platform. On web the bytes are read immediately — in the same JS
  // context that created the blob — so the PWA service worker can't later
  // intercept the blob: URL and hand back the offline page.
  Future<XFile?> pickSingleImage({required ImageSource source}) async {
    if (_isPickerActive) return null;
    _isPickerActive = true;
    try {
      // Web/PWA (gallery + camera): read the File directly via FileReader
      // (pickImagesAsBytesWeb) so there is no blob: URL for the service worker
      // to poison. capture opens the device camera on mobile.
      if (kIsWeb) {
        final result = await pickImagesAsBytesWeb(
          multiple: false,
          capture: source == ImageSource.camera,
        );
        if (result.bytes.isEmpty) return null;
        return XFile.fromData(
          result.bytes.first,
          name: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        );
      }

      final XFile? shot = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return shot;
    } catch (e) {
      if (e.toString().contains('already_active')) return null;
      throw ValidationException(e.toString());
    } finally {
      _isPickerActive = false;
    }
  }


  // Show image source dialog
  Future<File?> showImageSourceDialog(BuildContext context) async {
    return showModalBottomSheet<File>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await pickImageFromGallery();
                  if (context.mounted && image != null) {
                    Navigator.pop(context, image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await pickImageFromCamera();
                  if (context.mounted && image != null) {
                    Navigator.pop(context, image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // Validate file size
  Future<bool> _isFileSizeValid(File file) async {
    final fileSize = await file.length();
    return fileSize <= AppConstants.maxImageSize;
  }

  // Get image extension
  String getImageExtension(String path) {
    return path.split('.').last.toLowerCase();
  }

  // Validate image format
  bool isValidImageFormat(String path) {
    final extension = getImageExtension(path);
    return AppConstants.allowedImageFormats.contains(extension);
  }
}

// Runs on a background isolate (via compute) so the UI thread never blocks.
// Center-crops [bytes] to the largest 4:3 rect, resizes to 1 280 px wide, and
// JPEG-encodes at 88 %. Returns null if the bytes can't be decoded.
Uint8List? _cropToCardJpg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes); // applies EXIF orientation on decode
  if (decoded == null) return null;

  final srcW = decoded.width;
  final srcH = decoded.height;

  int cropW, cropH;
  if (srcW * 3 >= srcH * 4) {
    cropH = srcH;
    cropW = (srcH * 4 / 3).round();
  } else {
    cropW = srcW;
    cropH = (srcW * 3 / 4).round();
  }
  final offsetX = (srcW - cropW) ~/ 2;
  final offsetY = (srcH - cropH) ~/ 2;

  final cropped =
      img.copyCrop(decoded, x: offsetX, y: offsetY, width: cropW, height: cropH);
  final resized = img.copyResize(cropped, width: 1280);
  return img.encodeJpg(resized, quality: 88);
}

// Runs on a background isolate (via compute) so the UI thread never blocks.
// Decodes [bytes] (applying EXIF orientation), center-crops to the largest
// square, downsizes to 512 px and JPEG-encodes at 85 %. Returns null if the
// bytes can't be decoded.
Uint8List? _avatarToSquareJpg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final offsetX = (decoded.width - side) ~/ 2;
  final offsetY = (decoded.height - side) ~/ 2;

  final square =
      img.copyCrop(decoded, x: offsetX, y: offsetY, width: side, height: side);
  final sized = side > 512
      ? img.copyResize(square, width: 512, height: 512)
      : square;
  return img.encodeJpg(sized, quality: 85);
}

// Argument bundle for the [_resizeToServable] isolate entry point.
class _ResizeRequest {
  final Uint8List bytes;
  final int maxEdge;
  const _ResizeRequest(this.bytes, this.maxEdge);
}

// Runs on a background isolate (via compute). Downscales [req.bytes] so the
// longest edge is at most [req.maxEdge], applying EXIF orientation on decode.
// Keeps an alpha channel as PNG (logos with transparency) and encodes
// everything else as JPEG q82 so the stored file stays small (~300 KB).
// Returns null if the bytes can't be decoded.
Uint8List? _resizeToServable(_ResizeRequest req) {
  final decoded = img.decodeImage(req.bytes);
  if (decoded == null) return null;

  var image = decoded;
  final longest = image.width >= image.height ? image.width : image.height;
  if (longest > req.maxEdge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: req.maxEdge)
        : img.copyResize(image, height: req.maxEdge);
  }

  return image.hasAlpha
      ? img.encodePng(image)
      : img.encodeJpg(image, quality: 82);
}