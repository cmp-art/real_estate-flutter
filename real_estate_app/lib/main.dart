// lib/main.dart
// PRODUCTION VERSION - SUPABASE ONLY (No Firebase!)
// With Analytics, Error Logging, and Performance Monitoring

// ignore_for_file: unused_import

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'app.dart';
import 'core/utils/app_lifecycle_observer.dart';
import 'core/utils/logger.dart';
import 'core/services/analytics_supabase_service.dart';
import 'core/services/error_logging_service.dart';
import 'core/services/performance_monitor_service.dart';
import 'core/services/push_notification_service.dart';

late final SupabaseClient supabase;
late AppLinks _appLinks;
StreamSubscription? _deepLinkSubscription;

// Supabase-based services (NO Firebase!)
late final AnalyticsSupabaseService analyticsService;
late final ErrorLoggingService errorLoggingService;
late final PerformanceMonitorService performanceMonitor;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger.init();

  // ========================================
  // ENVIRONMENT VARIABLES - LOAD FIRST
  // ========================================
  try {
    await dotenv.load(fileName: "assets/.env");
    logger.d('.env file loaded successfully');
    _verifyEnvironmentVariables();
  } catch (e, s) {
    logger.e('Failed to load .env file', error: e, stackTrace: s);
  }

  AppLifecycleObserver().initialize();

  // Allow all orientations — app is fully responsive (phone portrait+landscape,
  // tablet, desktop). Never lock to portrait on larger screens.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  // ========================================
  // SUPABASE INITIALIZATION
  // ========================================
  try {
    logger.d('Initializing Supabase...');

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      throw Exception('SUPABASE_URL not found in .env file');
    }
    if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY not found in .env file');
    }

    logger.d('Supabase URL: $supabaseUrl');
    logger.d('Supabase Key: ${supabaseAnonKey.substring(0, 10)}...');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: kDebugMode, // Never expose auth tokens in production logs
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );

    supabase = Supabase.instance.client;

    final session = supabase.auth.currentSession;
    if (session != null) {
      logger.d('Supabase initialized - User logged in: ${session.user.email}');
    } else {
      logger.d('Supabase initialized - No user logged in');
    }
  } catch (e, s) {
    logger.e('Supabase initialization error', error: e, stackTrace: s);
    // Do NOT rethrow — a crash here kills the Dart isolate before the Flutter
    // engine emits its VM-service URL to logcat, so Flutter tools hang
    // indefinitely on "Waiting for VM Service port to be available...".
    // Instead, show a recoverable error screen and let the user retry.
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 72, color: Color(0xFFE94560)),
                  const SizedBox(height: 24),
                  const Text(
                    'Connection Failed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not connect to the server.\n\n${e.toString()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94560),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Restart App'),
                    onPressed: () {
                      // Hot-restart on emulator; on device user re-opens the app
                      throw Exception('User requested restart');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return; // Stop main() — do not proceed to runApp(RealEstateApp)
  }

  // ========================================
  // INITIALIZE SUPABASE MONITORING SERVICES
  // (Replaces Firebase Analytics, Sentry, etc.)
  // ========================================
  try {
    logger.d('Initializing Supabase monitoring services...');
    
    analyticsService = AnalyticsSupabaseService();
    errorLoggingService = ErrorLoggingService();
    performanceMonitor = PerformanceMonitorService();
    
    // Log app open event
    await analyticsService.logAppOpen();
    
    logger.d('✅ Supabase monitoring services initialized');
  } catch (e, s) {
    logger.e('❌ Failed to initialize monitoring services', error: e, stackTrace: s);
    // Don't rethrow - app can still work without monitoring
  }

  // ========================================
  // PUSH NOTIFICATIONS (Supabase Realtime → local banner, NO Firebase)
  // ========================================
  try {
    await PushNotificationService.instance.initialize();
    // Subscribe for the already-logged-in user (if any)
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      PushNotificationService.instance.subscribeToNotifications(currentUser.id);
    }
    // Listen to future sign-in / sign-out events
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        PushNotificationService.instance.subscribeToNotifications(user.id);
      } else {
        PushNotificationService.instance.unsubscribe();
      }
    });
    logger.d('✅ Push notification service initialized');
  } catch (e, s) {
    logger.e('❌ Push notification init failed', error: e, stackTrace: s);
  }

  // ========================================
  // GLOBAL ERROR HANDLER (Logs to Supabase!)
  // ========================================
  // Catch Flutter framework errors (widget build errors, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.e('Flutter Error', error: details.exception, stackTrace: details.stack);
    errorLoggingService.logError(
      errorType: 'FlutterError',
      errorMessage: details.exception.toString(),
      stackTrace: details.stack.toString(),
      severity: 'error',
    );
  };

  // Catch unhandled async errors (Dart zone errors not caught by Flutter)
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Unhandled async error', error: error, stackTrace: stack);
    errorLoggingService.logError(
      errorType: 'AsyncError:${error.runtimeType}',
      errorMessage: error.toString(),
      stackTrace: stack.toString(),
      severity: 'critical',
    );
    return true; // return true = handled, don't crash
  };

  _initDeepLinks();

  runApp(
    ProviderScope(
      overrides: [
        // Make services available throughout the app
        analyticsServiceProvider.overrideWithValue(analyticsService),
        errorLoggingServiceProvider.overrideWithValue(errorLoggingService),
        performanceMonitorProvider.overrideWithValue(performanceMonitor),
      ],
      child: const RealEstateApp(),
    ),
  );
}

