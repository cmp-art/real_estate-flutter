// lib/presentation/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/theme_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../features/authentication/presentation/widget/social_sign_in_buttons.dart';

import '../providers/auth_provider.dart';
import '../../features/main_navigation/presentation/screens/main_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

// East African countries supported by Patamjengo
const _kCountries = [
  {'code': 'TZ', 'flag': '🇹🇿', 'name': 'Tanzania'},
  {'code': 'KE', 'flag': '🇰🇪', 'name': 'Kenya'},
  {'code': 'UG', 'flag': '🇺🇬', 'name': 'Uganda'},
  {'code': 'RW', 'flag': '🇷🇼', 'name': 'Rwanda'},
  {'code': 'ET', 'flag': '🇪🇹', 'name': 'Ethiopia'},
  {'code': 'BI', 'flag': '🇧🇮', 'name': 'Burundi'},
  {'code': 'MZ', 'flag': '🇲🇿', 'name': 'Mozambique'},
  {'code': 'ZM', 'flag': '🇿🇲', 'name': 'Zambia'},
  {'code': 'ZW', 'flag': '🇿🇼', 'name': 'Zimbabwe'},
];

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const String _tag = 'RegisterScreen';

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _selectedCountry = 'TZ'; // Default: Tanzania

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final success = await ref.read(authNotifierProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            country: _selectedCountry,
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        SnackbarUtils.showSuccess(context, 'Account created successfully!');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        final authState = ref.read(authNotifierProvider);
        String errorMessage = 'Registration failed. Please try again.';

        if (authState.hasError) {
          errorMessage = authState.error.toString();
          if (errorMessage.contains('already registered')) {
            errorMessage = 'This email is already registered. Please login instead.';
          } else if (errorMessage.contains('password')) {
            errorMessage = 'Password must be at least 8 characters long.';
          }
        }
        SnackbarUtils.showError(context, errorMessage);
      }
    } catch (e, stack) {
      logger.e('Registration error', error: e, stackTrace: stack);
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showError(context, 'An unexpected error occurred. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isLoading,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to get started',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: ThemeConfig.textSecondaryColor,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
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
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: Validators.validatePassword,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      enabled: !_isLoading,
                      onFieldSubmitted: (_) => _handleRegister(),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: 16),

                    // Country dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCountry,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        hintText: 'Select your country',
                        prefixIcon: Icon(Icons.public_outlined),
                      ),
                      items: _kCountries.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['code'],
                          child: Text('${c['flag']}  ${c['name']}'),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (v) => setState(() => _selectedCountry = v),
                      validator: (v) =>
                          v == null ? 'Please select your country' : null,
                    ),
                    const SizedBox(height: 32),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
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
                              'Create Account',
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
                          'Already have an account? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  );
                                },
                          child: const Text('Login'),
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