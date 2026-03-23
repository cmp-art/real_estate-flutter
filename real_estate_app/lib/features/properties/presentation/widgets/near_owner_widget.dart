// lib/features/properties/presentation/widgets/near_owner_widget.dart
//
// Near-owner verification — requires property coordinates from the listing form.
//
// Flow:
//   1. Tap "Check Distance" → gets device GPS, computes distance to property coordinates.
//   2. Tap "Take/Upload Photo" → camera on native, gallery on web.
//   3. Tap "Verify Ownership" → GPS score (0–40) + photo similarity (0–60).
//   4. Total ≥ 60/100 → Verified ✅
//
// propertyLat / propertyLng must be passed from the listing form address field.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/verification_result.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/services/photo_similarity_service.dart';
import '../../../../core/services/verification_service.dart';

class NearOwnerWidget extends StatefulWidget {
  final List<XFile> listingPhotos;

  /// Coordinates from the listing form address field.
  final double? propertyLat;
  final double? propertyLng;

  /// Called with the verification result.
  final void Function(VerificationResult result) onResult;

  const NearOwnerWidget({
    super.key,
    required this.listingPhotos,
    required this.onResult,
    this.propertyLat,
    this.propertyLng,
  });

  @override
  State<NearOwnerWidget> createState() => _NearOwnerWidgetState();
}

class _NearOwnerWidgetState extends State<NearOwnerWidget> {
  late final VerificationService _service;
  final ImagePicker _picker = ImagePicker();

  XFile?  _livePhoto;
  VerificationResult? _result;

  bool    _checking  = false;
  bool    _verifying = false;
  String? _statusMsg;

  bool    _distanceChecked = false;
  double? _detectedDistanceM;

  @override
  void initState() {
    super.initState();
    _service = VerificationService(
      photoSimilarityService: PhotoSimilarityService(),
      ocrService:             OcrService(),
    );
  }

  // ── Step 1: Check distance ────────────────────────────────────────────────
  Future<void> _checkDistance() async {
    if (widget.propertyLat == null || widget.propertyLng == null) return;

    setState(() {
      _checking  = true;
      _statusMsg = 'Getting your GPS location…';
    });

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied || req == LocationPermission.deniedForever) {
          if (!mounted) return;
          setState(() {
            _checking  = false;
            _statusMsg = 'Location permission denied. Please enable it in Settings.';
          });
          return;
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
        widget.propertyLat!, widget.propertyLng!,
      );

