// features/users/data/datasources/user_remote_datasource.dart

import 'package:supabase_flutter/supabase_flutter.dart' ;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart' hide AuthException;
import '../../../authentication/data/models/user_model.dart';
import '../../../authentication/domain/entities/user_entity.dart';

class UserRemoteDataSource {
  final SupabaseClient supabaseClient;

  UserRemoteDataSource(this.supabaseClient);

  /// Search users by name or email
  Future<List<UserEntity>> searchUsers(String query) async {
    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      
      if (currentUserId == null) {
        throw const AuthException('User not authenticated');
      }

      final data = await supabaseClient
          .from(AppConstants.usersTable)
          .select()
          .or('full_name.ilike.%$query%,email.ilike.%$query%')
          .neq('id', currentUserId) // Exclude current user from search
          .limit(20);

      return (data as List).map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Get user by ID
  Future<UserEntity?> getUserById(String userId) async {
    try {
      final data = await supabaseClient
          .from(AppConstants.usersTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;

      return UserModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Get all users (for admin purposes or listing)
  Future<List<UserEntity>> getAllUsers({int limit = 50}) async {
    try {
      final currentUserId = supabaseClient.auth.currentUser?.id;
      
      if (currentUserId == null) {
        throw const AuthException('User not authenticated');
      }

      final data = await supabaseClient
          .from(AppConstants.usersTable)
          .select()
          .neq('id', currentUserId) // Exclude current user
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List).map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}