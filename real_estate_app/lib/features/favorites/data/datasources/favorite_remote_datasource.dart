import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../properties/data/models/property_model.dart';


class FavoriteRemoteDataSource {
  final SupabaseClient supabaseClient;

  FavoriteRemoteDataSource(this.supabaseClient);

  // Get all favorite properties for a user
  Future<List<PropertyModel>> getFavoriteProperties(String userId) async {
    try {
      final data = await supabaseClient
          .from(AppConstants.favoritesTable)
          .select('property_id, ${AppConstants.propertiesTable}(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<PropertyModel> properties = [];
      for (var item in data) {
        if (item['properties'] != null) {
          properties.add(PropertyModel.fromJson(item['properties']));
        }
      }

      return properties;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // Add property to favorites
  Future<void> addToFavorites({
    required String userId,
    required String propertyId,
  }) async {
    try {
      await supabaseClient.from(AppConstants.favoritesTable).insert({
        'user_id': userId,
        'property_id': propertyId,
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // Remove property from favorites
  Future<void> removeFromFavorites({
    required String userId,
    required String propertyId,
  }) async {
    try {
      await supabaseClient
          .from(AppConstants.favoritesTable)
          .delete()
          .eq('user_id', userId)
          .eq('property_id', propertyId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // Check if property is favorited
  Future<bool> isFavorite({
    required String userId,
    required String propertyId,
  }) async {
    try {
      final data = await supabaseClient
          .from(AppConstants.favoritesTable)
          .select('id')
          .eq('user_id', userId)
          .eq('property_id', propertyId)
          .maybeSingle();

      return data != null;
    } catch (e) {
      return false;
    }
  }
}