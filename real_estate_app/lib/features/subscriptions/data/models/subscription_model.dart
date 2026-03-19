// lib/features/subscriptions/data/models/subscription_model.dart

import 'package:equatable/equatable.dart';

/// Subscription tiers
enum SubscriptionTier {
  free,
  pro;

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Bure';
      case SubscriptionTier.pro:
        return 'Pro';
    }
  }

  String get description {
    switch (this) {
      case SubscriptionTier.free:
        return 'Matangazo hadi 3, na matangazo ya wengine';
      case SubscriptionTier.pro:
        return 'Matangazo yasio na kikomo (picha & video), bila matangazo, msaada wa kwanza';
    }
  }

  /// Monthly price in TZS
  int get monthlyPriceTzs {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.pro:
        return 15000; // TSh 15,000/month
    }
  }

  /// Yearly price in TZS — saves 2 months vs monthly (TSh 180,000 → TSh 120,000)
  int get yearlyPriceTzs {
    switch (this) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.pro:
        return 120000; // TSh 120,000/year (save TSh 60,000)
    }
  }

  // Keep for backward compat — maps to TZS now
  double get monthlyPrice => monthlyPriceTzs.toDouble();
}

/// User subscription model
class UserSubscription extends Equatable {
  final String id;
  final String userId;
  final String tierId;
  final SubscriptionTier tier;
  final String status;
  final DateTime startedAt;
  final DateTime expiresAt;
  final bool autoRenew;
  final String? paymentProviderId;

  const UserSubscription({
    required this.id,
    required this.userId,
    required this.tierId,
    required this.tier,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.autoRenew,
    this.paymentProviderId,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    // Get tier_id from the response
    final tierId = json['tier_id'] as String;
    
    // Try to get tier data from the joined subscription_tiers table
    final tierData = json['subscription_tiers'] as Map<String, dynamic>?;
    String tierName;
    
    if (tierData != null && tierData['name'] != null) {
      // If we have joined data, use it
      tierName = tierData['name'] as String;
    } else {
      // Fallback: try to get from the tier field if it exists (backward compatibility)
      tierName = json['tier'] as String? ?? 'free';
    }
    
    return UserSubscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tierId: tierId,
      tier: _parseTier(tierName),
      status: json['status'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      autoRenew: json['auto_renew'] as bool? ?? false,
      paymentProviderId: json['payment_provider_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tier_id': tierId,
      'status': status,
      'started_at': startedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'auto_renew': autoRenew,
      'payment_provider_id': paymentProviderId,
    };
  }

  static SubscriptionTier _parseTier(String tierName) {
    switch (tierName.toLowerCase()) {
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }

  UserSubscription copyWith({
    String? id,
    String? userId,
    String? tierId,
    SubscriptionTier? tier,
    String? status,
    DateTime? startedAt,
    DateTime? expiresAt,
    bool? autoRenew,
    String? paymentProviderId,
  }) {
    return UserSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tierId: tierId ?? this.tierId,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      autoRenew: autoRenew ?? this.autoRenew,
      paymentProviderId: paymentProviderId ?? this.paymentProviderId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        tierId,
        tier,
        status,
        startedAt,
        expiresAt,
        autoRenew,
        paymentProviderId,
      ];
}

/// Subscription tier information
class SubscriptionTierInfo extends Equatable {
  final String id;
  final String name;
  final double price;
  final Map<String, dynamic> features;
  final Map<String, int> limits;
  final bool isActive;

  const SubscriptionTierInfo({
    required this.id,
    required this.name,
    required this.price,
    required this.features,
    required this.limits,
    required this.isActive,
  });

  factory SubscriptionTierInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionTierInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      features: json['features'] as Map<String, dynamic>? ?? {},
      limits: Map<String, int>.from(json['limits'] as Map<String, dynamic>? ?? {}),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'features': features,
      'limits': limits,
      'is_active': isActive,
    };
  }

  SubscriptionTier get tier {
    switch (name.toLowerCase()) {
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }

  @override
  List<Object?> get props => [id, name, price, features, limits, isActive];
}

/// Usage tracking model
class UsageTracking extends Equatable {
  final String id;
  final String userId;
  final String featureName;
  final int count;
  final DateTime date;
  final DateTime? resetAt;

  const UsageTracking({
    required this.id,
    required this.userId,
    required this.featureName,
    required this.count,
    required this.date,
    this.resetAt,
  });

  factory UsageTracking.fromJson(Map<String, dynamic> json) {
    return UsageTracking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      featureName: json['feature_name'] as String,
      count: json['count'] as int? ?? json['usage_count'] as int? ?? 0,
      date: DateTime.parse(json['date'] as String),
      resetAt: json['reset_at'] != null 
          ? DateTime.parse(json['reset_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'feature_name': featureName,
      'count': count,
      'date': date.toIso8601String().split('T')[0],
      'reset_at': resetAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, userId, featureName, count, date, resetAt];
}