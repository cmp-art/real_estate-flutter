// core/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  // Format currency with support for different currencies
  static String formatCurrency(double amount, {String? currencyCode}) {
    final currency = currencyCode ?? 'TZS'; // Default to Tanzanian Shilling
    
    // Different formatting based on currency
    switch (currency) {
      case 'TZS':
        // Tanzanian Shilling formatting
        final formatter = NumberFormat.currency(
          locale: 'sw_TZ',
          symbol: 'TSh ',
          decimalDigits: 0, // TZS typically doesn't use decimals
        );
        return formatter.format(amount);
      
      case 'USD':
        final formatter = NumberFormat.currency(
          locale: 'en_US',
          symbol: '\$ ',
          decimalDigits: 2,
        );
        return formatter.format(amount);
      
      case 'EUR':
        final formatter = NumberFormat.currency(
          locale: 'en_EU',
          symbol: '€ ',
          decimalDigits: 2,
        );
        return formatter.format(amount);
      
      case 'GBP':
        final formatter = NumberFormat.currency(
          locale: 'en_GB',
          symbol: '£ ',
          decimalDigits: 2,
        );
        return formatter.format(amount);
      
      case 'KES':
        final formatter = NumberFormat.currency(
          locale: 'en_KE',
          symbol: 'KSh ',
          decimalDigits: 0,
        );
        return formatter.format(amount);
      
      case 'UGX':
        final formatter = NumberFormat.currency(
          locale: 'en_UG',
          symbol: 'USh ',
          decimalDigits: 0,
        );
        return formatter.format(amount);
      
      default:
        // Fallback to TZS
        final formatter = NumberFormat.currency(
          locale: 'sw_TZ',
          symbol: 'TSh ',
          decimalDigits: 0,
        );
        return formatter.format(amount);
    }
  }

  // Legacy method for backward compatibility
  static String formatCurrencyLegacy(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  // Format currency with decimals
  static String formatCurrencyWithDecimals(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  // Format number with commas
  static String formatNumber(num number) {
    final formatter = NumberFormat('#,##0');
    return formatter.format(number);
  }

  // Format area
  static String formatArea(double area, {String unit = 'sqm'}) {
    return '${formatNumber(area)} $unit';
  }

  // Format date (e.g., "Jan 15, 2024")
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  // Format date and time
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy · hh:mm a').format(dateTime);
  }

  // Format time (e.g., "3:45 PM")
  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  // Format relative time (e.g., "2 hours ago", "3 days ago")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Format message timestamp for chat
  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return formatTime(dateTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday ${formatTime(dateTime)}';
    } else if (now.difference(dateTime).inDays < 7) {
      return '${DateFormat('EEEE').format(dateTime)} ${formatTime(dateTime)}';
    } else {
      return '${DateFormat('MMM dd').format(dateTime)} ${formatTime(dateTime)}';
    }
  }

  // Format phone number
  static String formatPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    
    // Tanzania phone number format
    if (digitsOnly.startsWith('255') && digitsOnly.length == 12) {
      return '+255 ${digitsOnly.substring(3, 6)} ${digitsOnly.substring(6, 9)} ${digitsOnly.substring(9)}';
    } else if (digitsOnly.length == 9 && digitsOnly.startsWith('0')) {
      return '${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4, 7)} ${digitsOnly.substring(7)}';
    }
    // US phone number format
    else if (digitsOnly.length == 10) {
      return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      return '+1 (${digitsOnly.substring(1, 4)}) ${digitsOnly.substring(4, 7)}-${digitsOnly.substring(7)}';
    }
    
    return phone;
  }

  // Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  // Capitalize first letter
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Title case (capitalize first letter of each word)
  static String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Format compact number (e.g., "1.2K", "3.5M")
  static String formatCompactNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  // Format duration (e.g., "2h 30m")
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // Format file size (e.g., "1.5 MB")
  static String formatFileSize(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '$bytes B';
  }

  // Format percentage (e.g., "85%")
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }
}