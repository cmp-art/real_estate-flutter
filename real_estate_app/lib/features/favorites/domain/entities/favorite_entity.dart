import 'package:equatable/equatable.dart';

class FavoriteEntity extends Equatable {
  final String id;
  final String userId;
  final String propertyId;
  final DateTime createdAt;

  const FavoriteEntity({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, userId, propertyId, createdAt];
}