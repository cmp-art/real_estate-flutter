// Create this file: lib/core/utils/currency_helper.dart

class CurrencyHelper {
  static const Map<String, Map<String, String>> currencies = {
    'TZS': {
      'symbol': 'TSh',
      'name': 'Tanzanian Shilling',
    },
    'USD': {
      'symbol': '\$',
      'name': 'US Dollar',
    },
    
  };

  static String getSymbol(String currencyCode) {
    return currencies[currencyCode]?['symbol'] ?? '\$';
  }

  static String getName(String currencyCode) {
    return currencies[currencyCode]?['name'] ?? 'US Dollar';
  }
}