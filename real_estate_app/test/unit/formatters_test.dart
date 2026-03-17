// test/unit/formatters_test.dart
// Unit tests for Formatters utility — no Flutter widgets needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:patamjengo_app/core/utils/formatters.dart';

void main() {
  group('Formatters.formatCurrency', () {
    test('TZS format contains TSh symbol and no decimals', () {
      final result = Formatters.formatCurrency(1500000, currencyCode: 'TZS');
      expect(result, contains('TSh'));
      expect(result, isNot(contains('.')));
    });

    test('USD format contains dollar symbol', () {
      final result = Formatters.formatCurrency(1000, currencyCode: 'USD');
      expect(result, contains('\$'));
    });

    test('KES format contains KSh symbol', () {
      final result = Formatters.formatCurrency(50000, currencyCode: 'KES');
      expect(result, contains('KSh'));
    });

    test('unknown currency falls back to TSh', () {
      final result = Formatters.formatCurrency(1000, currencyCode: 'XYZ');
      expect(result, contains('TSh'));
    });

    test('zero amount formats correctly', () {
      final result = Formatters.formatCurrency(0, currencyCode: 'TZS');
      expect(result, isNotEmpty);
    });

    test('large amounts format with thousands separator', () {
      final result = Formatters.formatCurrency(10000000, currencyCode: 'TZS');
      // 10,000,000 should appear with comma separator
      expect(result, contains(','));
    });
  });

  group('Formatters.formatNumber', () {
    test('formats thousands with comma', () {
      expect(Formatters.formatNumber(1000), equals('1,000'));
    });

    test('formats millions correctly', () {
      expect(Formatters.formatNumber(1000000), equals('1,000,000'));
    });

    test('formats small numbers without comma', () {
      expect(Formatters.formatNumber(999), equals('999'));
    });
  });

  group('Formatters.formatArea', () {
    test('returns formatted area with unit', () {
      final result = Formatters.formatArea(150.0);
      expect(result, contains('150'));
      expect(result, contains('sqm'));
    });

    test('custom unit appears in output', () {
      final result = Formatters.formatArea(200.0, unit: 'sqft');
      expect(result, contains('sqft'));
    });
  });

  group('Formatters.formatRelativeTime', () {
    test('returns Just now for very recent time', () {
      final now = DateTime.now().subtract(const Duration(seconds: 10));
      expect(Formatters.formatRelativeTime(now), equals('Just now'));
    });

    test('returns minutes ago for recent time', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final result = Formatters.formatRelativeTime(past);
      expect(result, contains('minute'));
    });

    test('returns hours ago for same-day time', () {
      final past = DateTime.now().subtract(const Duration(hours: 3));
      final result = Formatters.formatRelativeTime(past);
      expect(result, contains('hour'));
    });

    test('returns days ago for past days', () {
      final past = DateTime.now().subtract(const Duration(days: 5));
      final result = Formatters.formatRelativeTime(past);
      expect(result, contains('day'));
    });

    test('returns months ago for old dates', () {
      final past = DateTime.now().subtract(const Duration(days: 60));
      final result = Formatters.formatRelativeTime(past);
      expect(result, contains('month'));
    });

    test('returns years ago for very old dates', () {
      final past = DateTime.now().subtract(const Duration(days: 400));
      final result = Formatters.formatRelativeTime(past);
      expect(result, contains('year'));
    });
  });

  group('Formatters.formatPhoneNumber', () {
    test('formats Tanzania 255 number', () {
      final result = Formatters.formatPhoneNumber('255712345678');
      expect(result, contains('+255'));
    });

    test('returns original if format unrecognised', () {
      const input = 'abc';
      expect(Formatters.formatPhoneNumber(input), equals(input));
    });
  });

  group('Formatters.formatDate', () {
    test('returns Today for current date', () {
      expect(Formatters.formatDate(DateTime.now()), equals('Today'));
    });

    test('returns Yesterday for previous day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(Formatters.formatDate(yesterday), equals('Yesterday'));
    });

    test('returns formatted date for older dates', () {
      final oldDate = DateTime(2022, 1, 1);
      final result = Formatters.formatDate(oldDate);
      expect(result, contains('Jan'));
      expect(result, contains('2022'));
    });
  });
}
