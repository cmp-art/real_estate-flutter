// lib/features/notifications/presentation/screens/notification_filter_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/services/notification_filter_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final notificationFilterServiceProvider = Provider<NotificationFilterService>((ref) {
  // Use Supabase.instance.client — matches the rest of the app; no mock provider
  return NotificationFilterService(Supabase.instance.client);
});

final notificationFilterProvider =
    FutureProvider.autoDispose.family<NotificationFilter?, FilterRequest>((ref, request) async {
  final service = ref.watch(notificationFilterServiceProvider);
  return service.getFilter(userId: request.userId, category: request.category);
});

// ─────────────────────────────────────────────────────────────────────────────
// FILTER REQUEST (value equality for FutureProvider.family caching)
// ─────────────────────────────────────────────────────────────────────────────

class FilterRequest {
  final String userId;
  final String category;

  const FilterRequest({required this.userId, required this.category});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterRequest && userId == other.userId && category == other.category;

  @override
  int get hashCode => userId.hashCode ^ category.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class NotificationFilterScreen extends ConsumerStatefulWidget {
  /// 'new_property' | 'price_change'
  final String category;
  /// Display title shown in AppBar, e.g. 'New Property Alerts'
  final String categoryTitle;

  const NotificationFilterScreen({
    super.key,
    required this.category,
    required this.categoryTitle,
  });

  @override
  ConsumerState<NotificationFilterScreen> createState() => _NotificationFilterScreenState();
}

class _NotificationFilterScreenState extends ConsumerState<NotificationFilterScreen> {
  final _formKey = GlobalKey<FormState>();

  // PropertyType comes from notification_filter_service.dart
  Set<PropertyType> _selectedTypes = PropertyType.values.toSet();

  double? _minPrice;
  double? _maxPrice;
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  int? _minBedrooms;
  int? _maxBedrooms;
  int? _minBathrooms;
  int? _maxBathrooms;

  double? _minArea;
  double? _maxArea;
  final _minAreaCtrl = TextEditingController();
  final _maxAreaCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingFilter = false;

