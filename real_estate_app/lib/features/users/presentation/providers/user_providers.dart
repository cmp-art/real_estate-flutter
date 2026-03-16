// features/users/presentation/providers/user_providers.dart
// FINAL VERSION - Add supabase provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../main.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../properties/domain/entities/property_entity.dart';
import '../../../properties/data/datasources/property_remote_datasource.dart';
import '../../data/datasources/user_remote_datasource.dart';

// Supabase Provider - For direct access in screens
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return supabase;
});

// User Remote Data Source Provider
final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource(supabase);
});

// Property Remote Data Source Provider (for user properties)
final propertyRemoteDataSourceProviderForUsers = Provider<PropertyRemoteDataSource>((ref) {
  return PropertyRemoteDataSource(supabase);
});

// Search Query Provider
final userSearchQueryProvider = StateProvider<String>((ref) => '');

// User Search Results Provider
final userSearchResultsProvider = FutureProvider<List<UserEntity>>((ref) async {
  final query = ref.watch(userSearchQueryProvider);
  
  if (query.isEmpty) return [];

  final dataSource = ref.read(userRemoteDataSourceProvider);
  return await dataSource.searchUsers(query);
});

// Get User by ID Provider
final userByIdProvider = FutureProvider.family<UserEntity?, String>((ref, userId) async {
  final dataSource = ref.read(userRemoteDataSourceProvider);
  return await dataSource.getUserById(userId);
});

// Get User Properties Provider
final userPropertiesProvider = FutureProvider.family<List<PropertyEntity>, String>(
  (ref, userId) async {
    final dataSource = ref.read(propertyRemoteDataSourceProviderForUsers);
    return await dataSource.getPropertiesByOwner(userId);
  },
);