// lib/features/properties/presentation/widgets/verification_section_widget.dart
//
// Unified ownership verification widget for the property creation form.
//
// Replaces the old Near Owner / Far Owner system with a single, simple,
// cross-platform widget that uses:
//   • NIDA number validation  (free, works on all platforms)
//   • EXIF GPS photo matching (free, works on all platforms)
//   • Fraud score display     (automatic, no admin needed)
//
// Usage:
//   VerificationSectionWidget(
//     listingPhotos: _selectedImages,
//     onVerified:    (r) => setState(() => _verificationResult = r),
//     propertyLat:   _propertyLat,
//     propertyLng:   _propertyLng,
//   )

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/models/verification_result.dart';
import '../../../../core/services/exif_gps_service.dart';
import '../../../../core/services/fraud_score_service.dart';
import '../../../../core/services/nida_validation_service.dart';

// ── Public interface (backward-compatible with property_create_screen) ──────

class VerificationSectionWidget extends StatefulWidget {
  final List<XFile> listingPhotos;
  final void Function(VerificationResult) onVerified;
  final double? propertyLat;
  final double? propertyLng;

  const VerificationSectionWidget({
    super.key,
    required this.listingPhotos,
    required this.onVerified,
    this.propertyLat,
    this.propertyLng,
  });

  @override
  State<VerificationSectionWidget> createState() =>
      _VerificationSectionWidgetState();
}

