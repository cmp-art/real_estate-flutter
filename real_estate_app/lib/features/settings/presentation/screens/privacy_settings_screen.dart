import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/responsive_helper.dart';
import 'app_translations.dart';

import '../../../settings/presentation/providers/app_providers.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(languageProvider).languageCode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('privacy', languageCode)),
        elevation: ResponsiveHelper.isDesktop(context) ? 0 : null,
      ),
      body: ResponsiveContainer(
        maxWidth: ResponsiveHelper.getMaxContentWidth(context),
        child: ListView(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          children: [
            Text(
              AppTranslations.translate('privacy_policy', languageCode),
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 24,
                  tablet: 28,
                  desktop: 32,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 2)),
            Text(
              '${AppTranslations.translate('last_updated', languageCode)}: January 11, 2026',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
            _buildSection(
              context,
              languageCode,
              'information_we_collect',
              'privacy_policy_info_collect',
            ),
            _buildSection(
              context,
              languageCode,
              'how_we_use_your_information',
              'privacy_policy_how_use',
            ),
            _buildSection(
              context,
              languageCode,
              'data_security',
              'privacy_policy_security',
            ),
            _buildSection(
              context,
              languageCode,
              'your_rights',
              'privacy_policy_rights',
            ),
            _buildSection(
              context,
              languageCode,
              'contact_us',
              'privacy_policy_contact',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String languageCode, String titleKey, String contentKey) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.translate(titleKey, languageCode),
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text(
            AppTranslations.translate(contentKey, languageCode),
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(
                context,
                mobile: 16,
                tablet: 17,
                desktop: 18,
              ),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}