void _verifyEnvironmentVariables() {
  logger.d('Verifying environment variables...');

  final requiredVars = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
  ];

  // NOTE: SELCOM_VENDOR / SELCOM_API_KEY / SELCOM_API_SECRET are intentionally
  // absent here. Those credentials live only in the backend server's .env file
  // (real_estate_app_backend/.env) and must never be loaded into the Flutter app.
  final optionalVars = [
    'SELCOM_BACKEND_URL',  // empty = DEMO_MODE; set to your Railway/Render URL
  ];

  for (final varName in requiredVars) {
    final value = dotenv.env[varName];
    if (value == null || value.isEmpty) {
      logger.w('Required env variable missing: $varName');
    } else {
      if (varName.contains('KEY') || varName.contains('SECRET')) {
        logger.d('✅ $varName: ${value.substring(0, 10)}...');
      } else {
        logger.d('✅ $varName: $value');
      }
    }
  }

  for (final varName in optionalVars) {
    final value = dotenv.env[varName];
    if (value == null || value.isEmpty) {
      logger.d('Optional env variable not set: $varName');
    } else {
      logger.d('✅ $varName: [configured]');
    }
  }
}

String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;

void _initDeepLinks() {
  _appLinks = AppLinks();
  _handleInitialLink();
  _deepLinkSubscription = _appLinks.uriLinkStream.listen(
    (Uri uri) {
      logger.d('🔗 Deep link received: $uri');
      _handleDeepLink(uri);
      
      // Log to analytics
      analyticsService.logEvent(
        eventName: 'deep_link_received',
        parameters: {'uri': uri.toString()},
      );
    },
    onError: (err) {
      logger.e('❌ Deep link error', error: err);
      
      // Log error to Supabase
      errorLoggingService.logError(
        errorType: 'DeepLinkError',
        errorMessage: err.toString(),
        severity: 'warning',
      );
    },
  );
}

Future<void> _handleInitialLink() async {
  try {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      logger.d('🔗 Initial deep link: $initialUri');
      _handleDeepLink(initialUri);
    }
  } catch (e, s) {
    logger.e('❌ Error getting initial link', error: e, stackTrace: s);
    
    errorLoggingService.logError(
      errorType: 'InitialLinkError',
      errorMessage: e.toString(),
      stackTrace: s.toString(),
      severity: 'warning',
    );
  }
}

Future<void> _handleDeepLink(Uri uri) async {
  logger.d('🔍 Processing deep link: $uri');

  if (uri.host == 'reset-password' ||
      uri.path.contains('reset-password') ||
      uri.host == 'reset-callback') {
    logger.d('🔐 Password reset deep link detected');
    await _handlePasswordRecovery(uri);
  }

  if (uri.path.contains('/auth/v1/callback') ||
      uri.path.contains('/auth/v1/verify')) {
    logger.d('🔑 Supabase auth callback detected');
  }
}

Future<void> _handlePasswordRecovery(Uri uri) async {
  final startTime = DateTime.now();
  
  try {
    final code = uri.queryParameters['code'];

    String? recoveryCode = code;
    if (recoveryCode == null && uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      recoveryCode = fragmentParams['code'];
    }

    if (recoveryCode == null) {
      logger.e('❌ No recovery code found in deep link');
      
      errorLoggingService.logWarning(
        errorType: 'PasswordRecoveryError',
        errorMessage: 'No recovery code in deep link',
      );
      return;
    }

    logger.d('🔄 Exchanging recovery code for session...');
    // NOTE: Never log the recovery code or any portion of it — partial
    // secrets are still extractable from crash-reporting pipelines.

    // Exchange the code for a session
    await supabase.auth.exchangeCodeForSession(recoveryCode);

    final session = supabase.auth.currentSession;
    final user = supabase.auth.currentUser;

    if (session != null && user != null) {
      logger.d('✅ Session established for: ${user.email}');
      
      // Log successful password recovery to analytics
      await analyticsService.logEvent(
        eventName: 'password_recovery_success',
        parameters: {'user_id': user.id},
      );
      
      // Track performance
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      await performanceMonitor.recordMetric(
        metricName: 'password_recovery',
        durationMs: duration,
      );
    } else {
      logger.w('⚠️ Session exchange completed but no user/session found');
      
      errorLoggingService.logWarning(
        errorType: 'PasswordRecoveryWarning',
        errorMessage: 'Session exchange completed but no user found',
      );
    }
  } catch (e, s) {
    logger.e('❌ Error exchanging recovery code', error: e, stackTrace: s);
    
    // Log error
    errorLoggingService.logError(
      errorType: 'PasswordRecoveryError',
      errorMessage: e.toString(),
      stackTrace: s.toString(),
      severity: 'error',
    );
    
    // Track failed performance
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    await performanceMonitor.recordMetric(
      metricName: 'password_recovery',
      durationMs: duration,
      metadata: {'success': false, 'error': e.toString()},
    );
  }
}

// ============================================================================
// PROVIDERS FOR MONITORING SERVICES
// ============================================================================

final analyticsServiceProvider = Provider<AnalyticsSupabaseService>((ref) {
  throw UnimplementedError('analyticsService must be overridden');
});

final errorLoggingServiceProvider = Provider<ErrorLoggingService>((ref) {
  throw UnimplementedError('errorLoggingService must be overridden');
});

final performanceMonitorProvider = Provider<PerformanceMonitorService>((ref) {
  throw UnimplementedError('performanceMonitor must be overridden');
});