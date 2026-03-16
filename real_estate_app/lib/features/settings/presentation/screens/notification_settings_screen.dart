// lib/features/settings/presentation/screens/notification_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../presentation/providers/auth_provider.dart';
import 'app_translations.dart';
import '../providers/app_providers.dart';
import '../../../subscriptions/data/models/subscription_model.dart';
import './notification_filter_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final languageCode = ref.watch(languageProvider).languageCode;

    // ── FIX: use real auth provider — _getCurrentUserId was always returning null ──
    final userId = ref.watch(authNotifierProvider).value?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('notifications', languageCode)),
        backgroundColor: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightAppBarBackground,
            darkColor: ThemeConfig.darkAppBarBackground),
        foregroundColor: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightAppBarForeground,
            darkColor: ThemeConfig.darkAppBarForeground),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppTranslations.translate('manage_notification_preferences', languageCode),
              // ── FIX: ThemeConfig has no static textSecondaryColor field ──
              style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context)),
            ),
          ),

          // ── Global Settings ──────────────────────────────────────────────
          _SectionHeader(title: AppTranslations.translate('global_settings', languageCode)),

          SwitchListTile(
            title: Text(AppTranslations.translate('push_notifications', languageCode)),
            subtitle: Text(AppTranslations.translate('receive_push_notifications', languageCode)),
            value: settings.pushNotifications,
            activeThumbColor: ThemeConfig.getPrimaryColor(context),
            onChanged: (value) => ref
                .read(notificationSettingsProvider.notifier)
                .updateSetting('push_notifications', value),
          ),

          const Divider(),

          SwitchListTile(
            title: Text(AppTranslations.translate('email_notifications', languageCode)),
            subtitle: Text(AppTranslations.translate('receive_email_notifications', languageCode)),
            value: settings.emailNotifications,
            activeThumbColor: ThemeConfig.getPrimaryColor(context),
            onChanged: (value) => ref
                .read(notificationSettingsProvider.notifier)
                .updateSetting('email_notifications', value),
          ),

          const Divider(height: 32, thickness: 8),

          // ── Property Alerts ──────────────────────────────────────────────
          _SectionHeader(title: AppTranslations.translate('property_alerts', languageCode)),

          _AlertTile(
            title: AppTranslations.translate('new_property_alerts', languageCode),
            subtitle: AppTranslations.translate('get_notified_new_properties', languageCode),
            value: settings.newPropertyAlerts,
            settingKey: 'new_property_alerts',
            filterCategory: 'new_property',
            filterCategoryTitle: AppTranslations.translate('new_property_alerts', languageCode),
            languageCode: languageCode,
          ),

          const Divider(),

          _AlertTile(
            title: AppTranslations.translate('price_change_alerts', languageCode),
            subtitle: AppTranslations.translate('get_notified_price_changes', languageCode),
            value: settings.priceChangeAlerts,
            settingKey: 'price_change_alerts',
            filterCategory: 'price_change',
            filterCategoryTitle: AppTranslations.translate('price_change_alerts', languageCode),
            languageCode: languageCode,
          ),

          const Divider(),

          // ── Price Drop Alerts (Pro) ───────────────────────────────────────
          if (userId != null)
            _PriceDropAlertTile(userId: userId, settings: settings, languageCode: languageCode)
          else
            // Not signed in — show greyed-out tile, don't crash
            _GuestPriceDropTile(languageCode: languageCode),

          const Divider(height: 32, thickness: 8),

          // ── Messages ─────────────────────────────────────────────────────
          _SectionHeader(title: AppTranslations.translate('messages', languageCode)),

          SwitchListTile(
            title: Text(AppTranslations.translate('message_notifications', languageCode)),
            subtitle: Text(AppTranslations.translate('get_notified_new_messages', languageCode)),
            value: settings.messageNotifications,
            activeThumbColor: ThemeConfig.getPrimaryColor(context),
            onChanged: (value) => ref
                .read(notificationSettingsProvider.notifier)
                .updateSetting('message_notifications', value),
          ),

          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT TILE — switch + optional filter button
// Must be a ConsumerWidget to read providers and navigate
// ─────────────────────────────────────────────────────────────────────────────

