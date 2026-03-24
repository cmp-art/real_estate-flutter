// lib/core/services/fraud_score_service.dart
//
// Calculates an automatic fraud/trust score (0–100) for a property listing.
//
// Score breakdown:
//   +35  NIDA validated        (format correct + unique to this user)
//   +35  EXIF GPS matched      (photos taken within 300 m of property address)
//   +15  3+ listing photos     (10 pts for 1–2 photos, 15 for 3+)
//   +10  Account ≥ 30 days old (older accounts = more accountable)
//   +5   Profile photo set     (avatar uploaded)
//  ────
//   100  max
//
// Tiers:
//   70–100 → fullyVerified     🟢  NIDA + EXIF GPS both confirmed
//   35–69  → partiallyVerified 🟡  NIDA confirmed only
//   1–34   → basicListing      🟠  photos / age signals only
//   0      → unverified        🔴  no signals at all

import '../models/verification_result.dart';

class FraudScoreService {
  static const int _kNidaMax    = 35;
  static const int _kExifMax    = 35;
  static const int _kPhotosMax  = 15;
  static const int _kAccountMax = 10;
  static const int _kProfileMax = 5;

  // ── Single public method ─────────────────────────────────────────────────

  /// Calculates and returns a [VerificationResult] from the individual signals.
  ///
  /// [nidaValidated]         — NIDA format is correct and is unique.
  /// [exifGpsMatched]        — at least one photo's EXIF GPS is ≤ 300 m from
  ///                           the property address.
  /// [exifGpsDistanceMeters] — closest distance found, or null.
  /// [photosCount]           — number of listing photos the user uploaded.
  /// [accountAgeDays]        — days since the user's account was created.
  /// [hasProfilePhoto]       — whether the user has an avatar set.
  /// [nidaNumber]            — the normalised NIDA string (stored for logging).
  VerificationResult calculate({
    required bool    nidaValidated,
    required bool    exifGpsMatched,
    double?          exifGpsDistanceMeters,
    required int     photosCount,
    required int     accountAgeDays,
    required bool    hasProfilePhoto,
    String?          nidaNumber,
  }) {
    // ── Individual point contributions ───────────────────────────────────
    final nidaPoints    = nidaValidated  ? _kNidaMax    : 0;
    final exifPoints    = exifGpsMatched ? _kExifMax    : 0;
    final photosPoints  = photosCount >= 3 ? _kPhotosMax
                        : photosCount >= 1 ? 10
                        :                    0;
    final accountPoints = accountAgeDays >= 30 ? _kAccountMax : 0;
    final profilePoints = hasProfilePhoto ? _kProfileMax : 0;

    final total = nidaPoints + exifPoints + photosPoints + accountPoints + profilePoints;

    // ── Tier assignment ──────────────────────────────────────────────────
    final tier = total >= 70 ? VerificationTier.fullyVerified
               : total >= 35 ? VerificationTier.partiallyVerified
               : total >= 1  ? VerificationTier.basicListing
               :               VerificationTier.unverified;

    return VerificationResult(
      fraudScore:            total,
      tier:                  tier,
      nidaValidated:         nidaValidated,
      nidaNumber:            nidaNumber,
      exifGpsMatched:        exifGpsMatched,
      exifGpsDistanceMeters: exifGpsDistanceMeters,
      photosCount:           photosCount,
      accountAgeOk:          accountAgeDays >= 30,
      hasProfilePhoto:       hasProfilePhoto,
      nidaPoints:            nidaPoints,
      exifPoints:            exifPoints,
      photosPoints:          photosPoints,
      accountPoints:         accountPoints,
      profilePoints:         profilePoints,
    );
  }
}
