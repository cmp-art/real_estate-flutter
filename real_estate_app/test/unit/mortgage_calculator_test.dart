// test/unit/mortgage_calculator_test.dart
// Unit tests for the mortgage calculator math (pure Dart — no widgets).

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

// Replicated from _MortgageCalculatorState to test in isolation.
double _calcMonthlyPayment({
  required double principal,
  required double annualRatePct,
  required double termYears,
}) {
  if (principal <= 0) return 0;
  final monthlyRate = annualRatePct / 100 / 12;
  final n = termYears * 12;
  if (monthlyRate == 0) return principal / n;
  final factor = math.pow(1 + monthlyRate, n).toDouble();
  return principal * (monthlyRate * factor) / (factor - 1);
}

void main() {
  group('MortgageCalculator._calcMonthlyPayment', () {
    test('returns 0 for zero principal', () {
      final result = _calcMonthlyPayment(
        principal: 0,
        annualRatePct: 12,
        termYears: 15,
      );
      expect(result, equals(0.0));
    });

    test('positive monthly payment for typical Tanzania mortgage', () {
      // 80M TZS, 12% annual, 15 years
      final result = _calcMonthlyPayment(
        principal: 80000000,
        annualRatePct: 12,
        termYears: 15,
      );
      expect(result, greaterThan(0));
      // Monthly payment should be less than principal
      expect(result, lessThan(80000000));
      // Sanity: monthly payment roughly 960_000 TZS range
      expect(result, greaterThan(800000));
      expect(result, lessThan(1200000));
    });

    test('zero interest rate returns simple division', () {
      final result = _calcMonthlyPayment(
        principal: 120000,
        annualRatePct: 0,
        termYears: 10,
      );
      // 120,000 / (10 * 12) = 1,000
      expect(result, closeTo(1000.0, 0.01));
    });

    test('total cost is monthly * n', () {
      const principal = 50000000.0;
      const rate = 10.0;
      const years = 20.0;
      final monthly = _calcMonthlyPayment(
        principal: principal,
        annualRatePct: rate,
        termYears: years,
      );
      final total = monthly * years * 12;
      // Total must be more than principal (interest was charged)
      expect(total, greaterThan(principal));
    });

    test('higher interest rate → higher monthly payment', () {
      final low = _calcMonthlyPayment(
          principal: 50000000, annualRatePct: 8, termYears: 15);
      final high = _calcMonthlyPayment(
          principal: 50000000, annualRatePct: 20, termYears: 15);
      expect(high, greaterThan(low));
    });

    test('longer term → lower monthly payment', () {
      final short = _calcMonthlyPayment(
          principal: 50000000, annualRatePct: 12, termYears: 10);
      final long = _calcMonthlyPayment(
          principal: 50000000, annualRatePct: 12, termYears: 25);
      expect(long, lessThan(short));
    });

    test('larger down payment → smaller loan → smaller monthly', () {
      const price = 100000000.0;
      const rate = 12.0;
      const years = 15.0;

      const loan20pct = price * 0.80; // 20% down
      const loan40pct = price * 0.60; // 40% down

      final monthly20 = _calcMonthlyPayment(
          principal: loan20pct, annualRatePct: rate, termYears: years);
      final monthly40 = _calcMonthlyPayment(
          principal: loan40pct, annualRatePct: rate, termYears: years);

      expect(monthly40, lessThan(monthly20));
    });
  });
}
