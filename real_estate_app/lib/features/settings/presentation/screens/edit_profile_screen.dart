// features/settings/presentation/screens/edit_profile_screen.dart
// COMPLETE VERSION with Country Code Selector and Number-Only Phone Input

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/country_codes.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../presentation/providers/auth_provider.dart';

import '../providers/app_providers.dart';
import 'app_translations.dart';
import '../../../../core/utils/responsive_helper.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _imageHelper = ImageHelper();
  final _searchController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes; // web preview + upload bytes
  UserType _selectedUserType = UserType.buyer;
  bool _showEmail = true;
  bool _showPhone = true;
  bool _isLoading = false;

  // Phone country code selection
  CountryCode _selectedCountryCode = CountryCodes.defaultCountry;
  List<CountryCode> _filteredCountries = CountryCodes.all;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).value;
    if (user != null) {
      _fullNameController.text = user.fullName;

      // Parse existing phone number to extract country code and number
      if (user.phone != null && user.phone!.isNotEmpty) {
        _parsePhoneNumber(user.phone!);
      }

      _bioController.text = user.bio ?? '';
      _selectedUserType = user.userType;
      _showEmail = user.showEmail;
      _showPhone = user.showPhone;
    }
  }

  void _parsePhoneNumber(String phone) {
    // Try to match phone with country codes (sorted by length descending to match longest first)
    final sortedCodes = List<CountryCode>.from(CountryCodes.all)
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

    for (var country in sortedCodes) {
      if (phone.startsWith(country.dialCode)) {
        setState(() {
          _selectedCountryCode = country;
          _phoneController.text = phone.substring(country.dialCode.length);
        });
        return;
      }
    }
    // If no match found, use the full number
    _phoneController.text = phone;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final currentLanguage = ref.read(languageProvider).languageCode;
    final sw = currentLanguage == 'sw';

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(sw ? 'Chagua kwenye Galari' : 'Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(sw ? 'Piga Picha' : 'Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(sw ? 'Ghairi' : 'Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await _imageHelper.pickSingleImage(source: source);
    if (picked == null || !mounted) return;

    // Normalise: transcodes iPhone HEIC to JPEG and validates the format, so a
    // broken/unrenderable avatar is never stored.
    final normalized =
        await _imageHelper.normalizeForUpload(context, picked, card: false);
    if (normalized == null) {
      if (mounted) {
        SnackbarUtils.showError(
            context,
            sw
                ? 'Picha hii haikuweza kushughulikiwa. Tumia programu au JPEG.'
                : 'That photo could not be processed. Try the app or a JPEG.');
      }
      return;
    }

    final bytes = await normalized.readAsBytes();
    if (bytes.isEmpty || !mounted) return;

    setState(() {
      _selectedImage = normalized;
      _selectedImageBytes = bytes;
    });
  }

  ImageProvider? _avatarProvider(String? existingUrl) {
    if (_selectedImage != null) {
      if (kIsWeb) {
        return _selectedImageBytes != null
            ? MemoryImage(_selectedImageBytes!)
            : null;
      }
      return FileImage(File(_selectedImage!.path));
    }
    if (existingUrl != null && existingUrl.isNotEmpty) {
      return CachedNetworkImageProvider(existingUrl);
    }
    return null;
  }

  void _showCountryCodePicker() {
    final currentLanguage = ref.read(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    _searchController.clear();
    _filteredCountries = CountryCodes.all;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  t('select_country_code'),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),

              // Search Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: t('search_country'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setModalState(() {
                                _filteredCountries = CountryCodes.all;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      _filteredCountries = CountryCodes.search(value);
                    });
                  },
                ),
              ),

              // Country List
              Expanded(
                child: _filteredCountries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                            Text(
                              t('no_country_found'),
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredCountries.length,
                        itemBuilder: (context, index) {
                          final country = _filteredCountries[index];
                          final isSelected =
                              country.code == _selectedCountryCode.code;

                          return ListTile(
                            leading: Text(
                              country.flag,
                              style: const TextStyle(fontSize: 28),
                            ),
                            title: Text(country.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  country.dialCode,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                                  ),
                                ),
                                if (isSelected) ...[
                                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                                  const Icon(
                                    Icons.check_circle,
                                    color: ThemeConfig.primaryColor,
                                  ),
                                ],
                              ],
                            ),
                            selected: isSelected,
                            selectedTileColor:
                                ThemeConfig.primaryColor.withOpacity(0.1),
                            onTap: () {
                              setState(() => _selectedCountryCode = country);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdateProfile() async {
    final currentLanguage = ref.read(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final user = ref.read(authNotifierProvider).value;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    String? imageUrl = user.avatarUrl;
    if (_selectedImage != null) {
      // Universal Upload Architecture: raw bytes → staging_media → Edge Function
      // → public_media.  readAsBytes() inside uploadSingleRawToStaging bypasses
      // Android Scoped Storage / iOS sandbox / PWA service-worker interception.
      final uploaded = await ImageUploadService.uploadSingleRawToStaging(
        file: _selectedImage!,
        userId: user.id,
        folder: 'avatar',
        label: '0',
      );
      if (uploaded == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          SnackbarUtils.showError(context, t('failed_to_update_profile'));
        }
        return;
      }
      imageUrl = uploaded;
    }

    // Combine country code with phone number
    String? fullPhoneNumber;
    if (_phoneController.text.trim().isNotEmpty) {
      fullPhoneNumber =
          '${_selectedCountryCode.dialCode}${_phoneController.text.trim()}';
    }

    final updatedUser = user.copyWith(
      fullName: _fullNameController.text.trim(),
      phone: fullPhoneNumber,
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
      avatarUrl: imageUrl,
      showEmail: _showEmail,
      showPhone: _showPhone,
      userType: _selectedUserType,
    );

    final success = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(updatedUser);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        SnackbarUtils.showSuccess(context, t('profile_updated_successfully'));
        // Screen stays open after successful save
      } else {
        SnackbarUtils.showError(context, t('failed_to_update_profile'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLanguage = ref.watch(languageProvider).languageCode;

    String t(String key) => AppTranslations.translate(key, currentLanguage);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('edit_profile_title')),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.done),
            tooltip: t('save'),
            onPressed: _isLoading ? null : _handleUpdateProfile,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ThemeConfig.primaryColor,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _avatarProvider(user?.avatarUrl),
                      child: _selectedImage == null && user?.avatarUrl == null
                          ? Text(
                              user?.fullName[0].toUpperCase() ?? 'U',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 48),
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.primaryColor,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ThemeConfig.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Center(
              child: TextButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.edit, size: ResponsiveHelper.getResponsiveIconSize(context)),
                label: Text(t('change_profile_picture')),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

            // Full Name
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: t('full_name'),
                hintText: t('enter_full_name'),
                prefixIcon: const Icon(Icons.person_outlined),
              ),
              validator: Validators.validateName,
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Email with visibility toggle
            TextFormField(
              initialValue: user?.email ?? '',
              enabled: true,
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.6),
              ),
              decoration: InputDecoration(
                labelText: t('email'),
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: Theme.of(context).iconTheme.color,
                ),
                suffixIcon: Tooltip(
                  message: _showEmail
                      ? t('visible_on_profile')
                      : t('hidden_on_profile'),
                  child: IconButton(
                    icon: Icon(
                      _showEmail ? Icons.visibility : Icons.visibility_off,
                      color:
                          _showEmail ? ThemeConfig.primaryColor : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _showEmail = !_showEmail);
                    },
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                _showEmail
                    ? t('email_visible_on_public_profile')
                    : t('email_hidden_from_public_profile'),
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: _showEmail ? ThemeConfig.successColor : Colors.grey,
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Phone Number with Country Code Selector
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country Code Selector Button
                InkWell(
                  onTap: _showCountryCodePicker,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedCountryCode.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedCountryCode.dialCode,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: ResponsiveHelper.getResponsiveIconSize(context)),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

                // Phone Number Input (Numbers Only)
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: t('phone_number'),
                      hintText: t('enter_phone_number'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: Tooltip(
                        message: _showPhone
                            ? t('visible_on_profile')
                            : t('hidden_on_profile'),
                        child: IconButton(
                          icon: Icon(
                            _showPhone
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: _showPhone
                                ? ThemeConfig.primaryColor
                                : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() => _showPhone = !_showPhone);
                          },
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly, // Only allow digits
                      LengthLimitingTextInputFormatter(15), // Max 15 digits
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null; // Phone is optional
                      }
                      if (value.length < 7) {
                        return t('phone_too_short');
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                _showPhone
                    ? t('phone_visible_on_public_profile')
                    : t('phone_hidden_from_public_profile'),
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: _showPhone ? ThemeConfig.successColor : Colors.grey,
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Bio
            TextFormField(
              controller: _bioController,
              decoration: InputDecoration(
                labelText: t('bio'),
                hintText: t('tell_about_yourself'),
                prefixIcon: const Icon(Icons.info_outlined),
                alignLabelWithHint: true,
                helperText: t('always_visible_on_profile'),
              ),
              maxLines: 4,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleUpdateProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      t('save_changes'),
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Cancel Button
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                ),
              ),
              child: Text(
                t('cancel'),
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}