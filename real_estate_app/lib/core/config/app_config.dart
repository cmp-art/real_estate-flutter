class AppConfig {
  // App Environment
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';

  // API Configuration
  static const int apiTimeout = 30; // seconds
  static const int maxRetries = 3;

  // Cache Configuration
  static const int cacheValidityDuration = 3600; // 1 hour in seconds
  static const int maxCacheSize = 100; // Maximum cached items

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // Map Configuration
  static const double defaultMapZoom = 14.0;
  static const double defaultLatitude = 0.0;
  static const double defaultLongitude = 0.0;

  // Animation Durations (milliseconds)
  static const int shortAnimationDuration = 200;
  static const int mediumAnimationDuration = 300;
  static const int longAnimationDuration = 500;

  // Debounce Durations (milliseconds)
  static const int searchDebounce = 500;
  static const int formDebounce = 300;
}