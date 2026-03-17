// features/properties/presentation/providers/property_providers.dart
// COMPLETE FIXED VERSION - All errors resolved

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patamjengo_app/presentation/providers/auth_provider.dart';
import 'package:patamjengo_app/main.dart';

import '../../data/datasources/property_remote_datasource.dart';
import '../../data/repositories/property_repository_impl.dart';
import '../../domain/entities/property_entity.dart';
import '../../domain/entities/property_filter_entity.dart';
import '../../domain/repositories/property_repository.dart';
import '../../../../core/constants/app_constants.dart';

// Property Data Source Provider
final propertyRemoteDataSourceProvider = Provider<PropertyRemoteDataSource>((ref) {
  return PropertyRemoteDataSource(supabase);
});

// Property Repository Provider
final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  return PropertyRepositoryImpl(ref.read(propertyRemoteDataSourceProvider));
});

// ============================================================================
// PROPERTY LIST STATE AND NOTIFIER
// ============================================================================

class PropertyListState {
  final List<PropertyEntity> properties;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  PropertyListState({
    this.properties = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
  });

  PropertyListState copyWith({
    List<PropertyEntity>? properties,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return PropertyListState(
      properties: properties ?? this.properties,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PropertyListNotifier extends StateNotifier<PropertyListState> {
  final PropertyRepository _repository;
  PropertyFilterEntity? _currentFilter;
  bool _isLoadingMore = false;

  PropertyListNotifier(this._repository) : super(PropertyListState());

  List<PropertyEntity> _filterAvailableProperties(List<PropertyEntity> properties) {
    return properties.where((p) => 
      p.status == PropertyStatus.available || 
      p.status == PropertyStatus.pending
    ).toList();
  }

  /// Arranges properties into pages of 10 slots with a strict 6:3:1 tier ratio.
  ///
  /// Per every 10-slot page:
  ///   - Slots 1-6  → Pro  owners  (ownerTier == 'pro')
  ///   - Slots 7-9  → Basic owners (ownerTier == 'basic')
  ///   - Slot  10   → Free  owners (ownerTier == 'free')
  ///
  /// If a tier has fewer listings than its allocated slots, the remaining
  /// slots in that page are filled by the next available tier in priority
  /// order (pro → basic → free), so the page is always full when there is
  /// enough total supply. Excess listings from any tier spill into the next
  /// page and are re-arranged there with the same ratio.
  List<PropertyEntity> _arrangeTierSlots(List<PropertyEntity> properties) {
    if (properties.isEmpty) return properties;

    // Separate into tier buckets (preserving server-side order within each tier)
    final proList    = properties.where((p) => p.ownerTier == 'pro').toList();
    final basicList  = properties.where((p) => p.ownerTier == 'basic').toList();
    final freeList   = properties.where((p) => p.ownerTier == 'free').toList();

    // Cursors into each bucket
    int proIdx   = 0;
    int basicIdx = 0;
    int freeIdx  = 0;

    // Slots per page by tier:  pro=6, basic=3, free=1  (total=10)
    const int pageSize  = 10;
    const int proSlots  = 6;
    const int basicSlots = 3;
    const int freeSlots  = 1;

    final List<PropertyEntity> arranged = [];
    final int total = properties.length;

    while (arranged.length < total) {
      // How many slots remain to fill this page
      final remaining = total - arranged.length;
      final pageSlots = remaining < pageSize ? remaining : pageSize;

      // Ideal quota for this page (may exceed available supply)
      int proQuota   = proSlots   < pageSlots ? proSlots   : pageSlots;
      int basicQuota = basicSlots < pageSlots - proQuota
          ? basicSlots
          : (pageSlots - proQuota);
      int freeQuota  = pageSlots - proQuota - basicQuota;

      // --- fill pro slots ---
      int proFilled = 0;
      while (proFilled < proQuota && proIdx < proList.length) {
        arranged.add(proList[proIdx++]);
        proFilled++;
      }

      // --- fill basic slots ---
      int basicFilled = 0;
      while (basicFilled < basicQuota && basicIdx < basicList.length) {
        arranged.add(basicList[basicIdx++]);
        basicFilled++;
      }

      // --- fill free slots ---
      int freeFilled = 0;
      while (freeFilled < freeQuota && freeIdx < freeList.length) {
        arranged.add(freeList[freeIdx++]);
        freeFilled++;
      }

      // --- back-fill any unfilled slots (shortage in higher tiers) ---
      // Priority: pro remainder → basic remainder → free remainder
      final slotsFilled = proFilled + basicFilled + freeFilled;
      int backfillNeeded = pageSlots - slotsFilled;

      // 1. Back-fill with remaining pro
      while (backfillNeeded > 0 && proIdx < proList.length) {
        arranged.add(proList[proIdx++]);
        backfillNeeded--;
      }
      // 2. Back-fill with remaining basic
      while (backfillNeeded > 0 && basicIdx < basicList.length) {
        arranged.add(basicList[basicIdx++]);
        backfillNeeded--;
      }
      // 3. Back-fill with remaining free
      while (backfillNeeded > 0 && freeIdx < freeList.length) {
        arranged.add(freeList[freeIdx++]);
        backfillNeeded--;
      }

      // Safety: if all buckets are exhausted but we still have a partial page
      // (shouldn't happen, but prevents infinite loop)
      if (proIdx >= proList.length &&
          basicIdx >= basicList.length &&
          freeIdx >= freeList.length) {
        break;
      }
    }

    return arranged;
  }

  Future<void> loadProperties({PropertyFilterEntity? filter, bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, error: null);
    _currentFilter = filter;
    
    if (refresh) {
      _isLoadingMore = false;
    }

    final result = await _repository.getProperties(
      filter: filter ?? _currentFilter,
      page: refresh ? 1 : state.currentPage,
      limit: 20,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (properties) {
        final availableProperties = _filterAvailableProperties(properties);

        if (refresh) {
          final arranged = _arrangeTierSlots(availableProperties);
          state = state.copyWith(
            properties: arranged,
            isLoading: false,
            hasMore: availableProperties.length >= 20,
            currentPage: 1,
          );
        } else {
          // For pagination: re-arrange the full accumulated list so the ratio
          // holds across page boundaries, not just within a single fetched page.
          final combined = [...state.properties, ...availableProperties];
          final arranged = _arrangeTierSlots(combined);
          state = state.copyWith(
            properties: arranged,
            isLoading: false,
            hasMore: availableProperties.length >= 20,
            currentPage: state.currentPage,
          );
        }
        _isLoadingMore = false;
      },
    );
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || state.isLoading || !state.hasMore) {
      return;
    }

    _isLoadingMore = true;
    
    final nextPage = state.currentPage + 1;
    state = state.copyWith(currentPage: nextPage);

    final result = await _repository.getProperties(
      filter: _currentFilter,
      page: nextPage,
      limit: 20,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          error: failure.message,
        );
        _isLoadingMore = false;
      },
      (properties) {
        final availableProperties = _filterAvailableProperties(properties);
        final combined = [...state.properties, ...availableProperties];
        final arranged = _arrangeTierSlots(combined);

        state = state.copyWith(
          properties: arranged,
          hasMore: availableProperties.length >= 20,
        );
        _isLoadingMore = false;
      },
    );
  }

  void applyFilter(PropertyFilterEntity filter) {
    _currentFilter = filter;
    loadProperties(filter: filter, refresh: true);
  }

  void clearFilter() {
    _currentFilter = null;
    loadProperties(refresh: true);
  }

  void addProperty(PropertyEntity property) {
    if (property.status == PropertyStatus.available || 
        property.status == PropertyStatus.pending) {
      final updated = [property, ...state.properties];
      state = state.copyWith(
        properties: _arrangeTierSlots(updated),
      );
    }
  }

  void removeProperty(String propertyId) {
    final remaining = state.properties.where((p) => p.id != propertyId).toList();
    state = state.copyWith(
      properties: _arrangeTierSlots(remaining),
    );
  }

  void updatePropertyInList(PropertyEntity property) {
    final index = state.properties.indexWhere((p) => p.id == property.id);
    if (index != -1) {
      final updatedList = [...state.properties];
      if (property.status == PropertyStatus.sold || 
          property.status == PropertyStatus.rented) {
        updatedList.removeAt(index);
        state = state.copyWith(properties: _arrangeTierSlots(updatedList));
      } else {
        updatedList[index] = property;
        state = state.copyWith(properties: _arrangeTierSlots(updatedList));
      }
    }
  }
}

final propertyListProvider = StateNotifierProvider<PropertyListNotifier, PropertyListState>((ref) {
  return PropertyListNotifier(ref.read(propertyRepositoryProvider));
});

// ============================================================================
// PROPERTY DETAIL STATE AND NOTIFIER
// ============================================================================

class PropertyDetailState {
  final PropertyEntity? property;
  final bool isLoading;
  final String? error;

