import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';
import '../config/theme_config.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';

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
    void Function(int skippedCount, double maxMB)? onOversized,
  }) async {
    if (_isPickerActive) return [];     // already open — silently ignore
    _isPickerActive = true;
    try {
      List<XFile> images;

      if (kIsWeb) {
        // Web: single-file pick to avoid parallel canvas decodes crashing mobile
        // browsers.  maxWidth/maxHeight capped at 1280 to reduce canvas RAM.
        final XFile? single = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
        );
        images = single != null ? [single] : [];
      } else {
        images = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
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

  // ── Crop an XFile to 4:3 for property card display ────────────────────────
  // Forces the user to frame their photo in a 4:3 landscape ratio so it fills
  // property cards perfectly without unexpected cropping at display time.
  // Works on Android, iOS, and Web. Returns null if the user cancels.
  Future<XFile?> cropToCard(BuildContext context, XFile image) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Frame your photo (4:3)',
            toolbarColor: ThemeConfig.primaryColor,
            toolbarWidgetColor: Colors.white,
            statusBarColor: ThemeConfig.primaryColor,
            activeControlsWidgetColor: ThemeConfig.primaryColor,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.ratio4x3,
            aspectRatioPresets: [CropAspectRatioPreset.ratio4x3],
            showCropGrid: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Frame your photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [CropAspectRatioPreset.ratio4x3],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 420),
          ),
        ],
      );
      if (croppedFile == null) return null;
      return XFile(croppedFile.path);
    } catch (e) {
      throw ValidationException(e.toString());
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