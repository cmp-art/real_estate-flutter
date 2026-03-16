import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/snackbar_utils.dart';
import 'app_translations.dart';

import '../../../../presentation/providers/auth_provider.dart';
import '../providers/app_providers.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    final languageCode = ref.read(languageProvider).languageCode;
    
    if (value == null || value.isEmpty) {
      return AppTranslations.translate('please_confirm_your_password', languageCode);
    }
    if (value != _newPasswordController.text) {
      return AppTranslations.translate('passwords_do_not_match', languageCode);
    }
    return null;
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final languageCode = ref.read(languageProvider).languageCode;
      
      // Call the auth provider to change password
      final errorMessage = await ref.read(authNotifierProvider.notifier).changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (errorMessage == null) {
          // Success
          SnackbarUtils.showSuccess(
            context, 
            AppTranslations.translate('password_changed_successfully', languageCode),
          );
          Navigator.pop(context);
        } else {
          // Error occurred
          SnackbarUtils.showError(context, errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final languageCode = ref.read(languageProvider).languageCode;
        SnackbarUtils.showError(
          context, 
          AppTranslations.translate('an_unexpected_error_occurred', languageCode),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = ref.watch(languageProvider).languageCode;
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('change_password', languageCode)),
        elevation: isDesktop ? 0 : null,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.getMaxFormWidth(context),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              children: [
                if (isDesktop) ...[
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),
                  Text(
                    AppTranslations.translate('change_password', languageCode),
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        mobile: 24,
                        desktop: 28,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                ],
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('current_password', languageCode),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
                      },
                    ),
                  ),
                  validator: Validators.validatePassword,
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('new_password', languageCode),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureNewPassword = !_obscureNewPassword);
                      },
                    ),
                  ),
                  validator: Validators.validatePassword,
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('confirm_new_password', languageCode),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: _validateConfirmPassword,
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleChangePassword,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2),
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
                      : Text(
                          AppTranslations.translate('change_password', languageCode),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              mobile: 16,
                              desktop: 18,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}