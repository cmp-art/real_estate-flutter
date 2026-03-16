// features/properties/domain/entities/property_entity.dart
// COMPLETE UPDATED VERSION - All issues resolved

import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class PropertyEntity extends Equatable {
  final String id;
  final String title;
  final String description;
  final double price;
  final PropertyType type;
  final PropertyCategory category;
  final String location;
  final double? latitude;
  final double? longitude;
  final int bedrooms;
  final int bathrooms;
  final double area;
  final List<String> images;
  final List<String> videos;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatar;
  /// Subscription tier of the property owner: 'pro', 'basic', or 'free'.
  /// Populated from get_property_tier_rank() SQL function via the datasource.
  /// Used to display tier badges on property cards.
  final String ownerTier;
  final PropertyStatus status;
  final RentDuration? rentDuration;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PropertyEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.type,
    required this.category,
    required this.location,
    this.latitude,
    this.longitude,
    required this.bedrooms,
    required this.bathrooms,
    required this.area,
    required this.images,
    this.videos = const [],
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatar,
    this.ownerTier = 'free',
    required this.status,
    this.rentDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper method to get rent duration display text
  String get rentDurationDisplayText {
    if (type != PropertyType.rent || rentDuration == null) {
      return '';
    }
    
    return rentDuration!.displayName;
  }

  // Helper method to get price suffix (e.g., "/month", "/year")
  String get priceSuffix {
    if (type != PropertyType.rent || rentDuration == null) {
      return '';
    }
    
    switch (rentDuration!) {
      case RentDuration.monthly:
        return '/month';
      case RentDuration.yearly:
        return '/year';
    }
  }

  // Helper method to get full price display with suffix
  String get priceWithSuffix {
    if (type != PropertyType.rent || rentDuration == null) {
      return '\$${price.toStringAsFixed(0)}';
    }
    
    return '\$${price.toStringAsFixed(0)}$priceSuffix';
  }

  // Method to get rent duration text for display
  String getRentDurationText({bool includePrefix = false}) {
    if (type != PropertyType.rent || rentDuration == null) {
      return '';
    }
    
    final durationText = rentDuration!.displayName;
    return includePrefix ? '$durationText Rent' : durationText;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        price,
        type,
        category,
        location,
        latitude,
        longitude,
        bedrooms,
        bathrooms,
        area,
        images,
        videos,
        ownerId,
        ownerName,
        ownerAvatar,
        ownerTier,
        status,
        rentDuration,
        createdAt,
        updatedAt,
      ];

  PropertyEntity copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    PropertyType? type,
    PropertyCategory? category,
    String? location,
    double? latitude,
    double? longitude,
    int? bedrooms,
    int? bathrooms,
    double? area,
    List<String>? images,
    List<String>? videos,
    String? ownerId,
    String? ownerName,
    String? ownerAvatar,
    String? ownerTier,
    PropertyStatus? status,
    RentDuration? rentDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PropertyEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      type: type ?? this.type,
      category: category ?? this.category,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      area: area ?? this.area,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerAvatar: ownerAvatar ?? this.ownerAvatar,
      ownerTier: ownerTier ?? this.ownerTier,
      status: status ?? this.status,
      rentDuration: rentDuration ?? this.rentDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'type': type.name,
      'category': category.name,
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
      'status': status.name,
      'rent_duration': rentDuration?.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory PropertyEntity.fromJson(Map<String, dynamic> json) {
    return PropertyEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      type: _parsePropertyType(json['type']),
      category: _parsePropertyCategory(json['category']),
      location: json['location'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      bedrooms: json['bedrooms'] as int? ?? 0,
      bathrooms: json['bathrooms'] as int? ?? 0,
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videos: (json['videos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      ownerId: json['owner_id'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
      ownerAvatar: json['owner_avatar'] as String?,
      ownerTier: json['owner_tier'] as String? ?? 'free',
      status: _parsePropertyStatus(json['status']),
      rentDuration: _parseRentDuration(json['rent_duration']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  // Helper method to parse PropertyType
  static PropertyType _parsePropertyType(dynamic value) {
    if (value == null) return PropertyType.sale;
    
    final typeString = value.toString().toLowerCase();
    return PropertyType.values.firstWhere(
      (e) => e.name.toLowerCase() == typeString,
      orElse: () => PropertyType.sale,
    );
  }

  // Helper method to parse PropertyCategory
  static PropertyCategory _parsePropertyCategory(dynamic value) {
    if (value == null) return PropertyCategory.house;
    
    final categoryString = value.toString().toLowerCase();
    return PropertyCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == categoryString,
      orElse: () => PropertyCategory.house,
    );
  }

  // Helper method to parse PropertyStatus
  static PropertyStatus _parsePropertyStatus(dynamic value) {
    if (value == null) return PropertyStatus.available;
    
    final statusString = value.toString().toLowerCase();
    return PropertyStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == statusString,
      orElse: () => PropertyStatus.available,
    );
  }

  // Helper method to parse RentDuration
  static RentDuration? _parseRentDuration(dynamic value) {
    if (value == null) return null;
    
    final durationString = value.toString().toLowerCase();
    try {
      return RentDuration.values.firstWhere(
        (e) => e.name.toLowerCase() == durationString,
      );
    } catch (e) {
      return null;
    }
  }

  // Helper method to parse DateTime
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    
    if (value is DateTime) return value;
    
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  @override
  String toString() {
    return 'PropertyEntity(id: $id, title: $title, price: $price, type: ${type.displayName}, category: ${category.displayName}, status: ${status.displayName})';
  }
}