// lib/app.dart
import 'package:flutter/material.dart';
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

class RealEstateApp extends ConsumerStatefulWidget {
  const RealEstateApp({super.key});

  @override
  ConsumerState<RealEstateApp> createState() => _RealEstateAppState();
}

class _RealEstateAppState extends ConsumerState<RealEstateApp> {
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
        logger.d('✅ User signed in - clearing recovery state');
        ref.read(isPasswordRecoveryProvider.notifier).state = false;
      } 
      else if (event == AuthChangeEvent.signedOut) {
        logger.d('🚪 User signed out - clearing recovery state');
        ref.read(isPasswordRecoveryProvider.notifier).state = false;
        // Force auth state refresh
        ref.invalidate(authNotifierProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeActualProvider);
    final locale = ref.watch(languageProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
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

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isPasswordRecovery = ref.watch(isPasswordRecoveryProvider);
    
    // CRITICAL FIX: Always check actual Supabase session
    final currentSession = supabase.auth.currentSession;
    final hasActiveSession = currentSession != null;
    
    logger.d('🔍 AuthWrapper - Session exists: $hasActiveSession');
    logger.d('🔍 AuthWrapper - Password recovery: $isPasswordRecovery');
    
    // Password recovery takes priority
    if (isPasswordRecovery) {
      logger.d('🔐 Password recovery mode - showing ResetPasswordScreen');
      return const ResetPasswordScreen();
    }
    
    // If no active session, always show login
    if (!hasActiveSession) {
      logger.d('❌ No active session - showing LoginScreen');
      return const LoginScreen();
    }
    
    // Has session - check auth state
    return authState.when(
      data: (user) {
        if (user == null) {
          logger.d('📱 User is null despite session - showing LoginScreen');
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