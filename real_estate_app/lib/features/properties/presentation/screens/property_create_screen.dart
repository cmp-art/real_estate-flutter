import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_compress/video_compress.dart';
import '../../../../core/utils/video_web_utils.dart'
    if (dart.library.io) '../../../../core/utils/video_web_utils_stub.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:patamjengo_app/presentation/providers/auth_provider.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/utils/currency_helper.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';

import '../../../settings/presentation/screens/app_translations.dart';
import '../providers/ai_providers.dart';
import '../providers/property_providers.dart';
import '../../domain/entities/property_entity.dart';
import '../../../settings/presentation/providers/app_providers.dart' hide accessControlProvider;

import '../../../../core/middleware/feature_gate_middleware.dart';
import '../../../subscriptions/presentation/screens/subscription_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bilingual strings helper
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final bool sw;
  const _S(this.sw);
  String pick(String en, String sw_) => sw ? sw_ : en;

  String get ok       => pick('OK', 'Sawa');
  String get tryAgain => pick('Edit & Retry', 'Hariri na Jaribu Tena');
  String get saving   => pick('Saving...', 'Inahifadhi...');
  String get checking => pick('Checking content...', 'Inakagua maudhui...');
  String get fixErrors => pick(
    'Please fix the highlighted errors before submitting.',
    'Tafadhali rekebisha makosa yaliyoonyeshwa kabla ya kutuma.',
  );

  // Instructions
  String get instructTitle => pick('📋 How to Create a Great Listing', '📋 Jinsi ya Kutengeneza Tangazo Nzuri');
  List<String> get instructions => sw ? [
    '📸 Piga picha angalau 3 zenye mwanga mzuri na wazi',
    '🏠 Jina liwe wazi: aina ya mali + vyumba + eneo (mf. Nyumba Vyumba 3 – Masaki)',
    '📝 Eleza hali ya nyumba, vifaa maalum, usalama na jirani',
    '💰 Weka bei ya soko — bei ya juu sana inapunguza maswali',
    '📍 Taja mtaa, wilaya na mji kwa usahihi (mf. Mikocheni B, Kinondoni)',
    '🏡 Nyumba na ardhi TU — bidhaa zingine zitakataliwa kiotomatiki',
  ] : [
    '📸 Add at least 3 clear, well-lit photos',
    '🏠 Write a specific title: type + rooms + area (e.g. 3BR House – Masaki)',
    '📝 Describe condition, special features, security and neighbourhood',
    '💰 Set a realistic market price — overpricing drastically reduces inquiries',
    '📍 Be precise with location — include neighbourhood, district & city',
    '🏡 Real estate ONLY — other products are automatically rejected',
  ];

  // Field tips
  String get titleTip => pick(
    'Be specific: type + bedrooms + location. Example: "2-Bed Apartment – Kariakoo, Dar"',
    'Kuwa wazi: aina + vyumba + eneo. Mfano: "Nyumba Vyumba 2 – Kariakoo, Dar"',
  );
  String get descTip => pick(
    'Include: floor level, parking, security, water/power reliability, nearby schools, road distance',
    'Eleza: ghorofa, maegesho, usalama, maji/umeme, shule za karibu, umbali wa barabara',
  );
  String get priceTip => pick(
    'Check similar listings nearby — fair pricing gets 3× more inquiries',
    'Angalia bei za nyumba zinazofanana — bei ya haki inapata maswali mara 3 zaidi',
  );
  String get locationTip => pick(
    'More detail = more visibility. Example: "Sinza Mori, Kinondoni, Dar es Salaam"',
    'Maelezo zaidi = uonekano zaidi. Mfano: "Sinza Mori, Kinondoni, Dar es Salaam"',
  );
  String get roomsTip => pick(
    'Enter the exact number. Use 0 for studio or open-plan spaces',
    'Ingiza idadi halisi. Tumia 0 kwa studio au nafasi wazi',
  );
  String get areaTip => pick(
    'Total floor or plot area in square metres (m²). 1 acre ≈ 4,047 m²',
    'Ukubwa wa sakafu au kiwanja kwa mita za mraba (m²). Ekari 1 ≈ 4,047 m²',
  );
  String get statusTip => pick(
    'Set to "Available" so buyers can find your listing immediately',
    'Weka "Inapatikana" ili wanunuzi wapate tangazo lako mara moja',
  );
  String get noRoomsTip => pick(
    'Bedroom and bathroom counts are not needed for land or commercial properties',
    'Idadi ya vyumba haihitajiki kwa ardhi au mali ya biashara',
  );
  String get imagesTip => pick(
    'Listings with 5+ photos get 70% more views. Add photos and/or a video. Min 1 required.',
    'Matangazo yenye picha 5+ yanapata maoni 70% zaidi. Ongeza picha na/au video. Angalau 1 inahitajika.',
  );
  String get addMediaBtn   => pick('Add Photo / Video', 'Ongeza Picha / Video');
  String get addMoreMedia  => pick('Add more', 'Ongeza zaidi');
  String get mediaSectionTitle => pick('Photos & Video', 'Picha & Video');
  String get mediaTip      => pick(
    'At least 1 photo required. Video optional — photos must come first.',
    'Picha angalau 1 inahitajika. Video ni ya hiari — picha lazima ziwe za kwanza.',
  );
  String get videoLabel    => pick('VIDEO', 'VIDEO');
  String get mediaRequired => pick(
    'At least one photo is required — you cannot post a video-only listing',
    'Picha angalau moja inahitajika — huwezi kutuma tangazo lenye video peke yake',
  );
  String get videoTooBig   => pick('Video must be under 50 MB', 'Video lazima iwe chini ya MB 50');
  String get videoFail     => pick(
    'Property saved! Video could not be uploaded — you can add it later.',
    'Mali imehifadhiwa! Video haikupakiwa — unaweza kuiongeza baadaye.',
  );
  String get photoOption   => pick('Photo', 'Picha');
  String get videoOption   => pick('Video', 'Video');

  // Field errors
  String get titleRequired   => pick('Title is required', 'Jina la nyumba linahitajika');
  String get titleTooShort   => pick('Title too short — add more detail (min 5 characters)', 'Jina ni fupi — ongeza maelezo (angalau herufi 5)');
  String get descRequired    => pick('Description is required', 'Maelezo yanahitajika');
  String get descTooShort    => pick('Too short — use at least 10 words to describe the property', 'Mfupi mno — tumia angalau maneno 10 kuelezea mali');
  String get priceRequired   => pick('Price is required', 'Bei inahitajika');
  String get priceInvalid    => pick('Enter a valid number (digits only, e.g. 500000)', 'Ingiza nambari sahihi (nambari tu, mf. 500000)');
  String get locationReq     => pick('Location is required — include neighbourhood, district and city', 'Eneo linahitajika — weka mtaa, wilaya na mji');
  String get bedroomsReq     => pick('Number of bedrooms is required', 'Idadi ya vyumba vya kulala inahitajika');
  String get bedroomsInvalid => pick('Enter a whole number (e.g. 2)', 'Ingiza nambari nzima (mf. 2)');
  String get bathroomsReq    => pick('Number of bathrooms is required', 'Idadi ya vyumba vya kuogea inahitajika');
  String get bathroomsInvalid=> pick('Enter a whole number (e.g. 1)', 'Ingiza nambari nzima (mf. 1)');
  String get areaRequired    => pick('Area size is required', 'Ukubwa wa eneo unahitajika');
  String get areaInvalid     => pick('Enter a valid area in m² (e.g. 120)', 'Ingiza ukubwa sahihi kwa m² (mf. 120)');
  // imageRequired kept as alias for backward compat
  String get imageRequired => mediaRequired;

  // AI messages
  String get aiRejectedTitle  => pick('⛔ Listing Not Allowed', '⛔ Tangazo Halijakubaliwa');
  String get aiRejectedIntro  => pick('Your listing was rejected because:', 'Tangazo lako lilikataliwa kwa sababu:');
  String get aiSuggestions    => pick('💡 How to fix it:', '💡 Jinsi ya kurekebisha:');
  String get aiRejectedFooter => pick(
    'This platform is for real estate ONLY — houses, apartments, land and offices. Other goods or services are always rejected.',
    'Jukwaa hili ni kwa mali isiyohamishika TU — nyumba, vyumba, ardhi na ofisi. Bidhaa au huduma zingine zitakataliwa daima.',
  );
  String get aiPendingTitle   => pick('🕐 Sent for Review', '🕐 Imetumwa kwa Ukaguzi');
  String get aiPendingMsg     => pick(
    'Your listing could not be auto-approved and has been sent to our moderation team. You will be notified within 24 hours.',
    'Tangazo lako halikuweza kukubaliwa kiotomatiki na limetumwa kwa timu yetu ya ukaguzi. Utaarifiwa ndani ya masaa 24.',
  );

  // Success
  String get createdOk => pick('Listing submitted successfully! 🎉', 'Tangazo limetumwa! 🎉');
  String get updatedOk => pick('Listing updated successfully!', 'Tangazo limesasishwa!');
  String get imageFail => pick('Photos could not be uploaded — please try again', 'Picha hazikupakiwa — tafadhali jaribu tena');
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable UI helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Collapsible banner shown at top of the form with step-by-step instructions
class _InstructionsBanner extends StatefulWidget {
  final String title;
  final List<String> items;
  const _InstructionsBanner({required this.title, required this.items});

