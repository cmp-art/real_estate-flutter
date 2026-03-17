// features/properties/presentation/screens/property_edit_screen.dart
// FIXED - Conditional validation for Land/Commercial properties

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:patamjengo_app/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/utils/currency_helper.dart';

import '../../../../shared/widgets/custom_button.dart';
import '../../../favorites/presentation/providers/favorite_providers.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../settings/presentation/screens/app_translations.dart';
import '../../domain/entities/property_entity.dart';
import '../providers/property_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

class PropertyEditScreen extends ConsumerStatefulWidget {
  final PropertyEntity property;

  const PropertyEditScreen({
    super.key,
    required this.property,
  });

  @override
  ConsumerState<PropertyEditScreen> createState() => _PropertyEditScreenState();
}

class _PropertyEditScreenState extends ConsumerState<PropertyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaController = TextEditingController();

  late PropertyType _selectedType;
  late PropertyCategory _selectedCategory;
  late PropertyStatus _selectedStatus;
  RentDuration _selectedRentDuration = RentDuration.monthly;

  List<String> _existingImages = [];
  final List<File> _selectedImages = [];
  bool _isLoading = false;

  final ImageHelper _imageHelper = ImageHelper();

  @override
  void initState() {
    super.initState();
    _loadPropertyData();
  }

  void _loadPropertyData() {
    final property = widget.property;
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

    _existingImages = List.from(property.images);
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

  Future<void> _pickImages() async {
    final currentLanguage = ref.read(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    final remainingSlots = AppConstants.maxImagesPerProperty -
        _existingImages.length -
        _selectedImages.length;
    if (remainingSlots <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${t('maximum_images')} ${AppConstants.maxImagesPerProperty} ${t('images_allowed')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final images = await _imageHelper.pickMultipleImages(
      maxImages: remainingSlots,
    );

    if (images.isNotEmpty && mounted) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Helper to check if current category requires beds/baths
  bool get _requiresBedroomsBathrooms {
    return _selectedCategory != PropertyCategory.land && 
           _selectedCategory != PropertyCategory.commercial;
  }

  Future<void> _handleSubmit() async {
    final currentLanguage = ref.read(languageProvider).languageCode;
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_existingImages.isEmpty && _selectedImages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('at_least_one_image')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authNotifierProvider).value;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('unauthorized')),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final repository = ref.read(propertyRepositoryProvider);

      // For land/commercial, set bedrooms/bathrooms to 0 if not provided
      final bedrooms = _requiresBedroomsBathrooms && _bedroomsController.text.isNotEmpty
          ? int.parse(_bedroomsController.text.trim())
          : 0;
      final bathrooms = _requiresBedroomsBathrooms && _bathroomsController.text.isNotEmpty
          ? int.parse(_bathroomsController.text.trim())
          : 0;

      final updatedProperty = PropertyEntity(
        id: widget.property.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        type: _selectedType,
        category: _selectedCategory,
        location: _locationController.text.trim(),
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        area: double.parse(_areaController.text.trim()),
        images: _existingImages,
        ownerId: widget.property.ownerId,
        status: _selectedStatus,
        rentDuration:
            _selectedType == PropertyType.rent ? _selectedRentDuration : null,
        createdAt: widget.property.createdAt,
        updatedAt: DateTime.now(),
        ownerName: widget.property.ownerName,
      );

      final result = await repository.updateProperty(updatedProperty);

      if (!mounted) return;

      await result.fold(
        (failure) async {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        (savedProperty) async {
          PropertyEntity finalProperty = savedProperty;

          if (_selectedImages.isNotEmpty) {
            final uploadResult = await repository.uploadImages(
              savedProperty.id,
              _selectedImages,
            );

            await uploadResult.fold(
              (failure) async {
                debugPrint('${t('image_upload_failed')}: ${failure.message}');
              },
              (imageUrls) async {
                finalProperty = savedProperty.copyWith(
                  images: [...savedProperty.images, ...imageUrls],
                );
                await repository.updateProperty(finalProperty);
              },
            );
          }

          if (mounted) {
            setState(() => _isLoading = false);

            ref
                .read(propertyListProvider.notifier)
                .updatePropertyInList(finalProperty);
            ref.invalidate(myPropertiesProvider);
            ref.invalidate(favoritePropertiesProvider);
            ref.invalidate(propertyDetailProvider(widget.property.id));

            Navigator.pop(context, true);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t('property_updated_successfully')),
                backgroundColor: Theme.of(context).primaryColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final currentLanguage = ref.read(languageProvider).languageCode;
        String t(String key) => AppTranslations.translate(key, currentLanguage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalImages = _existingImages.length + _selectedImages.length;
    final currentLanguage = ref.watch(languageProvider).languageCode;
    final currentCurrency = ref.watch(currencyProvider);
    final currencySymbol = CurrencyHelper.getSymbol(currentCurrency);
    String t(String key) => AppTranslations.translate(key, currentLanguage);

    String priceSuffix = '';
    if (_selectedType == PropertyType.rent) {
      if (_selectedRentDuration == RentDuration.monthly) {
        priceSuffix = t('per_month');
      } else {
        priceSuffix = t('per_year');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('edit_property')),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          children: [
            Text(
              t('property_images'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

            if (_existingImages.isNotEmpty) ...[
              Text(
                '${t('current_images')} (${_existingImages.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                            child: Image.network(
                              _existingImages[index],
                              height: 200,
                              width: 200,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  width: 200,
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  width: 200,
                                  color: theme.colorScheme.errorContainer,
                                  child: Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.error,
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              onPressed: () => _removeExistingImage(index),
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black87,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            ],

            if (_selectedImages.isNotEmpty) ...[
              Text(
                '${t('new_images')} (${_selectedImages.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                            child: Image.file(
                              _selectedImages[index],
                              height: 200,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              onPressed: () => _removeNewImage(index),
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black87,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t('new'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            ],

            if (totalImages < AppConstants.maxImagesPerProperty)
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(
                  _existingImages.isEmpty && _selectedImages.isEmpty
                      ? t('add_images')
                      : '${t('add_more_images')} ($totalImages/${AppConstants.maxImagesPerProperty})',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: t('property_title'),
                hintText: t('property_title_hint'),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) =>
                  Validators.validateRequired(value, t('title')),
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: t('description'),
                hintText: t('describe_property'),
                prefixIcon: const Icon(Icons.description),
              ),
              validator: (value) =>
                  Validators.validateRequired(value, t('description')),
              maxLines: 4,
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Category Dropdown - Place before bedrooms/bathrooms
            DropdownButtonFormField<PropertyCategory>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: t('category'),
                prefixIcon: const Icon(Icons.home_work),
              ),
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

            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: t('price'),
                hintText: '0',
                prefixText: '$currencySymbol ',
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: priceSuffix.isNotEmpty ? priceSuffix : null,
              ),
              keyboardType: TextInputType.number,
              validator: Validators.validatePrice,
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            DropdownButtonFormField<PropertyType>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: t('type'),
                prefixIcon: const Icon(Icons.category),
              ),
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
            
            if (_selectedType == PropertyType.rent) ...[
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              Text(
                t('rent_duration'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(t('monthly')),
                      selected: _selectedRentDuration == RentDuration.monthly,
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
                      selected: _selectedRentDuration == RentDuration.yearly,
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
            
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: t('location'),
                hintText: t('enter_location'),
                prefixIcon: const Icon(Icons.location_on),
              ),
              validator: (value) =>
                  Validators.validateRequired(value, t('location')),
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Bedrooms and Bathrooms - Only show for non-land/commercial
            if (_requiresBedroomsBathrooms) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bedroomsController,
                      decoration: InputDecoration(
                        labelText: t('bedrooms'),
                        hintText: '0',
                        prefixIcon: const Icon(Icons.bed),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          Validators.validateNumber(value, t('bedrooms')),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
                  Expanded(
                    child: TextFormField(
                      controller: _bathroomsController,
                      decoration: InputDecoration(
                        labelText: t('bathrooms'),
                        hintText: '0',
                        prefixIcon: const Icon(Icons.bathroom),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          Validators.validateNumber(value, t('bathrooms')),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            ] else ...[
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: ResponsiveHelper.getResponsiveIconSize(context)),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                    Expanded(
                      child: Text(
                        'Bedrooms and bathrooms are not required for ${_selectedCategory.displayName} properties',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            ],

            TextFormField(
              controller: _areaController,
              decoration: InputDecoration(
                labelText: t('area_sqft'),
                hintText: '0',
                prefixIcon: const Icon(Icons.square_foot),
              ),
              keyboardType: TextInputType.number,
              validator: Validators.validatePrice,
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            DropdownButtonFormField<PropertyStatus>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                labelText: t('status'),
                prefixIcon: const Icon(Icons.info),
              ),
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
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

            CustomButton(
              text: t('update_property'),
              onPressed: _handleSubmit,
              isLoading: _isLoading,
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          ],
        ),
      ),
    );
  }
}