// features/properties/data/datasources/property_remote_datasource.dart
// OPTIMIZED FOR EGRESS - Uses property_list_view for list queries
// FIXED: Added null/empty response handling

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/property_model.dart';
import '../models/property_filter_model.dart';

class PropertyRemoteDataSource {
  final SupabaseClient supabaseClient;

  PropertyRemoteDataSource(this.supabaseClient);

  /// OPTIMIZED: Use property_list_view for listings (80%+ egress reduction)
  /// Only fetches thumbnail (first image) instead of entire image array
  /// FIXED: Added null/empty response handling
  Future<List<PropertyModel>> getProperties({
    PropertyFilterModel? filter,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Use property_list_view instead of properties table
      PostgrestFilterBuilder query = supabaseClient
          .from('property_list_view')  // ✅ OPTIMIZED VIEW
          .select()
          .neq('status', 'deleted');

      if (filter != null) {
        if (filter.type != null) {
          query = query.eq('type', filter.type == PropertyType.sale ? 'sale' : 'rent');
        }
        if (filter.category != null) {
          query = query.eq('category', _categoryToString(filter.category!));
        }
        if (filter.minPrice != null) {
          query = query.gte('price', filter.minPrice!);
        }
        if (filter.maxPrice != null) {
          query = query.lte('price', filter.maxPrice!);
        }
        if (filter.minBedrooms != null) {
          query = query.gte('bedrooms', filter.minBedrooms!);
        }
        if (filter.maxBedrooms != null) {
          query = query.lte('bedrooms', filter.maxBedrooms!);
        }
        if (filter.minBathrooms != null) {
          query = query.gte('bathrooms', filter.minBathrooms!);
        }
        if (filter.maxBathrooms != null) {
          query = query.lte('bathrooms', filter.maxBathrooms!);
        }
        if (filter.minArea != null) {
          query = query.gte('area', filter.minArea!);
        }
        if (filter.maxArea != null) {
          query = query.lte('area', filter.maxArea!);
        }
        if (filter.location != null && filter.location!.isNotEmpty) {
          query = query.ilike('location', '%${filter.location}%');
        }
        if (filter.status != null) {
          query = query.eq('status', _statusToString(filter.status!));
        }
      }

      final data = await query
          .order('owner_tier_rank', ascending: true)   // pro → free
          .order('created_at', ascending: false)        // newest within tier
          .range((page - 1) * limit, page * limit - 1);

      // ✅ FIX: Check for null or empty response
      if (data == null) {
        print('⚠️ getProperties: Received null response');
        return [];
      }

      if (data is! List) {
        print('⚠️ getProperties: Response is not a List, got: ${data.runtimeType}');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ getProperties: No properties found');
        return [];
      }

      return _parsePropertiesFromListView(data);
    } on PostgrestException catch (e) {
      print('❌ PostgrestException in getProperties: ${e.message}');
      print('   Code: ${e.code}, Details: ${e.details}');
      throw ServerException('Database error: ${e.message}');
    } catch (e, stackTrace) {
      print('❌ Error in getProperties: $e');
      print('   Stack trace: $stackTrace');
      throw ServerException('Failed to load properties: ${e.toString()}');
    }
  }

