// features/properties/presentation/screens/property_search_screen.dart
// FIXED VERSION with proper theme-based text colors using textPrimary/Secondary colors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';

import "../widgets/property_list_card.dart";
import '../widgets/property_grid_card.dart';
import '../providers/property_providers.dart';
import '../../domain/entities/property_filter_entity.dart';
import '../../domain/entities/property_entity.dart';
import 'property_detail_screen.dart';
import 'property_filter_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class PropertySearchScreen extends ConsumerStatefulWidget {
  const PropertySearchScreen({super.key});

  @override
  ConsumerState<PropertySearchScreen> createState() => _PropertySearchScreenState();
}

class _PropertySearchScreenState extends ConsumerState<PropertySearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  PropertyFilterEntity? _activeFilter;
  Timer? _debounce;

  // Location autocomplete state
  String _typedText = '';
  bool _suppressSuggestions = false;

  @override
  void initState() {
    super.initState();
    // Rebuild so the suggestions panel follows the search field's focus.
    _focusNode.addListener(_onFocusChanged);
    // Auto-focus keyboard when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    setState(() => _suppressSuggestions = true);
    if (query.isNotEmpty) {
      ref.read(searchQueryProvider.notifier).state = query;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _typedText = query.trim();
      // A fresh keystroke re-enables suggestions after a prior selection/submit.
      _suppressSuggestions = false;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = query.trim();
    });
  }

  /// Top location matches for [text]; "starts-with" ranked above "contains".
  List<String> _matchLocations(String text, List<String> locations) {
    if (text.isEmpty) return const [];
    final q = text.toLowerCase();
    final starts = <String>[];
    final contains = <String>[];
    for (final loc in locations) {
      final l = loc.toLowerCase();
      if (l == q) continue; // already exactly in the field — nothing to add
      if (l.startsWith(q)) {
        starts.add(loc);
      } else if (l.contains(q)) {
        contains.add(loc);
      }
    }
    return [...starts, ...contains].take(6).toList();
  }

  void _selectSuggestion(String location) {
    _debounce?.cancel();
    _searchController.text = location;
    _searchController.selection =
        TextSelection.collapsed(offset: location.length);
    setState(() {
      _typedText = location;
      _suppressSuggestions = true;
    });
    ref.read(searchQueryProvider.notifier).state = location;
    _focusNode.unfocus();
  }

  Future<void> _openFilterScreen() async {
    final result = await Navigator.push<PropertyFilterEntity>(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyFilterScreen(
          initialFilter: _activeFilter,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _activeFilter = result;
      });
      
      ref.read(propertyFilterProvider.notifier).state = result;
    }
  }

  void _clearFilters() {
    setState(() {
      _activeFilter = null;
    });
    ref.read(propertyFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final activeFilter = ref.watch(propertyFilterProvider);
    final searchResults = ref.watch(filteredSearchResultsProvider);
    final theme = Theme.of(context);
    
    // Get theme-based colors
    final textPrimaryColor = ThemeConfig.getTextPrimaryColor(context);
    final textSecondaryColor = ThemeConfig.getTextSecondaryColor(context);
    final primaryColor = ThemeConfig.getPrimaryColor(context);
    
    // AppBar foreground color for icons
    final appBarForegroundColor = theme.appBarTheme.foregroundColor ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    // Location autocomplete: match the typed text against the cached set of
    // distinct listing locations. Shown only while the field is focused.
    final allLocations =
        ref.watch(propertyLocationsProvider).value ?? const <String>[];
    final suggestions = _matchLocations(_typedText, allLocations);
    final showSuggestions =
        _focusNode.hasFocus && !_suppressSuggestions && suggestions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: TextStyle(
            color: textPrimaryColor, // Using textPrimaryColor for better visibility
          ),
          decoration: InputDecoration(
            hintText: 'Search properties...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: textSecondaryColor, // Using textSecondaryColor for hint
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear, 
                      color: textSecondaryColor, // Using textSecondaryColor for icon
                    ),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                      setState(() {
                        _typedText = '';
                        _suppressSuggestions = true;
                      });
                      _focusNode.requestFocus();
                    },
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          onSubmitted: (value) {
            _performSearch();
          },
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: appBarForegroundColor, // Keep appBarForegroundColor for consistency with other icons
                ),
                onPressed: _openFilterScreen,
              ),
              if (activeFilter != null && activeFilter.hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ThemeConfig.errorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
        children: [
          // Active Filters Display
          if (activeFilter != null && activeFilter.hasActiveFilters)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              color: primaryColor.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.filter_alt,
                        size: 16,
                        color: primaryColor,
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      Text(
                        'Active Filters:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: Icon(Icons.clear, size: ResponsiveHelper.getResponsiveIconSize(context)),
                        label: const Text('Clear All'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildFilterChips(activeFilter),
                  ),
                ],
              ),
            ),

          // Search Results
          Expanded(
            child: searchQuery.isEmpty && (activeFilter == null || !activeFilter.hasActiveFilters)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 80,
                          color: textSecondaryColor.withOpacity(0.5),
                        ),
                        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                        Text(
                          'Search for properties',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                            color: textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveHorizontalPadding(context)),
                          child: Text(
                            'Type to search or use filters',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                              color: textSecondaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : searchResults.when(
                    data: (properties) {
                      if (properties.isEmpty) {
                        return EmptyState(
                          icon: Icons.search_off,
                          title: 'No Properties Found',
                          message: 'Try adjusting your search or filters.',
                          actionText: 'Clear Search',
                          onActionPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                            _clearFilters();
                            _focusNode.requestFocus();
                          },
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                            child: Text(
                              '${properties.length} ${properties.length == 1 ? 'property' : 'properties'} found',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                                color: textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildResultsList(context, properties),
                          ),
                        ],
                      );
                    },
                    loading: () => const LoadingIndicator(message: 'Searching properties...'),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.red),
                          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                          Text(
                            'Error searching properties',
                            style: TextStyle(
                              color: textPrimaryColor,
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                              color: textSecondaryColor,
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(filteredSearchResultsProvider);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
          ),
          if (showSuggestions)
            _buildSuggestionsOverlay(context, suggestions, textPrimaryColor,
                textSecondaryColor, primaryColor),
        ],
      ),
    );
  }

  void _navigateToDetail(PropertyEntity property) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailScreen(propertyId: property.id),
      ),
    );
  }

  /// Dropdown of matching listing locations, shown over the top of the body
  /// while the user is typing. Tapping a row fills the search field and runs
  /// the search for that location.
  Widget _buildSuggestionsOverlay(
    BuildContext context,
    List<String> suggestions,
    Color textPrimary,
    Color textSecondary,
    Color primary,
  ) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        color: Theme.of(context).cardColor,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: textSecondary.withOpacity(0.15)),
            itemBuilder: (context, index) {
              final location = suggestions[index];
              return ListTile(
                dense: true,
                leading: Icon(Icons.location_on_outlined, color: primary),
                title: Text(
                  location,
                  style: TextStyle(color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                    Icon(Icons.north_west, size: 16, color: textSecondary),
                onTap: () => _selectSuggestion(location),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, List<PropertyEntity> properties) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final hPad = ResponsiveHelper.getContentHorizontalPadding(context);

    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PropertyListCard(
              property: property,
              onShare: () {},
              onTap: () => _navigateToDetail(property),
            ),
          );
        },
      );
    }

    // Tablet / Desktop: grid of PropertyGridCard
    final cols = ResponsiveHelper.getPropertyGridColumns(context);
    const spacing = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - hPad * 2 - spacing * (cols - 1)) / cols;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: properties.map((property) {
              return SizedBox(
                width: cardWidth,
                child: PropertyGridCard(
                  property: property,
                  onTap: () => _navigateToDetail(property),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  List<Widget> _buildFilterChips(PropertyFilterEntity filter) {
    final List<Widget> chips = [];

    if (filter.type != null) {
      chips.add(_FilterChip(label: filter.type!.displayName));
    }
    if (filter.category != null) {
      chips.add(_FilterChip(label: filter.category!.displayName));
    }
    if (filter.status != null) {
      chips.add(_FilterChip(label: filter.status!.displayName));
    }
    if (filter.minPrice != null || filter.maxPrice != null) {
      final priceText = filter.minPrice != null && filter.maxPrice != null
          ? '\$${filter.minPrice!.toInt()} - \$${filter.maxPrice!.toInt()}'
          : filter.minPrice != null
              ? 'From \$${filter.minPrice!.toInt()}'
              : 'Up to \$${filter.maxPrice!.toInt()}';
      chips.add(_FilterChip(label: priceText));
    }
    if (filter.minBedrooms != null || filter.maxBedrooms != null) {
      final bedroomText = filter.minBedrooms != null && filter.maxBedrooms != null
          ? '${filter.minBedrooms}-${filter.maxBedrooms} beds'
          : filter.minBedrooms != null
              ? '${filter.minBedrooms}+ beds'
              : 'Up to ${filter.maxBedrooms} beds';
      chips.add(_FilterChip(label: bedroomText));
    }
    if (filter.location != null && filter.location!.isNotEmpty) {
      chips.add(_FilterChip(label: filter.location!));
    }

    return chips;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;

  const _FilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: ThemeConfig.getPrimaryColor(context).withOpacity(0.1),
      side: BorderSide(color: ThemeConfig.getPrimaryColor(context)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}