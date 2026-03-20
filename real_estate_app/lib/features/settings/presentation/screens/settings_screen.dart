// features/settings/presentation/screens/settings_screen.dart
// FIXED VERSION with proper delete account functionality and Advertiser Dashboard

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patamjengo_app/features/settings/presentation/screens/app_translations.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../presentation/screens/login_screen.dart';
import '../../../admin/admin_dashboard_screen.dart';
import '../../../subscriptions/data/models/subscription_model.dart';
import '../providers/app_providers.dart';
import '../../../advertising/presentation/screens/advertiser_dashboard.dart';
import 'notification_settings_screen.dart';
import 'notifications_screen.dart';
import 'language_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'privacy_settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'help_center_screen.dart';
import 'feed_back_screen.dart';
import 'rate_us_handler.dart';
import 'terms_of_service_screen.dart';
import '../../../properties/presentation/screens/archive_screen.dart';
import 'currency_settings_screen.dart';
import '../../../subscriptions/presentation/screens/subscription_screen.dart';
import '../../../../core/utils/responsive_helper.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // Sign out handler
  Future<void> _handleSignOut(
      BuildContext context, WidgetRef ref, String Function(String) t) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: t('sign_out_title'),
      message: t('sign_out_message'),
      confirmText: t('sign_out'),
      cancelText: t('cancel'),
      isDanger: false,
    );

    if (!confirmed) return;

    // Store navigator and messenger before async operations
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      print('🔄 Starting sign out process...');

      // Perform logout
      await ref.read(authNotifierProvider.notifier).logout();

      print('📱 Logout completed');

      // Small delay
      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate using stored navigator
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );

      print('🚪 Navigated to LoginScreen');

      // Show success message
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(t('signed_out_successfully')),
              backgroundColor: ThemeConfig.secondaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          print('ℹ️ Could not show snackbar: $e');
        }
      });
    } catch (e) {
      print('❌ Sign out error: $e');

      // Still navigate to login
      try {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      } catch (navError) {
        print('❌ Navigation error: $navError');
      }
    }
  }

  // FIXED: Delete account handler with proper TextEditingController management
  Future<void> _handleDeleteAccount(
      BuildContext context, WidgetRef ref, String Function(String) t) async {
    // First confirmation
    final firstConfirm = await DialogUtils.showConfirmDialog(
      context: context,
      title: t('delete_account_title'),
      message: t('delete_account_warning'),
      confirmText: t('continue'),
      cancelText: t('cancel'),
      isDanger: true,
    );

    if (!firstConfirm || !context.mounted) return;

    // Get current user for email display
    final currentUser = ref.read(authNotifierProvider).value;
    if (currentUser == null) {
      if (context.mounted) {
        SnackbarUtils.showError(context, t('user_not_found'));
      }
      return;
    }

    // Second confirmation with password
    // FIXED: Don't create controller here - let dialog manage it
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DeleteAccountDialog(
        t: t,
        userEmail: currentUser.email,
      ),
    );

    // If cancelled or null, return
    if (result == null || !context.mounted) return;

    final password = result;

    if (!context.mounted) return;

    // Store navigator and messenger before async operations
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading dialog and store the dialog context
    bool isLoadingDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                    Text(t('deleting_account')),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      print('🗑️ Starting account deletion process...');

      // Call the delete account method from auth provider
      final error = await ref.read(authNotifierProvider.notifier).deleteAccount(
            email: currentUser.email,
            password: password,
          );

      // Close loading dialog safely
      if (isLoadingDialogShowing && context.mounted) {
        isLoadingDialogShowing = false;
        navigator.pop(); // Close loading dialog
      }

      if (error != null) {
        // Show error message
        print('❌ Account deletion failed: $error');

        if (context.mounted) {
          // Wait a moment before showing error to avoid overlap
          await Future.delayed(const Duration(milliseconds: 100));

          if (context.mounted) {
            SnackbarUtils.showError(context, error);
          }
        }
        return;
      }

      // Success - account deleted
      print('✅ Account deleted successfully');

      // Small delay for user to see success
      await Future.delayed(const Duration(milliseconds: 300));

      // Navigate to login screen
      if (context.mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }

      // Show success message
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(t('account_deleted_successfully')),
              backgroundColor: ThemeConfig.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (e) {
          print('ℹ️ Could not show snackbar: $e');
        }
      });
    } catch (e) {
      print('❌ Account deletion error: $e');

      // Close loading dialog safely
      if (isLoadingDialogShowing && context.mounted) {
        isLoadingDialogShowing = false;
        try {
          navigator.pop(); // Close loading dialog
        } catch (popError) {
          print('⚠️ Error closing loading dialog: $popError');
        }
      }

      // Wait a moment before showing error
      await Future.delayed(const Duration(milliseconds: 100));

      // Show error message
      if (context.mounted) {
        SnackbarUtils.showError(context, t('account_deletion_failed'));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final currentLanguage = ref.watch(languageProvider).languageCode;
    final showFab = ref.watch(showAddPropertyFabProvider);
    final user = ref.watch(authNotifierProvider).value;

    String t(String key) => AppTranslations.translate(key, currentLanguage);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('settings')),
      ),
      body: ListView(
        children: [
          // User Info Card
          if (user != null)
            Container(
              margin: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              decoration: BoxDecoration(
                color: ThemeConfig.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                border: Border.all(
                  color: ThemeConfig.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: ThemeConfig.primaryColor,
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 24),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Subscription
          Consumer(
            builder: (context, ref, child) {
              final user = ref.watch(authNotifierProvider).value;
              if (user == null) return const SizedBox.shrink();

              final statsAsync = ref.watch(
                  subscriptionStatsProvider(user.id)); // FIXED: Removed space

              return statsAsync.when(
                data: (stats) {
                  final tierName = stats?.tier.displayName ?? 'Free';
                  final tierColor = stats?.tier == SubscriptionTier.pro
                      ? Colors.purple
                      : Colors.grey;

                  return ListTile(
                    leading: Icon(
                      Icons.workspace_premium,
                      color: tierColor,
                    ),
                    title: const Text('Subscription'),
                    subtitle: Text(tierName),
                    trailing: Icon(Icons.arrow_forward_ios, size: ResponsiveHelper.getResponsiveIconSize(context)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                  );
                },
                loading: () => const ListTile(
                  leading: Icon(Icons.workspace_premium),
                  title: Text('Subscription'),
                  subtitle: Text('Loading...'),
                ),
                error: (error, stack) => ListTile(
                  leading:
                      const Icon(Icons.workspace_premium, color: Colors.grey),
                  title: const Text('Subscription'),
                  subtitle: const Text('Free'), // Default to Free on error
                  trailing: Icon(Icons.arrow_forward_ios, size: ResponsiveHelper.getResponsiveIconSize(context)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    );
                  },
                ),
                
              );
            },
          ),

          

          // ✅ FIXED: Complete tile with error handling
_SettingsTile(
  icon: Icons.campaign,
  title: t('advertiser_dashboard'),
  subtitle: t('manage_your_ad_campaigns'),
  onTap: () async {
    // Check authentication
    if (user == null) {
      SnackbarUtils.showError(
        context,
        t('user_not_authenticated'),
      );
      return;
    }

    // Block non-TZ users — Selcom (ad funding) is Tanzania-only
    const _kSelcomCountries = {'TZ'};
    const _kCountryNames = {
      'KE': 'Kenya', 'UG': 'Uganda', 'RW': 'Rwanda',
      'ET': 'Ethiopia', 'BI': 'Burundi', 'MZ': 'Mozambique',
      'ZM': 'Zambia', 'ZW': 'Zimbabwe',
    };
    final userCountry = user.country;
    if (userCountry != null &&
        userCountry.isNotEmpty &&
        !_kSelcomCountries.contains(userCountry)) {
      final countryName = _kCountryNames[userCountry] ?? userCountry;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Text('🌍', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('Coming Soon'),
            ],
          ),
          content: Text(
            'The Advertiser Dashboard is currently available in Tanzania only '
            'because ad funding requires Selcom.\n\n'
            '$countryName support is on our roadmap — '
            'we\'ll notify you when it\'s available in your region.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    // Navigate with error handling
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdvertiserDashboard(),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
      SnackbarUtils.showError(
        context,
        t('error_loading_dashboard'),
      );
    }
  },
),

Consumer(
            builder: (context, ref, child) {
              // We use a FutureBuilder to check admin status asynchronously
              return FutureBuilder<bool>(
                future: ref.read(adminServiceProvider).isCurrentUserAdmin(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == true) {
                    return _SettingsTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin Dashboard',
                      subtitle: 'App management and moderation',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminDashboardScreen(),
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),

          _SectionHeader(title: t('general')),
          // ── Notification Settings ───────────────────────────────────────
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: t('notifications'),
            subtitle: t('manage_notification_preferences'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsSettingsScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.language,
            title: t('language'),
            subtitle: _getLanguageName(currentLanguage),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LanguageSettingsScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.attach_money,
            title: t('currency'),
            subtitle: _getCurrencyName(ref.watch(currencyProvider)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CurrencySettingsScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: t('theme'),
            subtitle: _getThemeName(currentTheme),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ThemeSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline,
                color: ThemeConfig.textSecondaryColor),
            title: Text(t('show_add_property_fab')),
            subtitle: Text(t('show_floating_button')),
            trailing: Switch(
              value: showFab,
              activeThumbColor: ThemeConfig.primaryColor,
              onChanged: (value) {
                ref.read(showAddPropertyFabProvider.notifier).toggleFab(value);
              },
            ),
          ),

          _SectionHeader(title: t('account')),
          _SettingsTile(
            icon: Icons.person_outline,
            title: t('edit_profile'),
            subtitle: t('update_personal_information'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: t('change_password'),
            subtitle: t('update_password'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.archive_outlined,
            title: t('archived_properties'),
            subtitle: t('view_archived_properties'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ArchiveScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.logout,
            title: t('sign_out'),
            subtitle: t('sign_out_account'),
            titleColor: ThemeConfig.primaryColor,
            onTap: () => _handleSignOut(context, ref, t),
          ),
          _SettingsTile(
            icon: Icons.delete_forever,
            title: t('delete_account'),
            subtitle: t('permanently_delete_account'),
            titleColor: ThemeConfig.errorColor,
            onTap: () => _handleDeleteAccount(context, ref, t),
          ),

          _SectionHeader(title: t('support')),
          _SettingsTile(
            icon: Icons.help_outline,
            title: t('help_center'),
            subtitle: t('get_help_support'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpCenterScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.feedback_outlined,
            title: t('send_feedback'),
            subtitle: t('share_thoughts'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FeedbackScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.star_outline,
            title: t('rate_us'),
            subtitle: t('rate_app_store'),
            onTap: () {
              RateUsHandler.openAppStore(context);
            },
          ),

          _SectionHeader(title: t('about')),
          _SettingsTile(
            icon: Icons.info_outline,
            title: t('about'),
            subtitle: '${t('version')} ${AppConstants.appVersion}',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationIcon: const Icon(
                  Icons.home_work,
                  size: 48,
                  color: ThemeConfig.primaryColor,
                ),
                children: const [
                  Text(
                    'A modern property platform for buying, selling, and renting properties in East Africa.',
                  ),
                ],
              );
            },
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: t('terms_of_service'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsOfServiceScreen(),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: t('privacy_policy'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),

          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
        ],
      ),
    );
  }

  String _getLanguageName(String languageCode) {
    final languages = {
      'en': 'English',
      'sw': 'Kiswahili',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'ar': 'العربية',
      'zh': '中文',
    };
    return languages[languageCode] ?? 'English';
  }

  String _getCurrencyName(String currencyCode) {
    final currencies = {
      'TZS': 'Tanzanian Shilling (TSh)',
      'USD': 'US Dollar (\$)',
      'EUR': 'Euro (€)',
      'GBP': 'British Pound (£)',
      'KES': 'Kenyan Shilling (KSh)',
      'UGX': 'Ugandan Shilling (USh)',
    };
    return currencies[currencyCode] ?? 'Tanzanian Shilling (TSh)';
  }

  String _getThemeName(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return 'Light mode';
      case AppThemeMode.dark:
        return 'Dark mode';
      case AppThemeMode.system:
        return 'System default';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ThemeConfig.primaryColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: titleColor ?? ThemeConfig.textSecondaryColor,
      ),
      title: Text(
        title,
        style: titleColor != null
            ? TextStyle(color: titleColor, fontWeight: FontWeight.w600)
            : null,
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// Delete Account Confirmation Dialog
class _DeleteAccountDialog extends StatefulWidget {
  final String Function(String) t;
  final String userEmail;

  const _DeleteAccountDialog({
    required this.t,
    required this.userEmail,
  });

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController _passwordController;
  String? errorMessage;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning, color: ThemeConfig.errorColor),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(child: Text(widget.t('confirm_account_deletion'))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.t('will_permanently_delete'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Text('• ${widget.t('profile_and_personal_info')}'),
            Text('• ${widget.t('all_property_listings')}'),
            Text('• ${widget.t('messages_and_conversations')}'),
            Text('• ${widget.t('favorites_and_saved')}'),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            Text(
              widget.t('enter_password_to_confirm'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Text(
              '${widget.t('email')}: ${widget.userEmail}',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            TextField(
              controller: _passwordController,
              obscureText: true,
              enabled: !isProcessing,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.t('password'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                errorText: errorMessage,
              ),
              onChanged: (value) {
                // Clear error when user types
                if (errorMessage != null) {
                  setState(() {
                    errorMessage = null;
                  });
                }
              },
              onSubmitted: (value) {
                if (value.isNotEmpty && !isProcessing) {
                  _handleConfirm();
                }
              },
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Text(
              widget.t('account_deletion_warning'),
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                color: ThemeConfig.errorColor,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isProcessing
              ? null
              : () {
                  // Return null to indicate cancellation
                  Navigator.pop(context, null);
                },
          child: Text(widget.t('cancel')),
        ),
        ElevatedButton(
          onPressed: isProcessing ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConfig.errorColor,
            disabledBackgroundColor: Colors.grey,
          ),
          child: isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(widget.t('delete_account')),
        ),
      ],
    );
  }

  void _handleConfirm() {
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        errorMessage = widget.t('please_enter_password');
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        errorMessage = widget.t('password_too_short');
      });
      return;
    }

    // Close dialog and return the password
    Navigator.pop(context, password);
  }
  
}