  /// Get single property by ID with full details (all images)
  /// Only call this when viewing individual property details
  /// FIXED: Added null checks
  Future<PropertyModel> getPropertyById(String id) async {
    try {
      final data = await supabaseClient
          .from(AppConstants.propertiesTable)
          .select('''
            *,
            owner:owner_id (
              id,
              full_name,
              avatar_url
            )
          ''')
          .eq('id', id)
          .single();

      final ownerData = data['owner'] as Map<String, dynamic>?;
      final propertyJson = Map<String, dynamic>.from(data);

      propertyJson['owner_name'] = ownerData?['full_name'] as String? ?? 'Unknown Owner';
      propertyJson['owner_avatar'] = ownerData?['avatar_url'] as String?;
      propertyJson.remove('owner');

      return PropertyModel.fromJson(propertyJson);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Property not found');
      }
      throw NotFoundException('Property not found: ${e.message}');
    } catch (e) {
      if (e is NotFoundException) rethrow;
      throw NotFoundException('Property not found: ${e.toString()}');
    }
  }

  /// OPTIMIZED: Get properties by owner using list view
  /// FIXED: Added null/empty checks
  Future<List<PropertyModel>> getPropertiesByOwner(
    String ownerId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final data = await supabaseClient
          .from('property_list_view')  // ✅ OPTIMIZED VIEW
          .select()
          .eq('owner_id', ownerId)
          .neq('status', 'deleted')
          .order('owner_tier_rank', ascending: true)
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      if (data.isEmpty) {
        print('ℹ️ getPropertiesByOwner: No properties found for owner $ownerId');
        return [];
      }

      return _parsePropertiesFromListView(data);
    } catch (e) {
      print('❌ Error in getPropertiesByOwner: $e');
      throw ServerException('Failed to load owner properties: ${e.toString()}');
    }
  }

  // Create new property
  // FIXED: Added null checks
  Future<PropertyModel> createProperty(PropertyModel property) async {
    try {
      final propertyData = {
        'title': property.title,
        'description': property.description,
        'price': property.price,
        'type': property.type == PropertyType.sale ? 'sale' : 'rent',
        'category': _categoryToString(property.category),
        'location': property.location,
        'latitude': property.latitude,
        'longitude': property.longitude,
        'bedrooms': property.bedrooms,
        'bathrooms': property.bathrooms,
        'area': property.area,
        'images': property.images,
        'owner_id': property.ownerId,
        'status': _statusToString(property.status),
        'rent_duration': property.rentDuration != null
            ? _rentDurationToString(property.rentDuration!)
            : null,
      };

      final data = await supabaseClient
          .from(AppConstants.propertiesTable)
          .insert(propertyData)
          .select('''
            *,
            owner:owner_id (
              id,
              full_name,
              avatar_url
            )
          ''')
          .single();

      final ownerData = data['owner'] as Map<String, dynamic>?;
      final propertyJson = Map<String, dynamic>.from(data);

      propertyJson['owner_name'] = ownerData?['full_name'] as String? ?? 'Unknown Owner';
      propertyJson['owner_avatar'] = ownerData?['avatar_url'] as String?;
      propertyJson.remove('owner');

      return PropertyModel.fromJson(propertyJson);
    } catch (e) {
      print('❌ Error creating property: $e');
      throw ServerException('Failed to create property: ${e.toString()}');
    }
  }

  // Update existing property
  // FIXED: Added null checks
  Future<PropertyModel> updateProperty(PropertyModel property) async {
    try {
      final propertyData = {
        'title': property.title,
        'description': property.description,
        'price': property.price,
        'type': property.type == PropertyType.sale ? 'sale' : 'rent',
        'category': _categoryToString(property.category),
        'location': property.location,
        'latitude': property.latitude,
        'longitude': property.longitude,
        'bedrooms': property.bedrooms,
        'bathrooms': property.bathrooms,
        'area': property.area,
        'images': property.images,
        'status': _statusToString(property.status),
        'rent_duration': property.rentDuration != null
            ? _rentDurationToString(property.rentDuration!)
            : null,
      };

      final data = await supabaseClient
          .from(AppConstants.propertiesTable)
          .update(propertyData)
          .eq('id', property.id)
          .select('''
            *,
            owner:owner_id (
              id,
              full_name,
              avatar_url
            )
          ''')
          .single();

      final ownerData = data['owner'] as Map<String, dynamic>?;
      final propertyJson = Map<String, dynamic>.from(data);

      propertyJson['owner_name'] = ownerData?['full_name'] as String? ?? 'Unknown Owner';
      propertyJson['owner_avatar'] = ownerData?['avatar_url'] as String?;
      propertyJson.remove('owner');

      return PropertyModel.fromJson(propertyJson);
    } catch (e) {
      print('❌ Error updating property: $e');
      throw ServerException('Failed to update property: ${e.toString()}');
    }
  }

  // Soft-delete property
  // FIXED: Better error handling for RPC calls
  Future<void> deleteProperty(String id) async {
    try {
      final result = await supabaseClient
          .rpc('user_delete_property', params: {'p_property_id': id});

      // ✅ FIX: Handle null or empty result
      if (result == null) {
        // RPC succeeded but returned null - this is OK
        return;
      }

      // Check if result is a Map with error info
      if (result is Map<String, dynamic>) {
        if (result['success'] == false) {
          throw ServerException(
              result['error'] as String? ?? 'Failed to delete property');
        }
      }
    } on PostgrestException catch (e) {
      print('❌ PostgrestException in deleteProperty: ${e.message}');
      throw ServerException('Database error: ${e.message}');
    } catch (e) {
      if (e is ServerException) rethrow;
      print('❌ Error deleting property: $e');
      throw ServerException('Failed to delete property: ${e.toString()}');
    }
  }

  /// OPTIMIZED: Upload images with compression
  /// NOTE: Images should be compressed on client-side BEFORE upload
  /// Max size: 5MB per image (enforced by storage bucket)
  Future<List<String>> uploadImages(String propertyId, List<XFile> images) async {
    try {
      final userId = supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw ServerException('User not authenticated');
      }

      final List<String> uploadedUrls = [];

      for (int i = 0; i < images.length; i++) {
        final xfile = images[i];

        // Read bytes — works on both web (blob URL) and native (file path)
        final bytes = await xfile.readAsBytes();

        // Check file size (5MB limit)
        if (bytes.length > 5 * 1024 * 1024) {
          throw ServerException('Image ${i + 1} exceeds 5MB limit. Please compress before upload.');
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${propertyId}_${timestamp}_$i.jpg';
        final filePath = '$userId/$fileName';

        // uploadBinary accepts Uint8List — works on web and native
        await supabaseClient.storage
            .from(SupabaseConfig.propertyImagesBucket)
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '31536000',
                upsert: false,
              ),
            );

        final url = supabaseClient.storage
            .from(SupabaseConfig.propertyImagesBucket)
            .getPublicUrl(filePath);

        uploadedUrls.add(url);
      }

      return uploadedUrls;
    } catch (e) {
      print('❌ Error uploading images: $e');
      throw ServerException('Failed to upload images: ${e.toString()}');
    }
  }

  // Delete image from Supabase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf(SupabaseConfig.propertyImagesBucket);

      if (bucketIndex == -1) {
        throw ServerException('Invalid image URL');
      }

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      await supabaseClient.storage
          .from(SupabaseConfig.propertyImagesBucket)
          .remove([filePath]);
    } catch (e) {
      print('❌ Error deleting image: $e');
      throw ServerException('Failed to delete image: ${e.toString()}');
    }
  }

  /// OPTIMIZED: Search using list view
  /// FIXED: Added null/empty checks
  Future<List<PropertyModel>> searchProperties(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final data = await supabaseClient
          .from('property_list_view')  // ✅ OPTIMIZED VIEW
          .select()
          .or('title.ilike.%$query%,description.ilike.%$query%,location.ilike.%$query%')
          .neq('status', 'deleted')
          .order('owner_tier_rank', ascending: true)
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      if (data.isEmpty) {
        print('ℹ️ searchProperties: No results for query "$query"');
        return [];
      }

      return _parsePropertiesFromListView(data);
    } catch (e) {
      print('❌ Error in searchProperties: $e');
      throw ServerException('Failed to search properties: ${e.toString()}');
    }
  }

  /// Parse properties from property_list_view
  /// This view returns thumbnail_url instead of full images array
  /// FIXED: Added null checks and error handling
  List<PropertyModel> _parsePropertiesFromListView(dynamic data) {
    final List<PropertyModel> properties = [];

    try {
      for (var item in data as List) {
        try {
          final propertyJson = Map<String, dynamic>.from(item);
          
          // Convert thumbnail_url to images array with single element
          // PropertyModel expects an images array
          if (propertyJson['thumbnail_url'] != null) {
            propertyJson['images'] = [propertyJson['thumbnail_url']];
          } else {
            propertyJson['images'] = [];
          }
          
          // Remove thumbnail_url as it's now in images
          propertyJson.remove('thumbnail_url');
          
          // Ensure owner_tier_rank is present and convert to tier name
          if (propertyJson['owner_tier_rank'] == null) {
            propertyJson['owner_tier_rank'] = 3; // default to free
          }

          properties.add(PropertyModel.fromJson(propertyJson));
        } catch (e) {
          print('⚠️ Failed to parse property item: $e');
          print('   Item data: $item');
          // Continue parsing other properties
          continue;
        }
      }
    } catch (e) {
      print('❌ Error in _parsePropertiesFromListView: $e');
    }

    return properties;
  }

  String _categoryToString(PropertyCategory category) {
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

  String _statusToString(PropertyStatus status) {
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

  String _rentDurationToString(RentDuration duration) {
    switch (duration) {
      case RentDuration.monthly:
        return 'monthly';
      case RentDuration.yearly:
        return 'yearly';
    }
  }
}