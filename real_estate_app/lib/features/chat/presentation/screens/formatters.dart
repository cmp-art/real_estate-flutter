import 'package:intl/intl.dart';

class Formatters {
  // Format currency
  static String formatCurrency(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat('#,##0.00');
    return '$symbol${formatter.format(amount)}';
  }

  // Format compact currency (e.g., $1.2M, $450K)
  static String formatCompactCurrency(double amount, {String symbol = '\$'}) {
    if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return '$symbol${amount.toStringAsFixed(0)}';
    }
  }

  // Format phone number
  static String formatPhoneNumber(String phone) {
    // Remove all non-numeric characters
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }
    return phone;
  }

  // Format date (DD/MM/YYYY)
  static String formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  // Format date with month name (e.g., Jan 15, 2024)
  static String formatDateWithMonth(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  // Format time (HH:mm)
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  // Format time with AM/PM (e.g., 2:30 PM)
  static String formatTime12Hour(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  // Format date and time
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} · ${formatTime(dateTime)}';
  }

  // Format date and time with month
  static String formatDateTimeWithMonth(DateTime dateTime) {
    return '${formatDateWithMonth(dateTime)} at ${formatTime12Hour(dateTime)}';
  }

  // Format relative time (e.g., "2 hours ago", "just now")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inSeconds > 5) {
      return '${difference.inSeconds}s ago';
    } else {
      return 'Just now';
    }
  }

  // Format relative time with full text (e.g., "2 hours ago", "yesterday")
  static String formatRelativeTimeFull(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } else if (messageDate == yesterday) {
      return 'Yesterday at ${formatTime12Hour(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${DateFormat('EEEE').format(dateTime)} at ${formatTime12Hour(dateTime)}';
    } else {
      return formatDateWithMonth(dateTime);
    }
  }

  // Format area/square footage
  static String formatArea(double area, {String unit = 'sq ft'}) {
    final formatter = NumberFormat('#,##0');
    return '${formatter.format(area)} $unit';
  }

  // Format number with commas
  static String formatNumber(int number) {
    final formatter = NumberFormat('#,##0');
    return formatter.format(number);
  }

  // Format percentage
  static String formatPercentage(double percentage, {int decimals = 1}) {
    return '${percentage.toStringAsFixed(decimals)}%';
  }

  // Format distance (e.g., "2.5 km", "500 m")
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    }
  }

  // Format duration (e.g., "2h 30m")
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  // Capitalize each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  // Truncate text with ellipsis
  static String truncate(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - suffix.length) + suffix;
  }

  // Format file size (e.g., "1.5 MB", "250 KB")
  static String formatFileSize(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '$bytes B';
    }
  }

  // Format rating (e.g., "4.5" or "5.0")
  static String formatRating(double rating, {int decimals = 1}) {
    return rating.toStringAsFixed(decimals);
  }

  // Format bedrooms/bathrooms (e.g., "3 beds", "2.5 baths")
  static String formatRooms(dynamic count, String type) {
    if (count is int) {
      return '$count $type${count == 1 ? '' : 's'}';
    } else if (count is double) {
      return '${count.toStringAsFixed(1)} $type${count == 1.0 ? '' : 's'}';
    }
    return '$count $type';
  }
}