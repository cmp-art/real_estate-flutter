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
import '../services/image_transcode_service.dart';
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
  // [onOversized] is called when one or more images are skipped because they
  // exceed [AppConstants.maxImageSize].  The callback receives the number of
  // skipped files and the limit in MB so the caller can show a snackbar.
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
    void Function(int skippedCount, double maxMB)? onOversized,
  }) async {
    if (_isPickerActive) return [];     // already open — silently ignore
    _isPickerActive = true;
    try {
      List<XFile> images;

      if (source == ImageSource.camera) {
        // Single shot from the device camera (web & native). No quality params
        // on web — image_picker_for_web would run an internal canvas encode that
        // fails silently on mobile browsers. webCropToCard resizes afterwards.
        final XFile? shot = kIsWeb
            ? await _picker.pickImage(source: ImageSource.camera)
            : await _picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 1920,
                maxHeight: 1920,
                imageQuality: 85,
              );
        images = shot != null ? [shot] : [];
      } else if (kIsWeb) {
        // Gallery on web: true multi-select. No maxWidth/maxHeight/imageQuality —
        // those make image_picker_for_web decode every selected photo on the
        // canvas in parallel (48–434 MB each), which crashes mobile tabs. Without
        // them it returns lightweight blob: URLs that we decode one at a time
        // below, and webCropToCard handles resizing (→ 1 280 px, JPEG 88 %).
        images = await _picker.pickMultiImage();
      } else {
        // Gallery on native: multi-select with fast native down-scaling.
        images = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      }

      // Web: convert blob: URL XFiles to byte-backed XFiles, one at a time so
      // peak memory stays bounded. Reading the bytes now — in the same JS
      // context that created the blob — also bypasses the service worker, which
      // can otherwise intercept blob: fetches and return the offline page.
      if (kIsWeb && images.isNotEmpty) {
        final converted = <XFile>[];
        for (final f in images) {
          try {
            final bytes = await f.readAsBytes();
            converted.add(bytes.isNotEmpty
                ? XFile.fromData(
                    bytes,
                    name: f.name.isNotEmpty ? f.name : 'photo.jpg',
                    mimeType: 'image/jpeg',
                  )
                : f); // bytes empty (rare) — keep blob URL as fallback
          } catch (_) {
            converted.add(f); // keep original on unexpected error
          }
        }
        images = converted;
      }

      if (images.isEmpty) return [];

      // Limit number of images to remaining slots
      final limitedImages = images.take(maxImages).toList();

      final List<XFile> validImages = [];
      int skipped = 0;
      for (final image in limitedImages) {
        final size = await image.length();
        if (size <= AppConstants.maxImageSize) {
          validImages.add(image);
        } else {
          skipped++;
        }
      }

      // Notify caller about skipped images so it can show a snackbar
      if (skipped > 0 && onOversized != null) {
        onOversized(skipped, AppConstants.maxImageSize / (1024 * 1024));
      }

      return validImages;
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
  // Guarantees the result is something every browser can render: iPhone HEIC is
  // transcoded to JPEG, the format is validated, and on [card]=true the image
  // is center-cropped to 4:3 for property cards. Works on Android, iOS, Web and
  // PWA. Used by property photos ([card]=true) and by avatars / logos / ad
  // images ([card]=false, no crop so their own aspect ratio is preserved).
  //
  // RETURN CONTRACT:
  //   • non-null XFile → ready to upload (JPEG, or an already-renderable
  //     original) with a correct name/mimeType.
  //   • null → the image could not be turned into anything renderable (HEIC the
  //     server couldn't transcode, a service-worker HTML page, or garbage). The
  //     caller MUST skip it rather than upload it, so we never store a file that
  //     shows up broken.
  //
  // Web path uses Canvas API (hardware-accelerated, async, ~0 Dart heap cost).
  // Native path uses the Dart image package (runs in a background isolate).
  Future<XFile?> normalizeForUpload(
    BuildContext context,
    XFile image, {
    bool card = true,
  }) async {
    final tag = DateTime.now().millisecondsSinceEpoch;

    if (kIsWeb) {
      // ── Web / PWA ──────────────────────────────────────────────────────────
      // The Dart `image` package decodes / re-encodes synchronously on the
      // main thread.  A 12 MP photo allocates ~100 MB of Dart heap and blocks
      // the UI for 3–5 s on mobile, which triggers "Page Unresponsive" and
      // can kill the browser tab.  Canvas API avoids both problems.
      try {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) return null;

        final fmt = detectImageFormat(bytes);

        // Service-worker offline page or undecodable junk — never store it.
        if (fmt == DetectedImageFormat.html ||
            fmt == DetectedImageFormat.unknown) {
          return null;
        }

        // HEIC: no browser except Safari can decode it, so the canvas cannot
        // crop or re-encode it. Transcode to JPEG on the server (which also
        // downscales). If the server can't be reached, skip the photo (return
        // null) instead of uploading bytes that render broken.
        if (fmt == DetectedImageFormat.heic) {
          final jpeg = await ImageTranscodeService.transcodeToJpeg(bytes);
          if (jpeg == null || jpeg.isEmpty) return null;
          if (!card) {
            return XFile.fromData(jpeg,
                name: 'photo_$tag.jpg', mimeType: 'image/jpeg');
          }
          final cropped = await webCropToCard(jpeg);
          final outBytes =
              (cropped != null && cropped.isNotEmpty) ? cropped : jpeg;
          return XFile.fromData(outBytes,
              name: 'crop_$tag.jpg', mimeType: 'image/jpeg');
        }

        // Renderable formats (JPEG/PNG/WebP/GIF): crop to 4:3 when [card],
        // otherwise leave the image as-is to preserve its aspect ratio.
        if (card) {
          final outBytes = await webCropToCard(bytes);
          if (outBytes != null && outBytes.isNotEmpty) {
            return XFile.fromData(outBytes,
                name: 'crop_$tag.jpg', mimeType: 'image/jpeg');
          }
        }
        // No crop requested (or the canvas crop failed) but the bytes are a
        // valid renderable image — upload them unchanged with the correct
        // type/extension rather than dropping a good photo.
        return XFile.fromData(bytes,
            name: 'photo_$tag.${fmt.fileExtension}', mimeType: fmt.mimeType);
      } catch (_) {
        return null; // unprocessable — skip
      }
    }

    // ── Android / iOS ──────────────────────────────────────────────────────
    // image_picker already down-scaled the image and transcoded HEIC→JPEG at
    // pick time, so for the no-crop case the original file is upload-ready.
    if (!card) return image;

    // Decode/crop/encode runs on a background isolate via compute() so a batch
    // of large photos can't block the UI thread and trigger an ANR ("app not
    // responding") on low-end devices. Crop is best-effort — fall back to the
    // original picked image on any error.
    try {
      final bytes = await image.readAsBytes();
      final outBytes = await compute(_cropToCardJpg, bytes);
      if (outBytes == null || outBytes.isEmpty) return image;

      final tmpDir = await getTemporaryDirectory();
      final outPath = '${tmpDir.path}/crop_$tag.jpg';
      await File(outPath).writeAsBytes(outBytes);
      return XFile(outPath);
    } catch (_) {
      return image;
    }
  }

  // 4:3 center-crop for property cards — thin wrapper over [normalizeForUpload].
  Future<XFile?> cropToCard(BuildContext context, XFile image) =>
      normalizeForUpload(context, image, card: true);

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
      final XFile? shot = kIsWeb
          ? await _picker.pickImage(source: source)
          : await _picker.pickImage(
              source: source,
              maxWidth: 1920,
              maxHeight: 1920,
              imageQuality: 85,
            );
      if (shot == null) return null;

      if (kIsWeb) {
        final bytes = await shot.readAsBytes();
        if (bytes.isNotEmpty) {
          return XFile.fromData(
            bytes,
            name: shot.name.isNotEmpty ? shot.name : 'photo.jpg',
            mimeType: 'image/jpeg',
          );
        }
      }
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