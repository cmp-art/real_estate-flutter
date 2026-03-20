// features/settings/presentation/providers/app_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/algorithm/access_control_algorithm.dart';
import '../../../../core/middleware/feature_gate_middleware.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../main.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../subscriptions/data/models/subscription_model.dart';

// =============================================================================
// Supabase Provider
// =============================================================================

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return supabase; // Uses global supabase instance from main.dart
});

// =============================================================================
// Service Providers
// =============================================================================

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final supabaseClient = ref.watch(supabaseProvider);
  return SubscriptionService(supabaseClient);
});



// =============================================================================
// Algorithm Providers
// =============================================================================

final accessControlProvider = Provider<AccessControlAlgorithm>((ref) {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return AccessControlAlgorithm(subscriptionService);
});



// =============================================================================
// Middleware Providers
// =============================================================================

final featureGateMiddlewareProvider = Provider<FeatureGateMiddleware>((ref) {
  final accessControl = ref.watch(accessControlProvider);
  return FeatureGateMiddleware(accessControl);
});

// =============================================================================
// Current User Provider (from auth)
// =============================================================================

// Helper to convert UserEntity to simple user model
class AppUser {
  final String id;
  final String? email;
  final String? name;
  final String? avatarUrl;

  AppUser({
    required this.id,
    this.email,
    this.name,
    this.avatarUrl,
  });

  factory AppUser.fromUserEntity(UserEntity user) {
    return AppUser(
      id: user.id,
      email: user.email,
      name: user.fullName,
      avatarUrl: user.avatarUrl,
    );
  }
}

// =============================================================================
// Subscription State Providers
// =============================================================================

/// Get user's current subscription
final userSubscriptionProvider = FutureProvider.autoDispose
    .family<UserSubscription?, String>((ref, userId) async {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return await subscriptionService.getUserSubscription(userId);
});

/// Stream of subscription changes
final subscriptionStreamProvider = StreamProvider.autoDispose
    .family<UserSubscription?, String>((ref, userId) {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return subscriptionService.subscriptionStream(userId);
});

/// Subscription statistics provider
final subscriptionStatsProvider = FutureProvider.autoDispose
    .family<SubscriptionStats?, String>((ref, userId) async {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return await subscriptionService.getSubscriptionStats(userId);
});

/// Available subscription tiers provider
final availableTiersProvider = FutureProvider.autoDispose<List<SubscriptionTierInfo>>((ref) async {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return await subscriptionService.getAvailableTiers();
});

/// Check if user is Pro subscriber
final isProSubscriberProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, userId) async {
  final subscription = await ref.watch(userSubscriptionProvider(userId).future);
  return subscription?.tier == SubscriptionTier.pro;
});

// =============================================================================
// Feature Access Providers
// =============================================================================

/// Request model for feature access
class FeatureAccessRequest {
  final String userId;
  final String featureName;
  final Map<String, dynamic>? additionalContext;

