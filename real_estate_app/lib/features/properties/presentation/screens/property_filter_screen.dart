// features/properties/presentation/screens/property_filter_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_helper.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';
import '../../domain/entities/property_filter_entity.dart';
import '../providers/property_providers.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

class PropertyFilterScreen extends ConsumerStatefulWidget {
  final PropertyFilterEntity? initialFilter;

  const PropertyFilterScreen({
    super.key,
    this.initialFilter,
  });

  @override
  ConsumerState<PropertyFilterScreen> createState() => _PropertyFilterScreenState();
}

class _PropertyFilterScreenState extends ConsumerState<PropertyFilterScreen> {
  PropertyType? _selectedType;
  PropertyCategory? _selectedCategory;
  PropertyStatus? _selectedStatus;
  RangeValues _priceRange = const RangeValues(0, 1000000);
  RangeValues _bedroomRange = const RangeValues(0, 10);
  RangeValues _bathroomRange = const RangeValues(0, 10);
  RangeValues _areaRange = const RangeValues(0, 1000);
  final _locationController = TextEditingController();
  
  static const String _filterPrefsKey = 'property_filter_state';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFilterState();
  }

  Future<void> _loadFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // TEMPORARY: Uncomment the line below to clear saved filters on hot reload
      // await prefs.remove(_filterPrefsKey);
      
      final filterJson = prefs.getString(_filterPrefsKey);
      
      if (filterJson != null) {
        final filterMap = json.decode(filterJson) as Map<String, dynamic>;
        setState(() {
          // Load property type
          if (filterMap['type'] != null) {
            _selectedType = PropertyType.values.firstWhere(
              (e) => e.toString() == filterMap['type'],
              orElse: () => PropertyType.values.first,
            );
          }
          
          // Load category
          if (filterMap['category'] != null) {
            _selectedCategory = PropertyCategory.values.firstWhere(
              (e) => e.toString() == filterMap['category'],
              orElse: () => PropertyCategory.values.first,
            );
          }
          
          // Load status
          if (filterMap['status'] != null) {
            _selectedStatus = PropertyStatus.values.firstWhere(
              (e) => e.toString() == filterMap['status'],
              orElse: () => PropertyStatus.values.first,
            );
          }
          
          // Load location
          if (filterMap['location'] != null) {
            _locationController.text = filterMap['location'];
          }
          
          // Load price range
          if (filterMap['priceRangeStart'] != null && filterMap['priceRangeEnd'] != null) {
            _priceRange = RangeValues(
              filterMap['priceRangeStart'].toDouble(),
              filterMap['priceRangeEnd'].toDouble(),
            );
          }
          
          // Load bedroom range
          if (filterMap['bedroomRangeStart'] != null && filterMap['bedroomRangeEnd'] != null) {
            _bedroomRange = RangeValues(
              filterMap['bedroomRangeStart'].toDouble(),
              filterMap['bedroomRangeEnd'].toDouble(),
            );
          }
          
          // Load bathroom range
          if (filterMap['bathroomRangeStart'] != null && filterMap['bathroomRangeEnd'] != null) {
            _bathroomRange = RangeValues(
              filterMap['bathroomRangeStart'].toDouble(),
              filterMap['bathroomRangeEnd'].toDouble(),
            );
          }
          
          // Load area range
          if (filterMap['areaRangeStart'] != null && filterMap['areaRangeEnd'] != null) {
            _areaRange = RangeValues(
              filterMap['areaRangeStart'].toDouble(),
              filterMap['areaRangeEnd'].toDouble(),
            );
          }
          
          _isLoading = false;
        });
      } else if (widget.initialFilter != null) {
        // Load from initial filter if no saved state
        _loadInitialFilter();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading filter state: $e');
      if (widget.initialFilter != null) {
        _loadInitialFilter();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadInitialFilter() {
    final filter = widget.initialFilter!;
    setState(() {
      _selectedType = filter.type;
      _selectedCategory = filter.category;
      _selectedStatus = filter.status;
      _locationController.text = filter.location ?? '';
      
      if (filter.minPrice != null || filter.maxPrice != null) {
        _priceRange = RangeValues(
          filter.minPrice ?? 0,
          filter.maxPrice ?? 1000000,
        );
      }
      if (filter.minBedrooms != null || filter.maxBedrooms != null) {
        _bedroomRange = RangeValues(
          filter.minBedrooms?.toDouble() ?? 0,
          filter.maxBedrooms?.toDouble() ?? 10,
        );
      }
      if (filter.minBathrooms != null || filter.maxBathrooms != null) {
        _bathroomRange = RangeValues(
          filter.minBathrooms?.toDouble() ?? 0,
          filter.maxBathrooms?.toDouble() ?? 10,
        );
      }
      if (filter.minArea != null || filter.maxArea != null) {
        _areaRange = RangeValues(
          filter.minArea ?? 0,
          filter.maxArea ?? 1000,
        );
      }
      _isLoading = false;
    });
  }

  Future<void> _saveFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterMap = {
        'type': _selectedType?.toString(),
        'category': _selectedCategory?.toString(),
        'status': _selectedStatus?.toString(),
        'location': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        'priceRangeStart': _priceRange.start,
        'priceRangeEnd': _priceRange.end,
        'bedroomRangeStart': _bedroomRange.start,
        'bedroomRangeEnd': _bedroomRange.end,
        'bathroomRangeStart': _bathroomRange.start,
        'bathroomRangeEnd': _bathroomRange.end,
        'areaRangeStart': _areaRange.start,
        'areaRangeEnd': _areaRange.end,
      };
      
      await prefs.setString(_filterPrefsKey, json.encode(filterMap));
    } catch (e) {
      debugPrint('Error saving filter state: $e');
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _applyFilters() async {
    final filter = PropertyFilterEntity(
      type: _selectedType,
      category: _selectedCategory,
      status: _selectedStatus,
      minPrice: _priceRange.start > 0 ? _priceRange.start : null,
      maxPrice: _priceRange.end < 1000000 ? _priceRange.end : null,
      minBedrooms: _bedroomRange.start.toInt() > 0 ? _bedroomRange.start.toInt() : null,
      maxBedrooms: _bedroomRange.end.toInt() < 10 ? _bedroomRange.end.toInt() : null,
      minBathrooms: _bathroomRange.start.toInt() > 0 ? _bathroomRange.start.toInt() : null,
      maxBathrooms: _bathroomRange.end.toInt() < 10 ? _bathroomRange.end.toInt() : null,
      minArea: _areaRange.start > 0 ? _areaRange.start : null,
      maxArea: _areaRange.end < 1000 ? _areaRange.end : null,
      location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
    );

    // Save the current filter state
    await _saveFilterState();

    // Apply to property list if navigating from main property list
    ref.read(propertyListProvider.notifier).applyFilter(filter);
    
    // Return the filter for search screen
    if (mounted) {
      Navigator.pop(context, filter);
    }
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedType = null;
      _selectedCategory = null;
      _selectedStatus = null;
      _priceRange = const RangeValues(0, 1000000);
      _bedroomRange = const RangeValues(0, 10);
      _bathroomRange = const RangeValues(0, 10);
      _areaRange = const RangeValues(0, 1000);
      _locationController.clear();
    });

    // Clear saved filter state
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_filterPrefsKey);
    } catch (e) {
      debugPrint('Error clearing filter state: $e');
    }

    ref.read(propertyListProvider.notifier).clearFilter();
    
    // Don't navigate back - just clear the filters and stay on screen
  }

  @override
  Widget build(BuildContext context) {
    final currentCurrency = ref.watch(currencyProvider);
    final currencySymbol = CurrencyHelper.getSymbol(currentCurrency);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Filter Properties'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Properties'),
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        children: [
          // Type Filter
          Text(
            'Property Type',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Wrap(
            spacing: 8,
            children: PropertyType.values.map((type) {
              return ChoiceChip(
                label: Text(type.displayName),
                selected: _selectedType == type,
                onSelected: (selected) {
                  setState(() {
                    _selectedType = selected ? type : null;
                  });
                },
              );
            }).toList(),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

          // Category Filter
          Text(
            'Category',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Wrap(
            spacing: 8,
            children: PropertyCategory.values.map((category) {
              return ChoiceChip(
                label: Text(category.displayName),
                selected: _selectedCategory == category,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = selected ? category : null;
                  });
                },
              );
            }).toList(),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

          // Status Filter
          Text(
            'Status',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Wrap(
            spacing: 8,
            children: PropertyStatus.values.map((status) {
              return ChoiceChip(
                label: Text(status.displayName),
                selected: _selectedStatus == status,
                onSelected: (selected) {
                  setState(() {
                    _selectedStatus = selected ? status : null;
                  });
                },
              );
            }).toList(),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

          // Price Range
          Text(
            'Price Range',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text(
            '$currencySymbol${_priceRange.start.toInt()} - $currencySymbol${_priceRange.end.toInt()}',
            style: const TextStyle(color: ThemeConfig.textSecondaryColor),
          ),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000000,
            divisions: 100,
            labels: RangeLabels(
              '$currencySymbol${_priceRange.start.toInt()}',
              '$currencySymbol${_priceRange.end.toInt()}',
            ),
            onChanged: (values) {
              setState(() {
                _priceRange = values;
              });
            },
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

          // Bedrooms Range
          Text(
            'Bedrooms',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text(
            '${_bedroomRange.start.toInt()} - ${_bedroomRange.end.toInt()} bedrooms',
            style: const TextStyle(color: ThemeConfig.textSecondaryColor),
          ),
          RangeSlider(
            values: _bedroomRange,
            min: 0,
            max: 10,
            divisions: 10,
            labels: RangeLabels(
              '${_bedroomRange.start.toInt()}',
              '${_bedroomRange.end.toInt()}',
            ),
            onChanged: (values) {
              setState(() {
                _bedroomRange = values;
              });
            },
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

          // Bathrooms Range
          Text(
            'Bathrooms',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text(
            '${_bathroomRange.start.toInt()} - ${_bathroomRange.end.toInt()} bathrooms',
            style: const TextStyle(color: ThemeConfig.textSecondaryColor),
          ),
          RangeSlider(
            values: _bathroomRange,
            min: 0,
            max: 10,
            divisions: 10,
            labels: RangeLabels(
              '${_bathroomRange.start.toInt()}',
              '${_bathroomRange.end.toInt()}',
            ),
            onChanged: (values) {
              setState(() {
                _bathroomRange = values;
              });
            },
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

          // Area Range
          Text(
            'Area (sqm)',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text(
            '${_areaRange.start.toInt()} - ${_areaRange.end.toInt()} sqm',
            style: const TextStyle(color: ThemeConfig.textSecondaryColor),
          ),
          RangeSlider(
            values: _areaRange,
            min: 0,
            max: 1000,
            divisions: 100,
            labels: RangeLabels(
              '${_areaRange.start.toInt()}',
              '${_areaRange.end.toInt()}',
            ),
            onChanged: (values) {
              setState(() {
                _areaRange = values;
              });
            },
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

          // Location
          Text(
            'Location',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          LocationAutocompleteField(
            controller: _locationController,
            hintText: 'e.g. Masaki, Westlands, Kololo…',
            clearOnSelect: false,
            onSelected: (_, displayName) {
              _locationController.text = displayName;
            },
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

          // Apply Button
          ElevatedButton(
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}