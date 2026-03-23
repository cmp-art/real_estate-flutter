// lib/core/models/verification_result.dart
//
// Ownership verification result — binary only (verified | rejected).
// All scoring happens on-device before this object is created.

enum VerificationMethod { nearOwner, farOwner }

enum VerificationStatus { verified, rejected }

class VerificationResult {
  final VerificationStatus status;
  final VerificationMethod method;

  // ── Near owner ──────────────────────────────────────────────────────────
  final int?    gpsScore;       // 0–40
  final int?    photoScore;     // 0–60
  final int?    totalScore;     // 0–100 (gps + photo)
  final double? distanceMeters;

  // ── Far owner ───────────────────────────────────────────────────────────
  final String? idDocumentType;     // 'nida' | 'driving_license' | 'voter'
  final String? idNameExtracted;    // raw OCR name from ID
  final String? hatiNameExtracted;  // raw OCR name from Hati
  final double? nameMatchPct;       // 0–100

  // ── Shared ──────────────────────────────────────────────────────────────
  final String? rejectionReason;

  const VerificationResult({
    required this.status,
    required this.method,
    this.gpsScore,
    this.photoScore,
    this.totalScore,
    this.distanceMeters,
    this.idDocumentType,
    this.idNameExtracted,
    this.hatiNameExtracted,
    this.nameMatchPct,
    this.rejectionReason,
  });

  bool get isVerified => status == VerificationStatus.verified;
  bool get isRejected => status == VerificationStatus.rejected;

  // Convenience factory for near owner
  factory VerificationResult.nearOwner({
    required bool verified,
    required int gpsScore,
    required int photoScore,
    required double distanceMeters,
    String? rejectionReason,
  }) =>
      VerificationResult(
        status:        verified ? VerificationStatus.verified : VerificationStatus.rejected,
        method:        VerificationMethod.nearOwner,
        gpsScore:      gpsScore,
        photoScore:    photoScore,
        totalScore:    gpsScore + photoScore,
        distanceMeters: distanceMeters,
        rejectionReason: rejectionReason,
      );

  // Convenience factory for far owner
  factory VerificationResult.farOwner({
    required bool verified,
    required double nameMatchPct,
    required String idDocumentType,
    required String idNameExtracted,
    required String hatiNameExtracted,
    String? rejectionReason,
  }) =>
      VerificationResult(
        status:             verified ? VerificationStatus.verified : VerificationStatus.rejected,
        method:             VerificationMethod.farOwner,
        nameMatchPct:       nameMatchPct,
        idDocumentType:     idDocumentType,
        idNameExtracted:    idNameExtracted,
        hatiNameExtracted:  hatiNameExtracted,
        rejectionReason:    rejectionReason,
      );

  // Method string for Supabase
  String get methodString =>
      method == VerificationMethod.nearOwner ? 'near_owner' : 'far_owner';

  String get statusString =>
      status == VerificationStatus.verified ? 'verified' : 'rejected';
}
