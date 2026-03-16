import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/currency_utils.dart';
import 'app_translations.dart';

import '../providers/app_providers.dart';

class CurrencySettingsScreen extends ConsumerWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCurrency = ref.watch(currencyProvider);
    final languageCode = ref.watch(languageProvider).languageCode;
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('currency', languageCode)),
        elevation: isDesktop ? 0 : null,
      ),
      body: ResponsiveContainer(
        maxWidth: ResponsiveHelper.getMaxContentWidth(context, isWide: false),
        child: Column(
          children: [
            // Info Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              margin: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
              decoration: BoxDecoration(
                color: ThemeConfig.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.getResponsiveBorderRadius(context),
                ),
                border: Border.all(
                  color: ThemeConfig.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: ThemeConfig.primaryColor,
                    size: ResponsiveHelper.getResponsiveIconSize(context),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  Expanded(
                    child: Text(
                      AppTranslations.translate('select_currency', languageCode),
                      style: TextStyle(
                        color: ThemeConfig.primaryColor,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          mobile: 14,
                          tablet: 15,
                          desktop: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Currency List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getResponsivePadding(context),
                ),
                itemCount: CurrencyUtils.currencyData.length,
                itemBuilder: (context, index) {
                  final currencyCode = CurrencyUtils.currencyData.keys.elementAt(index);
                  final isSelected = currentCurrency == currencyCode;

                  return Card(
                    elevation: isSelected ? 2 : 0,
                    margin: EdgeInsets.only(
                      bottom: ResponsiveHelper.getResponsiveSpacing(context),
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
                            CurrencyUtils.getFlag(currencyCode),
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
                        '${CurrencyUtils.getName(currencyCode)} (${CurrencyUtils.getSymbol(currencyCode)})',
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
                        '${CurrencyUtils.getNativeName(currencyCode)} • $currencyCode',
                        style: TextStyle(
                          color: isSelected 
                              ? ThemeConfig.primaryColor.withOpacity(0.7)
                              : Colors.grey[600],
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobile: 13,
                            tablet: 14,
                            desktop: 15,
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
                        if (currencyCode != currentCurrency) {
                          // Update currency
                          await ref.read(currencyProvider.notifier).setCurrency(currencyCode);
                          
                          // Show success message
                          if (context.mounted) {
                            final message = languageCode == 'sw'
                                ? '${AppTranslations.translate('currency_changed_to', languageCode)} ${CurrencyUtils.getNativeName(currencyCode)}'
                                : '${AppTranslations.translate('currency_changed_to', languageCode)} ${CurrencyUtils.getName(currencyCode)}';
                            
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
          ],
        ),
      ),
    );
  }
}