class _AlertTile extends ConsumerWidget {
  final String title;
  final String subtitle;
  final bool value;
  final String settingKey;
  final String filterCategory;
  final String filterCategoryTitle;
  final String languageCode;

  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.settingKey,
    required this.filterCategory,
    required this.filterCategoryTitle,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: AppTranslations.translate('configure_filters', languageCode),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationFilterScreen(
                    category: filterCategory,
                    categoryTitle: filterCategoryTitle,
                  ),
                ),
              ),
            ),
          Switch(
            value: value,
            activeThumbColor: ThemeConfig.getPrimaryColor(context),
            onChanged: (newValue) => ref
                .read(notificationSettingsProvider.notifier)
                .updateSetting(settingKey, newValue),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRICE DROP ALERT TILE — subscription-gated Pro feature
// ─────────────────────────────────────────────────────────────────────────────

class _PriceDropAlertTile extends ConsumerWidget {
  final String userId;
  final NotificationSettings settings;
  final String languageCode;

  const _PriceDropAlertTile({
    required this.userId,
    required this.settings,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(userSubscriptionProvider(userId));

    return subscriptionAsync.when(
      data: (subscription) {
        final isPro = subscription?.tier == SubscriptionTier.pro;
        return _buildContent(context, ref, isPro: isPro);
      },
      loading: () => ListTile(
        title: Row(children: [
          Text(AppTranslations.translate('price_drop_alerts', languageCode)),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        subtitle: Text(AppTranslations.translate('loading_subscription_status', languageCode)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, {required bool isPro}) {
    return Stack(
      children: [
        Opacity(
          opacity: isPro ? 1.0 : 0.5,
          child: ListTile(
            title: Row(children: [
              Text(AppTranslations.translate('price_drop_alerts', languageCode)),
              if (!isPro) ...[
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.purple, borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context))),
                  child: Text(
                    AppTranslations.translate('pro', languageCode),
                    style: TextStyle(
                        color: Colors.white, fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ]),
            subtitle: Text(AppTranslations.translate('instant_price_drop_alerts', languageCode)),
            trailing: isPro && settings.priceDropAlerts
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.tune_rounded),
                      tooltip: AppTranslations.translate('manage_alerts', languageCode),
                      onPressed: () => Navigator.of(context).pushNamed('/price-drop-alerts'),
                    ),
                    Switch(
                      value: settings.priceDropAlerts,
                      activeThumbColor: Colors.purple,
                      onChanged: (value) => ref
                          .read(notificationSettingsProvider.notifier)
                          .updateSetting('price_drop_alerts', value),
                    ),
                  ])
                : Switch(
                    value: isPro ? settings.priceDropAlerts : false,
                    activeThumbColor: Colors.purple,
                    onChanged: isPro
                        ? (value) => ref
                            .read(notificationSettingsProvider.notifier)
                            .updateSetting('price_drop_alerts', value)
                        : null,
                  ),
          ),
        ),
        // Invisible tap target for non-Pro — shows upgrade dialog
        if (!isPro)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showUpgradeDialog(context),
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context))),
        title: Row(children: [
          const Icon(Icons.workspace_premium, color: Colors.purple),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          Expanded(child: Text(AppTranslations.translate('upgrade_to_pro', languageCode))),
        ]),
        // ── FIX: wrap content in SingleChildScrollView to prevent overflow on small screens ──
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.translate('pro_feature_description', languageCode),
                style: const TextStyle(fontSize: 15),
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              Text(AppTranslations.translate('with_pro_you_get', languageCode),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              ...[
                'instant_price_drop_alerts',
                'custom_price_thresholds',
                'track_unlimited_properties',
                'priority_customer_support',
                'no_advertisements',
              ].map((key) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: ResponsiveHelper.getResponsiveIconSize(context)),
                      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      Expanded(
                        child: Text(AppTranslations.translate(key, languageCode),
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ]),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppTranslations.translate('maybe_later', languageCode)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/subscription');
            },
            child: Text(AppTranslations.translate('upgrade_now', languageCode)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GUEST PRICE DROP TILE — shown when user is not signed in
// ─────────────────────────────────────────────────────────────────────────────

class _GuestPriceDropTile extends StatelessWidget {
  final String languageCode;
  const _GuestPriceDropTile({required this.languageCode});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: ListTile(
        title: Row(children: [
          Text(AppTranslations.translate('price_drop_alerts', languageCode)),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.purple, borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context))),
            child: Text(AppTranslations.translate('pro', languageCode),
                style: TextStyle(
                    color: Colors.white, fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10), fontWeight: FontWeight.bold)),
          ),
        ]),
        subtitle: Text(AppTranslations.translate('instant_price_drop_alerts', languageCode)),
        trailing: const Switch(value: false, onChanged: null),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
              color: ThemeConfig.getPrimaryColor(context))),
    );
  }
}