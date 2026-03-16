// lib/core/services/notification_filter_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Property types for filtering
enum PropertyType {
  house,
  land,
  commercial,
  apartment;

  String get displayName {
    switch (this) {
      case PropertyType.house:
        return 'House';
      case PropertyType.land:
        return 'Land';
      case PropertyType.commercial:
        return 'Commercial';
      case PropertyType.apartment:
        return 'Apartment';
    }
  }
}

/// Notification filter model
class NotificationFilter {
  final String id;
  final String userId;
  final String notificationCategory; // 'new_property' or 'price_change'
  final List<PropertyType> propertyTypes;
  final double? minPrice;
  final double? maxPrice;
  final List<String>? regions;
  final List<String>? cities;
  final int? minBedrooms;
  final int? maxBedrooms;
  final int? minBathrooms;
  final int? maxBathrooms;
  final double? minArea;
  final double? maxArea;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationFilter({
    required this.id,
    required this.userId,
    required this.notificationCategory,
    required this.propertyTypes,
    this.minPrice,
    this.maxPrice,
    this.regions,
    this.cities,
    this.minBedrooms,
    this.maxBedrooms,
    this.minBathrooms,
    this.maxBathrooms,
    this.minArea,
    this.maxArea,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationFilter.fromJson(Map<String, dynamic> json) {
    return NotificationFilter(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      notificationCategory: json['notification_category'] as String,
      propertyTypes: _parsePropertyTypes(json['property_types']),
      minPrice: json['min_price'] != null ? (json['min_price'] as num).toDouble() : null,
      maxPrice: json['max_price'] != null ? (json['max_price'] as num).toDouble() : null,
      regions: json['regions'] != null ? List<String>.from(json['regions']) : null,
      cities: json['cities'] != null ? List<String>.from(json['cities']) : null,
      minBedrooms: json['min_bedrooms'] as int?,
      maxBedrooms: json['max_bedrooms'] as int?,
      minBathrooms: json['min_bathrooms'] as int?,
      maxBathrooms: json['max_bathrooms'] as int?,
      minArea: json['min_area'] != null ? (json['min_area'] as num).toDouble() : null,
      maxArea: json['max_area'] != null ? (json['max_area'] as num).toDouble() : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'notification_category': notificationCategory,
      'property_types': propertyTypes.map((e) => e.name).toList(),
      'min_price': minPrice,
      'max_price': maxPrice,
      'regions': regions,
      'cities': cities,
      'min_bedrooms': minBedrooms,
      'max_bedrooms': maxBedrooms,
      'min_bathrooms': minBathrooms,
      'max_bathrooms': maxBathrooms,
      'min_area': minArea,
      'max_area': maxArea,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static List<PropertyType> _parsePropertyTypes(dynamic types) {
    if (types == null) return PropertyType.values;
    
    final List<String> typeStrings = types is List 
        ? types.cast<String>() 
        : [types.toString()];
    
    return typeStrings.map((type) {
      switch (type.toLowerCase()) {
        case 'house':
          return PropertyType.house;
        case 'land':
          return PropertyType.land;
        case 'commercial':
          return PropertyType.commercial;
        case 'apartment':
          return PropertyType.apartment;
        default:
          return PropertyType.house;
      }
    }).toList();
  }

  NotificationFilter copyWith({
    String? id,
    String? userId,
    String? notificationCategory,
    List<PropertyType>? propertyTypes,
    double? minPrice,
    double? maxPrice,
    List<String>? regions,
    List<String>? cities,
    int? minBedrooms,
    int? maxBedrooms,
    int? minBathrooms,
    int? maxBathrooms,
    double? minArea,
    double? maxArea,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationFilter(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      notificationCategory: notificationCategory ?? this.notificationCategory,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      regions: regions ?? this.regions,
      cities: cities ?? this.cities,
      minBedrooms: minBedrooms ?? this.minBedrooms,
      maxBedrooms: maxBedrooms ?? this.maxBedrooms,
      minBathrooms: minBathrooms ?? this.minBathrooms,
      maxBathrooms: maxBathrooms ?? this.maxBathrooms,
      minArea: minArea ?? this.minArea,
      maxArea: maxArea ?? this.maxArea,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Service for managing notification filters
class NotificationFilterService {
  final SupabaseClient _supabase;

  NotificationFilterService(this._supabase);

  /// Get filter for a notification category
  Future<NotificationFilter?> getFilter({
    required String userId,
    required String category,
  }) async {
    try {
      final response = await _supabase
          .from('notification_property_filters')
          .select()
          .eq('user_id', userId)
          .eq('notification_category', category)
          .maybeSingle();

      if (response == null) return null;
      
      return NotificationFilter.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching notification filter: $e');
      return null;
    }
  }

  /// Get all filters for a user
  Future<List<NotificationFilter>> getAllFilters(String userId) async {
    try {
      final response = await _supabase
          .from('notification_property_filters')
          .select()
          .eq('user_id', userId);

      return (response as List)
          .map((json) => NotificationFilter.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notification filters: $e');
      return [];
    }
  }

  /// Create or update filter
  Future<NotificationFilter?> upsertFilter({
    required String userId,
    required String category,
    required List<PropertyType> propertyTypes,
    double? minPrice,
    double? maxPrice,
    List<String>? regions,
    List<String>? cities,
    int? minBedrooms,
    int? maxBedrooms,
    int? minBathrooms,
    int? maxBathrooms,
    double? minArea,
    double? maxArea,
    bool isActive = true,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'notification_category': category,
        'property_types': propertyTypes.map((e) => e.name).toList(),
        'min_price': minPrice,
        'max_price': maxPrice,
        'regions': regions,
        'cities': cities,
        'min_bedrooms': minBedrooms,
        'max_bedrooms': maxBedrooms,
        'min_bathrooms': minBathrooms,
        'max_bathrooms': maxBathrooms,
        'min_area': minArea,
        'max_area': maxArea,
        'is_active': isActive,
      };

      final response = await _supabase
          .from('notification_property_filters')
          .upsert(data)
          .select()
          .single();

      return NotificationFilter.fromJson(response);
    } catch (e) {
      debugPrint('Error upserting notification filter: $e');
      return null;
    }
  }

  /// Toggle filter active status
  Future<bool> toggleFilter({
    required String userId,
    required String category,
    required bool isActive,
  }) async {
    try {
      await _supabase
          .from('notification_property_filters')
          .update({'is_active': isActive})
          .eq('user_id', userId)
          .eq('notification_category', category);

      return true;
    } catch (e) {
      debugPrint('Error toggling filter: $e');
      return false;
    }
  }

  /// Delete filter
  Future<bool> deleteFilter({
    required String userId,
    required String category,
  }) async {
    try {
      await _supabase
          .from('notification_property_filters')
          .delete()
          .eq('user_id', userId)
          .eq('notification_category', category);

      return true;
    } catch (e) {
      debugPrint('Error deleting filter: $e');
      return false;
    }
  }

  /// Create default filter (all property types, no price limit)
  Future<NotificationFilter?> createDefaultFilter({
    required String userId,
    required String category,
  }) async {
    return await upsertFilter(
      userId: userId,
      category: category,
      propertyTypes: PropertyType.values,
      isActive: true,
    );
  }

  /// Stream filters for a user
  Stream<List<NotificationFilter>> filtersStream(String userId) {
    return _supabase
        .from('notification_property_filters')
        .stream(primaryKey: ['id'])
        .map((data) {
          return data
              .where((json) => json['user_id'] == userId)
              .map((json) => NotificationFilter.fromJson(json))
              .toList();
        });
  }
}
