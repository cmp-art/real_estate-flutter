// lib/core/models/verification_result.dart
//
// Unified ownership verification result — based on fraud scoring system.
//
// Scoring breakdown (100 pts total):
//   +35 pts  NIDA number validated (format correct + unique to this account)
//   +35 pts  EXIF GPS of listing photos matches the property address (≤ 300 m)
//   +15 pts  3 or more listing photos uploaded
//   +10 pts  Account older than 30 days
//   +5  pts  Profile photo set
//
// Trust tiers:
//   70–100  → fullyVerified     🟢  (NIDA + EXIF GPS both confirmed)
//   35–69   → partiallyVerified 🟡  (NIDA confirmed, EXIF not checked/failed)
//   1–34    → basicListing      🟠  (photos + account age only)
//   0       → unverified        🔴  (no signals at all)

enum VerificationTier {
  fullyVerified,
  partiallyVerified,
  basicListing,
  unverified,
}

class VerificationResult {
  final int            fraudScore;             // 0–100
  final VerificationTier tier;
  final bool           nidaValidated;          // NIDA format passed + accepted
  final String?        nidaNumber;             // the NIDA string entered
  final bool           exifGpsMatched;         // photo EXIF GPS ≤ 300 m from property
  final double?        exifGpsDistanceMeters;  // distance found in EXIF, null if no EXIF
  final int            photosCount;            // number of listing photos
  final bool           accountAgeOk;           // account older than 30 days
  final bool           hasProfilePhoto;        // user has avatar set

  // Score contribution breakdown
  final int nidaPoints;
  final int exifPoints;
  final int photosPoints;
  final int accountPoints;
  final int profilePoints;

  const VerificationResult({
    required this.fraudScore,
    required this.tier,
    required this.nidaValidated,
    this.nidaNumber,
    required this.exifGpsMatched,
    this.exifGpsDistanceMeters,
    required this.photosCount,
    required this.accountAgeOk,
    required this.hasProfilePhoto,
    required this.nidaPoints,
    required this.exifPoints,
    required this.photosPoints,
    required this.accountPoints,
    required this.profilePoints,
  });

  // ── Backward-compat helpers used by property_create_screen ──────────────

  /// True when identity has been at least partially confirmed (NIDA validated).
  bool get isVerified => fraudScore >= 35;

  /// Always false — the new system never blocks submission.
  bool get isRejected => false;

  // ── Supabase RPC helpers ─────────────────────────────────────────────────

  String get methodString => 'score_based';
  String get statusString => isVerified ? 'verified' : 'unverified';

  // Repurpose legacy RPC fields to carry new data
  int?    get totalScore        => fraudScore;
  int?    get gpsScore          => null;
  int?    get photoScore        => photosCount;
  double? get distanceMeters    => exifGpsDistanceMeters;
  String? get idDocumentType    => nidaValidated ? 'nida' : null;
  String? get idNameExtracted   => nidaNumber;   // store NIDA in name field
  String? get hatiNameExtracted => null;
  double? get nameMatchPct      => null;
  String? get rejectionReason   => null;

  // ── Display helpers ──────────────────────────────────────────────────────

  String get tierLabel {
    switch (tier) {
      case VerificationTier.fullyVerified:     return 'Fully Verified';
      case VerificationTier.partiallyVerified: return 'Partially Verified';
      case VerificationTier.basicListing:      return 'Basic Listing';
      case VerificationTier.unverified:        return 'Unverified';
    }
  }

  String get tierEmoji {
    switch (tier) {
      case VerificationTier.fullyVerified:     return '🟢';
      case VerificationTier.partiallyVerified: return '🟡';
      case VerificationTier.basicListing:      return '🟠';
      case VerificationTier.unverified:        return '🔴';
    }
  }

  /// Short description shown inside the verification widget.
  String get tierDescription {
    switch (tier) {
      case VerificationTier.fullyVerified:
        return 'NIDA confirmed and photos taken at property location.';
      case VerificationTier.partiallyVerified:
        return 'NIDA confirmed. Photos taken at property would increase score.';
      case VerificationTier.basicListing:
        return 'Add your NIDA number to improve trust score.';
      case VerificationTier.unverified:
        return 'No verification signals. Add NIDA and property photos to build trust.';
    }
  }
}
