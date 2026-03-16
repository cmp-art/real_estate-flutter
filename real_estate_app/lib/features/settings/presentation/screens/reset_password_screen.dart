// features/settings/presentation/screens/reset_password_screen.dart
// FULLY RESPONSIVE VERSION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../main.dart';
import '../../../../presentation/screens/login_screen.dart';
import '../../../../app.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const String _tag = 'ResetPassword';

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showCancelDialog = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onCancel() async {
    if (_isLoading) return;

    if (_passwordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty) {
      setState(() => _showCancelDialog = true);
      
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text(
            'You have entered password information. Are you sure you want to cancel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: ThemeConfig.errorColor,
              ),
              child: const Text('Discard'),
            ),
          ],
        ),
      );

      setState(() => _showCancelDialog = false);
      if (shouldCancel != true) return;
    }

    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    try {
      logger.d('🚪 Canceling password reset - signing out and navigating to login');
      
      final session = supabase.auth.currentSession;
      if (session != null && supabase.auth.currentUser != null) {
        await supabase.auth.signOut();
        logger.d('✅ Signed out recovery session');
      }
      
      ref.read(isPasswordRecoveryProvider.notifier).state = false;
      logger.d('✅ Cleared password recovery state');
      
    } catch (e, stack) {
      logger.w('⚠️ Error during cancel cleanup', error: e, stackTrace: stack);
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      logger.d('✅ Navigated to LoginScreen');
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      logger.d('🔄 Updating password...');
      
      final response = await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (response.user == null) {
        throw Exception('Password update failed - no user returned');
      }

      logger.d('✅ Password updated successfully for: ${response.user!.email}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully! Please login with your new password.'),
          backgroundColor: ThemeConfig.successColor,
          duration: Duration(seconds: 3),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      logger.d('🚪 Signing out after password update...');
      
      await supabase.auth.signOut();
      logger.d('✅ Signed out successfully');
      
      ref.read(isPasswordRecoveryProvider.notifier).state = false;
      logger.d('✅ Cleared password recovery state');
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      logger.d('✅ Navigated to LoginScreen');
      
    } catch (e, stack) {
      logger.e('❌ Password update error', error: e, stackTrace: stack);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage = 'An error occurred while updating your password';
      
      if (e is AuthException) {
        errorMessage = e.message;
        logger.e('AuthException: ${e.message}');
      } else if (e.toString().contains('session')) {
        errorMessage = 'Your reset session has expired. Please request a new password reset link.';
        logger.e('Session expired error');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: ThemeConfig.errorColor,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _onCancel();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Set New Password',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(
                context,
                mobile: 20,
                tablet: 22,
              ),
            ),
          ),
          leading: _isLoading || _showCancelDialog
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _onCancel,
                ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                ResponsiveHelper.getResponsivePadding(context),
              ),
              child: ResponsiveContainer(
                maxWidth: ResponsiveHelper.getMaxFormWidth(context),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: ResponsiveHelper.getResponsiveSpacing(
                          context,
                          multiplier: 5,
                        ),
                      ),
                      Icon(
                        Icons.lock_reset,
                        size: ResponsiveHelper.isMobile(context) ? 80 : 100,
                        color: ThemeConfig.primaryColor,
                      ),
                      SizedBox(
                        height: ResponsiveHelper.getResponsiveSpacing(
                          context,
                          multiplier: 3,
                        ),
                      ),
                      Text(
                        'Create New Password',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobile: 24,
                            tablet: 28,
                            desktop: 32,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                        height: ResponsiveHelper.getResponsiveSpacing(
                          context,
                          multiplier: 1.5,
                        ),
                      ),
                      Text(
                        'Please enter your new password. Make sure it\'s strong and secure.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: ThemeConfig.textSecondaryColor,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobile: 14,
                            tablet: 16,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                        height: ResponsiveHelper.getResponsiveSpacing(
                          context,
                          multiplier: 5,
                        ),
                      ),
                      
                      // New Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobile: 16,
                            tablet: 18,
                          ),
                        ),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: 'Enter new password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword 
                                ? Icons.visibility_outlined 
                                : Icons.visibility_off_outlined,
                            ),
                            onPressed: _isLoading 
                              ? null 
                              : () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(
                        height: ResponsiveHelper.getResponsiveSpacing(
                          context,
                          multiplier: 2,
                        ),
                      ),
                      
                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _updatePassword(),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobile: 16,
                            tablet: 18,
                          ),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Re-enter new password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword 
                                ? Icons.visibility_outlined 
                                : Icons.visibility_off_outlined,
                            ),
                            onPressed: _isLoading 
                              ? null 
                              : () => setState(() => 
                                  _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      SizedBox(
                        height: ResponsiveHelper.getResponsiveSpacing(
                          context,
                          multiplier: 3,
                        ),
                      ),
                      
                      // Password Requirements Info Box
                      Container(
                        padding: EdgeInsets.all(
                          ResponsiveHelper.getResponsivePadding(context),
                        ),
                        decoration: BoxDecoration(
                          color: ThemeConfig.infoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.getResponsiveBorderRadius(context),
                          ),
                          border: Border.all(
                            color: ThemeConfig.infoColor.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password Requirements:',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(
                                  context,
                                  mobile: 14,
                                  tablet: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• At least 6 characters long\n'
                              '• Contains a mix of letters and numbers (recommended)\n'
                              '• Avoid common passwords',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(
                                  context,
                                  mobile: 12,
                                  tablet: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: ResponsiveHelper.getResponsiveSpacing(
                          context,
                          multiplier: 4,
                        ),
                      ),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _onCancel,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: ResponsiveHelper.isMobile(context) ? 16 : 18,
                                ),
                                side: BorderSide(
                                  color: ThemeConfig.errorColor.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: ThemeConfig.errorColor,
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                                    context,
                                    mobile: 16,
                                    tablet: 18,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updatePassword,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: ResponsiveHelper.isMobile(context) ? 16 : 18,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Update Password',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                                          context,
                                          mobile: 16,
                                          tablet: 18,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
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
      ),
    );
  }
}