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
      'app_name': 'Makazi Estate',
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