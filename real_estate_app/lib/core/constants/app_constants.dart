// core/constants/app_constants.dart
// FIXED VERSION - Added missing PropertyCategory enum

class AppConstants {
  static const String appName = 'Patamjengo';
  static const String appVersion = '1.0.0';
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
  static const int maxImageSize = 15 * 1024 * 1024;
  static const int maxImagesPerProperty = 10;
  static const List<String> allowedImageFormats = ['jpg', 'jpeg', 'png', 'webp'];
  static const int minPasswordLength = 8;
  static const int maxPropertyTitleLength = 100;
  static const int maxPropertyDescriptionLength = 2000;
  
  static const String usersTable = 'user_profiles';
  static const String propertiesTable = 'properties';
  static const String favoritesTable = 'favorites';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';
  
  
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String onboardingKey = 'onboarding_completed';
}

enum PropertyType {
  sale,
  rent;
  
  String get displayName {
    switch (this) {
      case PropertyType.sale:
        return 'For Sale';
      case PropertyType.rent:
        return 'For Rent';
    }
  }
}

enum PropertyCategory {
  house,
  apartment,
  land,
  commercial;
  
  String get displayName {
    switch (this) {
      case PropertyCategory.house:
        return 'House';
      case PropertyCategory.apartment:
        return 'Apartment';
      case PropertyCategory.land:
        return 'Land';
      case PropertyCategory.commercial:
        return 'Commercial';
    }
  }
}

enum PropertyStatus {
  available,
  sold,
  rented,
  pending;
  
  String get displayName {
    switch (this) {
      case PropertyStatus.available:
        return 'Available';
      case PropertyStatus.sold:
        return 'Sold';
      case PropertyStatus.rented:
        return 'Rented';
      case PropertyStatus.pending:
        return 'Pending';
    }
  }
}

enum UserType {
  buyer,
  seller,
  both;
  
  String get displayName {
    switch (this) {
      case UserType.buyer:
        return 'Buyer';
      case UserType.seller:
        return 'Seller';
      case UserType.both:
        return 'Buyer & Seller';
    }
  }
}

enum RentDuration {
  monthly,
  yearly;
  
  String get displayName {
    switch (this) {
      case RentDuration.monthly:
        return 'Monthly';
      case RentDuration.yearly:
        return 'Yearly';
    }
  }
}