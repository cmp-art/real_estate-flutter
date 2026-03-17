// lib/features/authentication/presentation/widgets/social_sign_in_buttons.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/logger.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../core/utils/responsive_helper.dart';

class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getResponsiveHorizontalPadding(context)),
              child: Text(
                'OR',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ThemeConfig.textSecondaryColor,
                    ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
        const GoogleSignInButton(),
        
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          const AppleSignInButton(),
        ],
      ],
    );
  }
}

class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      logger.d('User clicked Google Sign-In button');

      if (kIsWeb) {
        // Web: redirect the current browser tab via Supabase OAuth.
        // PKCE code is automatically exchanged when the page reloads.
        // Requires Google provider enabled in Supabase Dashboard → Auth → Providers.
        final launched = await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'https://makaziestate.com',
          authScreenLaunchMode: LaunchMode.platformDefault,
        );
        logger.d('Web signInWithOAuth launched: $launched');
        if (!launched && mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Google sign-in unavailable. '
                'Enable the Google provider in Supabase Dashboard → Auth → Providers.',
              ),
              backgroundColor: ThemeConfig.errorColor,
              duration: Duration(seconds: 6),
            ),
          );
        }
        // If launched: browser redirects away, no further action needed.
        return;
      }

      // ── Mobile ────────────────────────────────────────────────────────────
      // Step 1: Try the native Google account picker (dialog inside the app).
      //         Requires SHA-1 fingerprint registered in Google Cloud Console
      //         for the project that owns GOOGLE_WEB_CLIENT_ID.
      logger.d('Mobile: attempting native Google Sign-In…');
      final nativeSuccess =
          await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;

      if (nativeSuccess) {
        setState(() => _isLoading = false);
        return;
      }

      // Check whether it was a user cancellation.
      final authState = ref.read(authNotifierProvider);
      final errMsg = authState.error?.toString().toLowerCase() ?? '';
      if (errMsg.contains('cancelled')) {
        setState(() => _isLoading = false);
        return;
      }

      // Step 2: native failed (DEVELOPER_ERROR / SHA-1 not registered yet).
      // Fall back to an in-app browser overlay:
      //   • Android → Chrome Custom Tabs (stays within app, NOT a separate browser app)
      //   • iOS     → SFSafariViewController (same in-app feel)
      // After auth, Supabase redirects to realestateapp://login-callback and
      // the app receives it via app_links — user never truly "leaves" the app.
      logger.w('Native Google Sign-In not configured — falling back to in-app browser OAuth');
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'realestateapp://login-callback',
        authScreenLaunchMode: LaunchMode.platformDefault,
      );
      logger.d('Mobile signInWithOAuth launched: $launched');

      if (!launched && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google sign-in unavailable. '
              'Enable the Google provider in Supabase Dashboard → Auth → Providers.',
            ),
            backgroundColor: ThemeConfig.errorColor,
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }

      // Overlay opened — Supabase auth-state stream fires when the deep link
      // callback arrives; AuthWrapper then navigates to MainScreen.
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      logger.e('Google Sign-In error', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: ${e.toString()}'),
            backgroundColor: ThemeConfig.errorColor,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.grey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 24,
                    width: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

class AppleSignInButton extends ConsumerStatefulWidget {
  const AppleSignInButton({super.key});

  @override
  ConsumerState<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends ConsumerState<AppleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

    try {
      logger.d('User clicked Apple Sign-In button');
      final success = await ref.read(authNotifierProvider.notifier).signInWithApple();

      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apple Sign-In failed. Please try again.'),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      }
    } catch (e) {
      logger.e('Apple Sign-In error', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple Sign-In failed: ${e.toString()}'),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAppleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apple, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.white),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  Text(
                    'Continue with Apple',
                    style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}