import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/property_entity.dart';
import '../../domain/entities/property_filter_entity.dart';
import '../../domain/repositories/property_repository.dart';
import '../datasources/property_remote_datasource.dart';
import '../models/property_model.dart';
import '../models/property_filter_model.dart';

class PropertyRepositoryImpl implements PropertyRepository {
  final PropertyRemoteDataSource remoteDataSource;

  PropertyRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<PropertyEntity>>> getProperties({
    PropertyFilterEntity? filter,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final filterModel = filter != null
          ? PropertyFilterModel.fromEntity(filter)
          : null;

      final properties = await remoteDataSource.getProperties(
        filter: filterModel,
        page: page,
        limit: limit,
      );
      return Right(properties);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PropertyEntity>> getPropertyById(String id) async {
    try {
      final property = await remoteDataSource.getPropertyById(id);
      return Right(property);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PropertyEntity>>> getPropertiesByOwner(
    String ownerId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final properties = await remoteDataSource.getPropertiesByOwner(
        ownerId,
        page: page,
        limit: limit,
      );
      return Right(properties);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PropertyEntity>> createProperty(
    PropertyEntity property,
  ) async {
    try {
      final propertyModel = PropertyModel.fromEntity(property);
      final createdProperty = await remoteDataSource.createProperty(propertyModel);
      return Right(createdProperty);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PropertyEntity>> updateProperty(
    PropertyEntity property,
  ) async {
    try {
      final propertyModel = PropertyModel.fromEntity(property);
      final updatedProperty = await remoteDataSource.updateProperty(propertyModel);
      return Right(updatedProperty);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProperty(String id) async {
    try {
      await remoteDataSource.deleteProperty(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> uploadImages(
    String propertyId,
    List<XFile> images,
  ) async {
    try {
      final urls = await remoteDataSource.uploadImages(propertyId, images);
      return Right(urls);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteImage(String imageUrl) async {
    try {
      await remoteDataSource.deleteImage(imageUrl);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PropertyEntity>>> searchProperties(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final properties = await remoteDataSource.searchProperties(
        query,
        page: page,
        limit: limit,
      );
      return Right(properties);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getPropertyLocations() async {
    try {
      final locations = await remoteDataSource.getPropertyLocations();
      return Right(locations);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}