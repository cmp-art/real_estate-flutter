// lib/core/utils/currency_utils.dart

class CurrencyUtils {
  // Map of currency codes to their data
  static const Map<String, Map<String, String>> currencyData = {
    'TZS': {
      'name': 'Tanzanian Shilling',
      'nativeName': 'Shilingi ya Tanzania',
      'symbol': 'TSh',
      'flag': '🇹🇿',
    },
    'USD': {
      'name': 'US Dollar',
      'nativeName': 'US Dollar',
      'symbol': '\$',
      'flag': '🇺🇸',
    },
    
  };

  /// Get currency symbol for a given currency code
  static String getSymbol(String currencyCode) {
    return currencyData[currencyCode]?['symbol'] ?? currencyCode;
  }

  /// Get currency name for a given currency code
  static String getName(String currencyCode) {
    return currencyData[currencyCode]?['name'] ?? currencyCode;
  }

  /// Get currency native name for a given currency code
  static String getNativeName(String currencyCode) {
    return currencyData[currencyCode]?['nativeName'] ?? currencyCode;
  }

  /// Get currency flag emoji for a given currency code
  static String getFlag(String currencyCode) {
    return currencyData[currencyCode]?['flag'] ?? '';
  }

  /// Format a price with the currency symbol
  /// Example: formatPrice(1000000, 'TZS') => "TSh 1,000,000"
  static String formatPrice(double price, String currencyCode) {
    final symbol = getSymbol(currencyCode);
    final formattedNumber = _formatNumber(price);
    
    // For USD, EUR, GBP - put symbol before number
    if (currencyCode == 'USD') {
      return '$symbol$formattedNumber';
    }
    
    // For others (TZS, KES, UGX) - put symbol before with space
    return '$symbol $formattedNumber';
  }

  /// Format a number with thousand separators
  static String _formatNumber(double number) {
    final parts = number.toStringAsFixed(0).split('.');
    final integerPart = parts[0];
    
    // Add thousand separators
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formatted = integerPart.replaceAllMapped(regExp, (match) => ',');
    
    return formatted;
  }

  /// Format price range with currency
  /// Example: formatPriceRange(100000, 500000, 'TZS') => "TSh 100,000 - TSh 500,000"
  static String formatPriceRange(double? minPrice, double? maxPrice, String currencyCode) {
    final symbol = getSymbol(currencyCode);
    
    if (minPrice != null && maxPrice != null) {
      return '${formatPrice(minPrice, currencyCode)} - ${formatPrice(maxPrice, currencyCode)}';
    } else if (minPrice != null) {
      return 'From ${formatPrice(minPrice, currencyCode)}';
    } else if (maxPrice != null) {
      return 'Up to ${formatPrice(maxPrice, currencyCode)}';
    }
    
    return 'Any price';
  }
}