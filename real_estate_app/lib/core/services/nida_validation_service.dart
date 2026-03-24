// lib/core/services/nida_validation_service.dart
//
// Tanzania NIDA number validation — free, zero API cost.
//
// Tanzania National ID format: YYYYMMDD-NNNNN-NNNNN-NN
//   YYYYMMDD  — date of birth
//   NNNNN     — district/ward code (5 digits)
//   NNNNN     — sequential serial number (5 digits)
//   NN        — check digits (2 digits)
//
// Examples:
//   19901215-12345-67890-12   (with dashes)
//   19901215123456789012      (without dashes — also accepted)
//
// Validation rules applied (all free, no API):
//   1. Format matches pattern (with or without dashes)
//   2. Date of birth is valid and person is 18–120 years old
//   3. This NIDA string is unique — not already registered on another account
//      (checked via Supabase ownership_verification_logs table; non-blocking
//       if the table/query fails)

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NidaValidationResult {
  final bool    isValid;
  final String? error;
  final String? normalizedNida; // formatted as YYYYMMDD-NNNNN-NNNNN-NN

  const NidaValidationResult({
    required this.isValid,
    this.error,
    this.normalizedNida,
  });
}

class NidaValidationService {
  // Pattern: 8 digits, dash, 5 digits, dash, 5 digits, dash, 2 digits
  static final RegExp _withDashes    = RegExp(r'^\d{8}-\d{5}-\d{5}-\d{2}$');
  // Same 20 digits but without dashes
  static final RegExp _withoutDashes = RegExp(r'^\d{20}$');

  // ── Format + age validation ──────────────────────────────────────────────

  /// Validates the NIDA number format and embedded date of birth.
  /// Returns immediately — no network call.
  NidaValidationResult validateFormat(String raw) {
    final input = raw.trim();

    if (input.isEmpty) {
      return const NidaValidationResult(
        isValid: false,
        error: 'Please enter your NIDA number.',
      );
    }

    // Normalise: accept with or without dashes
    String normalized;
    if (_withDashes.hasMatch(input)) {
      normalized = input;
    } else if (_withoutDashes.hasMatch(input)) {
      // Insert dashes: YYYYMMDD-NNNNN-NNNNN-NN
      normalized = '${input.substring(0, 8)}-'
                   '${input.substring(8, 13)}-'
                   '${input.substring(13, 18)}-'
                   '${input.substring(18)}';
    } else {
      return const NidaValidationResult(
        isValid: false,
        error: 'Invalid format. Use YYYYMMDD-XXXXX-XXXXX-XX '
               '(e.g. 19901215-12345-67890-12)',
      );
    }

    // ── Validate the date-of-birth portion ────────────────────────────────
    final datePart = normalized.substring(0, 8);
    final year  = int.tryParse(datePart.substring(0, 4));
    final month = int.tryParse(datePart.substring(4, 6));
    final day   = int.tryParse(datePart.substring(6, 8));

    if (year == null || month == null || day == null) {
      return const NidaValidationResult(
        isValid: false,
        error: 'NIDA date of birth part is not a valid number.',
      );
    }

    DateTime dob;
    try {
      dob = DateTime(year, month, day);
    } catch (_) {
      return const NidaValidationResult(
        isValid: false,
        error: 'NIDA contains an invalid date of birth.',
      );
    }

    final now = DateTime.now();
    final age = now.year - dob.year -
        ((now.month < dob.month ||
                (now.month == dob.month && now.day < dob.day))
            ? 1
            : 0);

    if (age < 18) {
      return const NidaValidationResult(
        isValid: false,
        error: 'NIDA date of birth indicates age under 18.',
      );
    }
    if (age > 120) {
      return const NidaValidationResult(
        isValid: false,
        error: 'NIDA date of birth is not realistic (age > 120).',
      );
    }

    return NidaValidationResult(
      isValid: true,
      normalizedNida: normalized,
    );
  }

  // ── Uniqueness check (non-blocking) ─────────────────────────────────────

  /// Returns true if [nida] has NOT been used by a different account.
  /// Returns true on any network/DB error (fail-open — don't punish the user
  /// for connectivity issues).
  Future<bool> isNidaUnique({
    required String nida,
    required String currentUserId,
  }) async {
    try {
      final rows = await Supabase.instance.client
          .from('ownership_verification_logs')
          .select('user_id')
          .eq('id_name_extracted', nida)   // we store NIDA in this column
          .neq('user_id', currentUserId)
          .limit(1);

      final isDuplicate = (rows as List).isNotEmpty;
      if (isDuplicate) {
        debugPrint('[NIDA] Duplicate found for $nida on a different account.');
      }
      return !isDuplicate;
    } catch (e) {
      debugPrint('[NIDA] Uniqueness check failed (non-fatal): $e');
      return true; // fail-open
    }
  }

  // ── Convenience: validate + uniqueness in one call ───────────────────────

  Future<NidaValidationResult> validate({
    required String raw,
    required String currentUserId,
  }) async {
    final formatResult = validateFormat(raw);
    if (!formatResult.isValid) return formatResult;

    final unique = await isNidaUnique(
      nida:          formatResult.normalizedNida!,
      currentUserId: currentUserId,
    );

    if (!unique) {
      return NidaValidationResult(
        isValid:        false,
        normalizedNida: formatResult.normalizedNida,
        error: 'This NIDA number is already registered on another account. '
               'Each NIDA can only be linked to one account.',
      );
    }

    return formatResult;
  }
}
