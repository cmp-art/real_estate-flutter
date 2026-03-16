// features/properties/data/models/property_model.dart
// FIXED - Now properly reads and writes rent_duration

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/property_entity.dart';

class PropertyModel extends PropertyEntity {
  const PropertyModel({
    required super.id,
    required super.title,
    required super.description,
    required super.price,
    required super.type,
    required super.category,
    required super.location,
    super.latitude,
    super.longitude,
    required super.bedrooms,
    required super.bathrooms,
    required super.area,
    required super.images,
    super.videos = const [],
    required super.ownerId,
    required super.ownerName,
    super.ownerAvatar,
    super.ownerTier = 'free',
    required super.status,
    super.rentDuration,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      type: _propertyTypeFromString(json['type'] as String),
      category: _propertyCategoryFromString(json['category'] as String),
      location: json['location'] as String,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      bedrooms: json['bedrooms'] as int,
      bathrooms: json['bathrooms'] as int,
      area: (json['area'] as num).toDouble(),
      images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      videos: (json['videos'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String? ?? 'Unknown Owner',
      ownerAvatar: json['owner_avatar'] as String?,
      // Read the tier rank returned by get_property_tier_rank() and convert
      // back to a human-readable tier name for badge display on cards.
      ownerTier: _tierRankToName(json['owner_tier_rank'] as int?),
      status: _propertyStatusFromString(json['status'] as String),
      rentDuration: json['rent_duration'] != null
          ? _rentDurationFromString(json['rent_duration'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'type': _propertyTypeToString(type),
      'category': _propertyCategoryToString(category),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'area': area,
      'images': images,
      'videos': videos,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_avatar': ownerAvatar,
      'owner_tier': ownerTier,
      'status': _propertyStatusToString(status),
      'rent_duration': rentDuration != null
          ? _rentDurationToString(rentDuration!)
          : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PropertyModel.fromEntity(PropertyEntity entity) {
    return PropertyModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      price: entity.price,
      type: entity.type,
      category: entity.category,
      location: entity.location,
      latitude: entity.latitude,
      longitude: entity.longitude,
      bedrooms: entity.bedrooms,
      bathrooms: entity.bathrooms,
      area: entity.area,
      images: entity.images,
      videos: entity.videos,
      ownerId: entity.ownerId,
      ownerName: entity.ownerName,
      ownerAvatar: entity.ownerAvatar,
      ownerTier: entity.ownerTier,
      status: entity.status,
      rentDuration: entity.rentDuration,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert numeric rank from properties_with_tier view to tier name string.
  static String _tierRankToName(int? rank) {
    switch (rank) {
      case 1:  return 'pro';
      default: return 'free';
    }
  }

  static PropertyType _propertyTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'rent':
        return PropertyType.rent;
      case 'sale':
      default:
        return PropertyType.sale;
    }
  }

  static String _propertyTypeToString(PropertyType type) {
    switch (type) {
      case PropertyType.sale:
        return 'sale';
      case PropertyType.rent:
        return 'rent';
    }
  }

  static PropertyCategory _propertyCategoryFromString(String category) {
    switch (category.toLowerCase()) {
      case 'apartment':
        return PropertyCategory.apartment;
      case 'land':
        return PropertyCategory.land;
      case 'commercial':
        return PropertyCategory.commercial;
      case 'house':
      default:
        return PropertyCategory.house;
    }
  }

  static String _propertyCategoryToString(PropertyCategory category) {
    switch (category) {
      case PropertyCategory.house:
        return 'house';
      case PropertyCategory.apartment:
        return 'apartment';
      case PropertyCategory.land:
        return 'land';
      case PropertyCategory.commercial:
        return 'commercial';
    }
  }

  static PropertyStatus _propertyStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'sold':
        return PropertyStatus.sold;
      case 'rented':
        return PropertyStatus.rented;
      case 'pending':
        return PropertyStatus.pending;
      case 'available':
      default:
        return PropertyStatus.available;
    }
  }

  static String _propertyStatusToString(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.available:
        return 'available';
      case PropertyStatus.sold:
        return 'sold';
      case PropertyStatus.rented:
        return 'rented';
      case PropertyStatus.pending:
        return 'pending';
    }
  }

  // ADDED: Helper method to convert string to RentDuration
  static RentDuration? _rentDurationFromString(String duration) {
    switch (duration.toLowerCase()) {
      case 'monthly':
        return RentDuration.monthly;
      case 'yearly':
        return RentDuration.yearly;
      default:
        return null;
    }
  }

  // ADDED: Helper method to convert RentDuration to string
  static String _rentDurationToString(RentDuration duration) {
    switch (duration) {
      case RentDuration.monthly:
        return 'monthly';
      case RentDuration.yearly:
        return 'yearly';
    }
  }
}