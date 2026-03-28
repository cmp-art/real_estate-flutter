import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../properties/data/models/property_model.dart';


class FavoriteRemoteDataSource {
  final SupabaseClient supabaseClient;

  FavoriteRemoteDataSource(this.supabaseClient);

  // Get all favorite properties for a user.
  // Two-step query: fetch ordered IDs from favorites, then load slim rows
  // from property_list_view (80%+ less egress than full properties table).
  Future<List<PropertyModel>> getFavoriteProperties(String userId) async {
    try {
      // Step 1 — ordered favorite IDs (tiny payload: UUID + timestamp only).
      final favRows = await supabaseClient
          .from(AppConstants.favoritesTable)
          .select('property_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (favRows.isEmpty) return [];

      final ids = favRows
          .map((r) => r['property_id'] as String)
          .toList();

      // Step 2 — slim property data from the optimised view.
      final propRows = await supabaseClient
          .from('property_list_view')
          .select()
          .inFilter('id', ids);

      // Restore favorites order (view returns rows in arbitrary order).
      final byId = {
        for (final row in propRows) row['id'] as String: row,
      };

      return ids
          .where(byId.containsKey)
          .map((id) => PropertyModel.fromJson(byId[id]!))
          .toList();
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