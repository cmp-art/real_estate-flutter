// core/config/theme_config.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeConfig {
  // ==================== LIGHT MODE COLORS ====================
  
  // Primary Colors
  static const Color lightPrimary = Color(0xFF2196F3);
  static const Color lightPrimaryDark = Color(0xFF1976D2);
  static const Color lightPrimaryLight = Color(0xFF64B5F6);
  
  // Secondary Colors
  static const Color lightSecondary = Color(0xFFFF9800);
  static const Color lightSecondaryDark = Color(0xFFF57C00);
  static const Color lightSecondaryLight = Color(0xFFFFB74D);
  
  // Background Colors
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  
  // AppBar Colors
  static const Color lightAppBarBackground = Color(0xFF2196F3);
  static const Color lightAppBarForeground = Color(0xFFFFFFFF);
  
  // BottomNav Colors
  static const Color lightBottomNavBackground = Color(0xFFFFFFFF);
  static const Color lightBottomNavSelected = Color(0xFF2196F3);
  static const Color lightBottomNavUnselected = Color(0xFF757575);
  
  // Text Colors
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightTextOnPrimary = Color(0xFFFFFFFF);
  
  // Border & Divider Colors
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightDivider = Color(0xFFE0E0E0);
  
  // Icon Colors
  static const Color lightIcon = Color(0xFF757575);
  static const Color lightIconActive = Color(0xFF2196F3);
  
  // Input Field Colors
  static const Color lightInputFill = Color(0xFFF5F5F5);
  static const Color lightInputBorder = Color(0xFFE0E0E0);
  static const Color lightInputFocused = Color(0xFF2196F3);
  
  // ==================== DARK MODE COLORS ====================
  
  // Primary Colors
  static const Color darkPrimary = Color(0xFF64B5F6);
  static const Color darkPrimaryDark = Color(0xFF42A5F5);
  static const Color darkPrimaryLight = Color(0xFF90CAF9);
  
  // Secondary Colors
  static const Color darkSecondary = Color(0xFFFFB74D);
  static const Color darkSecondaryDark = Color(0xFFFF9800);
  static const Color darkSecondaryLight = Color(0xFFFFCC80);
  
  // Background Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF1E1E1E);
  
  // AppBar Colors
  static const Color darkAppBarBackground = Color(0xFF1E1E1E);
  static const Color darkAppBarForeground = Color(0xFFFFFFFF);
  
  // BottomNav Colors
  static const Color darkBottomNavBackground = Color(0xFF1E1E1E);
  static const Color darkBottomNavSelected = Color(0xFF64B5F6);
  static const Color darkBottomNavUnselected = Color(0xFFB0B0B0);
  
  // Text Colors
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextOnPrimary = Color(0xFF000000);
  
  // Border & Divider Colors
  static const Color darkBorder = Color(0xFF424242);
  static const Color darkDivider = Color(0xFF424242);
  
  // Icon Colors
  static const Color darkIcon = Color(0xFFB0B0B0);
  static const Color darkIconActive = Color(0xFF64B5F6);
  
  // Input Field Colors
  static const Color darkInputFill = Color(0xFF2C2C2C);
  static const Color darkInputBorder = Color(0xFF424242);
  static const Color darkInputFocused = Color(0xFF64B5F6);
  
  // ==================== UTILITY COLORS (Same for both modes) ====================
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF43A047);
  static const Color warningColor = Color(0xFFFB8C00);
  static const Color infoColor = Color(0xFF1E88E5);
  
  // ==================== LEGACY SUPPORT ====================
  static const Color primaryColor = lightPrimary;
  static const Color primaryDark = lightPrimaryDark;
  static const Color primaryLight = lightPrimaryLight;
  static const Color secondaryColor = lightSecondary;
  static const Color textPrimaryColor = lightTextPrimary;
  static const Color textSecondaryColor = lightTextSecondary;
  
  // ==================== THEME BUILDERS ====================
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightBackground,
    cardColor: lightCard,
    dividerColor: lightDivider,
    
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightSecondary,
      surface: lightSurface,
      error: errorColor,
      onPrimary: lightTextOnPrimary,
      onSecondary: lightTextOnPrimary,
      onSurface: lightTextPrimary,
      onError: Color(0xFFFFFFFF),
      brightness: Brightness.light,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: lightAppBarBackground,
      foregroundColor: lightAppBarForeground,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: lightAppBarForeground),
      titleTextStyle: TextStyle(
        color: lightAppBarForeground,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      // Status bar: white background with dark icons (light mode — matches scaffold)
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFAFAFA),
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightBottomNavBackground,
      selectedItemColor: lightBottomNavSelected,
      unselectedItemColor: lightBottomNavUnselected,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightInputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightInputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightInputFocused, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: lightTextSecondary),
      hintStyle: const TextStyle(color: lightTextSecondary),
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextPrimary),
      bodySmall: TextStyle(color: lightTextSecondary),
      labelLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.w500),
    ),
  );
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkBackground,
    cardColor: darkCard,
    dividerColor: darkDivider,
    
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkSecondary,
      surface: darkSurface,
      error: errorColor,
      onPrimary: darkTextOnPrimary,
      onSecondary: darkTextOnPrimary,
      onSurface: darkTextPrimary,
      onError: Color(0xFFFFFFFF),
      brightness: Brightness.dark,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: darkAppBarBackground,
      foregroundColor: darkAppBarForeground,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: darkAppBarForeground),
      titleTextStyle: TextStyle(
        color: darkAppBarForeground,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      // Status bar: dark background with light icons (dark mode — matches scaffold)
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFF121212),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkBottomNavBackground,
      selectedItemColor: darkBottomNavSelected,
      unselectedItemColor: darkBottomNavUnselected,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkInputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkInputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: darkInputFocused, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: darkTextSecondary),
      hintStyle: const TextStyle(color: darkTextSecondary),
    ),
    
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: darkTextPrimary),
      bodyMedium: TextStyle(color: darkTextPrimary),
      bodySmall: TextStyle(color: darkTextSecondary),
      labelLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w500),
    ),
  );
  
  // ==================== HELPER METHODS ====================
  
  // Get color based on theme mode
  static Color getColor(BuildContext context, {
    required Color lightColor,
    required Color darkColor,
  }) {
    return Theme.of(context).brightness == Brightness.dark ? darkColor : lightColor;
  }
  
  // Quick access to themed colors
  static Color getPrimaryColor(BuildContext context) {
    return getColor(context, lightColor: lightPrimary, darkColor: darkPrimary);
  }
  
  static Color getBackgroundColor(BuildContext context) {
    return getColor(context, lightColor: lightBackground, darkColor: darkBackground);
  }
  
  static Color getTextPrimaryColor(BuildContext context) {
    return getColor(context, lightColor: lightTextPrimary, darkColor: darkTextPrimary);
  }
  
  static Color getTextSecondaryColor(BuildContext context) {
    return getColor(context, lightColor: lightTextSecondary, darkColor: darkTextSecondary);
  }
  
  static Color getCardColor(BuildContext context) {
    return getColor(context, lightColor: lightCard, darkColor: darkCard);
  }
}