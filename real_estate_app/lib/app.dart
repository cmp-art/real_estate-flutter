// lib/app.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/theme_config.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/logger.dart';
import 'features/main_navigation/presentation/screens/main_screen.dart';
import 'features/settings/presentation/providers/app_providers.dart';
import 'features/settings/presentation/screens/reset_password_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'main.dart';

// Provider to track password recovery state
final isPasswordRecoveryProvider = StateProvider<bool>((ref) => false);

// Provider to track guest mode (browsing without an account)
final isGuestModeProvider = StateProvider<bool>((ref) => false);

class PatamjengoApp extends ConsumerStatefulWidget {
  const PatamjengoApp({super.key});

  @override
  ConsumerState<PatamjengoApp> createState() => _PatamjengoAppState();
}

class _PatamjengoAppState extends ConsumerState<PatamjengoApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      
      logger.d('🔐 Auth event: $event');
      
      if (event == AuthChangeEvent.passwordRecovery) {
        logger.d('✅ Password recovery event detected - navigating to reset screen');
        ref.read(isPasswordRecoveryProvider.notifier).state = true;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = _navigatorKey.currentState;
          if (navigator != null) {
            logger.d('🚀 Pushing ResetPasswordScreen to navigator');
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const ResetPasswordScreen(),
              ),
              (route) => false,
            );
          } else {
            logger.e('❌ Navigator not available');
          }
        });
      } 
      else if (event == AuthChangeEvent.signedIn) {
        logger.d('✅ User signed in - refreshing auth state');
        ref.read(isPasswordRecoveryProvider.notifier).state = false;
        // Only refresh when the notifier hasn't already started loading the user.
        // If isLoading=true, signInWithGoogle() / signInWithApple() is still in
        // progress and will set state=data(user) itself — calling refreshUser()
        // here would create a race that sets state=loading AFTER the user data
        // is already set, dropping the user back to SplashScreen.
        // For the Chrome Custom Tabs path: state is data(null) when signedIn
        // fires (because we never kicked off a native sign-in), so refreshUser()
        // IS called and loads the user correctly.
        final current = ref.read(authNotifierProvider);
        if (!current.isLoading && current.valueOrNull == null) {
          ref.read(authNotifierProvider.notifier).refreshUser();
        }
      }
      else if (event == AuthChangeEvent.signedOut) {
        logger.d('🚪 User signed out - clearing recovery state');
        ref.read(isPasswordRecoveryProvider.notifier).state = false;
        ref.read(isGuestModeProvider.notifier).state = false;
        // DO NOT invalidate authNotifierProvider here — logout() already sets
        // state = AsyncValue.data(null). Invalidating disposes the notifier
        // while logout() is still running, causing "Bad state: Tried to use
        // AuthNotifier after dispose was called".
      }
    });
  }

  /// Re-apply the correct status-bar style whenever the theme changes so
  /// there is never a stale blue bar from a previous build pass.
  void _applyStatusBarStyle(ThemeMode mode) {
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeActualProvider);
    final locale = ref.watch(languageProvider);

    // Apply status-bar style on every theme change (including first build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyStatusBarStyle(themeMode);
    });

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Patamjengo - Buy, Sell & Rent Property in Tanzania | Real Estate',
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('sw', 'TZ'),
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper>
    with WidgetsBindingObserver {
  bool _refreshRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fires whenever the app comes back to the foreground — most importantly
  /// when Chrome Custom Tabs closes after OAuth. At that point the Supabase
  /// session is already set, but the notifier may not know yet.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshSession();
    }
  }

  void _checkAndRefreshSession() {
    final session = supabase.auth.currentSession;
    final authState = ref.read(authNotifierProvider);
    if (session != null && authState.valueOrNull == null && !authState.isLoading) {
      logger.d('🔄 App resumed with session but no user — triggering refresh');
      ref.read(authNotifierProvider.notifier).refreshUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isPasswordRecovery = ref.watch(isPasswordRecoveryProvider);
    // Watch the raw Supabase auth stream so AuthWrapper rebuilds the instant
    // the session changes (OAuth callback, logout, token refresh, etc.).
    ref.watch(supabaseAuthStreamProvider);

    final currentSession = supabase.auth.currentSession;
    final hasActiveSession = currentSession != null;

    logger.d('🔍 AuthWrapper - Session exists: $hasActiveSession');
    logger.d('🔍 AuthWrapper - Password recovery: $isPasswordRecovery');

    // Password recovery takes priority
    if (isPasswordRecovery) {
      logger.d('🔐 Password recovery mode - showing ResetPasswordScreen');
      return const ResetPasswordScreen();
    }

    // No session → check guest mode first
    if (!hasActiveSession) {
      final isGuestMode = ref.watch(isGuestModeProvider);
      if (isGuestMode) {
        logger.d('👤 Guest mode active - showing MainScreen');
        return const MainScreen();
      }
      logger.d('❌ No active session - showing LoginScreen');
      _refreshRequested = false;
      return const LoginScreen();
    }

    // Session exists but notifier hasn't loaded the user yet.
    // Trigger refreshUser() once as a fallback safety net.
    if (!authState.isLoading && authState.valueOrNull == null) {
      if (!_refreshRequested) {
        _refreshRequested = true;
        logger.d('🔄 Session active but user null — triggering refresh');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final current = ref.read(authNotifierProvider);
            if (current.valueOrNull == null && !current.isLoading) {
              ref.read(authNotifierProvider.notifier).refreshUser();
            }
          }
        });
      }
      logger.d('⏳ Waiting for user data - showing SplashScreen');
      return const SplashScreen();
    }

    // User is loaded — reset flag so the next logout/sign-in cycle works
    _refreshRequested = false;

    return authState.when(
      data: (user) {
        if (user == null) {
          logger.d('📱 User null after refresh - showing LoginScreen');
          return const LoginScreen();
        } else {
          logger.d('✅ User logged in - showing MainScreen');
          return const MainScreen();
        }
      },
      loading: () {
        logger.d('⏳ Auth loading - showing SplashScreen');
        return const SplashScreen();
      },
      error: (error, stack) {
        logger.e('❌ Auth error', error: error, stackTrace: stack);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Authentication error: ${error.toString()}'),
                backgroundColor: ThemeConfig.errorColor,
              ),
            );
          }
        });
        return const LoginScreen();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ThemeConfig.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work, size: 80, color: Colors.white),
            SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}