      if (!mounted) return;
      setState(() {
        _checking         = false;
        _distanceChecked  = true;
        _detectedDistanceM = dist;
        _statusMsg        = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking  = false;
        _statusMsg = 'Could not get location: $e';
      });
    }
  }

  // ── Step 2: Take / upload photo ───────────────────────────────────────────
  Future<void> _takePhoto() async {
    // On web, ImageSource.camera opens the file explorer on desktop — use gallery instead.
    final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;

    final photo = await _picker.pickImage(
      source:       source,
      maxWidth:     1280,
      maxHeight:    1280,
      imageQuality: 85,
    );
    if (photo == null) return;
    setState(() {
      _livePhoto = photo;
      _result    = null;
      _statusMsg = null;
    });
  }

  // ── Step 3: Verify ────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (widget.propertyLat == null || widget.propertyLng == null) {
      setState(() => _statusMsg = 'Property coordinates are not set. Select an address above.');
      return;
    }
    if (_livePhoto == null) {
      setState(() => _statusMsg = 'Please take or upload a photo first (Step 2).');
      return;
    }

    setState(() {
      _verifying = true;
      _statusMsg = 'Verifying…';
    });

    final result = await _service.verifyNearOwner(
      propertyLatitude:  widget.propertyLat!,
      propertyLongitude: widget.propertyLng!,
      listingPhotos:     widget.listingPhotos,
      livePhoto:         _livePhoto!,
    );

    setState(() {
      _verifying = false;
      _result    = result;
      _statusMsg = null;
    });

    widget.onResult(result);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCoords = widget.propertyLat != null && widget.propertyLng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info / coordinates card
        _infoCard(hasCoords),
        const SizedBox(height: 16),

        if (!hasCoords) ...[
          // No coordinates yet — block further steps
        ] else ...[
          // ── Step 1: Check Distance ─────────────────────────────────────
          _StepHeader(
            step:  '1',
            title: 'Check Distance to Property',
            done:  _distanceChecked,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _checking ? null : _checkDistance,
            icon: _checking
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_distanceChecked
                    ? Icons.location_on
                    : Icons.my_location_outlined),
            label: Text(_checking
                ? 'Getting location…'
                : _distanceChecked && _detectedDistanceM != null
                    ? _distanceChecked
                        ? (_detectedDistanceM! > 2000
                            ? 'Distance: ${(_detectedDistanceM! / 1000).toStringAsFixed(1)} km — too far (re-check)'
                            : 'Distance: ${_detectedDistanceM!.toStringAsFixed(0)} m — OK')
                        : 'Check My Distance'
                    : 'Check My Distance'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: _distanceChecked
                  ? (_detectedDistanceM != null && _detectedDistanceM! <= 2000
                      ? Colors.green
                      : Colors.orange)
                  : null,
              side: BorderSide(
                color: _distanceChecked
                    ? (_detectedDistanceM != null && _detectedDistanceM! <= 2000
                        ? Colors.green
                        : Colors.orange)
                    : Colors.grey.shade400,
              ),
            ),
          ),

          if (_distanceChecked && _detectedDistanceM != null && _detectedDistanceM! > 2000) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                'You are ${(_detectedDistanceM! / 1000).toStringAsFixed(1)} km from the property. '
                'Near-owner verification requires being within 2 km. '
                'You can still proceed, but verification will be rejected unless you are within 2 km. '
                'Consider using the "Far Owner" method instead.',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Step 2: Photo ──────────────────────────────────────────────
          _StepHeader(
            step:  '2',
            title: kIsWeb
                ? 'Upload a Photo Taken at the Property'
                : 'Take a Live Photo at the Property',
            done:  _livePhoto != null,
          ),
          const SizedBox(height: 8),
          if (kIsWeb) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'On web/PC, please upload a photo taken at the property.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ),
          ],
          OutlinedButton.icon(
            onPressed: _verifying ? null : _takePhoto,
            icon: Icon(_livePhoto != null
                ? (kIsWeb ? Icons.upload_file : Icons.camera_alt)
                : (kIsWeb ? Icons.upload_file_outlined : Icons.camera_alt_outlined)),
            label: Text(_livePhoto != null
                ? (kIsWeb ? 'Upload Different Photo' : 'Retake Photo')
                : (kIsWeb ? 'Upload Photo' : 'Open Camera')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: _livePhoto != null ? Colors.green : null,
              side: BorderSide(
                color: _livePhoto != null ? Colors.green : Colors.grey.shade400,
              ),
            ),
          ),

          if (_livePhoto != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb
                  ? Image.network(
                      _livePhoto!.path,
                      height: 140,
                      width:  double.infinity,
                      fit:    BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                    )
                  : Image.file(
                      File(_livePhoto!.path),
                      height: 140,
                      width:  double.infinity,
                      fit:    BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                    ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Step 3: Verify ─────────────────────────────────────────────
          _StepHeader(
            step:  '3',
            title: 'Verify Ownership',
            done:  _result?.isVerified == true,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: (_verifying || _livePhoto == null)
                ? null
                : _verify,
            icon: _verifying
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_outlined),
            label: Text(_verifying ? 'Verifying…' : 'Verify Ownership'),
            style: ElevatedButton.styleFrom(
              padding:         const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),

          if (_statusMsg != null) ...[
            const SizedBox(height: 10),
            Text(_statusMsg!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
          ],

          if (_result != null) ...[
            const SizedBox(height: 16),
            _NearResultCard(result: _result!),
          ],
        ],
      ],
    );
  }

  Widget _photoPlaceholder() => Container(
    height: 140,
    color: Colors.grey.shade200,
    child: const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
  );

  Widget _infoCard(bool hasCoords) {
    if (!hasCoords) {
      return Container(
        padding:    const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: Colors.amber.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location not set',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Please enter and select your property address from the suggestions above '
              'before using near-owner verification.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:    const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('1. Tap "Check My Distance" — we get your live GPS and measure distance to the property.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text('2. Take or upload a photo of the property from where you are standing.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text('3. GPS score (0–50) + Photo score (0–50). Total ≥ 60 → Verified.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text('   Both your location AND a photo of the property are required.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            'Property coordinates: ${widget.propertyLat!.toStringAsFixed(4)}, ${widget.propertyLng!.toStringAsFixed(4)}',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
          ),
          if (widget.listingPhotos.isEmpty) ...[
            const SizedBox(height: 8),
            Text('Add listing photos above before verifying.',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}

// ── Subwidgets ─────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final String step;
  final String title;
  final bool   done;
  const _StepHeader({required this.step, required this.title, required this.done});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: done ? Colors.green : Theme.of(context).colorScheme.primary,
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(step, style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ],
  );
}

class _NearResultCard extends StatelessWidget {
  final VerificationResult result;
  const _NearResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final v     = result.isVerified;
    final color = v ? Colors.green : Colors.red;

    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        color.shade50,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(v ? Icons.verified : Icons.cancel_outlined, color: color, size: 22),
            const SizedBox(width: 8),
            Text(v ? 'Ownership Verified' : 'Verification Rejected',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          if (result.gpsScore   != null) _ScoreRow('GPS',    '${result.gpsScore}/50',     result.gpsScore!,   50),
          if (result.photoScore != null) _ScoreRow('Photo',  '${result.photoScore}/50',   result.photoScore!, 50),
          if (result.totalScore != null) _ScoreRow('Total',  '${result.totalScore}/100',  result.totalScore!, 100, bold: true),
          if (result.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(result.rejectionReason!,
                style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
          ],
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  final int    score;
  final int    max;
  final bool   bold;
  const _ScoreRow(this.label, this.value, this.score, this.max, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 60,
          child: Text(label, style: TextStyle(fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Expanded(
        child: LinearProgressIndicator(
          value:           (score / max).clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(score / max >= 0.6 ? Colors.green : Colors.orange),
        ),
      ),
      const SizedBox(width: 8),
      Text(value, style: TextStyle(fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    ]),
  );
}
