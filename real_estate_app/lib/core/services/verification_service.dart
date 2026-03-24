// lib/core/services/verification_service.dart
//
// Ownership Verification — score-based, zero API cost, works on all platforms.
//
// Replaces the old Near Owner (GPS + photo similarity) and Far Owner
// (ML Kit OCR) system with a simpler, more reliable, cross-platform approach:
//
//   Signal 1 — NIDA number  (+35 pts)
//     User enters their Tanzania National ID number.
//     Validated for format, embedded date-of-birth, and uniqueness.
//     Free — no government API needed.
//
//   Signal 2 — EXIF GPS     (+35 pts)
//     Every photo taken with a phone camera contains hidden GPS coordinates.
//     The system reads these and checks they match the property address.
//     Works on Android, iOS, Web, PWA.  Free — pure-Dart exif package.
//
//   Signal 3 — Listing photos (+15 pts)
//     3+ photos = full score, 1–2 = 10 pts.
//
//   Signal 4 — Account age   (+10 pts)
//     Accounts older than 30 days get full points.
//
//   Signal 5 — Profile photo  (+5 pts)
//     User has an avatar uploaded.
//
// Score 70–100 → Fully Verified      🟢
// Score 35–69  → Partially Verified  🟡
// Score 1–34   → Basic Listing       🟠
// Score 0      → Unverified          🔴
//
// After a property is saved, call [attachVerificationToProperty] to log
// the result to Supabase.

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/verification_result.dart';
import 'exif_gps_service.dart';
import 'fraud_score_service.dart';
import 'nida_validation_service.dart';

void _vlog(String msg) {
  if (kDebugMode) debugPrint('[Verify] $msg');
}

class VerificationService {
  final SupabaseClient _supabase;

  VerificationService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  // ── Main verification entry point ────────────────────────────────────────

  /// Computes a [VerificationResult] from all available signals.
  ///
  /// [rawNida]       — the NIDA string the user typed (may be empty / invalid).
  /// [listingPhotos] — XFile list of photos the user added to the listing.
  /// [propertyLat]   — latitude from the address geocoder.
  /// [propertyLng]   — longitude from the address geocoder.
  Future<VerificationResult> verify({
    required String      rawNida,
    required List<XFile> listingPhotos,
    required double?     propertyLat,
    required double?     propertyLng,
  }) async {
    final userId = _supabase.auth.currentUser?.id ?? '';

    // ── Signal 1: NIDA ───────────────────────────────────────────────────
    _vlog('Validating NIDA...');
    final nidaService = NidaValidationService();
    final nidaResult  = await nidaService.validate(
      raw:           rawNida,
      currentUserId: userId,
    );
    _vlog('NIDA valid: ${nidaResult.isValid} '
          '(${nidaResult.error ?? nidaResult.normalizedNida})');

    // ── Signal 2: EXIF GPS ───────────────────────────────────────────────
    _vlog('Scanning ${listingPhotos.length} photo(s) for EXIF GPS...');
    final exifService  = ExifGpsService();
    final exifScan     = await exifService.scanPhotos(
      photos:      listingPhotos,
      propertyLat: propertyLat,
      propertyLng: propertyLng,
    );
    _vlog('EXIF GPS matched: ${exifScan.matched} '
          '(distance: ${exifScan.distanceMeters?.toStringAsFixed(0) ?? "—"} m, '
          '${exifScan.photosWithGps}/${listingPhotos.length} photos had GPS)');

    // ── Signal 3: Photos count ───────────────────────────────────────────
    final photosCount = listingPhotos.length;

    // ── Signal 4: Account age ────────────────────────────────────────────
    final createdAtStr = _supabase.auth.currentUser?.createdAt;
    int accountAgeDays = 0;
    if (createdAtStr != null) {
      try {
        final created = DateTime.parse(createdAtStr);
        accountAgeDays = DateTime.now().difference(created).inDays;
      } catch (_) {}
    }
    _vlog('Account age: $accountAgeDays days');

    // ── Signal 5: Profile photo ──────────────────────────────────────────
    final meta            = _supabase.auth.currentUser?.userMetadata;
    final hasProfilePhoto = (meta?['avatar_url'] as String?)?.isNotEmpty == true;
    _vlog('Has profile photo: $hasProfilePhoto');

    // ── Fraud score ──────────────────────────────────────────────────────
    final scoreService = FraudScoreService();
    final result = scoreService.calculate(
      nidaValidated:         nidaResult.isValid,
      exifGpsMatched:        exifScan.matched,
      exifGpsDistanceMeters: exifScan.distanceMeters,
      photosCount:           photosCount,
      accountAgeDays:        accountAgeDays,
      hasProfilePhoto:       hasProfilePhoto,
      nidaNumber:            nidaResult.normalizedNida,
    );

    _vlog('Score: ${result.fraudScore}/100 → ${result.tierLabel} ${result.tierEmoji}');
    return result;
  }

  // ── Attach to saved property ─────────────────────────────────────────────

  /// Logs the verification result to Supabase and marks
  /// [is_owner_verified] on the property row (true when score ≥ 35).
  Future<void> attachVerificationToProperty({
    required String             propertyId,
    required VerificationResult result,
  }) async {
    try {
      await _supabase.rpc('log_ownership_verification', params: {
        'p_property_id':         propertyId,
        'p_user_id':             _supabase.auth.currentUser!.id,
        'p_method':              result.methodString,
        'p_status':              result.statusString,
        'p_gps_score':           result.gpsScore,
        'p_photo_score':         result.photoScore,
        'p_total_score':         result.totalScore,
        'p_distance_meters':     result.distanceMeters,
        'p_id_document_type':    result.idDocumentType,
        'p_id_name_extracted':   result.idNameExtracted,
        'p_hati_name_extracted': result.hatiNameExtracted,
        'p_name_match_pct':      result.nameMatchPct,
        'p_rejection_reason':    result.rejectionReason,
        'p_app_version':         null,
      });
      _vlog('Verification attached to property $propertyId '
            '(score ${result.fraudScore}, ${result.statusString})');
    } catch (e) {
      _vlog('Failed to attach verification (non-fatal): $e');
    }
  }
}
