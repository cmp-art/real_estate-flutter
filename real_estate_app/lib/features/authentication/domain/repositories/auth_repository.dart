// features/authentication/domain/repositories/auth_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  // Get current user
  Future<Either<Failure, UserEntity?>> getCurrentUser();
  
  // Email/Password Authentication
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });
  
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });
  
  // ═══════════════════════════════════════════════════════════
  // NEW: Social Sign-In Methods
  // ═══════════════════════════════════════════════════════════
  Future<Either<Failure, UserEntity>> signInWithGoogle();
  
  Future<Either<Failure, UserEntity>> signInWithApple();
  // ═══════════════════════════════════════════════════════════
  
  // Logout
  Future<Either<Failure, void>> logout();
  
  // Password Management
  Future<Either<Failure, void>> resetPassword({
    required String email,
    required String redirectTo,
  });
  
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  
  // Account Management
  Future<Either<Failure, void>> deleteAccount({
    required String email,
    required String password,
  });
  
  Future<Either<Failure, UserEntity>> updateProfile({
    required UserEntity user,
  });
  
  // Status
  bool isLoggedIn();
  
  Stream<UserEntity?> get authStateChanges;
}