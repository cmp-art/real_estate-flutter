// lib/features/properties/presentation/widgets/near_owner_widget.dart
//
// Near-owner verification — self-contained, no pre-set coordinates needed.
//
// Flow:
//   1. Tap "Set Property Location" → captures current GPS as property location.
//   2. Tap "Take Live Photo"       → opens camera.
//   3. Tap "Verify"                → GPS score (40 since distance ≈ 0) +
//                                    TFLite photo similarity (0–60).
//   4. Total ≥ 60/100 → Verified ✅
//
// The captured GPS coordinates are passed back via [onResult] so the parent
// can store them on the property entity (property.latitude / .longitude).

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

  /// Called with the verification result.
  final void Function(VerificationResult result) onResult;

  /// Called with the captured GPS so the parent can save it on the property.
  final void Function(double lat, double lng)? onLocationCaptured;

  const NearOwnerWidget({
    super.key,
    required this.listingPhotos,
    required this.onResult,
    this.onLocationCaptured,
  });

  @override
  State<NearOwnerWidget> createState() => _NearOwnerWidgetState();
}

class _NearOwnerWidgetState extends State<NearOwnerWidget> {
  late final VerificationService _service;
  final ImagePicker _picker = ImagePicker();

  double? _capturedLat;
  double? _capturedLng;
  XFile?  _livePhoto;

  VerificationResult? _result;
  bool    _locating  = false;
  bool    _verifying = false;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _service = VerificationService(
      photoSimilarityService: PhotoSimilarityService(),
      ocrService:             OcrService(),
    );
  }

  // ── Step 1: Capture GPS location ──────────────────────────────────────────
  Future<void> _captureLocation() async {
    setState(() {
      _locating  = true;
      _statusMsg = 'Getting your GPS location…';
    });

    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied || req == LocationPermission.deniedForever) {
          setState(() {
            _locating  = false;
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

      setState(() {
        _capturedLat = pos.latitude;
        _capturedLng = pos.longitude;
        _locating    = false;
        _statusMsg   = null;
      });

      widget.onLocationCaptured?.call(pos.latitude, pos.longitude);
    } catch (e) {
      setState(() {
        _locating  = false;
        _statusMsg = 'Could not get location: $e';
      });
    }
  }

  // ── Step 2: Take live photo ───────────────────────────────────────────────
  Future<void> _takeLivePhoto() async {
    final photo = await _picker.pickImage(
      source:       ImageSource.camera,
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
    if (_capturedLat == null) {
      setState(() => _statusMsg = 'Please capture your location first (Step 1).');
      return;
    }
    if (_livePhoto == null) {
      setState(() => _statusMsg = 'Please take a live photo first (Step 2).');
      return;
    }

    setState(() {
      _verifying = true;
      _statusMsg = 'Verifying…';
    });

    // Since the user just captured GPS AT the property, distance = 0 → GPS score = 40.
    final result = await _service.verifyNearOwner(
      propertyLatitude:  _capturedLat!,
      propertyLongitude: _capturedLng!,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info
        _infoCard(),
        const SizedBox(height: 16),

        // ── Step 1: GPS ───────────────────────────────────────────────────
        _StepHeader(
          step:   '1',
          title:  'Set Property Location',
          done:   _capturedLat != null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _locating ? null : _captureLocation,
          icon: _locating
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_capturedLat != null
                  ? Icons.location_on
                  : Icons.my_location_outlined),
          label: Text(_locating
              ? 'Getting location…'
              : _capturedLat != null
                  ? 'Location set (${_capturedLat!.toStringAsFixed(4)}, ${_capturedLng!.toStringAsFixed(4)})'
                  : 'Use My Current Location'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: _capturedLat != null ? Colors.green : null,
            side: BorderSide(
              color: _capturedLat != null ? Colors.green : Colors.grey.shade400,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Step 2: Camera ────────────────────────────────────────────────
        _StepHeader(
          step:  '2',
          title: 'Take a Live Photo at the Property',
          done:  _livePhoto != null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _verifying ? null : _takeLivePhoto,
          icon: Icon(_livePhoto != null
              ? Icons.camera_alt
              : Icons.camera_alt_outlined),
          label: Text(_livePhoto != null ? 'Retake Photo' : 'Open Camera'),
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

        // ── Step 3: Verify ────────────────────────────────────────────────
        ElevatedButton.icon(
          onPressed: (_verifying || _capturedLat == null || _livePhoto == null)
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
    );
  }

  Widget _photoPlaceholder() => Container(
    height: 140,
    color: Colors.grey.shade200,
    child: const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
  );

  Widget _infoCard() => Container(
    padding:    const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        Colors.blue.shade50,
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: Colors.blue.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📍 How it works', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('1. Stand at the property and tap "Use My Current Location".',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text('2. Take a live photo of the property from where you are standing.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text('3. Your live photo is compared to your listing photos on-device.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text('4. Photo match ≥ 20/60 + GPS 40 = Total ≥ 60 → Verified ✅',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        if (widget.listingPhotos.isEmpty) ...[
          const SizedBox(height: 8),
          Text('⚠️ Add listing photos above before verifying.',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
        ],
      ],
    ),
  );
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
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
            Text(v ? 'Ownership Verified ✅' : 'Verification Rejected ❌',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          if (result.gpsScore   != null) _ScoreRow('GPS',    '${result.gpsScore}/40',     result.gpsScore!,   40),
          if (result.photoScore != null) _ScoreRow('Photo',  '${result.photoScore}/60',   result.photoScore!, 60),
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