  @override
  void initState() {
    super.initState();
    _loadExistingFilter();
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _minAreaCtrl.dispose();
    _maxAreaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingFilter() async {
    // ── FIX: read userId from authNotifierProvider, not a TODO stub ──
    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) return;

    setState(() => _isLoadingFilter = true);
    try {
      final filter = await ref.read(
        notificationFilterProvider(
          FilterRequest(userId: userId, category: widget.category),
        ).future,
      );

      if (filter != null && mounted) {
        setState(() {
          _selectedTypes = filter.propertyTypes.toSet();
          _minPrice = filter.minPrice;
          _maxPrice = filter.maxPrice;
          _minBedrooms = filter.minBedrooms;
          _maxBedrooms = filter.maxBedrooms;
          _minBathrooms = filter.minBathrooms;
          _maxBathrooms = filter.maxBathrooms;
          _minArea = filter.minArea;
          _maxArea = filter.maxArea;

          if (_minPrice != null) _minPriceCtrl.text = _minPrice!.toStringAsFixed(0);
          if (_maxPrice != null) _maxPriceCtrl.text = _maxPrice!.toStringAsFixed(0);
          if (_minArea  != null) _minAreaCtrl.text  = _minArea!.toStringAsFixed(0);
          if (_maxArea  != null) _maxAreaCtrl.text  = _maxArea!.toStringAsFixed(0);
        });
      }
    } catch (_) {
      // Silently fall through — user starts with defaults
    } finally {
      if (mounted) setState(() => _isLoadingFilter = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        backgroundColor: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightAppBarBackground,
            darkColor: ThemeConfig.darkAppBarBackground),
        foregroundColor: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightAppBarForeground,
            darkColor: ThemeConfig.darkAppBarForeground),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: _isLoadingFilter
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                children: [
                  _buildInfoCard(isDark),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                  _buildPropertyTypesSection(isDark),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                  _buildPriceRangeSection(isDark),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                  _buildBedroomsSection(isDark),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                  _buildBathroomsSection(isDark),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                  _buildAreaSection(isDark),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
                  _buildActionButtons(),
                  SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                ],
              ),
            ),
    );
  }

  // ── INFO CARD ──────────────────────────────────────────────────────────────

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
        border: Border.all(
            color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded,
            color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Expanded(
          child: Text(
            widget.category == 'new_property'
                ? 'Only receive alerts for properties that match your criteria. Leave fields empty for no restriction.'
                : 'Get notified when prices change for properties matching your criteria.',
            style: TextStyle(
                color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                fontSize: 13),
          ),
        ),
      ]),
    );
  }

  // ── PROPERTY CATEGORIES ────────────────────────────────────────────────────

  Widget _buildPropertyTypesSection(bool isDark) {
    return _Section(
      title: 'Property Types',
      subtitle: 'Select which types you want alerts for',
      isDark: isDark,
      child: Column(
        children: PropertyType.values.map((type) {
          final isSelected = _selectedTypes.contains(type);
          return CheckboxListTile(
            title: Text(type.displayName),
            subtitle: Text(_typeDescription(type),
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 12)),
            value: isSelected,
            activeColor: ThemeConfig.getPrimaryColor(context),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedTypes.add(type);
                } else if (_selectedTypes.length > 1) {
                  _selectedTypes.remove(type);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('At least one type must be selected'),
                        duration: Duration(seconds: 2)),
                  );
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  // ── PRICE RANGE ────────────────────────────────────────────────────────────

  Widget _buildPriceRangeSection(bool isDark) {
    final currentCurrency = ref.watch(currencyProvider);
    final currencySymbol = CurrencyUtils.getSymbol(currentCurrency);

    return _Section(
      title: 'Price Range',
      subtitle: 'Leave empty for no price limit',
      isDark: isDark,
      badge: currentCurrency,
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _minPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Min Price',
                prefixText: '$currencySymbol ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _minPrice = double.tryParse(v)),
            ),
          ),
          SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
          Expanded(
            child: TextFormField(
              controller: _maxPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Max Price',
                prefixText: '$currencySymbol ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _maxPrice = double.tryParse(v)),
              validator: (v) {
                if (v != null && v.isNotEmpty && _minPrice != null) {
                  final max = double.tryParse(v);
                  if (max != null && max <= _minPrice!) {
                    return 'Must be greater than min';
                  }
                }
                return null;
              },
            ),
          ),
        ]),
        if (_minPrice != null || _maxPrice != null) ...[
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text(
            CurrencyUtils.formatPriceRange(_minPrice, _maxPrice, currentCurrency),
            style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.w500),
          ),
        ],
      ]),
    );
  }

  // ── BEDROOMS ───────────────────────────────────────────────────────────────

  Widget _buildBedroomsSection(bool isDark) {
    return _Section(
      title: 'Bedrooms',
      subtitle: 'Optional — select "Any" for no restriction',
      isDark: isDark,
      child: Row(children: [
        Expanded(child: _NumberDropdown(
          label: 'Min Bedrooms',
          value: _minBedrooms,
          onChanged: (v) => setState(() => _minBedrooms = v),
        )),
        SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
        Expanded(child: _NumberDropdown(
          label: 'Max Bedrooms',
          value: _maxBedrooms,
          onChanged: (v) => setState(() => _maxBedrooms = v),
          minValue: _minBedrooms,
        )),
      ]),
    );
  }

  // ── BATHROOMS ──────────────────────────────────────────────────────────────

  Widget _buildBathroomsSection(bool isDark) {
    return _Section(
      title: 'Bathrooms',
      subtitle: 'Optional — select "Any" for no restriction',
      isDark: isDark,
      child: Row(children: [
        Expanded(child: _NumberDropdown(
          label: 'Min Bathrooms',
          value: _minBathrooms,
          onChanged: (v) => setState(() => _minBathrooms = v),
        )),
        SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
        Expanded(child: _NumberDropdown(
          label: 'Max Bathrooms',
          value: _maxBathrooms,
          onChanged: (v) => setState(() => _maxBathrooms = v),
          minValue: _minBathrooms,
        )),
      ]),
    );
  }

  // ── AREA ───────────────────────────────────────────────────────────────────

  Widget _buildAreaSection(bool isDark) {
    return _Section(
      // ── FIX: the app uses sq m not sq ft (Tanzania market) ──
      title: 'Area (sq m)',
      subtitle: 'Property area in square metres (optional)',
      isDark: isDark,
      child: Row(children: [
        Expanded(
          child: TextFormField(
            controller: _minAreaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: const InputDecoration(
              labelText: 'Min Area',
              suffixText: 'sq m',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _minArea = double.tryParse(v)),
          ),
        ),
        SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
        Expanded(
          child: TextFormField(
            controller: _maxAreaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: const InputDecoration(
              labelText: 'Max Area',
              suffixText: 'sq m',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _maxArea = double.tryParse(v)),
            validator: (v) {
              if (v != null && v.isNotEmpty && _minArea != null) {
                final max = double.tryParse(v);
                if (max != null && max <= _minArea!) return 'Must be greater than min';
              }
              return null;
            },
          ),
        ),
      ]),
    );
  }

  // ── ACTION BUTTONS ─────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveFilter,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: ThemeConfig.getPrimaryColor(context),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _isLoading ? null : _resetToDefaults,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Reset to Defaults'),
        ),
      ),
    ]);
  }

  // ── SAVE ───────────────────────────────────────────────────────────────────

  Future<void> _saveFilter() async {
    if (!_formKey.currentState!.validate()) return;

    // ── FIX: use real auth provider ──
    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save preferences')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(notificationFilterServiceProvider);
      final filter = await service.upsertFilter(
        userId: userId,
        category: widget.category,
        propertyTypes: _selectedTypes.toList(),
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        minBedrooms: _minBedrooms,
        maxBedrooms: _maxBedrooms,
        minBathrooms: _minBathrooms,
        maxBathrooms: _maxBathrooms,
        minArea: _minArea,
        maxArea: _maxArea,
        isActive: true,
      );

      if (!mounted) return;
      if (filter != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Save returned null');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── RESET ──────────────────────────────────────────────────────────────────

  void _resetToDefaults() {
    setState(() {
      _selectedTypes = PropertyType.values.toSet();
      _minPrice = _maxPrice = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _minBedrooms = _maxBedrooms = null;
      _minBathrooms = _maxBathrooms = null;
      _minArea = _maxArea = null;
      _minAreaCtrl.clear();
      _maxAreaCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to defaults'), duration: Duration(seconds: 2)),
    );
  }

  // ── HELP DIALOG ────────────────────────────────────────────────────────────

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context))),
        title: Row(children: [
          Icon(Icons.help_outline_rounded, size: ResponsiveHelper.getResponsiveIconSize(context)),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          const Text('Filter Help'),
        ]),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpItem('Property Categories',
                  'Choose which property types to receive alerts for. At least one must be selected.'),
              _HelpItem('Price Range',
                  'Set a min/max price. Leave both empty to receive alerts for any price.'),
              _HelpItem('Bedrooms & Bathrooms',
                  'Filter by room count. "Any" means no restriction on that field.'),
              _HelpItem('Area (sq m)',
                  'Set min/max floor area in square metres. Leave empty for no restriction.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  String _typeDescription(PropertyType type) {
    switch (type) {
      case PropertyType.house:      return 'Standalone houses and villas';
      case PropertyType.apartment:  return 'Flats, studios and condos';
      case PropertyType.land:       return 'Plots, farms and bare land';
      case PropertyType.commercial: return 'Offices, shops and warehouses';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SECTION WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool isDark;
  final String? badge;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isDark,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title,
            style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 17), fontWeight: FontWeight.w700)),
        if (badge != null) ...[
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(badge!,
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
          ),
        ],
      ]),
      const SizedBox(height: 4),
      Text(subtitle,
          style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13), color: isDark ? Colors.white54 : Colors.black45)),
      const SizedBox(height: 14),
      child,
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NUMBER DROPDOWN  — FIX: DropdownButtonFormField has no 'initialValue' param;
//                         use 'value' instead (the correct API)
// ─────────────────────────────────────────────────────────────────────────────

class _NumberDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final int? minValue;       // When set, filters out options below this
  final ValueChanged<int?> onChanged;

  const _NumberDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    this.minValue,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem(value: null, child: Text('Any')),
      ...List.generate(10, (i) => i + 1)
          .where((n) => minValue == null || n >= minValue!)
          .map((n) => DropdownMenuItem(value: n, child: Text('$n'))),
    ];

    // Guard: if current value was filtered out (e.g. min increased past max), reset to null
    final effectiveValue = (value != null && items.any((item) => item.value == value))
        ? value
        : null;

    return DropdownButtonFormField<int?>(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      // ── FIX: use 'value' not 'initialValue' ——
      // 'initialValue' does not exist on DropdownButtonFormField
      initialValue: effectiveValue,
      items: items,
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELP ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _HelpItem extends StatelessWidget {
  final String title;
  final String description;
  const _HelpItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        Text(description,
            style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13), color: Colors.grey.shade600)),
      ]),
    );
  }
}