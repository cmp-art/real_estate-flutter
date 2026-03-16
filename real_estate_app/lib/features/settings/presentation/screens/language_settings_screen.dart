import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/snackbar_utils.dart';

import '../providers/app_providers.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    final languages = {
      'en': {'name': 'English', 'nativeName': 'English', 'flag': '🇬🇧'},
      'sw': {'name': 'Swahili', 'nativeName': 'Kiswahili', 'flag': '🇹🇿'},
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
        elevation: isDesktop ? 0 : null,
      ),
      body: ResponsiveContainer(
        maxWidth: ResponsiveHelper.getMaxContentWidth(context, isWide: false),
        child: ListView.builder(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          itemCount: languages.length,
          itemBuilder: (context, index) {
            final languageCode = languages.keys.elementAt(index);
            final languageData = languages[languageCode]!;
            final isSelected = currentLanguage.languageCode == languageCode;

            return Card(
              elevation: isSelected ? 2 : 0,
              margin: EdgeInsets.only(
                bottom: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getResponsivePadding(context),
                  vertical: ResponsiveHelper.getResponsiveSpacing(context) / 2,
                ),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      languageData['flag']!,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          mobile: 32,
                          tablet: 36,
                          desktop: 40,
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: ThemeConfig.primaryColor,
                      )
                    else
                      const Icon(
                        Icons.circle_outlined,
                        color: Colors.grey,
                      ),
                  ],
                ),
                title: Text(
                  languageData['nativeName']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? ThemeConfig.primaryColor : null,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 16,
                      tablet: 17,
                      desktop: 18,
                    ),
                  ),
                ),
                subtitle: Text(
                  languageData['name']!,
                  style: TextStyle(
                    color: isSelected 
                        ? ThemeConfig.primaryColor.withOpacity(0.7)
                        : Colors.grey[600],
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.done,
                        color: ThemeConfig.primaryColor,
                        size: ResponsiveHelper.getResponsiveIconSize(context),
                      )
                    : null,
                onTap: () async {
                  if (languageCode != currentLanguage.languageCode) {
                    // Update language
                    await ref.read(languageProvider.notifier).setLanguage(languageCode);
                    
                    // Show success message
                    if (context.mounted) {
                      final message = languageCode == 'sw'
                          ? 'Lugha imebadilishwa kuwa ${languageData['nativeName']}'
                          : 'Language changed to ${languageData['nativeName']}';
                      
                      SnackbarUtils.showSuccess(context, message);
                      
                      // Pop back to settings after a short delay
                      await Future.delayed(const Duration(milliseconds: 800));
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}