  FeatureAccessRequest({
    required this.userId,
    required this.featureName,
    this.additionalContext,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureAccessRequest &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          featureName == other.featureName;

  @override
  int get hashCode => userId.hashCode ^ featureName.hashCode;
}

/// Check if user can access a specific feature
final canAccessFeatureProvider = FutureProvider.autoDispose
    .family<FeatureAccessResult, FeatureAccessRequest>((ref, request) async {
  final accessControl = ref.watch(accessControlProvider);
  return await accessControl.canAccessFeature(
    userId: request.userId,
    featureName: request.featureName,
    additionalContext: request.additionalContext,
  );
});



// =============================================================================
// USAGE TRACKING PROVIDERS - FIXED
// =============================================================================

/// Request model for usage tracking
class UsageRequest {
  final String userId;
  final String featureName;

  UsageRequest({
    required this.userId,
    required this.featureName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsageRequest &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          featureName == other.featureName;

  @override
  int get hashCode => userId.hashCode ^ featureName.hashCode;
}

/// ✅ FIXED: Current usage for a feature - NO ID COLUMN
final currentUsageProvider = FutureProvider.autoDispose
    .family<int, UsageRequest>((ref, request) async {
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return await subscriptionService.getCurrentUsage(
    userId: request.userId,
    featureName: request.featureName,
  );
});

/// ✅ NEW: Get daily usage statistics for charts (without ID column)
final dailyUsageProvider = FutureProvider.autoDispose
    .family<List<DailyUsage>, UsageRequest>((ref, request) async {
  final supabase = ref.watch(supabaseProvider);
  
  try {
    final response = await supabase
        .from('usage_tracking')
        .select('date, usage_count')  // ✅ NO ID COLUMN HERE
        .eq('user_id', request.userId)
        .eq('feature_name', request.featureName)
        .order('date', ascending: false)
        .limit(30);
    
    return (response as List)
        .map((item) => DailyUsage(
              date: DateTime.parse(item['date'] as String),
              count: item['usage_count'] as int,
            ))
        .toList();
  } catch (e) {
    debugPrint('Error fetching daily usage: $e');
    return [];
  }
});

/// ✅ NEW: Daily usage model
class DailyUsage {
  final DateTime date;
  final int count;

  DailyUsage({
    required this.date,
    required this.count,
  });
}

/// ✅ NEW: Get total usage count (simplified, no GROUP BY needed)
final totalUsageProvider = FutureProvider.autoDispose
    .family<int, UsageRequest>((ref, request) async {
  final supabase = ref.watch(supabaseProvider);
  
  try {
    final response = await supabase
        .from('usage_tracking')
        .select('usage_count')
        .eq('user_id', request.userId)
        .eq('feature_name', request.featureName)
        .maybeSingle();
    
    return response?['usage_count'] as int? ?? 0;
  } catch (e) {
    debugPrint('Error fetching total usage: $e');
    return 0;
  }
});

// =============================================================================
// Subscription Notifier (for state management)
// =============================================================================

/// Subscription state notifier for managing subscription actions
class SubscriptionNotifier extends StateNotifier<AsyncValue<UserSubscription?>> {
  final SubscriptionService _subscriptionService;
  final String userId;

  SubscriptionNotifier(this._subscriptionService, this.userId)
      : super(const AsyncValue.loading()) {
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _subscriptionService.getUserSubscription(userId);
      state = AsyncValue.data(subscription);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> upgrade({
    required SubscriptionTier tier,
    required String paymentProviderId,
    String billingCycle = 'monthly',
  }) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _subscriptionService.updateSubscription(
        userId: userId,
        newTier: tier,
        paymentProviderId: paymentProviderId,
        billingCycle: billingCycle,
      );
      state = AsyncValue.data(subscription);
      return subscription != null;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> cancel() async {
    state = const AsyncValue.loading();
    try {
      final success = await _subscriptionService.cancelSubscription(userId);
      if (success) {
        await _loadSubscription();
      }
      return success;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<void> refresh() => _loadSubscription();
}

final subscriptionNotifierProvider = StateNotifierProvider.autoDispose
    .family<SubscriptionNotifier, AsyncValue<UserSubscription?>, String>(
  (ref, userId) {
    final subscriptionService = ref.watch(subscriptionServiceProvider);
    return SubscriptionNotifier(subscriptionService, userId);
  },
);

// =============================================================================
// App Theme Provider
// =============================================================================

enum AppThemeMode { light, dark, system }

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString('theme_mode') ?? 'system';
      state = _themeModeFromString(themeString);
    } catch (e) {
      state = AppThemeMode.system;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', _themeModeToString(mode));
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  AppThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }

  String _themeModeToString(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }
}

// Actual ThemeMode for MaterialApp
final themeModeActualProvider = Provider<ThemeMode>((ref) {
  final appThemeMode = ref.watch(themeModeProvider);
  switch (appThemeMode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
});

// =============================================================================
// Language/Locale Provider
// =============================================================================

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale('en')) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('language') ?? 'en';
      state = Locale(languageCode);
    } catch (e) {
      state = const Locale('en');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    const supportedLanguages = [
      'en', 'sw', 'es', 'fr', 'de', 'it', 'pt',
      'ar', 'zh', 'ja', 'ko', 'ru', 'hi'
    ];
    
    if (!supportedLanguages.contains(languageCode)) {
      debugPrint('Unsupported language code: $languageCode');
      return;
    }

    state = Locale(languageCode);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', languageCode);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  String get currentLanguageCode => state.languageCode;
}

// =============================================================================
// Currency Provider
// =============================================================================

final currencyProvider = StateNotifierProvider<CurrencyNotifier, String>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier() : super('TZS') {
    _loadCurrency();
  }

  static const String _currencyKey = 'app_currency';

  Future<void> _loadCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currency = prefs.getString(_currencyKey) ?? 'TZS';
      state = currency;
    } catch (e) {
      state = 'TZS';
    }
  }

  Future<void> setCurrency(String currencyCode) async {
    state = currencyCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, currencyCode);
    } catch (e) {
      debugPrint('Error saving currency: $e');
    }
  }

  String get currentCurrency => state;
}

