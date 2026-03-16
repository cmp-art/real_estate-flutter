import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/login_screen.dart';

/// Route guard that requires authentication
class AuthGuard extends ConsumerWidget {
  final Widget child;

  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // User not authenticated, redirect to login
          return const LoginScreen();
        }
        // User authenticated, show the protected screen
        return child;
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => const LoginScreen(),
    );
  }
}

/// Route guard that redirects authenticated users
/// (useful for login/register screens)
class GuestOnlyGuard extends ConsumerWidget {
  final Widget child;
  final Widget authenticatedRedirect;

  const GuestOnlyGuard({
    super.key,
    required this.child,
    required this.authenticatedRedirect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // User is authenticated, redirect to home
          return authenticatedRedirect;
        }
        // User not authenticated, show login/register
        return child;
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => child,
    );
  }
}