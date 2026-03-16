// features/authentication/domain/entities/user_entity.dart
// SAFE VERSION - Use this if having crashes

import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final bool showEmail;
  final bool showPhone;
  final UserType userType;
  final DateTime createdAt;
  final Map<String, dynamic>? userMetadata;

  const UserEntity( {
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.showEmail = true,
    this.showPhone = true,
    required this.userType,
    required this.createdAt,
    this.userMetadata,
  });

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        phone,
        avatarUrl,
        bio,
        showEmail,
        showPhone,
        userType,
        createdAt,
        userMetadata,
      ];

  UserEntity copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? bio,
    bool? showEmail,
    bool? showPhone,
    UserType? userType,
    DateTime? createdAt,
    Map<String, dynamic>? userMetadata,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      userMetadata: userMetadata ?? this.userMetadata,
    );
  }

  @override
  String toString() {
    return 'UserEntity(id: $id, email: $email, fullName: $fullName, metadata: $userMetadata)';
  }
}