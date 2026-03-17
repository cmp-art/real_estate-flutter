// lib/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/theme_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/validators.dart';
import '../../features/authentication/presentation/widget/social_sign_in_buttons.dart';

import '../providers/auth_provider.dart';
import '../../features/main_navigation/presentation/screens/main_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const String _tag = 'LoginScreen';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(authNotifierProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        logger.d('Login successful');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        final authState = ref.read(authNotifierProvider);
        final errorMessage = authState.hasError
            ? authState.error.toString()
            : 'Login failed. Please check your credentials.';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: ThemeConfig.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stack) {
      logger.e('Login exception', error: e, stackTrace: stack);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.getResponsivePadding(context),
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveHelper.getMaxFormWidth(context),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.home_work,
                    size: 80,
                    color: ThemeConfig.primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: ThemeConfig.textSecondaryColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !_isLoading,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: Validators.validatePassword,
                  ),
                  const SizedBox(height: 8),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const SocialSignInButtons(),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterScreen(),
                                  ),
                                );
                              },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}