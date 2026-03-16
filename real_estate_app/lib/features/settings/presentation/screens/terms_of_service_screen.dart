import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/responsive_helper.dart';
import 'app_translations.dart';

import '../../../settings/presentation/providers/app_providers.dart';

class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(languageProvider).languageCode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('terms_of_service', languageCode)),
        elevation: ResponsiveHelper.isDesktop(context) ? 0 : null,
      ),
      body: ResponsiveContainer(
        maxWidth: ResponsiveHelper.getMaxContentWidth(context),
        child: ListView(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          children: [
            Text(
              AppTranslations.translate('terms_of_service', languageCode),
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
              languageCode,
              'acceptance_of_terms',
              'terms_acceptance_text',
            ),
            _buildSection(
              languageCode,
              'use_license',
              'terms_license_text',
            ),
            _buildSection(
              languageCode,
              'user_accounts',
              'terms_accounts_text',
            ),
            _buildSection(
              languageCode,
              'property_listings',
              'terms_listings_text',
            ),
            _buildSection(
              languageCode,
              'prohibited_uses',
              'terms_prohibited_text',
            ),
            _buildSection(
              languageCode,
              'disclaimer',
              'terms_disclaimer_text',
            ),
            _buildSection(
              languageCode,
              'limitations',
              'terms_limitations_text',
            ),
            _buildSection(
              languageCode,
              'modifications',
              'terms_modifications_text',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String languageCode, String titleKey, String contentKey) {
    return Builder(
      builder: (context) => Padding(
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
      ),
    );
  }
}