  @override
  State<_InstructionsBanner> createState() => _InstructionsBannerState();
}

class _InstructionsBannerState extends State<_InstructionsBanner> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final primary = ThemeConfig.getPrimaryColor(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                  Expanded(
                    child: Text(widget.title,
                        style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                            fontWeight: FontWeight.w700,
                            color: primary)),
                  ),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: primary, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: widget.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(item,
                            style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                                height: 1.45,
                                color: ThemeConfig.getTextPrimaryColor(context))),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small tip row shown below a field
class _FieldTip extends StatelessWidget {
  final String text;
  const _FieldTip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 12, color: ThemeConfig.getTextSecondaryColor(context)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                    height: 1.4,
                    color: ThemeConfig.getTextSecondaryColor(context))),
          ),
        ],
      ),
    );
  }
}

/// Highlighted info box (blue)
class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeConfig.infoColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
        border: Border.all(color: ThemeConfig.infoColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: ThemeConfig.infoColor, size: 16),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    height: 1.4,
                    color: ThemeConfig.getTextSecondaryColor(context))),
          ),
        ],
      ),
    );
  }
}

class PropertyCreateScreen extends ConsumerStatefulWidget {
  final PropertyEntity? property;

  const PropertyCreateScreen({super.key, this.property});

  @override
  ConsumerState<PropertyCreateScreen> createState() =>
      _PropertyCreateScreenState();
}

