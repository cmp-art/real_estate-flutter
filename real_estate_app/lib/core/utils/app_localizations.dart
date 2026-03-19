// Create this file: lib/core/l10n/app_localizations.dart

import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Common
      'app_name': 'Patamjengo',
      'welcome': 'Welcome',
      'hello': 'Hello',
      
      // Settings
      'settings': 'Settings',
      'app_settings': 'App Settings',
      'account': 'Account',
      'support': 'Support',
      'about': 'About',
      
      // Language
      'language': 'Language',
      'language_changed': 'Language changed to',
      
      // Currency
      'currency': 'Currency',
      'currency_changed': 'Currency changed to',
      
      // Theme
      'theme': 'Theme',
      'light_mode': 'Light mode',
      'dark_mode': 'Dark mode',
      'system_default': 'System default',
      
      // Properties
      'property': 'Property',
      'properties': 'Properties',
      'for_sale': 'For Sale',
      'for_rent': 'For Rent',
      'per_month': 'per month',
      'per_year': 'per year',
      
      // Property Details
      'bedrooms': 'Bedrooms',
      'bathrooms': 'Bathrooms',
      'area': 'Area',
      'price': 'Price',
      'location': 'Location',
      'description': 'Description',
      'status': 'Status',
      
      // Actions
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'update': 'Update',
      'create': 'Create',
      'search': 'Search',
      'filter': 'Filter',
      
      // Messages
      'success': 'Success',
      'error': 'Error',
      'loading': 'Loading...',
      'no_data': 'No data available',

      // Ads - user facing
      'sponsored': 'Sponsored',
      'ad_media_unavailable': 'Ad media unavailable',
      'video_ad': 'VIDEO AD',

      // Advertiser Dashboard
      'advertiser_dashboard': 'Advertiser Dashboard',
      'loading_dashboard': 'Loading Dashboard...',
      'retry': 'Retry',
      'unable_load_advertiser': 'Unable to load advertiser data',
      'new_campaign': 'New Campaign',
      'quick_actions': 'Quick Actions',
      'add_funds': 'Add Funds',
      'billing_history': 'Billing History',
      'performance_overview': 'Performance Overview',
      'impressions': 'Impressions',
      'clicks': 'Clicks',
      'active': 'Active',
      'avg_ctr': 'Avg CTR',
      'account_balance': 'Account Balance',
      'total_spent': 'Total Spent',
      'low_balance': 'Low Balance',
      'my_campaigns': 'My Campaigns',
      'no_campaigns_yet': 'No campaigns yet',
      'create_first_campaign': 'Create your first campaign to start advertising',
      'create_campaign': 'Create Campaign',
      'delete_campaign': 'Delete Campaign',
      'delete_campaign_title': 'Delete Campaign?',
      'delete_campaign_history': 'All spend, impressions and click history are preserved for billing records.',
      'campaign_deleted': 'Campaign deleted successfully',
      'budget': 'Budget',
      'ad_approved': 'Ad Approved',
      'ad_rejected': 'Ad Rejected',
      'pending_review': 'Pending Admin Review',
      'user_not_authenticated': 'User not authenticated. Please sign in.',
      'unable_create_advertiser': 'Unable to create advertiser account',
    },
    
    'sw': { // Swahili (Kiswahili)
      // Common
      'app_name': 'Mali',
      'welcome': 'Karibu',
      'hello': 'Habari',
      
      // Settings
      'settings': 'Mipangilio',
      'app_settings': 'Mipangilio ya Programu',
      'account': 'Akaunti',
      'support': 'Msaada',
      'about': 'Kuhusu',
      
      // Language
      'language': 'Lugha',
      'language_changed': 'Lugha imebadilishwa kuwa',
      
      // Currency
      'currency': 'Sarafu',
      'currency_changed': 'Sarafu imebadilishwa kuwa',
      
      // Theme
      'theme': 'Mandhari',
      'light_mode': 'Hali ya mwangaza',
      'dark_mode': 'Hali ya giza',
      'system_default': 'Chaguo-msingi la mfumo',
      
      // Properties
      'property': 'Mali',
      'properties': 'Mali',
      'for_sale': 'Kwa Kuuza',
      'for_rent': 'Kwa Kukodisha',
      'per_month': 'kwa mwezi',
      'per_year': 'kwa mwaka',
      
      // Property Details
      'bedrooms': 'Vyumba vya Kulala',
      'bathrooms': 'Vyumba vya Kuoga',
      'area': 'Eneo',
      'price': 'Bei',
      'location': 'Mahali',
      'description': 'Maelezo',
      'status': 'Hali',
      
      // Actions
      'save': 'Hifadhi',
      'cancel': 'Ghairi',
      'delete': 'Futa',
      'edit': 'Hariri',
      'update': 'Sasisha',
      'create': 'Unda',
      'search': 'Tafuta',
      'filter': 'Chuja',
      
      // Messages
      'success': 'Imefanikiwa',
      'error': 'Hitilafu',
      'loading': 'Inapakia...',
      'no_data': 'Hakuna data',

      // Ads - user facing
      'sponsored': 'Inafadhiliwa',
      'ad_media_unavailable': 'Picha ya tangazo haipatikani',
      'video_ad': 'TANGAZO LA VIDEO',

      // Advertiser Dashboard
      'advertiser_dashboard': 'Dashibodi ya Mtangazaji',
      'loading_dashboard': 'Inapakia Dashibodi...',
      'retry': 'Jaribu Tena',
      'unable_load_advertiser': 'Imeshindwa kupakia data ya mtangazaji',
      'new_campaign': 'Kampeni Mpya',
      'quick_actions': 'Vitendo vya Haraka',
      'add_funds': 'Ongeza Fedha',
      'billing_history': 'Historia ya Malipo',
      'performance_overview': 'Muhtasari wa Utendaji',
      'impressions': 'Maonyesho',
      'clicks': 'Mibonyezo',
      'active': 'Inafanya Kazi',
      'avg_ctr': 'CTR ya Wastani',
      'account_balance': 'Salio la Akaunti',
      'total_spent': 'Jumla Iliyotumika',
      'low_balance': 'Salio Chini',
      'my_campaigns': 'Kampeni Zangu',
      'no_campaigns_yet': 'Hakuna kampeni bado',
      'create_first_campaign': 'Unda kampeni yako ya kwanza kuanza kutangaza',
      'create_campaign': 'Unda Kampeni',
      'delete_campaign': 'Futa Kampeni',
      'delete_campaign_title': 'Futa Kampeni?',
      'delete_campaign_history': 'Historia yote ya matumizi, maonyesho na mibonyezo imehifadhiwa kwa kumbukumbu za malipo.',
      'campaign_deleted': 'Kampeni imefutwa',
      'budget': 'Bajeti',
      'ad_approved': 'Tangazo Limeidhinishwa',
      'ad_rejected': 'Tangazo Limekataliwa',
      'pending_review': 'Inasubiri Ukaguzi wa Msimamizi',
      'user_not_authenticated': 'Mtumiaji hajathibitishwa. Tafadhali ingia.',
      'unable_create_advertiser': 'Imeshindwa kuunda akaunti ya mtangazaji',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Convenience getters
  String get appName => translate('app_name');
  String get settings => translate('settings');
  String get language => translate('language');
  String get currency => translate('currency');
  String get theme => translate('theme');
  String get properties => translate('properties');
  String get forSale => translate('for_sale');
  String get forRent => translate('for_rent');
  String get perMonth => translate('per_month');
  String get perYear => translate('per_year');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get delete => translate('delete');
  String get edit => translate('edit');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'sw', 'es', 'fr', 'de', 'it', 'pt', 'ar', 'zh', 'ja', 'ko', 'ru', 'hi']
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}