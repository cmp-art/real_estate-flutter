// core/constants/country_codes.dart
// Complete list of country codes with dial codes and flags

class CountryCode {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  @override
  String toString() => '$flag $name ($dialCode)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CountryCode && other.code == code;
  }
  
  @override
  int get hashCode => code.hashCode;
}

class CountryCodes {
  static const List<CountryCode> all = [
    // East Africa
    CountryCode(name: 'Tanzania', code: 'TZ', dialCode: '+255', flag: '🇹🇿'),
    CountryCode(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪'),
    CountryCode(name: 'Uganda', code: 'UG', dialCode: '+256', flag: '🇺🇬'),
    CountryCode(name: 'Rwanda', code: 'RW', dialCode: '+250', flag: '🇷🇼'),
    CountryCode(name: 'Burundi', code: 'BI', dialCode: '+257', flag: '🇧🇮'),
    CountryCode(name: 'Ethiopia', code: 'ET', dialCode: '+251', flag: '🇪🇹'),
    CountryCode(name: 'Somalia', code: 'SO', dialCode: '+252', flag: '🇸🇴'),
    CountryCode(name: 'South Sudan', code: 'SS', dialCode: '+211', flag: '🇸🇸'),
    
    // Southern Africa
    CountryCode(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦'),
    CountryCode(name: 'Botswana', code: 'BW', dialCode: '+267', flag: '🇧🇼'),
    CountryCode(name: 'Namibia', code: 'NA', dialCode: '+264', flag: '🇳🇦'),
    CountryCode(name: 'Zimbabwe', code: 'ZW', dialCode: '+263', flag: '🇿🇼'),
    CountryCode(name: 'Zambia', code: 'ZM', dialCode: '+260', flag: '🇿🇲'),
    CountryCode(name: 'Malawi', code: 'MW', dialCode: '+265', flag: '🇲🇼'),
    CountryCode(name: 'Mozambique', code: 'MZ', dialCode: '+258', flag: '🇲🇿'),
    CountryCode(name: 'Lesotho', code: 'LS', dialCode: '+266', flag: '🇱🇸'),
    CountryCode(name: 'Eswatini', code: 'SZ', dialCode: '+268', flag: '🇸🇿'),
    
    // West Africa
    CountryCode(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),
    CountryCode(name: 'Ghana', code: 'GH', dialCode: '+233', flag: '🇬🇭'),
    CountryCode(name: 'Senegal', code: 'SN', dialCode: '+221', flag: '🇸🇳'),
    CountryCode(name: 'Ivory Coast', code: 'CI', dialCode: '+225', flag: '🇨🇮'),
    CountryCode(name: 'Cameroon', code: 'CM', dialCode: '+237', flag: '🇨🇲'),
    CountryCode(name: 'Mali', code: 'ML', dialCode: '+223', flag: '🇲🇱'),
    CountryCode(name: 'Burkina Faso', code: 'BF', dialCode: '+226', flag: '🇧🇫'),
    CountryCode(name: 'Niger', code: 'NE', dialCode: '+227', flag: '🇳🇪'),
    CountryCode(name: 'Togo', code: 'TG', dialCode: '+228', flag: '🇹🇬'),
    CountryCode(name: 'Benin', code: 'BJ', dialCode: '+229', flag: '🇧🇯'),
    CountryCode(name: 'Guinea', code: 'GN', dialCode: '+224', flag: '🇬🇳'),
    CountryCode(name: 'Sierra Leone', code: 'SL', dialCode: '+232', flag: '🇸🇱'),
    CountryCode(name: 'Liberia', code: 'LR', dialCode: '+231', flag: '🇱🇷'),
    
    // North Africa
    CountryCode(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬'),
    CountryCode(name: 'Morocco', code: 'MA', dialCode: '+212', flag: '🇲🇦'),
    CountryCode(name: 'Algeria', code: 'DZ', dialCode: '+213', flag: '🇩🇿'),
    CountryCode(name: 'Tunisia', code: 'TN', dialCode: '+216', flag: '🇹🇳'),
    CountryCode(name: 'Libya', code: 'LY', dialCode: '+218', flag: '🇱🇾'),
    CountryCode(name: 'Sudan', code: 'SD', dialCode: '+249', flag: '🇸🇩'),
    
    // Central Africa
    CountryCode(name: 'Democratic Republic of the Congo', code: 'CD', dialCode: '+243', flag: '🇨🇩'),
    CountryCode(name: 'Republic of the Congo', code: 'CG', dialCode: '+242', flag: '🇨🇬'),
    CountryCode(name: 'Central African Republic', code: 'CF', dialCode: '+236', flag: '🇨🇫'),
    CountryCode(name: 'Chad', code: 'TD', dialCode: '+235', flag: '🇹🇩'),
    CountryCode(name: 'Gabon', code: 'GA', dialCode: '+241', flag: '🇬🇦'),
    CountryCode(name: 'Equatorial Guinea', code: 'GQ', dialCode: '+240', flag: '🇬🇶'),
    
    // Europe
    CountryCode(name: 'United Kingdom', code: 'GB', dialCode: '+44', flag: '🇬🇧'),
    CountryCode(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
    CountryCode(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
    CountryCode(name: 'Italy', code: 'IT', dialCode: '+39', flag: '🇮🇹'),
    CountryCode(name: 'Spain', code: 'ES', dialCode: '+34', flag: '🇪🇸'),
    CountryCode(name: 'Portugal', code: 'PT', dialCode: '+351', flag: '🇵🇹'),
    CountryCode(name: 'Netherlands', code: 'NL', dialCode: '+31', flag: '🇳🇱'),
    CountryCode(name: 'Belgium', code: 'BE', dialCode: '+32', flag: '🇧🇪'),
    CountryCode(name: 'Switzerland', code: 'CH', dialCode: '+41', flag: '🇨🇭'),
    CountryCode(name: 'Austria', code: 'AT', dialCode: '+43', flag: '🇦🇹'),
    CountryCode(name: 'Sweden', code: 'SE', dialCode: '+46', flag: '🇸🇪'),
    CountryCode(name: 'Norway', code: 'NO', dialCode: '+47', flag: '🇳🇴'),
    CountryCode(name: 'Denmark', code: 'DK', dialCode: '+45', flag: '🇩🇰'),
    CountryCode(name: 'Finland', code: 'FI', dialCode: '+358', flag: '🇫🇮'),
    CountryCode(name: 'Poland', code: 'PL', dialCode: '+48', flag: '🇵🇱'),
    CountryCode(name: 'Russia', code: 'RU', dialCode: '+7', flag: '🇷🇺'),
    CountryCode(name: 'Ukraine', code: 'UA', dialCode: '+380', flag: '🇺🇦'),
    CountryCode(name: 'Greece', code: 'GR', dialCode: '+30', flag: '🇬🇷'),
    CountryCode(name: 'Turkey', code: 'TR', dialCode: '+90', flag: '🇹🇷'),
    
    // Americas
    CountryCode(name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
    CountryCode(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
    CountryCode(name: 'Mexico', code: 'MX', dialCode: '+52', flag: '🇲🇽'),
    CountryCode(name: 'Brazil', code: 'BR', dialCode: '+55', flag: '🇧🇷'),
    CountryCode(name: 'Argentina', code: 'AR', dialCode: '+54', flag: '🇦🇷'),
    CountryCode(name: 'Chile', code: 'CL', dialCode: '+56', flag: '🇨🇱'),
    CountryCode(name: 'Colombia', code: 'CO', dialCode: '+57', flag: '🇨🇴'),
    CountryCode(name: 'Peru', code: 'PE', dialCode: '+51', flag: '🇵🇪'),
    CountryCode(name: 'Venezuela', code: 'VE', dialCode: '+58', flag: '🇻🇪'),
    
    // Asia
    CountryCode(name: 'China', code: 'CN', dialCode: '+86', flag: '🇨🇳'),
    CountryCode(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳'),
    CountryCode(name: 'Japan', code: 'JP', dialCode: '+81', flag: '🇯🇵'),
    CountryCode(name: 'South Korea', code: 'KR', dialCode: '+82', flag: '🇰🇷'),
    CountryCode(name: 'Indonesia', code: 'ID', dialCode: '+62', flag: '🇮🇩'),
    CountryCode(name: 'Thailand', code: 'TH', dialCode: '+66', flag: '🇹🇭'),
    CountryCode(name: 'Vietnam', code: 'VN', dialCode: '+84', flag: '🇻🇳'),
    CountryCode(name: 'Philippines', code: 'PH', dialCode: '+63', flag: '🇵🇭'),
    CountryCode(name: 'Malaysia', code: 'MY', dialCode: '+60', flag: '🇲🇾'),
    CountryCode(name: 'Singapore', code: 'SG', dialCode: '+65', flag: '🇸🇬'),
    CountryCode(name: 'Pakistan', code: 'PK', dialCode: '+92', flag: '🇵🇰'),
    CountryCode(name: 'Bangladesh', code: 'BD', dialCode: '+880', flag: '🇧🇩'),
    CountryCode(name: 'Saudi Arabia', code: 'SA', dialCode: '+966', flag: '🇸🇦'),
    CountryCode(name: 'United Arab Emirates', code: 'AE', dialCode: '+971', flag: '🇦🇪'),
    CountryCode(name: 'Israel', code: 'IL', dialCode: '+972', flag: '🇮🇱'),
    
    // Oceania
    CountryCode(name: 'Australia', code: 'AU', dialCode: '+61', flag: '🇦🇺'),
    CountryCode(name: 'New Zealand', code: 'NZ', dialCode: '+64', flag: '🇳🇿'),
  ];

  // Get default country code (Tanzania)
  static CountryCode get defaultCountry => all.first;

  // Search countries by name or dial code
  static List<CountryCode> search(String query) {
    if (query.isEmpty) return all;
    
    final lowerQuery = query.toLowerCase();
    return all.where((country) {
      return country.name.toLowerCase().contains(lowerQuery) ||
             country.dialCode.contains(query) ||
             country.code.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Find country by dial code
  static CountryCode? findByDialCode(String dialCode) {
    try {
      return all.firstWhere((country) => country.dialCode == dialCode);
    } catch (e) {
      return null;
    }
  }

  // Find country by country code
  static CountryCode? findByCode(String code) {
    try {
      return all.firstWhere((country) => country.code == code);
    } catch (e) {
      return null;
    }
  }
  
  // 🎯 NEW: Parse phone number to extract country code
  static CountryCode parsePhoneNumber(String phoneNumber) {
    // Remove spaces, dashes, parentheses
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Ensure it starts with +
    if (!cleanPhone.startsWith('+')) {
      if (cleanPhone.startsWith('0')) {
        // Assume default country (Tanzania)
        return defaultCountry;
      }
      cleanPhone = '+$cleanPhone';
    }
    
    // Sort by dial code length (longest first) to match correctly
    final sortedCountries = List<CountryCode>.from(all)
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    
    for (var country in sortedCountries) {
      if (cleanPhone.startsWith(country.dialCode)) {
        return country;
      }
    }
    
    // Default to Tanzania
    return defaultCountry;
  }
  
  // 🎯 NEW: Get local phone number (without country code)
  static String getLocalNumber(String phoneNumber, CountryCode countryCode) {
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    if (cleanPhone.startsWith(countryCode.dialCode)) {
      return cleanPhone.substring(countryCode.dialCode.length);
    }
    
    if (cleanPhone.startsWith('+')) {
      // Try to find matching country code
      final parsedCountry = parsePhoneNumber(cleanPhone);
      if (parsedCountry.code == countryCode.code) {
        return cleanPhone.substring(parsedCountry.dialCode.length);
      }
    }
    
    // Remove leading zeros
    return cleanPhone.replaceAll(RegExp(r'^0+'), '');
  }
  
  // 🎯 NEW: Build full international number
  static String buildFullNumber(CountryCode countryCode, String localNumber) {
    // Remove any leading zeros and non-digits
    String cleanLocal = localNumber.replaceAll(RegExp(r'[^\d]'), '');
    cleanLocal = cleanLocal.replaceAll(RegExp(r'^0+'), '');
    return '${countryCode.dialCode}$cleanLocal';
  }
  
  // 🎯 NEW: Check if country uses Selcom (Tanzania only)
  static bool usesSelcom(String countryCode) {
    return countryCode == 'TZ';
  }
  
  // 🎯 NEW: Check if country uses Flutterwave
  static bool usesFlutterwave(String countryCode) {
    return !usesSelcom(countryCode);
  }
  
  // 🎯 NEW: Get payment provider name
  static String getPaymentProvider(String countryCode) {
    return usesSelcom(countryCode) ? 'Selcom' : 'Flutterwave';
  }
  
  // 🎯 NEW: Get payment provider details
  static String getPaymentMethods(String countryCode) {
    if (usesSelcom(countryCode)) {
      return 'M-Pesa, Tigo Pesa, Airtel Money, Halopesa';
    }
    
    // Country-specific Flutterwave methods
    switch (countryCode) {
      case 'KE': // Kenya
        return 'M-Pesa, Airtel Money, Cards';
      case 'UG': // Uganda
        return 'MTN Mobile Money, Airtel Money, Cards';
      case 'NG': // Nigeria
        return 'Cards, Bank Transfer, USSD';
      case 'GH': // Ghana
        return 'Mobile Money, Cards, Bank Transfer';
      default:
        return 'Cards, Bank Transfer';
    }
  }
}