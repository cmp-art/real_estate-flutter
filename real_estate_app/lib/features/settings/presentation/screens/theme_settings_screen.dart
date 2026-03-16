import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme_config.dart';
import 'app_translations.dart';
import '../providers/app_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final languageCode = ref.watch(languageProvider).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('theme', languageCode)),
      ),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
            child: Text(
              AppTranslations.translate('choose_preferred_theme', languageCode),
              style: const TextStyle(color: ThemeConfig.textSecondaryColor),
            ),
          ),
          RadioListTile<AppThemeMode>(
            title: Text(AppTranslations.translate('light_mode', languageCode)),
            subtitle: Text(AppTranslations.translate('always_use_light_theme', languageCode)),
            value: AppThemeMode.light,
            groupValue: currentTheme,
            activeColor: ThemeConfig.primaryColor,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
            secondary: const Icon(Icons.light_mode),
          ),
          RadioListTile<AppThemeMode>(
            title: Text(AppTranslations.translate('dark_mode', languageCode)),
            subtitle: Text(AppTranslations.translate('always_use_dark_theme', languageCode)),
            value: AppThemeMode.dark,
            groupValue: currentTheme,
            activeColor: ThemeConfig.primaryColor,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          RadioListTile<AppThemeMode>(
            title: Text(AppTranslations.translate('system_default', languageCode)),
            subtitle: Text(AppTranslations.translate('follow_system_settings', languageCode)),
            value: AppThemeMode.system,
            groupValue: currentTheme,
            activeColor: ThemeConfig.primaryColor,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
            secondary: const Icon(Icons.brightness_auto),
          ),
        ],
      ),
    );
  }
}