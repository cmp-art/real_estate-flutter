// lib/main.dart
// PRODUCTION VERSION — Supabase + Firebase Cloud Messaging (FCM)
// FCM is free (no cost per message, no limits) and handles push for
// Android (background/killed), iOS (background/killed), and Web/PWA.

// ignore_for_file: unused_import

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/utils/app_lifecycle_observer.dart';
import 'core/utils/logger.dart';
import 'core/services/analytics_supabase_service.dart';
import 'core/services/error_logging_service.dart';
import 'core/services/performance_monitor_service.dart';
import 'core/services/push_notification_service.dart';
import 'firebase_options.dart';

// ── FCM background message handler ──────────────────────────────────────────
// Must be a TOP-LEVEL function (not a method). Runs in a separate Dart isolate
// when a data-only FCM message arrives while the app is killed/backgrounded.
// Messages that include a `notification` field are shown automatically by the
// OS without this handler being called.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FlutterFire auto-initialises Firebase before calling this handler.
  // Only needed for data-only messages — notification messages are shown by OS.
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

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

  // Register FCM background handler BEFORE Firebase.initializeApp()
  // (Required by firebase_messaging — must be first thing after ensureInitialized)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── FIREBASE INITIALIZATION ─────────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.d('✅ Firebase initialized');
  } catch (e, s) {
    logger.e('❌ Firebase initialization error', error: e, stackTrace: s);
    // App can still run without FCM; Supabase Realtime covers foreground push
  }

  // ========================================
  // ENVIRONMENT VARIABLES - LOAD FIRST
  // ========================================
  // Strategy: --dart-define values (baked in at build time) take priority.
  // .env file is used as a fallback for local development only.
  try {
    await dotenv.load(fileName: "assets/.env");
    logger.d('.env file loaded successfully');
  } catch (e) {
    logger.d('.env file not found — relying on --dart-define values');
  }

  // Overlay --dart-define values (production/Netlify) over any .env values.
  // String.fromEnvironment reads values compiled in via --dart-define at build time.
  const defineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const defineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const defineGoogleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  if (defineSupabaseUrl.isNotEmpty) {
    dotenv.env['SUPABASE_URL'] = defineSupabaseUrl;
    logger.d('SUPABASE_URL loaded from --dart-define');
  }
  if (defineAnonKey.isNotEmpty) {
    dotenv.env['SUPABASE_ANON_KEY'] = defineAnonKey;
    logger.d('SUPABASE_ANON_KEY loaded from --dart-define');
  }
  if (defineGoogleClientId.isNotEmpty) {
    dotenv.env['GOOGLE_WEB_CLIENT_ID'] = defineGoogleClientId;
  }

  _verifyEnvironmentVariables();

  AppLifecycleObserver().initialize();

  // Orientation: portrait-only on mobile (hard lock — ignores system auto-rotate).
  // DeviceOrientation.values on web/desktop allows all orientations.
  if (kIsWeb) {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Apply initial status-bar style BEFORE the first frame so there is no
  // brief flash of the default Android blue bar.  The AppBarTheme's
  // systemOverlayStyle only takes effect once an AppBar widget is on screen,
  // so we must also set it here for splash / login screens that have no AppBar.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // will be overridden per-theme
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

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
    return; // Stop main() — do not proceed to runApp(PatamjengoApp)
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
  // PUSH NOTIFICATIONS
  // Foreground: Supabase Realtime → local banner (all platforms)
  // Background/killed: FCM → OS push (Android, iOS, Web/PWA)
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
      child: const PatamjengoApp(),
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

  // ── Password-reset flow ────────────────────────────────────────────────────
  if (uri.host == 'reset-password' ||
      uri.path.contains('reset-password') ||
      uri.host == 'reset-callback') {
    logger.d('🔐 Password reset deep link detected');
    await _handlePasswordRecovery(uri);
    return;
  }

  // ── Supabase server-side auth callback (email verify, magic link, etc.) ───
  if (uri.path.contains('/auth/v1/callback') ||
      uri.path.contains('/auth/v1/verify')) {
    logger.d('🔑 Supabase auth callback – exchanging code for session');
    try {
      await supabase.auth.getSessionFromUrl(uri);
    } catch (e) {
      logger.e('Failed to exchange Supabase auth callback', error: e);
    }
    return;
  }

  // ── OAuth login callback (Google Sign-In via Supabase redirect) ───────────
  // Deep link: patamjengo://login-callback?code=<pkce-code>
  // NOTE: supabase_flutter v2 automatically handles this deep link internally
  // via its own app_links listener and calls getSessionFromUrl() itself.
  // We must NOT call getSessionFromUrl() here — doing so would double-consume
  // the single-use PKCE code and cause "flow_state_not_found".
  if (uri.scheme == 'patamjengo' && uri.host == 'login-callback') {
    logger.d('🔑 OAuth login callback received – handled internally by supabase_flutter');
    return;
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