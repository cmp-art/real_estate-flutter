// lib/presentation/screens/splash_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/theme_config.dart';
import '../../core/utils/logger.dart';
import '../../features/main_navigation/presentation/screens/main_screen.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const String _tag = 'SplashScreen';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  /// Returns true when running in a mobile browser (phone/tablet web or PWA).
  /// Uses screen width as a reliable proxy: phones are <600 logical px wide.
  bool get _isMobileWeb {
    if (!kIsWeb) return false;
    return MediaQuery.sizeOf(context).width < 600;
  }

  Future<void> _showMobileWebWarning() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.phone_android_rounded, color: Colors.orange, size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Better on Desktop or App',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patamjengo works best on a desktop browser or the Android app. '
              'Some features (like photo uploads) may not work correctly on mobile browsers.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            _WarningOption(
              icon: Icons.computer_rounded,
              color: ThemeConfig.primaryColor,
              title: 'Use on PC / Desktop',
              subtitle: 'Open patamjengo.netlify.app on a desktop browser',
            ),
            const SizedBox(height: 10),
            _WarningOption(
              icon: Icons.android_rounded,
              color: Colors.green,
              title: 'Download Android App',
              subtitle: 'Get the full experience from Google Play Store',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue anyway',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.android_rounded, size: 18),
            label: const Text('Play Store'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(
                  'https://play.google.com/store/apps/details?id=com.patamjengo.app');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Warn mobile web / PWA users before proceeding
    if (_isMobileWeb) await _showMobileWebWarning();
    if (!mounted) return;

    try {
      final authState = ref.read(authNotifierProvider);

      authState.when(
        data: (user) {
          if (mounted) {
            if (user != null) {
              logger.d('User logged in, navigating to MainScreen');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainScreen()),
              );
            } else {
              logger.d('No user, navigating to LoginScreen');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          }
        },
        loading: () {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              logger.d('Timeout, navigating to LoginScreen');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          });
        },
        error: (error, stack) {
          logger.e('Auth error', error: error, stackTrace: stack);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        },
      );
    } catch (e, stack) {
      logger.e('Exception', error: e, stackTrace: stack);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.home_work,
                size: 70,
                color: ThemeConfig.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Patamjengo',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Makazi Yako Yanaanza Hapa',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helper widget used inside the mobile-web warning dialog ─────────────
class _WarningOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _WarningOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}