// lib/features/advertising/presentation/screens/create_creative_screen.dart
// Image-only ads (video ads removed to reduce storage/egress costs)
// ignore_for_file: unused_import, unused_field

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/services/direct_ad_models.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/utils/image_helper.dart';

import '../../../properties/domain/entities/property_entity.dart';
import '../../../properties/presentation/providers/ai_providers.dart';
import '../../../properties/presentation/providers/property_providers.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bilingual strings (EN / Kiswahili)
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final bool sw;
  const _S(this.sw);
  String pick(String en, String sw_) => sw ? sw_ : en;

  String get ok       => pick('OK', 'Sawa');
  String get tryAgain => pick('Edit & Retry', 'Hariri na Jaribu Tena');
  String get checking => pick('🤖 AI is checking your ad...', '🤖 AI inakagua tangazo lako...');
  String get submitting => pick('Submitting ad for review...', 'Inatuma tangazo kwa ukaguzi...');

  // Instructions
  String get instructTitle => pick('📋 How to Create a Great Ad', '📋 Jinsi ya Kutengeneza Tangazo Nzuri');
  List<String> get instructions => sw ? [
    '✅ KURUHUSIWA: Mali isiyohamishika, chakula, maduka, teknolojia, magari, afya, elimu, fedha na biashara zote halali',
    '🖼️ Pakia picha yenye ubora wa juu — inaonekana kwenye orodha ya mali mara moja baada ya kukubaliwa na AI',
    '✍️ Kichwa kiwe kifupi na cha kuvutia — maneno 5–10 yanayoelezea bidhaa au huduma yako',
    '📞 Chagua WhatsApp au simu — njia inayopatikana zaidi na wateja Tanzania',
    '⚡ AI itakagua tangazo lako papo hapo — likubaliwe litaonekana mara moja kwenye app',
  ] : [
    '✅ ALL BUSINESSES WELCOME: Real estate, food, retail, tech, automotive, health, education, finance and any legitimate business',
    '🖼️ Upload a high-quality image — once AI approves it goes live on the property list immediately',
    '✍️ Write a short compelling headline — 5–10 words about your product or service',
    '📞 Choose WhatsApp or phone — the most accessible contact method in Tanzania',
    '⚡ AI reviews your ad instantly — if approved it appears live in the app right away',
  ];

  List<String> get prohibitedItems => sw ? [
    '🔞 Maudhui ya ngono au huduma za ngono',
    '⚠️ Uuzaji wa hofu ("Nunua SASA au utapoteza kila kitu!")',
    '🗳️ Matangazo ya siasa au kampeni za uchaguzi',
    '🎰 Kamari, dau, kasino',
    '💊 Dawa haramu, silaha au bidhaa ghushi',
  ] : [
    '🔞 Adult content or sexual services',
    '⚠️ Fear-based marketing ("Buy NOW or lose everything!")',
    '🗳️ Political ads or election campaigns',
    '🎰 Gambling, betting, casinos',
    '💊 Illegal drugs, weapons, or counterfeit goods',
  ];
  String get prohibitedTitle => pick('🚫 What\'s NOT Allowed', '🚫 Kinachopigwa Marufuku');

  // Field tips
  String get imageTip => pick(
    'High quality image for the Brand.',
    'picha nzuri ya Brand .',
  );
  String get logoTip => pick(
    'Optional — your agency or company logo.',
    'Si lazima — nembo ya kampuni yako.',
  );
  String get headlineTip => pick(
    'Example:Sah Store',
    'mfano: Sah Store',
  );
  String get descriptionTip => pick(
    'Mention the top 1–2 selling points: location advantage, price, or unique feature.',
    'Taja faida kuu 1–2: eneo, bei au kipengele cha kipekee.',
  );
  String get destinationTip => pick(
    'Recommended: WhatsApp gets the fastest responses in Tanzania. Choose whichever channel you monitor most.',
    'Bora: WhatsApp inapata majibu ya haraka zaidi Tanzania. Chagua njia unayoangalia zaidi.',
  );
  String get phoneTip => pick(
    'Include country code, e.g. +255712345678 for Tanzania.',
    'Weka nambari ya nchi, mf. +255712345678 kwa Tanzania.',
  );
  String get whatsappTip => pick(
    'Include country code, e.g. +255712345678. The pre-filled message will be sent when a buyer taps your ad.',
    'Weka nambari ya nchi, mf. +255712345678. Ujumbe ulioandikwa mapema utatumwa mtumiaji anapogonga tangazo lako.',
  );
  String get formatTip => pick(
    '"Native Medium" works best for most placements.',
    '"Native Medium" inafanya kazi vizuri kwa maeneo mengi.',
  );

  // Error messages
  String get headlineRequired => pick('Headline is required', 'Kichwa cha tangazo kinahitajika');
  String get headlineTooShort => pick('Headline too short — be more specific (min 5 characters)', 'Kichwa ni kifupi mno — kuwa wazi zaidi (angalau herufi 5)');
  String get imageRequired    => pick('Please upload a main image before submitting', 'Tafadhali pakia picha kuu kabla ya kutuma');
  String get phoneRequired    => pick('Enter a phone number with country code (e.g. +255712345678)', 'Ingiza nambari ya simu yenye nambari ya nchi (mf. +255712345678)');
  String get whatsappRequired => pick('Enter a WhatsApp number with country code (e.g. +255712345678)', 'Ingiza nambari ya WhatsApp yenye nambari ya nchi (mf. +255712345678)');
  String get propertyRequired => pick('Select one of your property listings to link this ad to', 'Chagua moja ya matangazo yako ya mali kuunganisha tangazo hili');
  String get websiteRequired  => pick('Website URL is required', 'URL ya tovuti inahitajika');
  String get websiteInvalid   => pick('Enter a valid URL starting with https://', 'Ingiza URL halali inayoanza na https://');
  String get loginRequired    => pick('You must be logged in to submit an ad', 'Lazima uingie kwanza ili kutuma tangazo');

  // AI messages
  String get aiRejectedTitle  => pick('⛔ Ad Not Approved', '⛔ Tangazo Halijakubaliwa');
  String get aiRejectedIntro  => pick('Your ad was reviewed and rejected because:', 'Tangazo lako lilikaguliwa na kukataliwa kwa sababu:');
  String get aiSuggestions    => pick('💡 How to fix it:', '💡 Jinsi ya kurekebisha:');
  String get appealTitle   => pick('Think this is a mistake?', 'Unadhani kuna kosa?');
  String get appealBtn     => pick('Request Human Review', 'Omba Ukaguzi wa Binadamu');
  String get appealHint    => pick(
    'Explain why your ad should be approved...',
    'Eleza kwa nini tangazo lako linapaswa kukubaliwa...',
  );
  String get appealSent    => pick(
    '✅ Appeal submitted. Our team will review it within 24 hours.',
    '✅ Ombi limetumwa. Timu yetu itaangalia ndani ya masaa 24.',
  );
  String get appealFailed  => pick(
    'Could not submit appeal. Please try again.',
    'Ombi halikutumwa. Tafadhali jaribu tena.',
  );
  String get aiRejectedFooter => pick(
    'Most business ads are allowed. Only prohibited: adult/sexual content, fear-based marketing, political ads, gambling, and illegal products.',
    'Matangazo mengi ya biashara yanakubaliwa. Yaliyopigwa marufuku tu: maudhui ya ngono, uuzaji wa hofu, matangazo ya siasa, kamari na bidhaa haramu.',
  );
  String get aiPendingTitle   => pick('🕐 Ad Sent for Review', '🕐 Tangazo Limetumwa kwa Ukaguzi');
  String get aiPendingMsg     => pick(
    'Your ad could not be auto-approved and has been sent to our moderation team. You will be notified within 24 hours.',
    'Tangazo lako halikuweza kukubaliwa kiotomatiki na limetumwa kwa timu yetu ya ukaguzi. Utaarifiwa ndani ya masaa 24.',
  );
  String get submitSuccess    => pick('Ad submitted for review! ✓', 'Tangazo limetumwa kwa ukaguzi! ✓');
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers (also used by PropertyCreateScreen)
// ─────────────────────────────────────────────────────────────────────────────

