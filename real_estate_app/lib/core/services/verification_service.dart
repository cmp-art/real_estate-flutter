// lib/core/services/verification_service.dart
//
// Property Ownership Verification — on-device, zero API cost.
//
// ┌─────────────────────────────────────────────────────────┐
// │  METHOD 1 — Near Owner (owner is at / near the property)│
// │                                                         │
// │  1. GPS check: distance from device to property.        │
// │     0–300 m   → +70 pts  (auto-pass; ≥60 on its own)   │
// │     300–1000 m → +35 pts                                │
// │     1–2 km    → +15 pts                                 │
// │     > 2 km    → 0 pts (fail immediately)                │
// │                                                         │
// │  2. Photo: live camera shot vs listing photos.          │
// │     Native: 15 base + cosine bonus → 0–30 pts.          │
// │     Web:    20 pts if photo decodes, else 0.            │
// │                                                         │
// │  Total ≥ 60 / 100 → Verified ✅                         │
// │  Total < 60 / 100 → Rejected ❌                         │
// └─────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────┐
// │  METHOD 2 — Far Owner (owner is not at the property)    │
// │                                                         │
// │  1. ID card  — NIDA / Driving License / Voter ID.       │
// │     ML Kit OCR extracts the owner's name.               │
// │                                                         │
// │  2. Hati (Title Deed).                                  │
// │     ML Kit OCR extracts the registered owner's name.    │
// │                                                         │
// │  Fuzzy token match (Jaccard) ≥ 70% → Verified ✅        │
// │  Otherwise → Rejected ❌                                │
// └─────────────────────────────────────────────────────────┘
//
// After verification (pass or fail) the result is logged to Supabase via
// log_ownership_verification(). Nothing is uploaded until the user passes.

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/verification_result.dart';
import 'ocr_service.dart';
import 'photo_similarity_service.dart';

void _vlog(String msg) {
  if (kDebugMode) debugPrint('[Verify] $msg');
}

// ── Thresholds ────────────────────────────────────────────────────────────────
const int    _kNearOwnerPassThreshold = 60;    // out of 100
const double _kFarOwnerPassThreshold  = 70.0;  // percent
const double _kMaxDistanceMeters      = 2000.0; // 2 km GPS tolerance

// GPS score bands (out of 70):
//   ≤ 300 m   → 70 pts  (auto-passes 60-point threshold on its own)
//   300–1000 m → 35 pts
//   1–2 km    → 15 pts
//   > 2 km    → 0 pts / immediate fail

class VerificationService {
  final PhotoSimilarityService _photoSim;
  final OcrService             _ocr;
  final SupabaseClient         _supabase;

  VerificationService({
    required PhotoSimilarityService photoSimilarityService,
    required OcrService             ocrService,
    SupabaseClient?                 supabaseClient,
  })  : _photoSim = photoSimilarityService,
        _ocr      = ocrService,
        _supabase = supabaseClient ?? Supabase.instance.client;

  // ══════════════════════════════════════════════════════════════════════════
  // METHOD 1 — NEAR OWNER
  // ══════════════════════════════════════════════════════════════════════════