class _VerificationSectionWidgetState
    extends State<VerificationSectionWidget> {
  final _nidaController    = TextEditingController();
  final _nidaFocus         = FocusNode();
  final _nidaService       = NidaValidationService();

  // Live state
  NidaValidationResult? _nidaResult;
  ExifGpsScanResult?    _exifScan;
  bool                  _isCheckingExif = false;
  VerificationResult?   _result;
  bool                  _nidaValidating  = false; // network uniqueness check

  @override
  void initState() {
    super.initState();
    _runExifScan();
  }

  @override
  void didUpdateWidget(covariant VerificationSectionWidget old) {
    super.didUpdateWidget(old);
    // Re-scan EXIF when photos or property coordinates change
    if (old.listingPhotos != widget.listingPhotos ||
        old.propertyLat   != widget.propertyLat   ||
        old.propertyLng   != widget.propertyLng) {
      _runExifScan();
    }
  }

  @override
  void dispose() {
    _nidaController.dispose();
    _nidaFocus.dispose();
    super.dispose();
  }

  // ── EXIF GPS scan ────────────────────────────────────────────────────────

  Future<void> _runExifScan() async {
    if (widget.listingPhotos.isEmpty) {
      setState(() { _exifScan = ExifGpsScanResult.empty; });
      _recalcScore();
      return;
    }

    setState(() => _isCheckingExif = true);

    final scan = await ExifGpsService().scanPhotos(
      photos:      widget.listingPhotos,
      propertyLat: widget.propertyLat,
      propertyLng: widget.propertyLng,
    );

    if (mounted) {
      setState(() {
        _exifScan        = scan;
        _isCheckingExif  = false;
      });
      _recalcScore();
    }
  }

  // ── NIDA input ───────────────────────────────────────────────────────────

  void _onNidaChanged(String value) {
    // Instant format check (no network)
    final formatResult = _nidaService.validateFormat(value);
    setState(() => _nidaResult = formatResult);
    _recalcScore();

    // If format is valid, trigger async uniqueness check
    if (formatResult.isValid) _checkNidaUnique(formatResult.normalizedNida!);
  }

  Future<void> _checkNidaUnique(String nida) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    setState(() => _nidaValidating = true);

    final unique = await _nidaService.isNidaUnique(
      nida:          nida,
      currentUserId: userId,
    );

    if (!mounted) return;
    if (!unique) {
      setState(() {
        _nidaResult = NidaValidationResult(
          isValid:        false,
          normalizedNida: nida,
          error: 'This NIDA is already registered on another account.',
        );
        _nidaValidating = false;
      });
    } else {
      setState(() => _nidaValidating = false);
    }
    _recalcScore();
  }

  // ── Fraud score recalculation ────────────────────────────────────────────

  void _recalcScore() {
    final user = Supabase.instance.client.auth.currentUser;
    int accountAgeDays = 0;
    if (user?.createdAt != null) {
      try {
        accountAgeDays =
            DateTime.now().difference(DateTime.parse(user!.createdAt)).inDays;
      } catch (_) {}
    }
    final meta            = user?.userMetadata;
    final hasProfilePhoto = (meta?['avatar_url'] as String?)?.isNotEmpty == true;

    final result = FraudScoreService().calculate(
      nidaValidated:         _nidaResult?.isValid == true,
      exifGpsMatched:        _exifScan?.matched   == true,
      exifGpsDistanceMeters: _exifScan?.distanceMeters,
      photosCount:           widget.listingPhotos.length,
      accountAgeDays:        accountAgeDays,
      hasProfilePhoto:       hasProfilePhoto,
      nidaNumber:            _nidaResult?.normalizedNida,
    );

    setState(() => _result = result);
    widget.onVerified(result);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final isDark   = theme.brightness == Brightness.dark;
    final primary  = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.security, size: 20, color: primary),
            const SizedBox(width: 8),
            Text(
              'Ownership Verification',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_result != null) _TrustScoreChip(result: _result!),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Verify your identity to build trust with buyers and renters. '
          'Verification is optional but increases your listing visibility.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: Colors.grey.shade600),
        ),

        const SizedBox(height: 18),

        // ── Signal 1: NIDA number ────────────────────────────────────────
        _SectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SignalHeader(
                icon:  Icons.badge_outlined,
                title: 'National ID (NIDA)',
                pts:   '${_result?.nidaPoints ?? 0}/35 pts',
                ok:    _nidaResult?.isValid == true,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller:   _nidaController,
                focusNode:    _nidaFocus,
                keyboardType: TextInputType.number,
                maxLength:    22, // YYYYMMDD-NNNNN-NNNNN-NN = 22 chars
                onChanged:    _onNidaChanged,
                decoration: InputDecoration(
                  hintText:    'YYYYMMDD-XXXXX-XXXXX-XX',
                  labelText:   'NIDA Number',
                  counterText: '',
                  prefixIcon:  const Icon(Icons.credit_card_outlined),
                  suffixIcon: _nidaValidating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _nidaResult == null
                          ? null
                          : Icon(
                              _nidaResult!.isValid
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: _nidaResult!.isValid
                                  ? Colors.green
                                  : Colors.red,
                            ),
                  errorText: _nidaResult?.isValid == false &&
                          _nidaController.text.isNotEmpty
                      ? _nidaResult!.error
                      : null,
                  border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled:        true,
                  fillColor:     isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                  isDense:       true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              if (_nidaResult?.isValid == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'NIDA validated — +35 points',
                        style: TextStyle(
                          fontSize: 12, color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Signal 2: EXIF GPS ───────────────────────────────────────────
        _SectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SignalHeader(
                icon:  Icons.photo_camera_outlined,
                title: 'Photo Location (EXIF GPS)',
                pts:   '${_result?.exifPoints ?? 0}/35 pts',
                ok:    _exifScan?.matched == true,
              ),
              const SizedBox(height: 8),
              _ExifStatusWidget(
                isChecking:   _isCheckingExif,
                exifScan:     _exifScan,
                photosCount:  widget.listingPhotos.length,
                propertyLat:  widget.propertyLat,
                propertyLng:  widget.propertyLng,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Score summary ────────────────────────────────────────────────
        if (_result != null) _ScoreSummaryCard(result: _result!, isDark: isDark),
      ],
    );
  }
}

// ── EXIF status widget ──────────────────────────────────────────────────────

class _ExifStatusWidget extends StatelessWidget {
  final bool                isChecking;
  final ExifGpsScanResult?  exifScan;
  final int                 photosCount;
  final double?             propertyLat;
  final double?             propertyLng;

  const _ExifStatusWidget({
    required this.isChecking,
    required this.exifScan,
    required this.photosCount,
    required this.propertyLat,
    required this.propertyLng,
  });

  @override
  Widget build(BuildContext context) {
    if (isChecking) {
      return const Row(
        children: [
          SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Scanning photo locations...', style: TextStyle(fontSize: 13)),
        ],
      );
    }

    if (photosCount == 0) {
      return _hint(Icons.add_photo_alternate_outlined, Colors.grey,
          'Add listing photos — GPS location embedded in your photos will '
          'be checked automatically.');
    }

    if (propertyLat == null || propertyLng == null) {
      return _hint(Icons.location_off_outlined, Colors.orange,
          'Set the property address to enable location matching.');
    }

    if (exifScan == null || exifScan!.photosWithGps == 0) {
      return _hint(Icons.gps_off_outlined, Colors.orange,
          'None of your photos contain GPS data. '
          'Take photos directly with your phone camera (with location enabled) '
          'at the property to earn +35 pts.');
    }

    if (exifScan!.matched) {
      final dist = exifScan!.distanceMeters;
      return _hint(Icons.check_circle, Colors.green,
          'Photos taken at property location '
          '(${dist != null ? "${dist.toStringAsFixed(0)} m away" : "confirmed"}). '
          '+35 points earned ✅');
    } else {
      final dist = exifScan!.distanceMeters;
      return _hint(Icons.location_off, Colors.red,
          'Photos appear to be taken '
          '${dist != null ? "${(dist / 1000).toStringAsFixed(1)} km away" : "far"} '
          'from the property address. '
          'Take new photos at the property to earn +35 pts.');
    }
  }

  Widget _hint(IconData icon, Color color, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85))),
      ),
    ],
  );
}

