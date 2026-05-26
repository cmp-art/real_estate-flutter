// features/properties/presentation/screens/property_create_screen.dart
// Simplified property creation/editing form.
// Photos only (no video). Gemini AI moderates photos before the listing is
// saved (server-side, with a rule-based fallback when it is unreachable).
// Works on Android, iOS, Web, and PWA.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/middleware/feature_gate_middleware.dart';
import '../../../../core/services/ai_validation_service.dart';
import '../../../../core/services/error_logging_service.dart';
import '../../../../core/utils/currency_helper.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/responsive_helper.dart';
// Drag-and-drop file support on desktop web; a no-op stub on native (dart:io).
import '../../../../core/utils/web_drop_zone.dart'
    if (dart.library.io) '../../../../core/utils/web_drop_zone_stub.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/app_providers.dart'
    hide accessControlProvider;
import '../../../subscriptions/presentation/screens/subscription_screen.dart';
import '../../domain/entities/property_entity.dart';
import '../providers/ai_providers.dart';
import '../providers/property_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bilingual strings
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final bool sw;
  const _S(this.sw);
  String pick(String en, String sw_) => sw ? sw_ : en;

  String get addProperty     => pick('Add Property', 'Ongeza Mali');
  String get editProperty    => pick('Edit Property', 'Hariri Mali');
  String get photos          => pick('Photos', 'Picha');
  String get addPhotos       => pick('Add Photos', 'Ongeza Picha');
  String get addMore         => pick('Add more', 'Ongeza zaidi');
  String get photosTip       => pick(
    'Add at least 1 photo. Up to ${AppConstants.maxImagesPerProperty} photos allowed.',
    'Ongeza picha angalau 1. Picha hadi ${AppConstants.maxImagesPerProperty} zinaruhusiwa.',
  );
  String get webDragDrop     => pick(
    'You can also drag & drop photos on desktop.',
    'Unaweza pia kuburuta picha kwenye kompyuta.',
  );

  String get saleLabel       => pick('For Sale', 'Inauzwa');
  String get rentLabel       => pick('For Rent', 'Inapangishwa');
  String get monthly         => pick('Monthly', 'Kwa Mwezi');
  String get yearly          => pick('Yearly', 'Kwa Mwaka');

  String get titleLabel      => pick('Title', 'Jina la Mali');
  String get titleHint       => pick('e.g. 3-Bed House – Masaki, Dar', 'mf. Nyumba Vyumba 3 – Masaki, Dar');
  String get titleRequired   => pick('Title is required', 'Jina linahitajika');
  String get titleTooShort   => pick('Title too short (min 5 characters)', 'Jina ni fupi (angalau herufi 5)');

  String get categoryLabel   => pick('Category', 'Aina ya Mali');
  String get priceLabel      => pick('Price', 'Bei');
  String get priceHint       => pick('e.g. 500000', 'mf. 500000');
  String get priceRequired   => pick('Price is required', 'Bei inahitajika');
  String get priceInvalid    => pick('Enter a valid number', 'Ingiza nambari sahihi');
  String get rentDurationLabel => pick('Rent period', 'Kipindi cha pango');

  String get locationLabel   => pick('Location', 'Eneo');
  String get locationHint    => pick('Neighbourhood, district, city', 'Mtaa, wilaya, mji');
  String get locationRequired => pick('Location is required', 'Eneo linahitajika');

  String get bedroomsLabel   => pick('Bedrooms', 'Vyumba vya Kulala');
  String get bathroomsLabel  => pick('Bathrooms', 'Vyumba vya Kuoga');
  String get roomsRequired   => pick('Required', 'Inahitajika');
  String get roomsInvalid    => pick('Whole number', 'Nambari nzima');
  String get noRoomsInfo     => pick(
    'Bedroom and bathroom counts are not needed for land or commercial properties.',
    'Idadi ya vyumba haihitajiki kwa ardhi au mali ya biashara.',
  );

  String get areaLabel       => pick('Area (m²)', 'Ukubwa (m²)');
  String get areaHint        => pick('e.g. 120', 'mf. 120');
  String get areaRequired    => pick('Area is required', 'Ukubwa unahitajika');
  String get areaInvalid     => pick('Enter a valid area in m²', 'Ingiza ukubwa sahihi kwa m²');
  String get areaTip         => pick('1 acre ≈ 4,047 m²', 'Ekari 1 ≈ 4,047 m²');

  String get descLabel       => pick('Description', 'Maelezo');
  String get descHint        => pick(
    'Describe condition, floor, parking, security, water/power, nearby amenities…',
    'Eleza hali, ghorofa, maegesho, usalama, maji/umeme, huduma za karibu…',
  );
  String get descRequired    => pick('Description is required', 'Maelezo yanahitajika');
  String get descTooShort    => pick('Too short — use at least 10 words', 'Fupi mno — tumia angalau maneno 10');

  String get photoRequired   => pick('At least one photo is required', 'Picha angalau moja inahitajika');
  String get fixErrors       => pick('Please fix the highlighted errors', 'Tafadhali rekebisha makosa yaliyoonyeshwa');
  String get saving          => pick('Saving…', 'Inahifadhi…');
  String get submit          => pick('Post Property', 'Tuma Mali');
  String get update          => pick('Update Property', 'Sasisha Mali');
  String get createdOk       => pick('Listing posted successfully!', 'Tangazo limetumwa!');
  String get updatedOk       => pick('Listing updated successfully!', 'Tangazo limesasishwa!');
  String get photoFail       => pick('Photos could not be uploaded — please try again', 'Picha hazikupakiwa — jaribu tena');
  String get upgradeRequired => pick('Upgrade Required', 'Unahitajika Kupandisha Kiwango');
  String get cancel          => pick('Cancel', 'Ghairi');
  String get upgradePro      => pick('Upgrade to Pro', 'Panda kwa Pro');
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class PropertyCreateScreen extends ConsumerStatefulWidget {
  final PropertyEntity? property;
  const PropertyCreateScreen({super.key, this.property});

  @override
  ConsumerState<PropertyCreateScreen> createState() =>
      _PropertyCreateScreenState();
}