class _PropertyCreateScreenState extends ConsumerState<PropertyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaController = TextEditingController();

  PropertyType _selectedType = PropertyType.sale;
  PropertyCategory _selectedCategory = PropertyCategory.house;
  PropertyStatus _selectedStatus = PropertyStatus.available;
  RentDuration _selectedRentDuration = RentDuration.monthly;
  List<XFile> _selectedImages = [];
  final List<XFile> _selectedVideos  = [];
  final Map<String, dynamic> _videoThumbnails = {};
  bool _isLoading    = false;
  bool _isValidating = false;

  // bilingual helper — reads current language from provider
  _S get _s {
    try {
      final lang = ref.read(languageProvider).languageCode;
      return _S(lang == 'sw');
    } catch (_) { return const _S(false); }
  }

  final ImageHelper _imageHelper = ImageHelper();

  @override
  void initState() {
    super.initState();
    _checkCreateQuota();
    if (widget.property != null) {
      _loadPropertyData();
    }
  }

  Future<void> _checkCreateQuota() async {
    // Wait for frame to complete
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authNotifierProvider).value;
      if (user == null) return;

      // Only check on new property creation (not editing)
      if (widget.property != null) return;

      final middleware = ref.read(featureGateMiddlewareProvider);
      final canCreate = await middleware.checkFeatureAccess(
        context: context,
        userId: user.id,
        featureName: 'create_listing',
        showUpgradePrompt: true,
      );

      if (!canCreate && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Check subscription limits for property creation including video/image rules.
  /// Returns true if allowed, false if blocked (snackbar shown automatically).
  Future<bool> _checkPropertyCreationLimits({required bool hasVideo}) async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return false;

    try {
      final supabase = ref.read(supabaseProvider);
      final result = await supabase.rpc(
        'check_property_creation_allowed',
        params: {
          'p_user_id': user.id,
          'p_has_video': hasVideo,
        },
      );

      final map = result as Map<String, dynamic>;
      if (map['allowed'] == true) return true;

      // Show upgrade dialog
      if (mounted) {
        final reason = map['reason'] as String? ?? 'Subscription limit reached';
        final upgradeRequired = map['upgrade_required'] as bool? ?? false;

        if (upgradeRequired) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.orange),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                  const Text('Upgrade Required'),
                ],
              ),
              content: Text(reason),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Upgrade to Pro'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(reason), backgroundColor: Colors.red),
          );
        }
      }
      return false;
    } catch (e) {
      // Fail open — let the backend enforce if RPC unavailable
      return true;
    }
  }

  void _loadPropertyData() {
    final property = widget.property!;
    _titleController.text = property.title;
    _descriptionController.text = property.description;
    _priceController.text = property.price.toString();
    _locationController.text = property.location;
    _bedroomsController.text = property.bedrooms.toString();
    _bathroomsController.text = property.bathrooms.toString();
    _areaController.text = property.area.toString();
    _selectedType = property.type;
    _selectedCategory = property.category;
    _selectedStatus = property.status;

    if (property.type == PropertyType.rent) {
      _selectedRentDuration = property.rentDuration ?? RentDuration.monthly;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _showRejectionDialog({required String reason, required List<String> suggestions}) {
    final s = _s;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context))),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(children: [
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
            decoration: BoxDecoration(color: ThemeConfig.errorColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.block_rounded, color: ThemeConfig.errorColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
          ),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(child: Text(s.aiRejectedTitle,
              style: TextStyle(color: ThemeConfig.errorColor, fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w700))),
        ]),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Text(s.aiRejectedIntro,
                style: TextStyle(color: ThemeConfig.getTextSecondaryColor(ctx), fontSize: 13)),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              decoration: BoxDecoration(
                color: ThemeConfig.errorColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThemeConfig.errorColor.withOpacity(0.25)),
              ),
              child: Text(reason,
                  style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14), height: 1.5, color: ThemeConfig.getTextPrimaryColor(ctx))),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(s.aiSuggestions,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              ...suggestions.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(tip, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13), height: 1.4))),
                ]),
              )),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeConfig.infoColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: ResponsiveHelper.getResponsiveIconSize(context), color: ThemeConfig.infoColor),
                const SizedBox(width: 6),
                Expanded(child: Text(s.aiRejectedFooter,
                    style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), height: 1.4,
                        color: ThemeConfig.getTextSecondaryColor(ctx)))),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: ThemeConfig.errorColor),
            child: Text(s.tryAgain, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showPendingDialog() {
    final s = _s;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context))),
        title: Row(children: [
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
            decoration: BoxDecoration(color: ThemeConfig.warningColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.hourglass_top_rounded, color: ThemeConfig.warningColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
          ),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(child: Text(s.aiPendingTitle,
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w700))),
        ]),
        content: Text(s.aiPendingMsg, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14), height: 1.5)),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context, true); },
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.warningColor, foregroundColor: Colors.white),
            child: Text(s.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMediaSheet() async {
    final s = _s;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(s.photoOption),
            onTap: () async {
              Navigator.pop(ctx);
              await _pickImages();
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam_rounded),
            title: Text(s.videoOption),
            subtitle: const Text('Max 90 seconds',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () async {
              Navigator.pop(ctx);
              await _pickVideo();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _pickImages() async {
    final images = await _imageHelper.pickMultipleImages(
      maxImages: AppConstants.maxImagesPerProperty,
    );
    setState(() {
      _selectedImages = images;
    });
  }

  Future<void> _pickVideo() async {
    // Free-tier users cannot add video — check before opening picker
    final user = ref.read(authNotifierProvider).value;
    if (user != null) {
      final blocked = await _checkPropertyCreationLimits(hasVideo: true);
      if (!blocked) return;
    }

    final picker = ImagePicker();
    final XFile? picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 90),
    );
    if (picked == null) return;

    // ── Duration check (90-second max) ───────────────────────────────
    // Web: use networkUrl with blob URL. Native: use file().
    try {
      final probe = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(picked.path))
          : VideoPlayerController.file(File(picked.path));
      await probe.initialize();
      final dur = probe.value.duration;
      await probe.dispose();
      if (dur > const Duration(seconds: 90)) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Video Too Long'),
              content: Text(
                'Your video is ${dur.inSeconds} seconds long.\n\n'
                'Maximum allowed is 90 seconds. '
                'Please trim it and try again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    } catch (_) {
      // Can't read duration — continue
    }

    // ── Size check ────────────────────────────────────────────────────
    // Web: no compression available, so limit is 50 MB to avoid egress costs.
    // Native: allow up to 500 MB (compressed to ~10 MB afterwards).
    final fileSize = await picked.length();
    final maxBytes = kIsWeb ? 50 * 1024 * 1024 : 500 * 1024 * 1024;
    if (fileSize > maxBytes) {
      if (mounted) {
        if (kIsWeb) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Video Too Large'),
              content: const Text(
                'Web uploads are limited to 50 MB to keep the app fast for everyone.\n\n'
                'For best results:\n'
                '• Compress your video using a free tool before uploading, or\n'
                '• Download the Patamjengo app from the Play Store — it compresses videos automatically.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Video is too large (max 500 MB). Please choose a shorter clip.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
      return;
    }

    // ── Compression (native only) ─────────────────────────────────────
    XFile finalVideo = picked;
    if (!kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              const Text('Compressing video to 720p...'),
            ],
          ),
          duration: const Duration(seconds: 30),
          backgroundColor: Colors.black87,
        ));
      }
      try {
        final MediaInfo? info = await VideoCompress.compressVideo(
          picked.path,
          quality: VideoQuality.Res1280x720Quality,
          deleteOrigin: false,
          includeAudio: true,
        );
        if (info?.file != null) {
          finalVideo = XFile(info!.file!.path);
          debugPrint('Video compressed: ${fileSize}B → ${await finalVideo.length()}B');
        }
      } catch (e) {
        debugPrint('Video compression failed, using original: $e');
      }
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    // ── Thumbnail ────────────────────────────────────────────────────
    // Web: capture frame via canvas (dart:html). Native: video_thumbnail package.
    final Uint8List? thumb = kIsWeb
        ? await captureVideoThumbnailWeb(picked.path)
        : await _generateVideoThumbnail(finalVideo.path);

    if (mounted) {
      setState(() {
        _selectedVideos.add(finalVideo);
        _videoThumbnails[finalVideo.path] = thumb;
      });
    }
  }

  Future<Uint8List?> _generateVideoThumbnail(String videoPath) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
      );
    } catch (_) {
      return null;
    }
  }

  // Helper to check if current category requires beds/baths
  bool get _requiresBedroomsBathrooms {
    return _selectedCategory != PropertyCategory.land &&
        _selectedCategory != PropertyCategory.commercial;
  }

  Future<void> _handleSubmit() async {
    final user = ref.read(authNotifierProvider).value;

    // Only enforce limits on new property creation, not editing
    if (user != null && widget.property == null) {
      final hasVideo = _selectedVideos.isNotEmpty;
      final allowed = await _checkPropertyCreationLimits(hasVideo: hasVideo);
      if (!allowed) return;
    }

    final currentLanguage = ref.read(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);
    final s = _s;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.fixErrors),
        backgroundColor: ThemeConfig.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    if (_selectedImages.isEmpty && widget.property == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.mediaRequired),
        backgroundColor: ThemeConfig.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _isLoading = true);

    // ── GUARD: user must be logged in ─────────────────────────────────────
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    // ── AI VALIDATION — runs BEFORE saving to the database ────────────────
    // This blocks non-real-estate content from ever being created.
    setState(() { _isLoading = false; _isValidating = true; });

    final bedrooms =
        _requiresBedroomsBathrooms && _bedroomsController.text.isNotEmpty
            ? int.parse(_bedroomsController.text)
            : 0;
    final bathrooms =
        _requiresBedroomsBathrooms && _bathroomsController.text.isNotEmpty
            ? int.parse(_bathroomsController.text)
            : 0;

    final aiService = ref.read(aiValidationServiceProvider);
    final validation = await aiService.validateProperty(
      title:       _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location:    _locationController.text.trim(),
      price:       double.tryParse(_priceController.text) ?? 0,
      category:    _selectedCategory.name,
      type:        _selectedType.name,
      bedrooms:    bedrooms,
      bathrooms:   bathrooms,
      area:        double.tryParse(_areaController.text) ?? 0,
      images:      _selectedImages.isNotEmpty ? _selectedImages : null,
      videos:      _selectedVideos.isNotEmpty ? _selectedVideos : null,
      submittedBy: user.id,
    );

    if (!mounted) return;
    setState(() => _isValidating = false);

    // ── Rejected: block save, show reason ────────────────────────────────
    if (validation.isRejected) {
      _showRejectionDialog(
        reason: validation.reason,
        suggestions: validation.suggestions,
      );
      return;
    }

    // ── Pending manual review: block save, inform user ───────────────────
    if (validation.isPending) {
      _showPendingDialog();
      return;
    }

    // ── Approved: proceed with saving ────────────────────────────────────
    setState(() => _isLoading = true);

    final repository = ref.read(propertyRepositoryProvider);

    final property = PropertyEntity(
      id: widget.property?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.parse(_priceController.text),
      type: _selectedType,
      category: _selectedCategory,
      location: _locationController.text.trim(),
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      area: double.parse(_areaController.text),
      images: widget.property?.images ?? [],
      ownerId: user.id,
      status: _selectedStatus,
      rentDuration:
          _selectedType == PropertyType.rent ? _selectedRentDuration : null,
      createdAt: widget.property?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      ownerName: '',
    );

    final result = widget.property == null
        ? await repository.createProperty(property)
        : await repository.updateProperty(property);

    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      },
      (createdProperty) async {
        if (_selectedImages.isNotEmpty) {
          final uploadResult = await repository.uploadImages(
            createdProperty.id,
            _selectedImages,
          );

          await uploadResult.fold(
            (failure) async {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${t('property_created')} ${t('image_upload_failed')}: ${failure.message}'),
                    backgroundColor: ThemeConfig.warningColor,
                  ),
                );
              }
            },
            (imageUrls) async {
              final updatedProperty = createdProperty.copyWith(
                images: [...createdProperty.images, ...imageUrls],
              );
              await repository.updateProperty(updatedProperty);
            },
          );
        }

        // ── Upload video (non-fatal) ─────────────────────────────────
        // PropertyEntity doesn't have a videos field — we write the URL
        // directly to the properties.videos column via Supabase.
        if (_selectedVideos.isNotEmpty) {
          try {
            final video  = _selectedVideos.first;
            final ts     = DateTime.now().millisecondsSinceEpoch;
            final name   = video.name.isNotEmpty ? video.name : video.path.split('/').last;
            final ext    = name.split('.').last.toLowerCase();
            final path   = '${user.id}/${createdProperty.id}_$ts.$ext';
            if (kIsWeb) {
              final videoBytes = await video.readAsBytes();
              await Supabase.instance.client.storage
                  .from('property_videos')
                  .uploadBinary(path, videoBytes,
                      fileOptions: const FileOptions(cacheControl: '31536000', upsert: false));
            } else {
              await Supabase.instance.client.storage
                  .from('property_videos')
                  .upload(path, File(video.path),
                      fileOptions: const FileOptions(
                        cacheControl: '31536000',
                        upsert: false,
                      ));
            }
            final videoUrl = Supabase.instance.client.storage
                .from('property_videos')
                .getPublicUrl(path);
            // Append URL directly to the videos column
            await Supabase.instance.client
                .from('properties')
                .update({'videos': [videoUrl]})
                .eq('id', createdProperty.id);
          } catch (_) {
            // Non-fatal — property is saved, video just didn't upload
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_s.videoFail),
                backgroundColor: ThemeConfig.warningColor,
              ));
            }
          }
        }

        if (mounted) {
          setState(() => _isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.property == null
                  ? t('property_created_successfully')
                  : t('property_updated_successfully')),
              backgroundColor: ThemeConfig.secondaryColor,
            ),
          );

          if (widget.property == null) {
            ref
                .read(propertyListProvider.notifier)
                .addProperty(createdProperty);
          } else {
            ref
                .read(propertyListProvider.notifier)
                .updatePropertyInList(createdProperty);
          }

          final subscriptionService = ref.read(subscriptionServiceProvider);
          await subscriptionService.incrementUsage(
            userId: user.id,
            featureName: 'create_listing',
          );
        
          ref.invalidate(myPropertiesProvider);
          Navigator.pop(context, true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _S(ref.watch(languageProvider).languageCode == 'sw');
    final currentLanguage = ref.watch(languageProvider).languageCode;
    final currentCurrency = ref.watch(currencyProvider);
    final currencySymbol = CurrencyHelper.getSymbol(currentCurrency);
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.property == null ? t('add_property') : t('edit_property')),
        actions: [
          // ✅ ADD THIS:
          Consumer(
            builder: (context, ref, child) {
              final user = ref.watch(authNotifierProvider).value;
              if (user == null) return const SizedBox.shrink();

              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: QuotaIndicator(featureName: 'create_listing'),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          children: [
            // ── Instructions banner ──────────────────────────────────
            _InstructionsBanner(
              title: s.instructTitle,
              items: s.instructions,
            ),
            const SizedBox(height: 20),

            // ── Photos & Video Section ────────────────────────────────
            Text(
              s.mediaSectionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _FieldTip(s.mediaTip),
            const SizedBox(height: 10),

            // Empty state — two tap targets side by side (shown until at least one image is added)
            if (_selectedImages.isEmpty)
              Row(
                children: [
                  // Photos tap
                  Expanded(
                    child: InkWell(
                      onTap: _pickImages,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.grey),
                            const SizedBox(height: 6),
                            const Text('Add Photos', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Video tap
                  Expanded(
                    child: InkWell(
                      onTap: _pickVideo,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_rounded, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.grey),
                            const SizedBox(height: 6),
                            const Text('Add Video', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )

            // Media grid — photos and video together
            else
              Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Photos
                        ..._selectedImages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file  = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                                  child: kIsWeb
                                    ? Image.network(
                                        file.path,
                                        height: 200, width: 200,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(file.path),
                                        height: 200, width: 200,
                                        fit: BoxFit.cover,
                                      ),
                                ),
                                // Remove button
                                Positioned(
                                  top: 6, right: 6,
                                  child: IconButton(
                                    onPressed: () => setState(() => _selectedImages.removeAt(index)),
                                    icon: Icon(Icons.close, size: ResponsiveHelper.getResponsiveIconSize(context)),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(28, 28),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Video tile
                        ..._selectedVideos.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file  = entry.value;
                          final name  = file.path.split('/').last;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                Container(
                                  width: 200, height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.play_circle_fill_rounded,
                                          color: Colors.white, size: 52),
                                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          name,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // VIDEO badge
                                Positioned(
                                  top: 8, left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(s.videoLabel,
                                        style: TextStyle(
                                            color: Colors.white, fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                // Remove button
                                Positioned(
                                  top: 6, right: 6,
                                  child: IconButton(
                                    onPressed: () => setState(() => _selectedVideos.removeAt(index)),
                                    icon: Icon(Icons.close, size: ResponsiveHelper.getResponsiveIconSize(context)),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(28, 28),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                  // Action row — add more photos / add video
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: Icon(Icons.add_photo_alternate, size: ResponsiveHelper.getResponsiveIconSize(context)),
                        label: const Text('Photos'),
                      ),
                      if (_selectedVideos.isEmpty) ...[
                        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                        TextButton.icon(
                          onPressed: _pickVideo,
                          icon: Icon(Icons.videocam_rounded, size: ResponsiveHelper.getResponsiveIconSize(context)),
                          label: const Text('Video'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: t('property_title'),
                hintText: t('property_title_hint'),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return s.titleRequired;
                if (v.trim().length < 5) return s.titleTooShort;
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            _FieldTip(s.titleTip),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Description Field
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: t('description'),
                hintText: t('describe_property'),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return s.descRequired;
                if (v.trim().split(RegExp(r'\s+')).length < 10) return s.descTooShort;
                return null;
              },
              maxLines: 4,
            ),
            _FieldTip(s.descTip),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Category Dropdown - Place before price to control validation
            DropdownButtonFormField<PropertyCategory>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(labelText: t('category')),
              items: PropertyCategory.values
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                    // Clear bedroom/bathroom fields if switching to land/commercial
                    if (!_requiresBedroomsBathrooms) {
                      _bedroomsController.clear();
                      _bathroomsController.clear();
                    }
                  });
                }
              },
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Price Field with Rent Duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: t('price'),
                    hintText: '0',
                    prefixText: '$currencySymbol ',
                    suffixText: _selectedType == PropertyType.rent
                        ? t('per_month')
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return s.priceRequired;
                    if (double.tryParse(v) == null) return s.priceInvalid;
                    return null;
                  },
                ),
                _FieldTip(s.priceTip),
                if (_selectedType == PropertyType.rent) ...[
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  Text(
                    t('rent_duration'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(t('monthly')),
                          selected:
                              _selectedRentDuration == RentDuration.monthly,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedRentDuration = RentDuration.monthly;
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(t('yearly')),
                          selected:
                              _selectedRentDuration == RentDuration.yearly,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedRentDuration = RentDuration.yearly;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Type Dropdown
            DropdownButtonFormField<PropertyType>(
              initialValue: _selectedType,
              decoration: InputDecoration(labelText: t('type')),
              items: PropertyType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                    if (value == PropertyType.rent) {
                      _selectedRentDuration = RentDuration.monthly;
                    }
                  });
                }
              },
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Location Field
            LocationAutocompleteField(
              controller: _locationController,
              labelText: t('location'),
              hintText: t('enter_location'),
              clearOnSelect: false,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.locationReq : null,
              onSelected: (_, displayName) {
                _locationController.text = displayName;
              },
            ),
            _FieldTip(s.locationTip),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Bedrooms and Bathrooms Row - Only show for non-land/commercial
            if (_requiresBedroomsBathrooms) ...[
              _FieldTip(s.roomsTip),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bedroomsController,
                      decoration: InputDecoration(
                        labelText: t('bedrooms'),
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return s.bedroomsReq;
                        if (int.tryParse(v) == null) return s.bedroomsInvalid;
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
                  Expanded(
                    child: TextFormField(
                      controller: _bathroomsController,
                      decoration: InputDecoration(
                        labelText: t('bathrooms'),
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return s.bathroomsReq;
                        if (int.tryParse(v) == null) return s.bathroomsInvalid;
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            ] else ...[
              _InfoBox(s.noRoomsTip),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            ],

            // Area Field
            TextFormField(
              controller: _areaController,
              decoration: InputDecoration(
                labelText: t('area_sqft'),
                hintText: '0',
                suffixText: 'm²',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return s.areaRequired;
                if (double.tryParse(v) == null) return s.areaInvalid;
                return null;
              },
            ),
            _FieldTip(s.areaTip),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Status Dropdown
            DropdownButtonFormField<PropertyStatus>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(labelText: t('status')),
              items: PropertyStatus.values
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
            ),
            _FieldTip(s.statusTip),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || _isValidating)
                    ? null
                    : () { _handleSubmit(); },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                  ),
                ),
                child: (_isLoading || _isValidating)
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                          Text(
                            _isValidating ? s.checking : s.saving,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        widget.property == null
                            ? t('create_property')
                            : t('update_property'),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          ],
        ),
      ),
    );
  }
}