// =============================================================================
// Notification Settings Provider
// =============================================================================

final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettings {
  final bool pushNotifications;
  final bool emailNotifications;
  final bool newPropertyAlerts;
  final bool priceChangeAlerts;
  final bool priceDropAlerts; // NEW: Pro-only feature
  final bool messageNotifications;

  NotificationSettings({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.newPropertyAlerts = false, // Opt-in — user must enable explicitly
    this.priceChangeAlerts = true,
    this.priceDropAlerts = false,
    this.messageNotifications = true,
  });

  NotificationSettings copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? newPropertyAlerts,
    bool? priceChangeAlerts,
    bool? priceDropAlerts,
    bool? messageNotifications,
  }) {
    return NotificationSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      newPropertyAlerts: newPropertyAlerts ?? this.newPropertyAlerts,
      priceChangeAlerts: priceChangeAlerts ?? this.priceChangeAlerts,
      priceDropAlerts: priceDropAlerts ?? this.priceDropAlerts,
      messageNotifications: messageNotifications ?? this.messageNotifications,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_notifications': pushNotifications,
      'email_notifications': emailNotifications,
      'new_property_alerts': newPropertyAlerts,
      'price_change_alerts': priceChangeAlerts,
      'price_drop_alerts': priceDropAlerts,
      'message_notifications': messageNotifications,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushNotifications: json['push_notifications'] as bool? ?? true,
      emailNotifications: json['email_notifications'] as bool? ?? true,
      newPropertyAlerts: json['new_property_alerts'] as bool? ?? false,
      priceChangeAlerts: json['price_change_alerts'] as bool? ?? true,
      priceDropAlerts: json['price_drop_alerts'] as bool? ?? false,
      messageNotifications: json['message_notifications'] as bool? ?? true,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(NotificationSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = NotificationSettings(
        pushNotifications: prefs.getBool('push_notifications') ?? true,
        emailNotifications: prefs.getBool('email_notifications') ?? true,
        newPropertyAlerts: prefs.getBool('new_property_alerts') ?? false,
        priceChangeAlerts: prefs.getBool('price_change_alerts') ?? true,
        priceDropAlerts: prefs.getBool('price_drop_alerts') ?? false,
        messageNotifications: prefs.getBool('message_notifications') ?? true,
      );
    } catch (e) {
      state = NotificationSettings();
    }
  }

  Future<void> updateSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);

      switch (key) {
        case 'push_notifications':
          state = state.copyWith(pushNotifications: value);
          break;
        case 'email_notifications':
          state = state.copyWith(emailNotifications: value);
          break;
        case 'new_property_alerts':
          state = state.copyWith(newPropertyAlerts: value);
          break;
        case 'price_change_alerts':
          state = state.copyWith(priceChangeAlerts: value);
          break;
        case 'price_drop_alerts':
          state = state.copyWith(priceDropAlerts: value);
          break;
        case 'message_notifications':
          state = state.copyWith(messageNotifications: value);
          break;
      }
    } catch (e) {
      debugPrint('Error updating notification setting: $e');
    }
  }
}

// =============================================================================
// Show Add Property FAB Provider
// =============================================================================

final showAddPropertyFabProvider = StateNotifierProvider<ShowAddPropertyFabNotifier, bool>((ref) {
  return ShowAddPropertyFabNotifier();
});

class ShowAddPropertyFabNotifier extends StateNotifier<bool> {
  ShowAddPropertyFabNotifier() : super(true) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool('show_add_property_fab') ?? true;
    } catch (e) {
      state = true;
    }
  }

  Future<void> toggleFab(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_add_property_fab', value);
    } catch (e) {
      debugPrint('Error saving FAB setting: $e');
    }
  }
}