  PropertyDetailState({
    this.property,
    this.isLoading = false,
    this.error,
  });

  PropertyDetailState copyWith({
    PropertyEntity? property,
    bool? isLoading,
    String? error,
  }) {
    return PropertyDetailState(
      property: property ?? this.property,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PropertyDetailNotifier extends StateNotifier<PropertyDetailState> {
  final PropertyRepository _repository;

  PropertyDetailNotifier(this._repository) : super(PropertyDetailState());

  Future<void> loadProperty(String id) async {
    state = PropertyDetailState(isLoading: true);

    final result = await _repository.getPropertyById(id);

    result.fold(
      (failure) => state = PropertyDetailState(error: failure.message),
      (property) => state = PropertyDetailState(property: property),
    );
  }

  Future<bool> deleteProperty(String id) async {
    final result = await _repository.deleteProperty(id);
    return result.isRight();
  }
}

final propertyDetailProvider = StateNotifierProvider.family<PropertyDetailNotifier, PropertyDetailState, String>(
  (ref, propertyId) {
    final notifier = PropertyDetailNotifier(ref.read(propertyRepositoryProvider));
    notifier.loadProperty(propertyId);
    return notifier;
  },
);

// ============================================================================
// MY PROPERTIES STATE AND NOTIFIER
// ============================================================================

class MyPropertiesState {
  final List<PropertyEntity> properties;
  final bool isLoading;
  final String? error;

  MyPropertiesState({
    this.properties = const [],
    this.isLoading = false,
    this.error,
  });

  MyPropertiesState copyWith({
    List<PropertyEntity>? properties,
    bool? isLoading,
    String? error,
  }) {
    return MyPropertiesState(
      properties: properties ?? this.properties,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Add when method to match AsyncValue pattern
  T when<T>({
    required T Function(List<PropertyEntity> properties) data,
    required T Function() loading,
    required T Function(String error, StackTrace? stackTrace) error,
  }) {
    if (this.error != null && properties.isEmpty) {
      return error(this.error!, null);
    }
    
    if (isLoading && properties.isEmpty) {
      return loading();
    }
    
    return data(properties);
  }
}

class MyPropertiesNotifier extends StateNotifier<MyPropertiesState> {
  final PropertyRepository _repository;
  final String? _userId;

  MyPropertiesNotifier(this._repository, this._userId) : super(MyPropertiesState()) {
    if (_userId != null) {
      loadProperties();
    }
  }

  Future<void> loadProperties() async {
    if (_userId == null) {
      state = MyPropertiesState(properties: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getPropertiesByOwner(_userId!);
    
    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (properties) {
        final activeProperties = properties.where((p) => 
          p.status == PropertyStatus.available || 
          p.status == PropertyStatus.pending
        ).toList();
        
        state = MyPropertiesState(
          properties: activeProperties,
          isLoading: false,
        );
      },
    );
  }

  void addProperty(PropertyEntity property) {
    if (property.status == PropertyStatus.available || 
        property.status == PropertyStatus.pending) {
      state = state.copyWith(
        properties: [property, ...state.properties],
      );
    }
  }

  void removeProperty(String propertyId) {
    state = state.copyWith(
      properties: state.properties.where((p) => p.id != propertyId).toList(),
    );
  }

  void updateProperty(PropertyEntity property) {
    final index = state.properties.indexWhere((p) => p.id == property.id);
    if (index != -1) {
      final updatedList = [...state.properties];
      if (property.status == PropertyStatus.sold || 
          property.status == PropertyStatus.rented) {
        updatedList.removeAt(index);
      } else {
        updatedList[index] = property;
      }
      state = state.copyWith(properties: updatedList);
    }
  }
}

final myPropertiesProvider = StateNotifierProvider<MyPropertiesNotifier, MyPropertiesState>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  return MyPropertiesNotifier(
    ref.read(propertyRepositoryProvider),
    user?.id,
  );
});

// ============================================================================
// ARCHIVED PROPERTIES STATE AND NOTIFIER
// ============================================================================

class ArchivedPropertiesState {
  final List<PropertyEntity> properties;
  final bool isLoading;
  final String? error;

  ArchivedPropertiesState({
    this.properties = const [],
    this.isLoading = false,
    this.error,
  });

  ArchivedPropertiesState copyWith({
    List<PropertyEntity>? properties,
    bool? isLoading,
    String? error,
  }) {
    return ArchivedPropertiesState(
      properties: properties ?? this.properties,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Add when method to match AsyncValue pattern
  T when<T>({
    required T Function(List<PropertyEntity> properties) data,
    required T Function() loading,
    required T Function(String error, StackTrace? stackTrace) error,
  }) {
    if (this.error != null && properties.isEmpty) {
      return error(this.error!, null);
    }
    
    if (isLoading && properties.isEmpty) {
      return loading();
    }
    
    return data(properties);
  }
}

class ArchivedPropertiesNotifier extends StateNotifier<ArchivedPropertiesState> {
  final PropertyRepository _repository;
  final String? _userId;

  ArchivedPropertiesNotifier(this._repository, this._userId) : super(ArchivedPropertiesState()) {
    if (_userId != null) {
      loadProperties();
    }
  }

  Future<void> loadProperties() async {
    if (_userId == null) {
      state = ArchivedPropertiesState(properties: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getPropertiesByOwner(_userId!);
    
    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (properties) {
        final archivedProperties = properties.where((p) => 
          p.status == PropertyStatus.sold || 
          p.status == PropertyStatus.rented
        ).toList();
        
        state = ArchivedPropertiesState(
          properties: archivedProperties,
          isLoading: false,
        );
      },
    );
  }

  void addProperty(PropertyEntity property) {
    if (property.status == PropertyStatus.sold || 
        property.status == PropertyStatus.rented) {
      state = state.copyWith(
        properties: [property, ...state.properties],
      );
    }
  }

  void removeProperty(String propertyId) {
    state = state.copyWith(
      properties: state.properties.where((p) => p.id != propertyId).toList(),
    );
  }
}

final archivedPropertiesProvider = StateNotifierProvider<ArchivedPropertiesNotifier, ArchivedPropertiesState>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  return ArchivedPropertiesNotifier(
    ref.read(propertyRepositoryProvider),
    user?.id,
  );
});

// ============================================================================
// SEARCH PROVIDERS
// ============================================================================

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<PropertyEntity>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  
  if (query.isEmpty) return [];

  final repository = ref.read(propertyRepositoryProvider);
  final result = await repository.searchProperties(query);

  return result.fold(
    (failure) => [],
    (properties) {
      return properties.where((p) => 
        p.status == PropertyStatus.available || 
        p.status == PropertyStatus.pending
      ).toList();
    },
  );
});

// ============================================================================
// FILTER PROVIDERS
// ============================================================================

final propertyFilterProvider = StateProvider<PropertyFilterEntity?>((ref) => null);

final filteredSearchResultsProvider = FutureProvider<List<PropertyEntity>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(propertyFilterProvider);
  
  if (query.isEmpty && (filter == null || !filter.hasActiveFilters)) {
    return [];
  }

  final repository = ref.read(propertyRepositoryProvider);
  
  if (filter != null && filter.hasActiveFilters) {
    final result = await repository.getProperties(filter: filter);
    return result.fold(
      (failure) => [],
      (properties) {
        final availableProperties = properties.where((p) => 
          p.status == PropertyStatus.available || 
          p.status == PropertyStatus.pending
        ).toList();

        if (query.isNotEmpty) {
          return availableProperties.where((p) {
            final q = query.toLowerCase();
            return p.title.toLowerCase().contains(q) ||
                   p.description.toLowerCase().contains(q) ||
                   p.location.toLowerCase().contains(q);
          }).toList();
        }
        return availableProperties;
      },
    );
  } else {
    final result = await repository.searchProperties(query);
    return result.fold(
      (failure) => [],
      (properties) {
        return properties.where((p) => 
          p.status == PropertyStatus.available || 
          p.status == PropertyStatus.pending
        ).toList();
      },
    );
  }
});