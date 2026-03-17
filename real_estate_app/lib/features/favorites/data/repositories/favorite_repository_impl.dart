import 'package:dartz/dartz.dart';
import 'package:patamjengo_app/features/favorites/data/datasources/favorite_remote_datasource.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../properties/domain/entities/property_entity.dart';
import '../../domain/repositories/favorite_repository.dart';


class FavoriteRepositoryImpl implements FavoriteRepository {
  final FavoriteRemoteDataSource remoteDataSource;

  FavoriteRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<PropertyEntity>>> getFavoriteProperties(
    String userId,
  ) async {
    try {
      final properties = await remoteDataSource.getFavoriteProperties(userId);
      return Right(properties);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addToFavorites({
    required String userId,
    required String propertyId,
  }) async {
    try {
      await remoteDataSource.addToFavorites(
        userId: userId,
        propertyId: propertyId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeFromFavorites({
    required String userId,
    required String propertyId,
  }) async {
    try {
      await remoteDataSource.removeFromFavorites(
        userId: userId,
        propertyId: propertyId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isFavorite({
    required String userId,
    required String propertyId,
  }) async {
    try {
      final result = await remoteDataSource.isFavorite(
        userId: userId,
        propertyId: propertyId,
      );
      return Right(result);
    } catch (e) {
      return const Right(false);
    }
  }
}