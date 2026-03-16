// lib/presentation/providers/auth_provider.dart
// Complete provider with delete account and logger - NO ERRORS

// ignore_for_file: unused_catch_stack

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../features/settings/presentation/providers/app_providers.dart';
import '../../features/subscriptions/data/models/subscription_model.dart';
import '../../main.dart';
import '../../features/authentication/data/datasources/auth_remote_datasource.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';

// Auth Data Source Provider
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(supabase);
});

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(authRemoteDataSourceProvider));
});

// Current User Provider
final currentUserProvider = StreamProvider<UserEntity?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

// Auth State Notifier
class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository _repository;
  final _logger = AppLogger();

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    _initialize();
  }

  void _initialize() {
    _logger.i('🔧 Initializing Auth State');

    Future.microtask(() async {
      try {
        final result = await _repository.getCurrentUser();

        if (mounted) {
          result.fold(
            (failure) {
              _logger.e('❌ Auth init failed: ${failure.message}');
              state = const AsyncValue.data(null);
            },
            (user) {
              if (user != null) {
                _logger.i('✅ Auth init: User found - ${user.email}');
                state = AsyncValue.data(user);
              } else {
                _logger.i('ℹ️ Auth init: No user logged in');
                state = const AsyncValue.data(null);
              }
            },
          );
        }
      } catch (e, stack) {
        _logger.e('❌ Auth init error: $e', error: e, stackTrace: stack);
        if (mounted) {
          state = const AsyncValue.data(null);
        }
      }
    });
  }

  Future<bool> signInWithGoogle() async {
  try {
    _logger.i('Google Sign-In Attempt');
    state = const AsyncValue.loading();
    final result = await _repository.signInWithGoogle();
    return result.fold(
      (failure) {
        _logger.e('Google Sign-In failed: ${failure.message}');
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (user) async {
        _logger.i('Google Sign-In successful: ${user.email}');
        try {
          final container = ProviderContainer();
          final subscriptionService = container.read(subscriptionServiceProvider);
          final subscription = await subscriptionService.getUserSubscription(user.id);
          if (subscription == null) {
            _logger.i('Creating default free subscription');
            await subscriptionService.createSubscription(
              userId: user.id,
              tier: SubscriptionTier.free,
              paymentProviderId: 'google_signin_default',
              duration: const Duration(days: 36500),
            );
          }
          container.dispose();
        } catch (e) {
          _logger.w('Could not initialize subscription: $e');
        }
        state = AsyncValue.data(user);
        return true;
      },
    );
  } catch (e, stack) {
    _logger.e('Google Sign-In exception: $e', error: e, stackTrace: stack);
    state = AsyncValue.error(e, stack);
    return false;
  }
}

Future<bool> signInWithApple() async {
  try {
    _logger.i('Apple Sign-In Attempt');
    state = const AsyncValue.loading();
    final result = await _repository.signInWithApple();
    return result.fold(
      (failure) {
        _logger.e('Apple Sign-In failed: ${failure.message}');
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (user) async {
        _logger.i('Apple Sign-In successful: ${user.email}');
        try {
          final container = ProviderContainer();
          final subscriptionService = container.read(subscriptionServiceProvider);
          final subscription = await subscriptionService.getUserSubscription(user.id);
          if (subscription == null) {
            _logger.i('Creating default free subscription');
            await subscriptionService.createSubscription(
              userId: user.id,
              tier: SubscriptionTier.free,
              paymentProviderId: 'apple_signin_default',
              duration: const Duration(days: 36500),
            );
          }
          container.dispose();
        } catch (e) {
          _logger.w('Could not initialize subscription: $e');
        }
        state = AsyncValue.data(user);
        return true;
      },
    );
  } catch (e, stack) {
    _logger.e('Apple Sign-In exception: $e', error: e, stackTrace: stack);
    state = AsyncValue.error(e, stack);
    return false;
  }
}

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('🔐 Login Attempt - Email: $email');
      
      state = const AsyncValue.loading();

      final result = await _repository.login(
        email: email,
        password: password,
      );

      return result.fold(
        (failure) {
          _logger.e('❌ Login failed: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
          return false;
        },
        (user) async {
          _logger.i('✅ Login successful: ${user.email}');
          
          // Update subscription provider
          try {
            final container = ProviderContainer();
            final subscriptionService = container.read(subscriptionServiceProvider);
            
            // Check/create subscription for user
            final subscription = await subscriptionService.getUserSubscription(user.id);
            if (subscription == null) {
              _logger.i('📝 Creating default free subscription for user');
              await subscriptionService.createSubscription(
                userId: user.id,
                tier: SubscriptionTier.free,
                paymentProviderId: 'free_tier_default',
                duration: const Duration(days: 36500), // 100 years for free
              );
            }
            container.dispose();
          } catch (e) {
            _logger.w('⚠️ Could not initialize subscription: $e');
          }
          
          state = AsyncValue.data(user);
          return true;
        },
      );
    } catch (e, stack) {
      _logger.e('❌ Login exception: $e', error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      _logger.i('📝 Registration Attempt - Email: $email');
      
      state = const AsyncValue.loading();

      final result = await _repository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      return result.fold(
        (failure) {
          _logger.e('❌ Registration failed: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
          return false;
        },
        (user) async {
          _logger.i('✅ Registration successful: ${user.email}');
          
          // Create free tier subscription automatically
          try {
            final container = ProviderContainer();
            final subscriptionService = container.read(subscriptionServiceProvider);
            
            _logger.i('📝 Creating free subscription for new user');
            await subscriptionService.createSubscription(
              userId: user.id,
              tier: SubscriptionTier.free,
              paymentProviderId: 'free_tier_default',
              duration: const Duration(days: 36500), // 100 years for free
            );
            _logger.i('✅ Free subscription created');
            container.dispose();
          } catch (e) {
            _logger.w('⚠️ Could not create subscription: $e');
            // Continue even if subscription creation fails
          }
          
          state = AsyncValue.data(user);
          return true;
        },
      );
    } catch (e, stack) {
      _logger.e('❌ Registration exception: $e', error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  
Future<bool> logout() async {
  try {
    _logger.i('🚪 Logout Process Started');

    // Set state to loading first
    state = const AsyncValue.loading();

    final result = await _repository.logout();

    return result.fold(
      (failure) {
        _logger.e('❌ Logout failed: ${failure.message}');
        // Even if failed, clear state
        state = const AsyncValue.data(null);
        _logger.i('✅ State cleared to null (after failure)');
        return false;
      },
      (_) {
        _logger.i('✅ Logout successful from repository');
        
        // CRITICAL: Clear state immediately
        state = const AsyncValue.data(null);
        _logger.i('✅ State cleared to null');
        
        // Double-check the state
        if (state.value != null) {
          _logger.e('❌ WARNING: State not null after clearing!');
          state = const AsyncValue.data(null);
        }
        
        return true;
      },
    );
  } catch (e, stack) {
    _logger.e('❌ Logout exception: $e', error: e, stackTrace: stack);
    // Always clear state on error
    state = const AsyncValue.data(null);
    _logger.i('✅ State cleared to null (error recovery)');
    return true; // Return true so UI navigates to login
  }
}

  /// Send password reset email
  /// Opens in web browser where user completes the reset
  Future<bool> resetPassword(String email) async {
    try {
      _logger.i('📧 Password Reset Request - Email: $email');
      _logger.d('Redirect: io.supabase.realestate://reset-password');

      final result = await _repository.resetPassword(
        email: email,
        redirectTo: 'io.supabase.realestate://reset-password',
      );

      return result.fold(
        (failure) {
          _logger.e('❌ Reset failed: ${failure.message}');
          return false;
        },
        (_) {
          _logger.i('✅ Reset email sent successfully');
          _logger.d('Deep link will open app directly');
          return true;
        },
      );
    } catch (e) {
      _logger.e('❌ Reset exception: $e', error: e);
      return false;
    }
  }

  /// Change password (for logged-in users in settings)
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _logger.i('🔐 Change Password');

      final result = await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      return result.fold(
        (failure) {
          _logger.e('❌ Password change failed: ${failure.message}');
          return failure.message;
        },
        (_) {
          _logger.i('✅ Password changed successfully');
          return null;
        },
      );
    } catch (e) {
      _logger.e('❌ Password change exception: $e', error: e);
      return 'An unexpected error occurred';
    }
  }

  /// Delete account
  Future<String?> deleteAccount({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('🗑️ Delete Account - Email: $email');

      final result = await _repository.deleteAccount(
        email: email,
        password: password,
      );

      return result.fold(
        (failure) {
          _logger.e('❌ Account deletion failed: ${failure.message}');
          return failure.message;
        },
        (_) {
          _logger.i('✅ Account deleted successfully');
          // Clear the state after successful deletion
          state = const AsyncValue.data(null);
          _logger.i('✅ State cleared to null');
          return null;
        },
      );
    } catch (e) {
      _logger.e('❌ Account deletion exception: $e', error: e);
      return 'An unexpected error occurred';
    }
  }

  Future<bool> updateProfile(UserEntity user) async {
    try {
      _logger.i('👤 Update Profile - User: ${user.email}');

      final currentState = state;

      final result = await _repository.updateProfile(user: user);

      return result.fold(
        (failure) {
          _logger.e('❌ Update failed: ${failure.message}');
          state = currentState;
          return false;
        },
        (updatedUser) {
          _logger.i('✅ Profile updated successfully');
          state = AsyncValue.data(updatedUser);
          return true;
        },
      );
    } catch (e, stack) {
      _logger.e('❌ Update exception: $e', error: e, stackTrace: stack);
      return false;
    }
  }

  Future<void> refreshUser() async {
    try {
      _logger.i('🔄 Refresh User Data');
      
      final result = await _repository.getCurrentUser();

      if (mounted) {
        result.fold(
          (failure) {
            _logger.e('❌ Refresh failed: ${failure.message}');
          },
          (user) {
            if (user != null) {
              _logger.i('✅ User data refreshed: ${user.email}');
              state = AsyncValue.data(user);
            } else {
              _logger.i('ℹ️ No user found during refresh');
            }
          },
        );
      }
    } catch (e) {
      _logger.e('❌ Refresh exception: $e', error: e);
    }
  }
}

// Auth State Provider
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});