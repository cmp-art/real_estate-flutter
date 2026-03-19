// features/authentication/data/datasources/auth_remote_datasource.dart
// COMPLETE FILE - UPDATED WITH GOOGLE AND APPLE SIGN-IN + SUPABASE ONLY

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ← ADDED THIS IMPORT
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart' hide AuthException;
import '../../../../core/utils/logger.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final SupabaseClient supabaseClient;
  final GoogleSignIn _googleSignIn;

  AuthRemoteDataSource(
    this.supabaseClient, {
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
            );

  // ════════════════════════════════════════════════════════════════
  // GOOGLE SIGN-IN (Works with Supabase only, no Firebase needed!)
  // ════════════════════════════════════════════════════════════════
  Future<UserModel> signInWithGoogle() async {
    try {
      logger.d('Starting Google Sign-In...');

      // Sign out any existing Google account first
      await _googleSignIn.signOut();

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        logger.d('Google Sign-In cancelled by user');
        throw const AuthException('Google Sign-In was cancelled');
      }

      logger.d('Google user signed in: ${googleUser.email}');

      // Obtain Google Auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw const AuthException('Missing Google Access Token');
      }
      if (idToken == null) {
        throw const AuthException('Missing Google ID Token');
      }

      logger.d('Google tokens obtained, signing in to Supabase...');

      // Sign in to Supabase with Google credentials
      final response = await supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        logger.e('Google sign-in failed: No user in response');
        throw const AuthException('Google sign-in failed');
      }

      logger.d('Supabase auth successful for: ${response.user!.email}');

      // Wait for profile to be created
      await Future.delayed(const Duration(milliseconds: 500));

      // Get or create user profile
      final userProfile = await _getOrCreateUserProfile(
        userId: response.user!.id,
        email: response.user!.email ?? googleUser.email,
        fullName: googleUser.displayName ?? 'Google User',
        avatarUrl: googleUser.photoUrl,
      );

      return userProfile;
    } on AuthException catch (e) {
      logger.e('Google Sign-In auth exception', error: e);
      rethrow;
    } catch (e, s) {
      logger.e('Google Sign-In error', error: e, stackTrace: s);
      throw ServerException('Google Sign-In failed: ${e.toString()}');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // APPLE SIGN-IN (iOS only - Works with Supabase only!)
  // ════════════════════════════════════════════════════════════════
  Future<UserModel> signInWithApple() async {
    try {
      if (kIsWeb || (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.macOS)) {
        throw const AuthException(
            'Apple Sign-In is only available on iOS/macOS');
      }

      logger.d('Starting Apple Sign-In...');

      // Request Apple Sign-In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      logger.d('Apple credential obtained');

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('Missing Apple ID Token');
      }

      // Sign in to Supabase with Apple credentials
      final response = await supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      if (response.user == null) {
        logger.e('Apple sign-in failed: No user in response');
        throw const AuthException('Apple sign-in failed');
      }

      logger.d('Supabase auth successful for: ${response.user!.email}');

      // Wait for profile to be created
      await Future.delayed(const Duration(milliseconds: 500));

      // Build full name from Apple credential
      String fullName = 'Apple User';
      if (credential.givenName != null || credential.familyName != null) {
        fullName =
            '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                .trim();
        if (fullName.isEmpty) fullName = 'Apple User';
      }

      // Get or create user profile
      final userProfile = await _getOrCreateUserProfile(
        userId: response.user!.id,
        email: response.user!.email ?? credential.email ?? '',
        fullName: fullName,
      );

      return userProfile;
    } on AuthException catch (e) {
      logger.e('Apple Sign-In auth exception', error: e);
      rethrow;
    } catch (e, s) {
      logger.e('Apple Sign-In error', error: e, stackTrace: s);
      throw ServerException('Apple Sign-In failed: ${e.toString()}');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // HELPER: GET OR CREATE USER PROFILE
  // ════════════════════════════════════════════════════════════════
  Future<UserModel> _getOrCreateUserProfile({
    required String userId,
    required String email,
    required String fullName,
    String? avatarUrl,
  }) async {
    try {
      // Try to get existing profile
      final existingProfile = await supabaseClient
          .from(AppConstants.usersTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (existingProfile != null) {
        logger.d('User profile found in database');
        return UserModel.fromJson(existingProfile);
      }

      // Create new profile
      logger.d('Creating new user profile...');
      final newProfile = {
        'id': userId,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'user_type': 'buyer',
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabaseClient.from(AppConstants.usersTable).insert(newProfile);
      logger.d('User profile created successfully');

      return UserModel.fromJson(newProfile);
    } catch (e, s) {
      logger.e('Error getting/creating user profile', error: e, stackTrace: s);
      throw ServerException('Failed to create user profile: ${e.toString()}');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ALL YOUR EXISTING METHODS (unchanged)
  // ════════════════════════════════════════════════════════════════

  Future<UserModel?> getCurrentUser() async {
    try {
      final authUser = supabaseClient.auth.currentUser;

      if (authUser == null) {
        logger.d('No current auth user');
        return null;
      }

      logger.d('Current auth user: ${authUser.id}');

      final response = await supabaseClient
          .from(AppConstants.usersTable)
          .select()
          .eq('id', authUser.id)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              logger.w('getCurrentUser timeout');
              return null;
            },
          );

      if (response != null) {
        logger.d('User profile loaded: ${response['email']}');
        return UserModel.fromJson(response);
      }

      // No profile row — first sign-in via Google/Apple OAuth.
      // Auto-create the profile from OAuth metadata so AuthWrapper can navigate.
      logger.d('No profile for ${authUser.id} — creating from OAuth metadata');
      final email = authUser.email ?? '';
      final fullName = (authUser.userMetadata?['full_name'] as String?)
          ?? (authUser.userMetadata?['name'] as String?)
          ?? 'User';
      final avatarUrl = (authUser.userMetadata?['avatar_url'] as String?)
          ?? (authUser.userMetadata?['picture'] as String?);

      return await _getOrCreateUserProfile(
        userId: authUser.id,
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );
    } catch (e, s) {
      logger.e('getCurrentUser error', error: e, stackTrace: s);
      return null;
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      logger.d('Attempting login for: $email');

      final response = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        logger.e('Login failed: No user in response');
        throw const AuthException('Login failed - no user returned');
      }

      logger.d('Auth successful for user: ${response.user!.id}');

      await Future.delayed(const Duration(milliseconds: 500));

      final userProfile = await supabaseClient
          .from(AppConstants.usersTable)
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      if (userProfile == null) {
        logger.d('No user profile found in database');

        final newProfile = {
          'id': response.user!.id,
          'email': response.user!.email ?? email,
          'full_name': response.user!.userMetadata?['full_name'] ?? 'User',
          'user_type': 'buyer',
          'created_at': DateTime.now().toIso8601String(),
        };

        await supabaseClient.from(AppConstants.usersTable).insert(newProfile);
        logger.d('Created new user profile');
        return UserModel.fromJson(newProfile);
      }

      logger.d('User profile loaded successfully');
      return UserModel.fromJson(userProfile);
    } on AuthException catch (e) {
      logger.e('Auth exception', error: e);
      rethrow;
    } catch (e, s) {
      logger.e('Login error', error: e, stackTrace: s);
      throw ServerException('Login failed: ${e.toString()}');
    }
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      logger.d('Attempting registration for: $email');

      final response = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (response.user == null) {
        logger.e('Registration failed: No user in response');
        throw const AuthException('Registration failed');
      }

      logger.d('Registration successful for: ${response.user!.id}');

      await Future.delayed(const Duration(seconds: 1));

      if (phone != null && phone.isNotEmpty) {
        await supabaseClient
            .from(AppConstants.usersTable)
            .update({'phone': phone}).eq('id', response.user!.id);
      }

      final userProfile = await supabaseClient
          .from(AppConstants.usersTable)
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      if (userProfile == null) {
        logger.d('Creating user profile manually');

        final newProfile = {
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'user_type': 'buyer',
          'created_at': DateTime.now().toIso8601String(),
        };

        await supabaseClient.from(AppConstants.usersTable).insert(newProfile);
        return UserModel.fromJson(newProfile);
      }

      return UserModel.fromJson(userProfile);
    } on AuthException catch (e) {
      logger.e('Auth exception during registration', error: e);
      rethrow;
    } catch (e, s) {
      logger.e('Registration error', error: e, stackTrace: s);
      throw ServerException('Registration failed: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      logger.d('🚪 Starting logout process');

      // Get current session before logout
      final currentSession = supabaseClient.auth.currentSession;
      logger.d('Current session exists: ${currentSession != null}');

      // Sign out from Google — disconnect() revokes tokens fully so the next
      // signIn() always shows a fresh account-picker instead of silently
      // reusing a stale cached credential that Supabase may reject.
      try {
        await _googleSignIn.signOut();
        await _googleSignIn.disconnect();
        logger.d('✅ Signed out and disconnected from Google');
      } catch (e) {
        logger.w('⚠️ Google sign out warning: $e');
        // Continue with Supabase logout even if Google disconnect fails
      }

      // Sign out from Supabase
      await supabaseClient.auth.signOut();
      logger.d('✅ Signed out from Supabase');

      // CRITICAL: Wait a moment to ensure logout is processed
      await Future.delayed(const Duration(milliseconds: 300));

      // Verify logout was successful
      final sessionAfterLogout = supabaseClient.auth.currentSession;
      if (sessionAfterLogout != null) {
        logger.e('❌ WARNING: Session still exists after logout!');
        // Try one more time
        await supabaseClient.auth.signOut();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final finalSession = supabaseClient.auth.currentSession;
      logger.d('Final session check: ${finalSession == null ? "Cleared" : "Still exists"}');

      logger.i('✅ Logout completed successfully');
    } catch (e, s) {
      logger.e('❌ Logout error', error: e, stackTrace: s);
      // Even if there's an error, try to clear the session
      try {
        await supabaseClient.auth.signOut();
      } catch (_) {}
      throw ServerException(e.toString());
    }
  }

  Future<void> resetPassword({
    required String email,
    required String redirectTo,
  }) async {
    try {
      logger.d('Sending password reset email to: $email');
      logger.d('Redirect deep link: $redirectTo');

      final currentSession = supabaseClient.auth.currentSession;
      if (currentSession != null) {
        logger.w('Active session found – signing out before reset');
        await supabaseClient.auth.signOut();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await supabaseClient.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );

      logger.d('Password reset email sent');
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('user not found') ||
          e.message.toLowerCase().contains('email not found')) {
        logger.d('User not found – returning success for security');
        return;
      }
      logger.e('Reset password auth error', error: e);
      rethrow;
    } catch (e, s) {
      logger.e('Reset password error', error: e, stackTrace: s);
      throw ServerException(e.toString());
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      logger.d('Attempting to change password');

      final currentUser = supabaseClient.auth.currentUser;
      if (currentUser == null) {
        throw const AuthException('No user logged in');
      }

      final email = currentUser.email;
      if (email == null) {
        throw const AuthException('User email not found');
      }

      if (newPassword.length < 6) {
        throw const AuthException(
            'New password must be at least 6 characters long');
      }

      if (currentPassword == newPassword) {
        throw const AuthException(
            'New password must be different from current password');
      }

      logger.d('Verifying current password...');
      try {
        await supabaseClient.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
        logger.d('Current password verified');
      } on AuthException catch (e) {
        logger.e('Current password verification failed', error: e);
        if (e.message.toLowerCase().contains('invalid') ||
            e.message.toLowerCase().contains('credentials') ||
            e.message.toLowerCase().contains('password')) {
          throw const AuthException('Current password is incorrect');
        }
        rethrow;
      }

      logger.d('Updating to new password...');
      final updateResponse = await supabaseClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (updateResponse.user == null) {
        throw const AuthException('Failed to update password');
      }

      logger.d('Password changed successfully');
    } on AuthException catch (e) {
      logger.e('Change password auth error', error: e);
      rethrow;
    } catch (e, s) {
      logger.e('Change password error', error: e, stackTrace: s);
      throw ServerException('Failed to change password: ${e.toString()}');
    }
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    try {
      logger.d('Starting account deletion process');

      try {
        await supabaseClient.auth.signInWithPassword(
          email: email,
          password: password,
        );
        logger.d('Authentication successful');
      } on AuthException catch (e) {
        logger.e('Authentication failed', error: e);
        if (e.message.toLowerCase().contains('invalid') ||
            e.message.toLowerCase().contains('credentials') ||
            e.message.toLowerCase().contains('password')) {
          throw const AuthException('Incorrect password');
        }
        rethrow;
      }

      final currentUser = supabaseClient.auth.currentUser;
      if (currentUser == null) {
        throw const AuthException('No user logged in');
      }
      final userId = currentUser.id;

      logger.d('Deleting user profile data...');
      try {
        await supabaseClient
            .from(AppConstants.usersTable)
            .delete()
            .eq('id', userId);
        logger.d('User profile deleted from database');
      } catch (e) {
        logger.w('Profile deletion warning', error: e);
      }

      logger.d('Deleting auth user via RPC...');

      try {
        await supabaseClient.rpc('delete_user');
        logger.d('Auth user deleted successfully via RPC');
      } catch (rpcError) {
        logger.e('RPC delete_user failed', error: rpcError);

        final errorString = rpcError.toString().toLowerCase();
        if (errorString.contains('not found') ||
            errorString.contains('does not exist') ||
            errorString.contains('undefined function')) {
          logger.e('''
════════════════════════════════════════════════════════════
CRITICAL: delete_user() RPC function NOT FOUND            
The user account is NOT deleted from Supabase Auth!       
                                                            
TO FIX:                                                    
1. Open Supabase Dashboard                                
2. Go to SQL Editor                                       
3. Run the SQL from your SQL files                  
                                                            
Until you do this, users will NOT be deleted!             
════════════════════════════════════════════════════════════''');

          throw ServerException(
            'Account deletion failed: Database function not set up. '
            'Please contact support.',
          );
        }

        throw ServerException(
            'Failed to delete auth user: ${rpcError.toString()}');
      }

      logger.d('Account deletion completed successfully');
    } on AuthException catch (e) {
      logger.e('Delete account auth error', error: e);
      rethrow;
    } catch (e, s) {
      logger.e('Delete account error', error: e, stackTrace: s);
      if (e is AuthException) rethrow;
      throw ServerException('Failed to delete account: ${e.toString()}');
    }
  }

  Future<UserModel> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? bio,
    bool? showEmail,
    bool? showPhone,
    String? userType,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bio != null) updates['bio'] = bio;
      if (showEmail != null) updates['show_email'] = showEmail;
      if (showPhone != null) updates['show_phone'] = showPhone;
      if (userType != null) updates['user_type'] = userType;

      if (updates.isEmpty) {
        throw ValidationException('No updates provided');
      }

      final response = await supabaseClient
          .from(AppConstants.usersTable)
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e, s) {
      logger.e('Update profile error', error: e, stackTrace: s);
      throw ServerException(e.toString());
    }
  }

  bool isLoggedIn() {
    final loggedIn = supabaseClient.auth.currentUser != null;
    logger.d('Is logged in: $loggedIn');
    return loggedIn;
  }

  Stream<UserModel?> get authStateChanges {
    return supabaseClient.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;

      if (user == null) {
        logger.d('Auth state: No user');
        return null;
      }

      try {
        final userProfile = await supabaseClient
            .from(AppConstants.usersTable)
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        if (userProfile == null) {
          logger.d('No profile in auth state change');
          return null;
        }

        return UserModel.fromJson(userProfile);
      } catch (e, s) {
        logger.e('Auth state change error', error: e, stackTrace: s);
        return null;
      }
    });
  }
}