// Compact info icon button that shows instructions in a dialog
class _InfoIconButton extends StatelessWidget {
  final String instructTitle;
  final List<String> instructions;
  final String prohibitedTitle;
  final List<String> prohibitedItems;

  const _InfoIconButton({
    required this.instructTitle,
    required this.instructions,
    required this.prohibitedTitle,
    required this.prohibitedItems,
  });

  void _showInstructionsDialog(BuildContext context) {
    final primary = ThemeConfig.getPrimaryColor(context);
    const red = Color(0xFFD32F2F);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                      Expanded(
                        child: Text(
                          instructTitle,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                
                // Instructions content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...instructions.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13), height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      )),
                      
                      const SizedBox(height: 20),
                      Divider(color: red.withOpacity(0.3)),
                      SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                      
                      // Prohibited section
                      Row(
                        children: [
                          Icon(Icons.block_rounded, color: red, size: ResponsiveHelper.getResponsiveIconSize(context)),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                          Expanded(
                            child: Text(
                              prohibitedTitle,
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
                                fontWeight: FontWeight.w700,
                                color: red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                      
                      ...prohibitedItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                                  height: 1.5,
                                  color: red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = ThemeConfig.getPrimaryColor(context);
    
    return Container(
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(Icons.info_outline_rounded, color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
        onPressed: () => _showInstructionsDialog(context),
        tooltip: instructTitle,
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}

class _InstructionsBanner extends StatefulWidget {
  final String title;
  final List<String> items;
  const _InstructionsBanner({required this.title, required this.items});

  @override
  State<_InstructionsBanner> createState() => _InstructionsBannerState();
}

class _InstructionsBannerState extends State<_InstructionsBanner> {
  bool _expanded = false; // Changed to false - collapsed by default
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
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              Expanded(child: Text(widget.title,
                  style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13), fontWeight: FontWeight.w700, color: primary))),
              Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: widget.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(item,
                    style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), height: 1.45,
                        color: ThemeConfig.getTextPrimaryColor(context)))),
              ]),
            )).toList()),
          ),
        ],
      ]),
    );
  }
}

// Red "What's NOT allowed" collapsible banner shown above the form
class _ProhibitedBanner extends StatefulWidget {
  final String title;
  final List<String> items;
  const _ProhibitedBanner({required this.title, required this.items});
  @override
  State<_ProhibitedBanner> createState() => _ProhibitedBannerState();
}

class _ProhibitedBannerState extends State<_ProhibitedBanner> {
  bool _expanded = false; // collapsed by default — not in the way
  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFD32F2F);
    const redLight = Color(0xFFFFEBEE);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? red.withOpacity(0.12) : redLight;
    final border = red.withOpacity(0.35);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
            child: Row(children: [
              Icon(Icons.block_rounded, color: red, size: ResponsiveHelper.getResponsiveIconSize(context)),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              Expanded(child: Text(widget.title,
                  style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13), fontWeight: FontWeight.w700, color: red))),
              Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: red, size: ResponsiveHelper.getResponsiveIconSize(context)),
            ]),
          ),
        ),
        if (_expanded) ...[
          Divider(height: 1, color: red.withOpacity(0.25), indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(children: widget.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(item,
                    style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), height: 1.45, color: red))),
              ]),
            )).toList()),
          ),
        ],
      ]),
    );
  }
}

class _FieldTip extends StatelessWidget {
  final String text;
  const _FieldTip(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5, left: 2, bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline_rounded, size: 12,
          color: ThemeConfig.getTextSecondaryColor(context)),
      const SizedBox(width: 5),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), height: 1.4,
              color: ThemeConfig.getTextSecondaryColor(context)))),
    ]),
  );
}

