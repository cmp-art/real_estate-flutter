import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/validators.dart';

import '../../../../presentation/providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref
        .read(authNotifierProvider.notifier)
        .resetPassword(_emailController.text.trim());

    if (mounted) {
      setState(() {
        _isLoading = false;
        _emailSent = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            backgroundColor: ThemeConfig.secondaryColor,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send reset email. Please try again.'),
            backgroundColor: ThemeConfig.errorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        elevation: isDesktop ? 0 : null,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: ResponsiveHelper.getMaxFormWidth(context),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_reset,
                      size: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        mobile: 80,
                        tablet: 90,
                        desktop: 100,
                      ),
                      color: ThemeConfig.primaryColor,
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                    Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          mobile: 24,
                          tablet: 28,
                          desktop: 32,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

                    Text(
                      _emailSent
                          ? 'We\'ve sent a password reset link to your email. Please check your inbox and follow the instructions.'
                          : 'Enter your email address and we\'ll send you a link to reset your password.',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          mobile: 16,
                          tablet: 17,
                          desktop: 18,
                        ),
                        color: ThemeConfig.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

                    if (!_emailSent) ...[
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleResetPassword(),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: Validators.validateEmail,
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Send Reset Link',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                                    context,
                                    mobile: 16,
                                    desktop: 18,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.check_circle_outline,
                        size: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          mobile: 60,
                          tablet: 70,
                          desktop: 80,
                        ),
                        color: ThemeConfig.secondaryColor,
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                      Container(
                        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                        decoration: BoxDecoration(
                          color: ThemeConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.getResponsiveBorderRadius(context),
                          ),
                          border: Border.all(
                            color: ThemeConfig.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: ResponsiveHelper.getResponsiveIconSize(context) * 0.8,
                                  color: ThemeConfig.primaryColor,
                                ),
                                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                                Text(
                                  'Next Steps',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ThemeConfig.primaryColor,
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                                      context,
                                      mobile: 16,
                                      desktop: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                            _buildStep('1', 'Check your email inbox'),
                            _buildStep('2', 'Click the reset password link'),
                            _buildStep('3', 'Enter your new password in the browser'),
                            _buildStep('4', 'Return to the app and login'),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2),
                          ),
                        ),
                        child: Text(
                          'Back to Login',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              mobile: 16,
                              desktop: 18,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),

                      TextButton(
                        onPressed: () {
                          setState(() => _emailSent = false);
                        },
                        child: Text(
                          'Didn\'t receive the email? Send again',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              mobile: 14,
                              desktop: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveHelper.getResponsiveSpacing(context),
      ),
      child: Row(
        children: [
          Container(
            width: ResponsiveHelper.getResponsiveFontSize(context, mobile: 24, desktop: 28),
            height: ResponsiveHelper.getResponsiveFontSize(context, mobile: 24, desktop: 28),
            decoration: const BoxDecoration(
              color: ThemeConfig.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                    context,
                    mobile: 12,
                    desktop: 14,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  desktop: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}