  /// Verifies that the user is physically near the property and their live
  /// camera photo matches the listing photos.
  ///
  /// [propertyLatitude]  / [propertyLongitude] — coordinates entered on the
  ///   listing form (or picked from map).
  ///
  /// [listingPhotos] — images the user has already selected for the listing
  ///   (held in device memory, not yet uploaded to Supabase).
  ///
  /// [livePhoto] — fresh photo taken from the camera right now.
  Future<VerificationResult> verifyNearOwner({
    required double   propertyLatitude,
    required double   propertyLongitude,
    required List<XFile> listingPhotos,
    required XFile    livePhoto,
  }) async {
    // ── 1. GPS score ─────────────────────────────────────────────────────
    final gpsResult = await _computeGpsScore(propertyLatitude, propertyLongitude);
    final gpsScore      = gpsResult.$1;
    final distanceM     = gpsResult.$2;
    final gpsFailReason = gpsResult.$3;

    _vlog('GPS: ${distanceM.toStringAsFixed(0)} m → score $gpsScore/70');

    if (gpsFailReason != null) {
      // > 2 km → immediate fail
      final result = VerificationResult.nearOwner(
        verified:      false,
        gpsScore:      0,
        photoScore:    0,
        distanceMeters: distanceM,
        rejectionReason: gpsFailReason,
      );
      await _log(result, propertyId: null);
      return result;
    }

    // ── 2. Photo similarity score ─────────────────────────────────────────
    final photoScore = await _photoSim.comparePhotos(
      livePhoto:    livePhoto,
      listingPhotos: listingPhotos,
    );
    _vlog('Photo score: $photoScore/30');

    final totalScore = gpsScore + photoScore;
    final passed     = totalScore >= _kNearOwnerPassThreshold;

    _vlog('Total: $totalScore/100 → ${passed ? "VERIFIED ✅" : "REJECTED ❌"}');

    final result = VerificationResult.nearOwner(
      verified:      passed,
      gpsScore:      gpsScore,
      photoScore:    photoScore,
      distanceMeters: distanceM,
      rejectionReason: passed
          ? null
          : 'Score $totalScore/100 is below the required 60. '
            'GPS: $gpsScore/70, Photo: $photoScore/30. '
            'Tip: being within 300 m of the property (GPS ≥ 70) alone is enough to pass.',
    );

    await _log(result, propertyId: null);
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METHOD 2 — FAR OWNER
  // ══════════════════════════════════════════════════════════════════════════

  /// Verifies ownership by matching the name on an ID card against the name
  /// on a Hati (Title Deed) using on-device ML Kit OCR.
  ///
  /// [idImage]        — photo of the ID card (NIDA, Driving License, or Voter ID).
  /// [hatiImage]      — photo of the Hati (Title Deed).
  /// [idDocumentType] — which ID was used ('nida' | 'driving_license' | 'voter').
  Future<VerificationResult> verifyFarOwner({
    required XFile  idImage,
    required XFile  hatiImage,
    required String idDocumentType,
  }) async {
    // ── 1. OCR both documents ──────────────────────────────────────────────
    _vlog('Running OCR on ID card...');
    final idDoc   = await _ocr.processDocument(idImage);
    _vlog('Running OCR on Hati...');
    final hatiDoc = await _ocr.processDocument(hatiImage);

    final idName   = idDoc.name;
    final hatiName = hatiDoc.name;

    // ── 2. Country check — both documents must be Tanzanian ───────────────
    if (!idDoc.isTanzanian || !hatiDoc.isTanzanian) {
      final which = !idDoc.isTanzanian && !hatiDoc.isTanzanian
          ? 'ID card and Hati'
          : !idDoc.isTanzanian ? 'ID card' : 'Hati';
      final result = VerificationResult.farOwner(
        verified: false,
        nameMatchPct: 0.0,
        idDocumentType: idDocumentType,
        idNameExtracted: idDoc.name ?? '',
        hatiNameExtracted: hatiDoc.name ?? '',
        rejectionReason: '$which does not appear to be a Tanzanian document. '
            'Only Tanzanian NIDA cards, Driving Licenses, Voter IDs, and Hati documents are accepted.',
      );
      await _log(result, propertyId: null);
      return result;
    }

    if (idName == null || hatiName == null) {
      final missing = idName == null && hatiName == null
          ? 'Both ID card and Hati'
          : idName == null ? 'ID card' : 'Hati';
      _vlog('OCR failed: $missing — could not extract a name');

      final result = VerificationResult.farOwner(
        verified:          false,
        nameMatchPct:      0.0,
        idDocumentType:    idDocumentType,
        idNameExtracted:   idName   ?? '',
        hatiNameExtracted: hatiName ?? '',
        rejectionReason: '$missing: could not read the owner\'s name. '
            'Ensure the document is clear and well-lit.',
      );
      await _log(result, propertyId: null);
      return result;
    }

    // ── 3. Fuzzy name match ───────────────────────────────────────────────
    final matchPct = fuzzyNameMatch(idName, hatiName);
    final passed   = matchPct >= _kFarOwnerPassThreshold;

    _vlog('Name match: "$idName" vs "$hatiName" → ${matchPct.toStringAsFixed(1)}% → '
        '${passed ? "VERIFIED ✅" : "REJECTED ❌"}');

    final result = VerificationResult.farOwner(
      verified:          passed,
      nameMatchPct:      matchPct,
      idDocumentType:    idDocumentType,
      idNameExtracted:   idName,
      hatiNameExtracted: hatiName,
      rejectionReason: passed
          ? null
          : 'Name match ${matchPct.toStringAsFixed(0)}% is below the required 70%. '
            'ID: "$idName" — Hati: "$hatiName". '
            'Ensure both documents belong to the same owner.',
    );

    await _log(result, propertyId: null);
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STAMP property after submission
  // ══════════════════════════════════════════════════════════════════════════

  /// Call this after the property has been saved to Supabase to link the
  /// verification log to the property row.
  ///
  /// This updates `properties.is_owner_verified` via the DB function.
  Future<void> attachVerificationToProperty({
    required String propertyId,
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
      _vlog('Verification attached to property $propertyId');
    } catch (e) {
      _vlog('Failed to attach verification to property: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNALS
  // ══════════════════════════════════════════════════════════════════════════

  // ── GPS ──────────────────────────────────────────────────────────────────

  /// Returns (gpsScore, distanceMeters, failReason).
  /// failReason is non-null only when > 2 km (instant fail).
  Future<(int, double, String?)> _computeGpsScore(
    double propertyLat, double propertyLng,
  ) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          return (0, 9999.0, 'Location permission denied. Please enable location access to verify near-owner.');
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        propertyLat, propertyLng,
      );

      _vlog('Device: (${pos.latitude}, ${pos.longitude})  '
            'Property: ($propertyLat, $propertyLng)  '
            'Distance: ${dist.toStringAsFixed(0)} m');

      if (dist > _kMaxDistanceMeters) {
        return (
          0,
          dist,
          'You are ${(dist / 1000).toStringAsFixed(1)} km from the property. '
          'Near-owner verification requires being within 2 km. '
          'If you are far away, use the "Far Owner" method instead.',
        );
      }

      final score = dist <= 300  ? 70   // ≤300 m → auto-pass (70 ≥ 60 threshold)
                  : dist <= 1000 ? 35   // 300–1000 m → 35 pts
                  :                15;  // 1–2 km → 15 pts

      return (score, dist, null);
    } catch (e) {
      _vlog('GPS error: $e');
      return (0, 9999.0, 'Could not determine your location. Please enable GPS and try again.');
    }
  }

  // ── Supabase logging ──────────────────────────────────────────────────────

  Future<void> _log(VerificationResult result, {required String? propertyId}) async {
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
    } catch (e) {
      // Non-fatal: verification result is already computed on-device.
      _vlog('Supabase log error (non-fatal): $e');
    }
  }
}