class CreateCreativeScreen extends ConsumerStatefulWidget {
  final String campaignId;
  final AdCampaign campaign;

  const CreateCreativeScreen({
    super.key,
    required this.campaignId,
    required this.campaign,
  });

  @override
  ConsumerState<CreateCreativeScreen> createState() =>
      _CreateCreativeScreenState();
}

class _CreateCreativeScreenState extends ConsumerState<CreateCreativeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _headlineController = TextEditingController();
  final _descriptionController = TextEditingController();
  // Destination-specific controllers
  final _phoneController      = TextEditingController();
  final _whatsappController   = TextEditingController();
  final _whatsappMsgController = TextEditingController();
  final _websiteUrlController  = TextEditingController();
  final ImageHelper _imageHelper = ImageHelper();
  // Web preview bytes for picked images (Image.memory works in CanvasKit).
  final Map<String, Uint8List> _previewBytes = {};

  // Form selections
  String _selectedFormat    = 'native_medium';
  String _selectedCTA       = 'Learn More';

  // Ad destination: 'phone' | 'whatsapp' | 'property' | 'profile' | 'website'
  String _destinationType = 'whatsapp';

  // For property destination — advertiser picks one of their listings
  PropertyEntity? _selectedProperty;

  // Picked images (XFile so the flow works on web + native)
  XFile? _imageFile;
  XFile? _logoFile;

  // Uploaded Supabase public URLs
  String? _imageUrl;
  String? _logoUrl;

  // UI state
  bool _isUploadingImage = false;
  bool _isUploadingLogo = false;
  bool _isValidating = false;
  bool _isSubmitting = false;

  // ── helpers ──────────────────────────────────────────────────────────────

  bool get _anyUploading =>
      _isUploadingImage || _isUploadingLogo || _isValidating;

  // bilingual helper — reads current app language; falls back to English
  _S get _s {
    try {
      return _S(ref.read(languageProvider).languageCode == 'sw');
    } catch (_) {
      return const _S(false);
    }
  }

  // Web-safe preview for a picked image: Image.memory on web (CanvasKit can't
  // read a File), Image.file on native.
  Widget _previewImage(XFile file, {BoxFit fit = BoxFit.cover}) {
    if (!kIsWeb) return Image.file(File(file.path), fit: fit);
    final bytes = _previewBytes[file.path];
    if (bytes != null) return Image.memory(bytes, fit: fit);
    return Image.network(file.path,
        fit: fit,
        errorBuilder: (_, __, ___) => const ColoredBox(
            color: Colors.black12,
            child: Icon(Icons.broken_image_rounded, color: Colors.grey)));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ThemeConfig.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ThemeConfig.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── pickers ──────────────────────────────────────────────────────────────

  // Pick → normalise (HEIC transcode + format validation) → upload, choosing
  // the stored object's Content-Type/extension from the real bytes. Works on
  // web, PWA and native.
  Future<void> _pickAndUpload({
    required String folder,
    required String label,
    required void Function(XFile? file, String? url) onPicked,
    required void Function(bool uploading) setUploading,
  }) async {
    try {
      final picked =
          await _imageHelper.pickSingleImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final normalized =
          await _imageHelper.normalizeForUpload(context, picked, card: false);
      if (normalized == null) {
        _showError(_s.sw
            ? 'Picha hii haikuweza kushughulikiwa. Tumia programu au JPEG.'
            : 'That image could not be processed. Try the app or a JPEG.');
        return;
      }

      // Web-only: read bytes now for Image.memory preview (CanvasKit can't use
      // File paths).  On native, Image.file works directly and readAsBytes() is
      // deferred into uploadSingleRawToStaging where it acts as the Scoped
      // Storage / service-worker bypass.
      if (kIsWeb) {
        final previewBytes = await normalized.readAsBytes();
        if (previewBytes.isEmpty) {
          _showError('That image could not be read. Please try another.');
          return;
        }
        _previewBytes[normalized.path] = previewBytes;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        _showError(_s.loginRequired);
        return;
      }

      setState(() {
        onPicked(normalized, null);
        setUploading(true);
      });

      // Universal Upload Architecture: raw bytes → staging_media → Edge Function
      // → public_media. No client-side transcoding — backend handles all formats.
      final url = await ImageUploadService.uploadSingleRawToStaging(
        file: normalized,
        userId: userId,
        folder: folder,
        label: label,
      );

      if (!mounted) return;
      if (url != null) {
        setState(() {
          onPicked(normalized, url);
          setUploading(false);
        });
        _showSuccess(label == 'logo'
            ? 'Logo uploaded successfully'
            : 'Image uploaded successfully');
      } else {
        setState(() {
          onPicked(null, null);
          setUploading(false);
        });
        _showError('${label == 'logo' ? 'Logo' : 'Image'} upload failed. '
            'Please try again.');
      }
    } catch (e) {
      if (mounted) setState(() => setUploading(false));
      _showError('Could not open gallery: $e');
    }
  }

  Future<void> _pickAndUploadImage() => _pickAndUpload(
        folder: 'ad_images',
        label: 'main',
        onPicked: (file, url) {
          _imageFile = file;
          _imageUrl = url;
        },
        setUploading: (v) => _isUploadingImage = v,
      );

  Future<void> _pickAndUploadLogo() => _pickAndUpload(
        folder: 'ad_logos',
        label: 'logo',
        onPicked: (file, url) {
          _logoFile = file;
          _logoUrl = url;
        },
        setUploading: (v) => _isUploadingLogo = v,
      );

  // ── submission ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate media
    if (_imageUrl == null) {
      _showError(_s.imageRequired);
      return;
    }
    // Video ads removed — image-only ads going forward

    // Build landing_url + linkedPropertyId from destination selection
    final String landingUrl;
    String? linkedPropertyId;

    switch (_destinationType) {
      // ── Phone call ────────────────────────────────────────────────
      case 'phone':
        // Strip everything except digits — no '+' sign in path to avoid
        // percent-encoding issues (Uri.parse encodes '+' as '%2B').
        // The ad card prepends '+' when building the tel: URI.
        final digitsOnly = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.isEmpty || digitsOnly.length < 9) {
          _showError(_s.phoneRequired);
          return;
        }
        // Store digits-only in the URL path — safe from encoding issues.
        landingUrl = 'https://call.nyumba.co.tz/$digitsOnly';
        break;

      // ── WhatsApp ──────────────────────────────────────────────────
      case 'whatsapp':
        final rawWa = _whatsappController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
        if (rawWa.isEmpty || rawWa.length < 9) {
          _showError(_s.whatsappRequired);
          return;
        }
        final msg = Uri.encodeComponent(
          _whatsappMsgController.text.trim().isEmpty
              ? 'Hi, I saw your ad on Nyumba and I am interested.'
              : _whatsappMsgController.text.trim(),
        );
        landingUrl = 'https://wa.me/$rawWa?text=$msg';
        break;

      // ── Specific property listing ─────────────────────────────────
      case 'property':
        if (_selectedProperty == null) {
          _showError(_s.propertyRequired);
          return;
        }
        linkedPropertyId = _selectedProperty!.id;
        landingUrl = 'https://property.nyumba.co.tz/${_selectedProperty!.id}';
        break;

      // ── In-app profile ────────────────────────────────────────────
      case 'profile':
        final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
        if (userId.isEmpty) {
          _showError(_s.loginRequired);
          return;
        }
        landingUrl = 'https://profile.nyumba.co.tz/$userId';
        break;

      // ── External website (optional) ───────────────────────────────
      default: // 'website'
        final url = _websiteUrlController.text.trim();
        if (url.isEmpty) {
          _showError(_s.websiteRequired);
          return;
        }
        final uri = Uri.tryParse(url);
        if (uri == null || !uri.isAbsolute || !url.startsWith('http')) {
          _showError(_s.websiteInvalid);
          return;
        }
        landingUrl = url;
    }

    // ── AI VALIDATION — before saving ────────────────────────────────────
    setState(() => _isValidating = true);

    final user = Supabase.instance.client.auth.currentUser;
    final aiService = ref.read(aiValidationServiceProvider);
    final validation = await aiService.validateAd(
      headline:          _headlineController.text.trim(),
      description:       _descriptionController.text.trim(),
      callToAction:      _selectedCTA,
      companyType:       'advertiser',  // generic — all business types are allowed
      campaignObjective: widget.campaign.campaignObjective,
      landingUrl:        landingUrl,
      image:             _imageFile,
      submittedBy:       user?.id,
    );

    if (!mounted) return;
    setState(() => _isValidating = false);

    // Rejected → save to inbox + show dialog
    if (validation.isRejected) {
      // Persist to notification inbox so user sees it later
      final userId = user?.id;
      if (userId != null) {
        final headline = _headlineController.text.trim();
        Supabase.instance.client.from('user_notifications').insert({
          'user_id': userId,
          'type':    'ad_rejected',
          'title':   _s.sw ? '❌ Tangazo Limekataliwa' : '❌ Ad Not Approved',
          'message': _s.sw
              ? 'Tangazo lako "$headline" limekataliwa: ${validation.reason}'
              : 'Your ad "$headline" was not approved: ${validation.reason}',
          'data': {
            'headline':  headline,
            'reason':    validation.reason,
            'screen':    'create_creative',
          },
          'is_read': false,
        }).catchError((_) {}); // non-blocking — dialog still shows even if insert fails
      }
      _showRejectionDialog(
        reason: validation.reason,
        suggestions: validation.suggestions,
      );
      return;
    }

    // Pending = AI uncertain → treat as rejected, ask user to fix and resubmit
    // We do NOT send to admin queue — AI makes the final call.
    if (validation.isPending) {
      _showRejectionDialog(
        reason: validation.reason.isNotEmpty
            ? validation.reason
            : 'Your ad could not be verified automatically. Please review your content and try again.',
        suggestions: [
          ...validation.suggestions,
          'Make sure your ad does not contain prohibited content (adult, political, fear-based, gambling)',
          'Use a clear, professional image that represents your product or service',
          'Make sure your headline clearly describes what you are offering',
        ],
      );
      return;
    }

    // ── Approved: save to database ────────────────────────────────────────
    setState(() => _isSubmitting = true);

    try {
      // AI approved → live immediately, no admin queue.
      // reviewed_by is NULL because AI (not a human) approved this.
      await Supabase.instance.client.from('ad_creatives').insert({
        'campaign_id':      widget.campaignId,
        'ad_format':        _selectedFormat,
        'headline':         _headlineController.text.trim(),
        'description':      _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'call_to_action':   _selectedCTA,
        'image_url':        _imageUrl!,
        'logo_url':         _logoUrl,
        'landing_url':      landingUrl,
        'destination_type':    _destinationType,
        'linked_property_id':  linkedPropertyId,
        'status':           'active',   // goes live on property list immediately
        'is_approved':      true,
        'ai_approved':      true,
        'ai_confidence':    validation.confidence,
        'ai_category':      validation.detectedCategory,
        'ai_reviewed_at':   DateTime.now().toUtc().toIso8601String(),
        'reviewed_by':      null,       // null = AI auto-approved, no human reviewer
        'reviewed_at':      DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        // Persist approval to notification inbox
        final userId = user?.id;
        if (userId != null) {
          final headline = _headlineController.text.trim();
          Supabase.instance.client.from('user_notifications').insert({
            'user_id': userId,
            'type':    'ad_approved',
            'title':   _s.sw ? '✅ Tangazo Lmekubaliwa na Linaonyeshwa!' : '✅ Ad Approved and Live!',
            'message': _s.sw
                ? 'Tangazo lako "$headline" limekubaliwa na sasa linaonyeshwa kwenye orodha ya mali.'
                : 'Your ad "$headline" was approved and is now showing on the property list.',
            'data': {
              'headline':    headline,
              'campaign_id': widget.campaignId,
              'screen':      'create_creative',
            },
            'is_read': false,
          }).catchError((_) {}); // non-blocking
        }

        _showSuccess(_s.sw
            ? 'Tangazo limekubaliwa na linaonyeshwa! 🎉'
            : 'Ad approved and live on the property list! 🎉');
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      _showError('Failed to submit creative: $e');
    }
  }

  // ── bilingual dialogs ─────────────────────────────────────────────────────

  void _showRejectionDialog({required String reason, required List<String> suggestions}) {
    final s = _s;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              child: Text(reason, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14), height: 1.5,
                  color: ThemeConfig.getTextPrimaryColor(ctx))),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: ThemeConfig.infoColor),
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
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAppealDialog(rejectionReason: reason);
            },
            child: Text(s.appealBtn,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAppealDialog({required String rejectionReason}) {
    final s = _s;
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.appealTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('If you believe this was rejected by mistake, explain why your ad is genuine.',
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13), color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: s.appealHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = Supabase.instance.client.auth.currentUser;
              final svc  = ref.read(aiValidationServiceProvider);
              final ok   = await svc.submitAppeal(
                contentType:     'ad',
                contentId:       widget.campaignId,
                rejectionReason: rejectionReason,
                userMessage:     msgCtrl.text.trim(),
                submittedBy:     user?.id,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? s.appealSent : s.appealFailed),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ));
              }
            },
            child: Text(s.appealBtn),
          ),
        ],
      ),
    );
  }

  // ── dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _headlineController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _whatsappMsgController.dispose();
    _websiteUrlController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: _buildAppBar(),
      body: (_isSubmitting || _isValidating)
          ? _buildSubmittingState()
          : _buildForm(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: ThemeConfig.getColor(
        context,
        lightColor: ThemeConfig.lightAppBarBackground,
        darkColor: ThemeConfig.darkAppBarBackground,
      ),
      leading: IconButton(
        icon: Icon(
          Icons.close_rounded,
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightAppBarForeground,
            darkColor: ThemeConfig.darkAppBarForeground,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Create Ad Creative',
        style: TextStyle(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightAppBarForeground,
            darkColor: ThemeConfig.darkAppBarForeground,
          ),
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSubmittingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: ThemeConfig.getPrimaryColor(context),
          ),
          const SizedBox(height: 20),
          Text(
            _isValidating
                ? '🤖 AI is checking your ad content...'
                : _s.submitting,
            style: TextStyle(
              color: ThemeConfig.getTextSecondaryColor(context),
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info icon button (shows instructions when tapped) ────
            Align(
              alignment: Alignment.centerRight,
              child: _InfoIconButton(
                instructTitle: _s.instructTitle,
                instructions: _s.instructions,
                prohibitedTitle: _s.prohibitedTitle,
                prohibitedItems: _s.prohibitedItems,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

            // ── Campaign info ────────────────────────────────────────
            _buildCampaignInfo(),
            const SizedBox(height: 28),

            // ── STEP 1: Media type ───────────────────────────────────
            _buildSectionHeader(
                _s.sw ? '1. Chagua Aina ya Maudhui' : '1. Choose Media Type',
                Icons.perm_media_rounded),
            const SizedBox(height: 14),
            _buildMediaTypeSelector(),
            const SizedBox(height: 28),

            // ── STEP 2: Upload media ─────────────────────────────────
            _buildSectionHeader(
              _s.sw ? '2. Pakia Picha' : '2. Upload Image',
              Icons.cloud_upload_rounded,
            ),
            const SizedBox(height: 14),
            _buildImageUploadArea(),
            _FieldTip(_s.imageTip),
            // Video upload removed — image-only ads

            const SizedBox(height: 28),

            // ── STEP 3: Logo ─────────────────────────────────────────
            _buildSectionHeader(
                _s.sw ? '3. Nembo ya Kampuni (si lazima)' : '3. Company Logo (optional)',
                Icons.business_rounded),
            const SizedBox(height: 14),
            _buildLogoUploadArea(),
            _FieldTip(_s.logoTip),
            const SizedBox(height: 28),

            // ── STEP 4: Ad copy ──────────────────────────────────────
            _buildSectionHeader(
                _s.sw ? '4. Maneno ya Tangazo' : '4. Ad Copy',
                Icons.edit_note_rounded),
            const SizedBox(height: 14),
            _buildAdCopyFields(),
            const SizedBox(height: 28),

            // ── STEP 5: Destination (previously Step 6) ──────────────
            _buildSectionHeader(
                _s.sw ? '5. Mawasiliano / Hatua ya Mtumiaji' : '5. Contact / Call to Action',
                Icons.ads_click_rounded),
            const SizedBox(height: 6),
            _FieldTip(_s.destinationTip),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            _buildDestinationSection(),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

            // ── Info banner ──────────────────────────────────────────
            _buildInfoBanner(),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

            // ── Submit button ────────────────────────────────────────
            _buildSubmitButton(),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
          ],
        ),
      ),
    );
  }

  // ── section widgets ───────────────────────────────────────────────────────

  Widget _buildCampaignInfo() {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: ThemeConfig.getPrimaryColor(context).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeConfig.getPrimaryColor(context).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded,
              color: ThemeConfig.getPrimaryColor(context)),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campaign',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                    fontWeight: FontWeight.w600,
                    color: ThemeConfig.getTextSecondaryColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.campaign.campaignName,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getTextPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
          decoration: BoxDecoration(
            color: ThemeConfig.getPrimaryColor(context).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(icon, size: 18, color: ThemeConfig.getPrimaryColor(context)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
            fontWeight: FontWeight.w700,
            color: ThemeConfig.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  // ── MEDIA TYPE SELECTOR ───────────────────────────────────────────────────

  Widget _buildMediaTypeSelector() {
    // Image-only ads — video ads removed to reduce storage/egress costs
    return _MediaTypeCard(
      icon: Icons.image_rounded,
      title: 'Image Ad',
      subtitle: 'JPG or PNG · up to 1920×1080',
      isSelected: true,
      onTap: () {},
    );
  }

  // ── IMAGE UPLOAD ──────────────────────────────────────────────────────────

  Widget _buildImageUploadArea() {
    final uploaded = _imageUrl != null;
    final uploading = _isUploadingImage;

    return GestureDetector(
      onTap: _anyUploading ? null : _pickAndUploadImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 200,
        decoration: BoxDecoration(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightInputFill,
            darkColor: ThemeConfig.darkInputFill,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: uploaded
                ? ThemeConfig.successColor
                : ThemeConfig.getColor(
                    context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder,
                  ),
            width: uploaded ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: uploading
              ? _buildUploadingState('Uploading image...')
              : uploaded
                  ? _buildImagePreview(
                      _imageFile!,
                      label: 'Ad Image ✓',
                      onRemove: () => setState(() {
                        _imageFile = null;
                        _imageUrl = null;
                      }),
                    )
                  : _buildUploadPlaceholder(
                      icon: Icons.add_photo_alternate_rounded,
                      primary: 'Tap to upload ad image',
                      secondary: 'JPG or PNG • Recommended 1200×630 px',
                    ),
        ),
      ),
    );
  }

  // ── LOGO UPLOAD ───────────────────────────────────────────────────────────

  Widget _buildLogoUploadArea() {
    final uploaded = _logoUrl != null;
    final uploading = _isUploadingLogo;

    return GestureDetector(
      onTap: _anyUploading ? null : _pickAndUploadLogo,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // 1. REMOVE: height: 110,
        padding: const EdgeInsets.symmetric(
            vertical: 24, horizontal: 16), // 2. ADD padding
        decoration: BoxDecoration(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightInputFill,
            darkColor: ThemeConfig.darkInputFill,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: uploaded
                ? ThemeConfig.successColor
                : ThemeConfig.getColor(
                    context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder,
                  ),
            width: uploaded ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: uploading
              ? _buildUploadingState('Uploading logo...')
              : uploaded
                  ? AspectRatio(
                      // 3. ADD AspectRatio for the preview
                      aspectRatio: 3,
                      child: _buildImagePreview(
                        _logoFile!,
                        label: 'Logo ✓',
                        onRemove: () => setState(() {
                          _logoFile = null;
                          _logoUrl = null;
                        }),
                      ),
                    )
                  : _buildUploadPlaceholder(
                      icon: Icons.business_center_rounded,
                      primary: 'Tap to upload company logo',
                      secondary: 'Square PNG or JPG • 512×512 px recommended',
                    ),
        ),
      ),
    );
  }
  // ── shared upload sub-widgets ─────────────────────────────────────────────

  Widget _buildUploadingState(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              color: ThemeConfig.getPrimaryColor(context), strokeWidth: 3),
          const SizedBox(height: 14),
          Text(label,
              style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                  color: ThemeConfig.getTextSecondaryColor(context))),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder({
    required IconData icon,
    required String primary,
    required String secondary,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeConfig.getPrimaryColor(context).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child:
              Icon(icon, size: 32, color: ThemeConfig.getPrimaryColor(context)),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Text(
          primary,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
            fontWeight: FontWeight.w600,
            color: ThemeConfig.getTextPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          secondary,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: ThemeConfig.getTextSecondaryColor(context)),
        ),
      ],
    );
  }

  Widget _buildImagePreview(
    XFile file, {
    required String label,
    required VoidCallback onRemove,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _previewImage(file),
        // Dark scrim at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: ThemeConfig.successColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                        fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ThemeConfig.errorColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white, size: ResponsiveHelper.getResponsiveIconSize(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── AD COPY FIELDS ────────────────────────────────────────────────────────

  Widget _buildAdCopyFields() {
    return Column(
      children: [
        // Headline
        TextFormField(
          controller: _headlineController,
          maxLength: 30,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: _inputDecoration(
            label: _s.sw ? 'Kichwa cha Tangazo *' : 'Headline *',
            hint: _s.sw ? 'mf. Nyumba za Gharama Nafuu – Dar es Salaam' : 'e.g. Premium Apartments in Dar es Salaam',
            icon: Icons.title_rounded,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return _s.headlineRequired;
            if (v.trim().length < 5) return _s.headlineTooShort;
            if (v.trim().length > 30) return _s.sw ? 'Herufi nyingi mno — angalau 30' : 'Max 30 characters';
            return null;
          },
        ),
        _FieldTip(_s.headlineTip),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

        // Description
        TextFormField(
          controller: _descriptionController,
          maxLength: 90,
          maxLines: 3,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: _inputDecoration(
            label: _s.sw ? 'Maelezo (si lazima)' : 'Description (optional)',
            hint: _s.sw
                ? 'Eleza sababu ya kuchagua nyumba hii...'
                : 'Tell users why they should click your ad...',
            icon: Icons.description_rounded,
          ),
        ),
        _FieldTip(_s.descriptionTip),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

        // Call to Action
        DropdownButtonFormField<String>(
          initialValue: _selectedCTA,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context), fontSize: 14),
          dropdownColor: ThemeConfig.getCardColor(context),
          decoration: _inputDecoration(
            label: _s.sw ? 'Wito wa Kutenda *' : 'Call to Action *',
            hint: '',
            icon: Icons.touch_app_rounded,
          ),
          items: [
            'Learn More',
            'View Property',
            'Contact Us',
            'Get Quote',
            'Call Now',
            'Visit Website',
            'Apply Now',
            'Schedule Tour',
            // 'Watch Video' removed (video ads disabled)
          ].map((cta) => DropdownMenuItem(value: cta, child: Text(cta))).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedCTA = v);
          },
        ),
      ],
    );
  }

  // ── AD DESTINATION ───────────────────────────────────────────────────────

  Widget _buildDestinationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 5-option picker row (scrollable so it fits any screen) ──────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
             /* _DestinationTypeCard(
                icon: Icons.phone_rounded,
                title: 'Phone Call',
                subtitle: 'Dial directly',
                isSelected: _destinationType == 'phone',
                onTap: () => setState(() => _destinationType = 'phone'),
              ),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),*/
              _DestinationTypeCard(
                icon: Icons.chat_rounded,
                title: 'WhatsApp',
                subtitle: 'Open chat',
                isSelected: _destinationType == 'whatsapp',
                onTap: () => setState(() => _destinationType = 'whatsapp'),
              ),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              _DestinationTypeCard(
                icon: Icons.home_rounded,
                title: 'My Property',
                subtitle: 'In-app listing',
                isSelected: _destinationType == 'property',
                onTap: () => setState(() => _destinationType = 'property'),
              ),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              _DestinationTypeCard(
                icon: Icons.person_rounded,
                title: 'My Profile',
                subtitle: 'Agent page',
                isSelected: _destinationType == 'profile',
                onTap: () => setState(() => _destinationType = 'profile'),
              ),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              _DestinationTypeCard(
                icon: Icons.language_rounded,
                title: 'Website',
                subtitle: 'External URL',
                isSelected: _destinationType == 'website',
                onTap: () => setState(() => _destinationType = 'website'),
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
        // ── Contextual input based on selection ──────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_destinationType),
            child: _buildDestinationInput(),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationInput() {
    switch (_destinationType) {

      // ── Phone call ──────────────────────────────────────────────────────
      case 'phone':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
              decoration: _inputDecoration(
                label: _s.sw ? 'Nambari ya Simu *' : 'Phone Number *',
                hint: '+255712345678',
                icon: Icons.phone_rounded,
              ),
            ),
            _FieldTip(_s.phoneTip),
            const SizedBox(height: 4),
            _buildDestinationHint(
              _s.sw
                ? 'Weka nambari ya nchi (+255 Tanzania). Mtumiaji anapogonga tangazo, simu itafunguka na nambari yako imewekwa.'
                : 'Include country code (e.g. +255 for Tanzania). Tapping the ad opens the phone dialer with your number pre-filled.',
            ),
          ],
        );

      // ── WhatsApp ────────────────────────────────────────────────────────
      case 'whatsapp':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
              decoration: _inputDecoration(
                label: _s.sw ? 'Nambari ya WhatsApp *' : 'WhatsApp Number *',
                hint: '+255712345678',
                icon: Icons.chat_rounded,
              ),
            ),
            _FieldTip(_s.whatsappTip),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            TextFormField(
              controller: _whatsappMsgController,
              maxLength: 160,
              maxLines: 2,
              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
              decoration: _inputDecoration(
                label: _s.sw ? 'Ujumbe wa Awali (si lazima)' : 'Pre-filled Message (optional)',
                hint: _s.sw
                    ? 'Habari, nimeona tangazo lako kwenye Nyumba na ninapenda kujua zaidi.'
                    : 'Hi, I saw your ad on Nyumba and I am interested.',
                icon: Icons.message_rounded,
              ),
            ),
            const SizedBox(height: 4),
            _buildDestinationHint(
              _s.sw
                ? 'WhatsApp itafunguka na nambari yako na ujumbe huu umewekwa tayari — mtumiaji atume tu.'
                : 'WhatsApp will open with your number and this message already typed — users just hit send.',
            ),
          ],
        );

      // ── Specific property listing ────────────────────────────────────────
      case 'property':
        return _buildPropertyPicker();

      // ── In-app profile ───────────────────────────────────────────────────
      case 'profile':
        return _buildProfileDestinationInfo();

      // ── External website ─────────────────────────────────────────────────
      default: // 'website'
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _websiteUrlController,
              keyboardType: TextInputType.url,
              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
              decoration: _inputDecoration(
                label: 'Website URL *',
                hint: 'https://yourwebsite.com/page',
                icon: Icons.open_in_browser_rounded,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            _buildDestinationHint(
              'Users will be taken to this URL when they tap your ad.',
            ),
          ],
        );
    }
  }

  // ── Property picker ────────────────────────────────────────────────────────

  Widget _buildPropertyPicker() {
    // Trigger a load the first time this picker is shown so it never appears
    // empty just because the notifier was constructed before auth was ready.
    final myPropertiesState = ref.watch(myPropertiesProvider);
    final properties = myPropertiesState.properties;
    final isLoading  = myPropertiesState.isLoading;

    // If nothing loaded yet and not currently loading, kick off a fresh fetch.
    if (!isLoading && properties.isEmpty && myPropertiesState.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(myPropertiesProvider.notifier).loadProperties();
      });
    }

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeConfig.getColor(context,
              lightColor: ThemeConfig.lightInputFill,
              darkColor: ThemeConfig.darkInputFill),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeConfig.getColor(context,
                lightColor: ThemeConfig.lightBorder,
                darkColor: ThemeConfig.darkBorder),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ThemeConfig.getPrimaryColor(context),
              ),
            ),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Text('Loading your listings…',
                style: TextStyle(
                    color: ThemeConfig.getTextSecondaryColor(context))),
          ],
        ),
      );
    }

    if (properties.isEmpty) {
      return Container(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        decoration: BoxDecoration(
          color: ThemeConfig.getColor(context,
              lightColor: ThemeConfig.lightInputFill,
              darkColor: ThemeConfig.darkInputFill),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeConfig.getColor(context,
                lightColor: ThemeConfig.lightBorder,
                darkColor: ThemeConfig.darkBorder),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: ThemeConfig.getTextSecondaryColor(context)),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Expanded(
              child: Text(
                'You have no active listings. Create a property first, then come back to link it to an ad.',
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                    color: ThemeConfig.getTextSecondaryColor(context),
                    height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected property preview
        if (_selectedProperty != null) ...[
          _buildSelectedPropertyCard(_selectedProperty!),
          const SizedBox(height: 10),
        ],
        // Scrollable list of properties
        Text(
          _selectedProperty == null
              ? 'Select a listing to link:'
              : 'Change listing:',
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
            fontWeight: FontWeight.w600,
            color: ThemeConfig.getTextSecondaryColor(context),
          ),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: properties.length,
            separatorBuilder: (_, __) => SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
            itemBuilder: (context, index) {
              final prop = properties[index];
              final isSelected = _selectedProperty?.id == prop.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedProperty = prop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 200,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ThemeConfig.getPrimaryColor(context).withOpacity(0.10)
                        : ThemeConfig.getCardColor(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? ThemeConfig.getPrimaryColor(context)
                          : ThemeConfig.getColor(context,
                              lightColor: ThemeConfig.lightBorder,
                              darkColor: ThemeConfig.darkBorder),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: prop.images.isNotEmpty
                            ? Image.network(
                                prop.images.first,
                                width: 44, height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _propertyPlaceholder(),
                              )
                            : _propertyPlaceholder(),
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              prop.title,
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? ThemeConfig.getPrimaryColor(context)
                                    : ThemeConfig.getTextPrimaryColor(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              prop.location,
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                                color: ThemeConfig.getTextSecondaryColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: ThemeConfig.getPrimaryColor(context),
                            size: ResponsiveHelper.getResponsiveIconSize(context)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        _buildDestinationHint(
          'Tapping the ad will open this property detail page inside the app.',
        ),
      ],
    );
  }

  Widget _buildSelectedPropertyCard(PropertyEntity prop) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
      decoration: BoxDecoration(
        color: ThemeConfig.getPrimaryColor(context).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeConfig.getPrimaryColor(context).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: prop.images.isNotEmpty
                ? Image.network(
                    prop.images.first,
                    width: 52, height: 52, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _propertyPlaceholder(),
                  )
                : _propertyPlaceholder(),
          ),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prop.title,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                    fontWeight: FontWeight.w700,
                    color: ThemeConfig.getTextPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  prop.location,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    color: ThemeConfig.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: ThemeConfig.getPrimaryColor(context), size: ResponsiveHelper.getResponsiveIconSize(context)),
        ],
      ),
    );
  }

  Widget _propertyPlaceholder() {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightInputFill,
            darkColor: ThemeConfig.darkInputFill),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.home_rounded,
          color: ThemeConfig.getTextSecondaryColor(context), size: ResponsiveHelper.getResponsiveIconSize(context)),
    );
  }

  Widget _buildProfileDestinationInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: ThemeConfig.getPrimaryColor(context).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeConfig.getPrimaryColor(context).withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ThemeConfig.getPrimaryColor(context).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded,
                color: ThemeConfig.getPrimaryColor(context), size: ResponsiveHelper.getResponsiveIconSize(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your In-App Profile',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                    fontWeight: FontWeight.w700,
                    color: ThemeConfig.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user != null
                      ? 'Tapping the ad opens your agent profile page, showing all your listings.'
                      : 'You must be logged in to link your profile.',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    color: ThemeConfig.getTextSecondaryColor(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: ThemeConfig.getPrimaryColor(context), size: ResponsiveHelper.getResponsiveIconSize(context)),
        ],
      ),
    );
  }

  Widget _buildDestinationHint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded,
            size: 14, color: ThemeConfig.getTextSecondaryColor(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
              color: ThemeConfig.getTextSecondaryColor(context),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ── INFO BANNER ───────────────────────────────────────────────────────────

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeConfig.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ThemeConfig.infoColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: ThemeConfig.infoColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(
            child: Text(
              'Your ad will be reviewed before going live.',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                color: ThemeConfig.getTextSecondaryColor(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SUBMIT BUTTON ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _anyUploading ? null : _submit,
        icon: const Icon(Icons.send_rounded),
        label: Text(
          _isValidating
              ? _s.checking
              : _anyUploading
                  ? (_s.sw ? 'Subiri upakiaji ukamilike...' : 'Please wait for uploads to finish...')
                  : (_s.sw ? 'Tuma Tangazo kwa Ukaguzi' : 'Submit for Review'),
          style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeConfig.getPrimaryColor(context),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              ThemeConfig.getTextSecondaryColor(context).withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: ThemeConfig.getTextSecondaryColor(context)),
      hintStyle: TextStyle(color: ThemeConfig.getTextSecondaryColor(context)),
      prefixIcon: Icon(icon,
          color: ThemeConfig.getTextSecondaryColor(context), size: ResponsiveHelper.getResponsiveIconSize(context)),
      filled: true,
      fillColor: ThemeConfig.getColor(
        context,
        lightColor: ThemeConfig.lightInputFill,
        darkColor: ThemeConfig.darkInputFill,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightInputBorder,
            darkColor: ThemeConfig.darkInputBorder,
          ),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightInputBorder,
            darkColor: ThemeConfig.darkInputBorder,
          ),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: ThemeConfig.getPrimaryColor(context),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ThemeConfig.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ThemeConfig.errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Private helper widget — media type card
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
// Private helper widget — destination type card
// ══════════════════════════════════════════════════════════════════════════════

class _DestinationTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DestinationTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = ThemeConfig.getPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withOpacity(0.10)
              : ThemeConfig.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primary
                : ThemeConfig.getColor(
                    context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder,
                  ),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 28,
                color: isSelected
                    ? primary
                    : ThemeConfig.getTextSecondaryColor(context)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? primary
                    : ThemeConfig.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle_rounded, color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _MediaTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = ThemeConfig.getPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withOpacity(0.10)
              : ThemeConfig.getCardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primary
                : ThemeConfig.getColor(
                    context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder,
                  ),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 36,
                color: isSelected
                    ? primary
                    : ThemeConfig.getTextSecondaryColor(context)),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? primary
                    : ThemeConfig.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                height: 1.4,
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 10),
              Icon(Icons.check_circle_rounded, color: primary, size: ResponsiveHelper.getResponsiveIconSize(context)),
            ],
          ],
        ),
      ),
    );
  }

}