// ── Score summary card ──────────────────────────────────────────────────────

class _ScoreSummaryCard extends StatelessWidget {
  final VerificationResult result;
  final bool isDark;
  const _ScoreSummaryCard({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final (bg, border, textColor) = switch (result.tier) {
      VerificationTier.fullyVerified     => (Colors.green.shade50,  Colors.green.shade300,  Colors.green.shade800),
      VerificationTier.partiallyVerified => (Colors.amber.shade50,  Colors.amber.shade300,  Colors.amber.shade800),
      VerificationTier.basicListing      => (Colors.orange.shade50, Colors.orange.shade300, Colors.orange.shade800),
      VerificationTier.unverified        => (Colors.grey.shade100,  Colors.grey.shade400,   Colors.grey.shade700),
    };

    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        isDark ? Colors.grey.shade900 : bg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(result.tierEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '${result.tierLabel}  —  ${result.fraudScore}/100',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(result.tierDescription,
              style: TextStyle(fontSize: 12, color: textColor)),
          const SizedBox(height: 10),
          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           result.fraudScore / 100,
              minHeight:       8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                result.tier == VerificationTier.fullyVerified     ? Colors.green
                : result.tier == VerificationTier.partiallyVerified ? Colors.amber
                : result.tier == VerificationTier.basicListing       ? Colors.orange
                :                                                       Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Breakdown
          _BreakdownRow('NIDA validated',          result.nidaPoints,    35),
          _BreakdownRow('Photos at property',      result.exifPoints,    35),
          _BreakdownRow('3+ listing photos',        result.photosPoints,  15),
          _BreakdownRow('Account age (30+ days)',   result.accountPoints, 10),
          _BreakdownRow('Profile photo',            result.profilePoints,  5),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int    earned;
  final int    max;
  const _BreakdownRow(this.label, this.earned, this.max);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(
          earned > 0 ? Icons.check : Icons.radio_button_unchecked,
          size: 14,
          color: earned > 0 ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                color: earned > 0 ? null : Colors.grey,
              )),
        ),
        Text(
          '+$earned / $max',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: earned > 0 ? Colors.green.shade700 : Colors.grey,
          ),
        ),
      ],
    ),
  );
}

// ── Trust score chip (header) ───────────────────────────────────────────────

class _TrustScoreChip extends StatelessWidget {
  final VerificationResult result;
  const _TrustScoreChip({required this.result});

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (result.tier) {
      VerificationTier.fullyVerified     => (Colors.green.shade100,  Colors.green.shade400,  Colors.green.shade800),
      VerificationTier.partiallyVerified => (Colors.amber.shade100,  Colors.amber.shade400,  Colors.amber.shade800),
      VerificationTier.basicListing      => (Colors.orange.shade100, Colors.orange.shade400, Colors.orange.shade800),
      VerificationTier.unverified        => (Colors.grey.shade200,   Colors.grey.shade400,   Colors.grey.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: border),
      ),
      child: Text(
        '${result.fraudScore}/100  ${result.tierEmoji}',
        style: TextStyle(
          fontSize:   12,
          fontWeight: FontWeight.bold,
          color:      fg,
        ),
      ),
    );
  }
}

// ── Signal section header ───────────────────────────────────────────────────

class _SignalHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   pts;
  final bool     ok;
  const _SignalHeader({
    required this.icon,
    required this.title,
    required this.pts,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: ok ? Colors.green : Colors.grey.shade600),
      const SizedBox(width: 6),
      Expanded(
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color:        ok ? Colors.green.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(pts,
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.bold,
              color:      ok ? Colors.green.shade700 : Colors.grey.shade600,
            )),
      ),
    ],
  );
}

// ── Section card wrapper ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool   isDark;
  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding:    const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: Colors.grey.shade300),
    ),
    child: child,
  );
}
