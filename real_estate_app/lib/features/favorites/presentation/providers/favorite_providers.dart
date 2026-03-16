import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart';
import '../../../../presentation/providers/auth_provider.dart';

import '../../../properties/domain/entities/property_entity.dart';
import '../../data/datasources/favorite_remote_datasource.dart';

import '../../data/repositories/favorite_repository_impl.dart';
import '../../domain/repositories/favorite_repository.dart';

// Favorite Data Source Provider
final favoriteRemoteDataSourceProvider = Provider<FavoriteRemoteDataSource>((ref) {
  return FavoriteRemoteDataSource(supabase);
});

// Favorite Repository Provider
final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepositoryImpl(ref.read(favoriteRemoteDataSourceProvider));
});

// Favorite Properties Provider
final favoritePropertiesProvider = FutureProvider<List<PropertyEntity>>((ref) async {
  final user = ref.watch(authNotifierProvider).value;
  
  if (user == null) return [];

  final repository = ref.read(favoriteRepositoryProvider);
  final result = await repository.getFavoriteProperties(user.id);

  return result.fold(
    (failure) => [],
    (properties) => properties,
  );
});

// Is Favorite Provider (for a specific property)
final isFavoriteProvider = FutureProvider.family<bool, String>((ref, propertyId) async {
  final user = ref.watch(authNotifierProvider).value;
  
  if (user == null) return false;

  final repository = ref.read(favoriteRepositoryProvider);
  final result = await repository.isFavorite(
    userId: user.id,
    propertyId: propertyId,
  );

  return result.fold(
    (failure) => false,
    (isFavorite) => isFavorite,
  );
});

// Favorite Actions Notifier
class FavoriteNotifier extends StateNotifier<AsyncValue<void>> {
  final FavoriteRepository _repository;

  FavoriteNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<bool> toggleFavorite({
    required String userId,
    required String propertyId,
    required bool currentStatus,
  }) async {
    state = const AsyncValue.loading();

    final result = currentStatus
        ? await _repository.removeFromFavorites(
            userId: userId,
            propertyId: propertyId,
          )
        : await _repository.addToFavorites(
            userId: userId,
            propertyId: propertyId,
          );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

// Favorite Notifier Provider
final favoriteNotifierProvider = StateNotifierProvider<FavoriteNotifier, AsyncValue<void>>((ref) {
  return FavoriteNotifier(ref.read(favoriteRepositoryProvider));
});