class _PropertyCreateScreenState extends ConsumerState<PropertyCreateScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _titleCtrl      = TextEditingController();
  final _priceCtrl      = TextEditingController();
  final _locationCtrl   = TextEditingController();
  final _bedroomsCtrl   = TextEditingController();
  final _bathroomsCtrl  = TextEditingController();
  final _areaCtrl       = TextEditingController();
  final _descCtrl       = TextEditingController();

  PropertyType     _type     = PropertyType.sale;
  PropertyCategory _category = PropertyCategory.house;
  RentDuration     _rentDur  = RentDuration.monthly;

  List<XFile>           _images        = [];
  final Map<String, Uint8List> _webBytes = {};  // web CanvasKit cache

  double? _lat;
  double? _lng;

  bool _isLoading = false;

  final ImageHelper _imageHelper = ImageHelper();

  // ── Helpers ────────────────────────────────────────────────────────────────
  _S get _s {
    try {
      return _S(ref.read(languageProvider).languageCode == 'sw');
    } catch (_) {
      return const _S(false);
    }
  }

  bool get _needsRooms =>
      _category != PropertyCategory.land &&
      _category != PropertyCategory.commercial;

  bool get _isEditing => widget.property != null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (_isEditing) _prefill(widget.property!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkQuota());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _areaCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _prefill(PropertyEntity p) {
    _titleCtrl.text     = p.title;
    _priceCtrl.text     = p.price.toStringAsFixed(0);
    _locationCtrl.text  = p.location;
    _bedroomsCtrl.text  = p.bedrooms.toString();
    _bathroomsCtrl.text = p.bathrooms.toString();
    _areaCtrl.text      = p.area.toStringAsFixed(0);
    _descCtrl.text      = p.description;
    _type               = p.type;
    _category           = p.category;
    _lat                = p.latitude;
    _lng                = p.longitude;
    if (p.type == PropertyType.rent) {
      _rentDur = p.rentDuration ?? RentDuration.monthly;
    }
  }

  // ── Subscription quota check ───────────────────────────────────────────────
  Future<void> _checkQuota() async {
    if (_isEditing || !mounted) return;
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    final ok = await ref.read(featureGateMiddlewareProvider).checkFeatureAccess(
      context: context,
      userId: user.id,
      featureName: 'create_listing',
      showUpgradePrompt: true,
    );
    if (!ok && mounted) Navigator.of(context).pop();
  }

  // ── Check creation limits (subscription tier) ─────────────────────────────
  Future<bool> _checkCreationLimits() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return false;
    try {
      final result = await Supabase.instance.client.rpc(
        'check_property_creation_allowed',
        params: {'p_user_id': user.id, 'p_has_video': false},
      );
      final map = result as Map<String, dynamic>;
      if (map['allowed'] == true) return true;
      if (!mounted) return false;
      final reason          = map['reason'] as String? ?? 'Subscription limit reached';
      final upgradeRequired = map['upgrade_required'] as bool? ?? false;
      if (upgradeRequired) {
        _showUpgradeDialog(reason);
      } else {
        _snack(reason, isError: true);
      }
      return false;
    } catch (e) {
      ErrorLoggingService.instance?.logError(
        errorType: 'QuotaCheckFailed',
        errorMessage: 'check_property_creation_allowed RPC failed: $e',
        screenName: 'PropertyCreateScreen',
        severity: 'warning',
      );
      return true; // fail open — backend enforces anyway
    }
  }

  void _showUpgradeDialog(String reason) {
    final s = _s;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Text(s.upgradeRequired),
        ]),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(s.upgradePro),
          ),
        ],
      ),
    );
  }

  // ── Web image bytes cache (CanvasKit compatibility) ────────────────────────
  Future<void> _cacheWebBytes(List<XFile> files) async {
    if (!kIsWeb) return;
    for (final f in files) {
      if (_webBytes.containsKey(f.path)) continue;
      try {
        // 10-second timeout prevents an old service worker from blocking
        // blob: URL reads indefinitely.
        final b = await f.readAsBytes()
            .timeout(const Duration(seconds: 10));
        // Ignore anything that looks like HTML (service worker fallback page)
        if (b.length > 100 && !_looksLikeHtml(b)) {
          _webBytes[f.path] = b;
        }
      } catch (e) {
        ErrorLoggingService.instance?.logError(
          errorType: 'WebByteCacheFailed',
          errorMessage: 'Failed to cache web image bytes for "${f.name}": $e',
          screenName: 'PropertyCreateScreen',
          severity: 'warning',
        );
      }
    }
  }

  /// Returns true if the bytes start with an HTML doctype / tag —
  /// which means the service worker returned the offline fallback page
  /// instead of the actual image.
  static bool _looksLikeHtml(Uint8List b) {
    if (b.length < 5) return false;
    final head = String.fromCharCodes(b.take(15)).toLowerCase();
    return head.contains('<!doc') || head.contains('<html');
  }

  // Returns the correct image widget for web (Image.memory) and native (Image.file).
  // On web:
  //   1. Use Image.memory if bytes were cached at pick time.
  //   2. Otherwise fall back to Image.network(blob URL) — the browser renders
  //      blob: URLs natively; the service worker now skips them (v4).
  Widget _thumb(XFile file, {double size = 90}) {
    if (!kIsWeb) {
      return Image.file(File(file.path),
          width: size, height: size, fit: BoxFit.cover);
    }
    final cached = _webBytes[file.path];
    if (cached != null) {
      return Image.memory(cached, width: size, height: size, fit: BoxFit.cover);
    }
    // Fallback: let Flutter load the blob URL directly. No FutureBuilder
    // needed — Image.network handles the loading / error states itself.
    return Image.network(
      file.path,
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, event) {
        if (event == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: event.expectedTotalBytes != null
                  ? event.cumulativeBytesLoaded / event.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.broken_image_rounded,
            size: size * 0.5, color: Colors.grey.shade400),
      ),
    );
  }

  // ── Resolve XFiles for upload (web: use cached bytes to bypass blob: SW issue) ─
  // On web, image_picker returns XFile objects whose path is a blob: URL.
  // The PWA service worker intercepts blob: fetches from its own context where
  // the blob is inaccessible, so readAsBytes() would receive index.html bytes.
  // We pre-cache bytes at pick time (_cacheWebBytes) and create byte-backed
  // XFile objects here so the datasource's readAsBytes() never touches the
  // blob URL at all.
  Future<List<XFile>> _resolveUploadFiles() async {
    if (!kIsWeb) return _images;
    final result = <XFile>[];
    for (final f in _images) {
      var bytes = _webBytes[f.path];
      if (bytes == null || bytes.isEmpty) {
        try {
          bytes = await f.readAsBytes().timeout(const Duration(seconds: 10));
          if (bytes.isNotEmpty && !_looksLikeHtml(bytes)) {
            _webBytes[f.path] = bytes;
          }
        } catch (_) {}
      }
      if (bytes != null && bytes.isNotEmpty) {
        // image_picker_for_web v3 already applies imageQuality:85 + maxWidth/
        // maxHeight via browser Canvas API — no extra compression needed here.
        result.add(XFile.fromData(bytes,
            name: f.name.isNotEmpty ? f.name : 'photo.jpg',
            mimeType: 'image/jpeg'));
      }
    }
    return result.isEmpty ? _images : result;
  }

  // ── Photo picker ───────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    final remaining = AppConstants.maxImagesPerProperty - _images.length;
    if (remaining <= 0) {
      _snack('Maximum ${AppConstants.maxImagesPerProperty} photos allowed',
          isError: true);
      return;
    }
    final source = await _choosePhotoSource();
    if (source == null || !mounted) return;
    await _addPhotos(source, remaining);
  }

  // Bottom sheet: pick Gallery (one or more photos) or Camera (single shot).
  Future<ImageSource?> _choosePhotoSource() {
    final s = _s;
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.pick('Choose from Gallery', 'Chagua kwenye Galari')),
              subtitle: Text(
                  s.pick('Select one or more photos', 'Chagua picha moja au zaidi')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(s.pick('Take a Photo', 'Piga Picha')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(s.cancel),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhotos(ImageSource source, int remaining) async {
    int unreadableCount = 0;

    final picked = await _imageHelper.pickMultipleImages(
      maxImages: remaining,
      source: source,
      // Fires when the service worker poisoned a blob URL with HTML bytes.
      // We surface this immediately so the user knows to re-pick that photo.
      onUnreadable: (count) => unreadableCount += count,
    );

    if (!mounted) return;

    // cropToCard is best-effort: on web it canvas-crops JPEG/PNG/WebP; for
    // HEIC/AVIF it returns null and we fall back to the raw bytes, which
    // ImageUploadService coerces to a servable JPEG at upload time. We only
    // drop an image if it had NO readable bytes at all (already filtered by
    // pickMultipleImages via onUnreadable above).
    final ready = <XFile>[];
    for (final image in picked) {
      if (!mounted) break;
      try {
        final result = await _imageHelper.cropToCard(context, image);
        // result == null means canvas couldn't decode it (e.g. HEIC on Chrome).
        // Keep the original — backend handles the format. Never silently drop.
        ready.add(result ?? image);
      } catch (_) {
        ready.add(image);
      }
    }

    if (ready.isNotEmpty && mounted) {
      await _cacheWebBytes(ready);
      setState(() => _images = [..._images, ...ready]);
    }

    // Warn about any photos the browser could not read at all
    if (unreadableCount > 0 && mounted) {
      _snack(
        _s.pick(
          '$unreadableCount photo${unreadableCount > 1 ? 's' : ''} could not be loaded '
              '— try picking ${unreadableCount > 1 ? 'them' : 'it'} again.',
          'Picha $unreadableCount hazikuweza kupakiwa — jaribu tena.',
        ),
        isError: true,
      );
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  // Shown when Gemini (or the rule-based fallback) rejects the photos.
  Future<void> _showModerationRejected(ValidationResult v) async {
    final s = _s;
    final reason = v.reason.isNotEmpty
        ? v.reason
        : s.pick(
            'These photos do not appear to show a real estate property.',
            'Picha hizi hazionekani kuwa za mali isiyohamishika.',
          );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.report_gmailerrorred, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.pick('Photos not accepted', 'Picha hazikukubaliwa')),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            if (v.suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...v.suggestions.map(
                (sug) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(sug)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.pick('OK', 'Sawa')),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final s = _s;
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) {
      _snack(s.fixErrors, isError: true);
      return;
    }
    if (_images.isEmpty && !_isEditing) {
      _snack(s.photoRequired, isError: true);
      return;
    }

    if (!_isEditing) {
      final allowed = await _checkCreationLimits();
      if (!allowed) return;
    }

    setState(() => _isLoading = true);

    // On web, image_picker returns blob:-URL XFiles whose readAsBytes() can be
    // intercepted by the PWA service worker and yield HTML instead of the photo.
    // Resolve them to byte-backed XFiles ONCE (a no-op on native) and reuse the
    // same list for BOTH moderation and upload, so Gemini sees the real image
    // bytes on web/PWA exactly like it does on native.
    final resolvedImages = await _resolveUploadFiles();

    // ── AI image moderation — verify photos genuinely show real estate ──────
    // Gemini runs server-side as a plain HTTPS call (works on Android, iOS, Web
    // & PWA). If it is undeployed / unreachable the submission is allowed
    // through — photos are never judged by their text.
    if (resolvedImages.isNotEmpty) {
      final moderation =
          await ref.read(aiValidationServiceProvider).validateProperty(
        images:      resolvedImages,
        submittedBy: user.id,
      );
      if (!mounted) return;
      if (!moderation.isApproved) {
        setState(() => _isLoading = false);
        await _showModerationRejected(moderation);
        return;
      }
    }

    final bedrooms  = _needsRooms ? (int.tryParse(_bedroomsCtrl.text)  ?? 0) : 0;
    final bathrooms = _needsRooms ? (int.tryParse(_bathroomsCtrl.text) ?? 0) : 0;

    final property = PropertyEntity(
      id:           widget.property?.id ?? '',
      title:        _titleCtrl.text.trim(),
      description:  _descCtrl.text.trim(),
      price:        double.parse(_priceCtrl.text),
      type:         _type,
      category:     _category,
      location:     _locationCtrl.text.trim(),
      latitude:     _lat ?? widget.property?.latitude,
      longitude:    _lng ?? widget.property?.longitude,
      bedrooms:     bedrooms,
      bathrooms:    bathrooms,
      area:         double.parse(_areaCtrl.text),
      images:       widget.property?.images ?? [],
      ownerId:      user.id,
      ownerName:    '',
      status:       PropertyStatus.available,
      rentDuration: _type == PropertyType.rent ? _rentDur : null,
      createdAt:    widget.property?.createdAt ?? DateTime.now(),
      updatedAt:    DateTime.now(),
    );

    final repo   = ref.read(propertyRepositoryProvider);
    final result = _isEditing
        ? await repo.updateProperty(property)
        : await repo.createProperty(property);

    if (!mounted) return;

    await result.fold(
      (failure) async {
        ErrorLoggingService.instance?.logError(
          errorType: _isEditing ? 'PropertyUpdateFailed' : 'PropertyCreateFailed',
          errorMessage: failure.message,
          screenName: 'PropertyCreateScreen',
          severity: 'error',
        );
        setState(() => _isLoading = false);
        _snack(failure.message, isError: true);
      },
      (saved) async {
        // Upload new photos and capture the final entity with image URLs
        PropertyEntity finalSaved = saved;

        bool uploadFailed = false;
        if (_images.isNotEmpty) {
          // Reuse the byte-backed XFiles already resolved above (web blob/SW bypass).
          final toUpload = resolvedImages;
          final uploadResult = await repo.uploadImages(saved.id, toUpload);
          await uploadResult.fold(
            (_) async { uploadFailed = true; },
            (urls) async {
              // Warn if any images were silently dropped by the upload layer
              // (e.g. empty bytes at upload time after picking).
              final dropped = toUpload.length - urls.length;
              if (dropped > 0 && mounted) {
                _snack(
                  _s.pick(
                    '$dropped photo${dropped > 1 ? 's' : ''} failed to upload and '
                        '${dropped > 1 ? 'were' : 'was'} skipped.',
                    'Picha $dropped hazikupakiwa — ziliachwa.',
                  ),
                  isError: false,
                );
              }
              final withImages = saved.copyWith(
                  images: [...saved.images, ...urls]);

              // Persist image URLs to DB — retry up to 3× for transient failures.
              // On permanent failure the in-memory entity still has the URLs so
              // the current screen stays correct; the provider invalidation below
              // will refetch from DB where images may be missing until the next
              // successful save.
              bool imagesSaved = false;
              for (int imgAttempt = 1; imgAttempt <= 3 && !imagesSaved; imgAttempt++) {
                if (imgAttempt > 1) {
                  await Future.delayed(Duration(seconds: imgAttempt - 1));
                }
                final updateResult = await repo.updateProperty(withImages);
                updateResult.fold(
                  (_) {
                    if (imgAttempt >= 3) {
                      finalSaved = withImages;
                      ErrorLoggingService.instance?.logError(
                        errorType: 'PropertyImageUrlUpdateFailed',
                        errorMessage:
                            'Failed to save image URLs to DB for property '
                            '${saved.id} after 3 attempts',
                        screenName: 'PropertyCreateScreen',
                        severity: 'error',
                      );
                    }
                  },
                  (u) {
                    finalSaved = u;
                    imagesSaved = true;
                  },
                );
              }
            },
          );
        }

        if (!mounted) return;

        if (uploadFailed) {
          // Roll back: soft-delete the just-created property so it doesn't
          // appear in listings without images. For edits the property already
          // exists, so leave it as-is (text changes were already saved).
          if (!_isEditing) {
            ErrorLoggingService.instance?.logError(
              errorType: 'PropertyPhotoUploadFailed',
              errorMessage:
                  'All photos failed to upload for property ${saved.id}; '
                  'listing rolled back',
              screenName: 'PropertyCreateScreen',
              severity: 'error',
            );
            try { await repo.deleteProperty(saved.id); } catch (_) {}
          }
          setState(() => _isLoading = false);
          _snack(s.photoFail, isError: true);
          return;
        }

        setState(() => _isLoading = false);

        // Update in-memory providers with the entity that has image URLs
        if (_isEditing) {
          ref.read(propertyListProvider.notifier).updatePropertyInList(finalSaved);
        } else {
          ref.read(propertyListProvider.notifier).addProperty(finalSaved);
          try {
            await ref
                .read(subscriptionServiceProvider)
                .incrementUsage(userId: user.id, featureName: 'create_listing');
          } catch (e) {
            logger.w('Usage increment failed (non-critical)', error: e);
          }
        }
        ref.invalidate(myPropertiesProvider);
        ref.invalidate(propertyListProvider);

        // Photos are uploaded directly to a public bucket, so they are live
        // immediately — no "processing" wait to message about.
        _snack(_isEditing ? s.updatedOk : s.createdOk, isError: false);
        Navigator.pop(context, true);
      },
    );
  }

  // ── Snackbar helper ────────────────────────────────────────────────────────
  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? ThemeConfig.errorColor : ThemeConfig.secondaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang   = ref.watch(languageProvider).languageCode;
    final s      = _S(lang == 'sw');
    final currency = ref.watch(currencyProvider);
    final symbol = CurrencyHelper.getSymbol(currency);
    final pad    = ResponsiveHelper.getResponsivePadding(context);
    final radius = ResponsiveHelper.getResponsiveBorderRadius(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.editProperty : s.addProperty),
        centerTitle: false,
      ),
      // On desktop web the whole form is a drop target: photos dropped from the
      // file explorer are added just like gallery picks. No-op on native.
      body: WebDropZone(
        maxFiles: AppConstants.maxImagesPerProperty,
        onFilesDropped: (dropped) async {
          final remaining = AppConstants.maxImagesPerProperty - _images.length;
          if (remaining <= 0) {
            _snack('Maximum ${AppConstants.maxImagesPerProperty} photos allowed',
                isError: true);
            return;
          }
          final toAdd = dropped.take(remaining).toList();
          await _cacheWebBytes(toAdd);
          if (mounted) setState(() => _images.addAll(toAdd));
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 32),
            children: [
              // ── Photos ────────────────────────────────────────────────
              _SectionLabel(s.photos),
              const SizedBox(height: 6),
              Text(
                s.photosTip,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: ThemeConfig.getTextSecondaryColor(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              _buildPhotoSection(radius, s),
              // Mobile web warning banner — shown only on phone/tablet browsers
              if (kIsWeb && MediaQuery.sizeOf(context).width < 600) ...[
                const SizedBox(height: 10),
                _MobileWebBanner(),
              ],
              const SizedBox(height: 24),

              // ── Property Type ─────────────────────────────────────────
              const _SectionLabel('Property Type'),
              const SizedBox(height: 8),
              _buildTypeChips(s),
              if (_type == PropertyType.rent) ...[
                const SizedBox(height: 10),
                _buildRentDurationChips(s),
              ],
              const SizedBox(height: 20),

              // ── Category ──────────────────────────────────────────────
              _SectionLabel(s.categoryLabel),
              const SizedBox(height: 8),
              _buildCategoryDropdown(context, radius),
              const SizedBox(height: 20),

              // ── Title ─────────────────────────────────────────────────
              _buildField(
                controller: _titleCtrl,
                label: s.titleLabel,
                hint: s.titleHint,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return s.titleRequired;
                  if (v.trim().length < 5) return s.titleTooShort;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Price ─────────────────────────────────────────────────
              _buildField(
                controller: _priceCtrl,
                label: s.priceLabel,
                hint: s.priceHint,
                prefixText: '$symbol ',
                suffixText: _type == PropertyType.rent
                    ? (_rentDur == RentDuration.monthly ? '/mo' : '/yr')
                    : null,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return s.priceRequired;
                  if (double.tryParse(v) == null) return s.priceInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Location ──────────────────────────────────────────────
              _SectionLabel(s.locationLabel),
              const SizedBox(height: 8),
              LocationAutocompleteField(
                controller: _locationCtrl,
                hintText: s.locationHint,
                onSelected: (_, displayName) =>
                    _locationCtrl.text = displayName,
                onCoordinatesSelected: (lat, lng) {
                  _lat = lat;
                  _lng = lng;
                },
                onCoordinatesCleared: () {
                  _lat = null;
                  _lng = null;
                },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s.locationRequired
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Bedrooms & Bathrooms (conditional) ────────────────────
              if (_needsRooms) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _bedroomsCtrl,
                        label: s.bedroomsLabel,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return s.roomsRequired;
                          if (int.tryParse(v) == null) return s.roomsInvalid;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(
                        controller: _bathroomsCtrl,
                        label: s.bathroomsLabel,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return s.roomsRequired;
                          if (int.tryParse(v) == null) return s.roomsInvalid;
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeConfig.infoColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(radius / 2),
                    border: Border.all(
                        color: ThemeConfig.infoColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: ThemeConfig.infoColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.noRoomsInfo,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context, mobile: 12),
                            color: ThemeConfig.getTextSecondaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Area ──────────────────────────────────────────────────
              _buildField(
                controller: _areaCtrl,
                label: s.areaLabel,
                hint: s.areaHint,
                suffixText: 'm²',
                helperText: s.areaTip,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return s.areaRequired;
                  if (double.tryParse(v) == null) return s.areaInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Description ───────────────────────────────────────────
              _buildField(
                controller: _descCtrl,
                label: s.descLabel,
                hint: s.descHint,
                maxLines: 5,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return s.descRequired;
                  if (v.trim().split(RegExp(r'\s+')).length < 10) {
                    return s.descTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // ── Submit button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.getPrimaryColor(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius)),
                    disabledBackgroundColor:
                        ThemeConfig.getPrimaryColor(context).withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text(s.saving,
                                style: const TextStyle(fontSize: 16)),
                          ],
                        )
                      : Text(
                          _isEditing ? s.update : s.submit,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photos section ─────────────────────────────────────────────────────────
  Widget _buildPhotoSection(double radius, _S s) {
    if (_images.isEmpty) {
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(radius),
            color: ThemeConfig.getCardColor(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_rounded,
                  size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(s.addPhotos,
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Existing image thumbnails
              ..._images.asMap().entries.map((e) {
                final idx  = e.key;
                final file = e.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _thumb(file),
                      ),
                      // Remove button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _webBytes.remove(_images[idx].path);
                            _images.removeAt(idx);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Add more button
              if (_images.length < AppConstants.maxImagesPerProperty)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 28, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text(s.addMore,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_images.length} / ${AppConstants.maxImagesPerProperty}',
          style: TextStyle(
            fontSize: 11,
            color: ThemeConfig.getTextSecondaryColor(context),
          ),
        ),
      ],
    );
  }

  // ── Property type chips ────────────────────────────────────────────────────
  Widget _buildTypeChips(_S s) {
    return Row(
      children: [
        _TypeChip(
          label: s.saleLabel,
          selected: _type == PropertyType.sale,
          onTap: () => setState(() => _type = PropertyType.sale),
          context: context,
        ),
        const SizedBox(width: 10),
        _TypeChip(
          label: s.rentLabel,
          selected: _type == PropertyType.rent,
          onTap: () => setState(() {
            _type = PropertyType.rent;
            _rentDur = RentDuration.monthly;
          }),
          context: context,
        ),
      ],
    );
  }

  // ── Rent duration chips ────────────────────────────────────────────────────
  Widget _buildRentDurationChips(_S s) {
    return Row(
      children: [
        _TypeChip(
          label: s.monthly,
          selected: _rentDur == RentDuration.monthly,
          onTap: () => setState(() => _rentDur = RentDuration.monthly),
          context: context,
          small: true,
        ),
        const SizedBox(width: 10),
        _TypeChip(
          label: s.yearly,
          selected: _rentDur == RentDuration.yearly,
          onTap: () => setState(() => _rentDur = RentDuration.yearly),
          context: context,
          small: true,
        ),
      ],
    );
  }

  // ── Category dropdown ──────────────────────────────────────────────────────
  Widget _buildCategoryDropdown(BuildContext context, double radius) {
    return DropdownButtonFormField<PropertyCategory>(
      initialValue: _category,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius / 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: PropertyCategory.values.map((c) {
        return DropdownMenuItem(
          value: c,
          child: Text(c.displayName),
        );
      }).toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _category = v;
          if (!_needsRooms) {
            _bedroomsCtrl.clear();
            _bathroomsCtrl.clear();
          }
        });
      },
    );
  }

  // ── Reusable text field ────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefixText,
    String? suffixText,
    String? helperText,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    FormFieldValidator<String>? validator,
  }) {
    final radius = ResponsiveHelper.getResponsiveBorderRadius(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        helperText: helperText,
        helperMaxLines: 2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius / 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: ThemeConfig.getTextPrimaryColor(context),
          ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BuildContext context;
  final bool small;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.context,
    this.small = false,
  });

  @override
  Widget build(BuildContext ctx) {
    final primary = ThemeConfig.getPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 14 : 20,
          vertical: small ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? primary : Colors.grey.shade400,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : ThemeConfig.getTextSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}

// ── Mobile web warning banner ─────────────────────────────────────────────────
class _MobileWebBanner extends StatelessWidget {
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.patamjengo.app';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.blue, size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tip: use the Android app for the fastest experience',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Photo upload works on mobile browsers. For the smoothest experience, download the Android app.',
            style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 8),
          _BannerButton(
            icon: Icons.android_rounded,
            label: 'Download on Play Store',
            color: Colors.green,
            onTap: () async {
              final uri = Uri.parse(_playStoreUrl);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
          ),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BannerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
