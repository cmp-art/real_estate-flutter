// features/authentication/data/models/user_model.dart
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  static const String _tag = 'UserModel';

  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.phone,
    super.avatarUrl,
    super.bio,
    super.showEmail = true,
    super.showPhone = true,
    required super.userType,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserModel(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? 'User',
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        showEmail: json['show_email'] as bool? ?? true,
        showPhone: json['show_phone'] as bool? ?? true,
        userType: _userTypeFromString(json['user_type'] as String? ?? 'buyer'),
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
    } catch (e, stack) {
      logger.e('Error parsing UserModel', error: e, stackTrace: stack);
      return UserModel(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? 'User',
        userType: UserType.buyer,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'avatar_url': avatarUrl,
    'bio': bio,
    'show_email': showEmail,
    'show_phone': showPhone,
    'user_type': _userTypeToString(userType),
    'created_at': createdAt.toIso8601String(),
  };

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
    id: entity.id,
    email: entity.email,
    fullName: entity.fullName,
    phone: entity.phone,
    avatarUrl: entity.avatarUrl,
    bio: entity.bio,
    showEmail: entity.showEmail,
    showPhone: entity.showPhone,
    userType: entity.userType,
    createdAt: entity.createdAt,
  );

  static UserType _userTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'seller': return UserType.seller;
      case 'both': return UserType.both;
      case 'buyer': default: return UserType.buyer;
    }
  }

  static String _userTypeToString(UserType type) {
    switch (type) {
      case UserType.buyer: return 'buyer';
      case UserType.seller: return 'seller';
      case UserType.both: return 'both';
    }
  }
}