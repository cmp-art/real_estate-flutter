import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../properties/domain/entities/property_entity.dart';

abstract class FavoriteRepository {
  // Get all favorite properties for a user
  Future<Either<Failure, List<PropertyEntity>>> getFavoriteProperties(
    String userId,
  );

  // Add property to favorites
  Future<Either<Failure, void>> addToFavorites({
    required String userId,
    required String propertyId,
  });

  // Remove property from favorites
  Future<Either<Failure, void>> removeFromFavorites({
    required String userId,
    required String propertyId,
  });

  // Check if property is favorited
  Future<Either<Failure, bool>> isFavorite({
    required String userId,
    required String propertyId,
  });
}