import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/failures.dart';
import '../entities/property_entity.dart';
import '../entities/property_filter_entity.dart';

abstract class PropertyRepository {
  // Get all properties with optional filters
  Future<Either<Failure, List<PropertyEntity>>> getProperties({
    PropertyFilterEntity? filter,
    int page = 1,
    int limit = 20,
  });

  // Get single property by ID
  Future<Either<Failure, PropertyEntity>> getPropertyById(String id);

  // Get properties by owner
  Future<Either<Failure, List<PropertyEntity>>> getPropertiesByOwner(
    String ownerId, {
    int page = 1,
    int limit = 20,
  });

  // Create new property
  Future<Either<Failure, PropertyEntity>> createProperty(
    PropertyEntity property,
  );

  // Update existing property
  Future<Either<Failure, PropertyEntity>> updateProperty(
    PropertyEntity property,
  );

  // Delete property
  Future<Either<Failure, void>> deleteProperty(String id);

  // Upload property images
  Future<Either<Failure, List<String>>> uploadImages(
    String propertyId,
    List<XFile> images,
  );

  // Delete property image
  Future<Either<Failure, void>> deleteImage(String imageUrl);

  // Search properties
  Future<Either<Failure, List<PropertyEntity>>> searchProperties(
    String query, {
    int page = 1,
    int limit = 20,
  });

  // Distinct listing locations (powers the search-bar location autocomplete)
  Future<Either<Failure, List<String>>> getPropertyLocations();
}