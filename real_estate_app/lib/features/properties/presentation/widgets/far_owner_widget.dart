// lib/features/properties/presentation/widgets/far_owner_widget.dart
//
// Far-owner verification step:
//   1. User picks ID card photo (NIDA / Driving License / Voter ID).
//   2. User picks Hati (Title Deed) photo.
//   3. On-device ML Kit OCR extracts names from both.
//   4. Fuzzy token match ≥ 70% → Verified ✅.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/verification_result.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/services/photo_similarity_service.dart';
import '../../../../core/services/verification_service.dart';

class FarOwnerWidget extends StatefulWidget {
  final void Function(VerificationResult) onResult;
  const FarOwnerWidget({super.key, required this.onResult});

  @override
  State<FarOwnerWidget> createState() => _FarOwnerWidgetState();
}

class _FarOwnerWidgetState extends State<FarOwnerWidget> {
  late final VerificationService _service;
  final ImagePicker _picker = ImagePicker();

  // ID selection
  String  _idType  = 'nida';
  XFile?  _idImage;
  XFile?  _hatiImage;

  VerificationResult? _result;
  bool    _loading  = false;
  String? _statusMsg;

  static const _idOptions = [
    ('nida',            'NIDA Card'),
    ('driving_license', 'Driving License'),
    ('voter',           'Voter ID'),
  ];

  @override
  void initState() {
    super.initState();
    _service = VerificationService(
      photoSimilarityService: PhotoSimilarityService(),
      ocrService:             OcrService(),
    );
  }

  // ── Pick image ────────────────────────────────────────────────────────────
  Future<void> _pickImage({required bool isId}) async {
    final image = await _picker.pickImage(
      source:   ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (image == null) return;
    setState(() {
      if (isId) {
        _idImage = image;
      } else {
        _hatiImage = image;
      }
      _result    = null;
      _statusMsg = null;
    });
  }

  // ── Verify ────────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_idImage == null || _hatiImage == null) {
      setState(() => _statusMsg = 'Please upload both your ID card and Hati document.');
      return;
    }

    setState(() {
      _loading   = true;
      _statusMsg = 'Reading documents…';
    });

    final result = await _service.verifyFarOwner(
      idImage:        _idImage!,
      hatiImage:      _hatiImage!,
      idDocumentType: _idType,
    );

    setState(() {
      _loading   = false;
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
        // ── How it works ─────────────────────────────────────────────────
        _infoCard(),
        const SizedBox(height: 16),

        // ── ID type selector ──────────────────────────────────────────────
        Text('ID Card Type', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: _idOptions.map((opt) {
            final selected = _idType == opt.$1;
            return ChoiceChip(
              label:    Text(opt.$2),
              selected: selected,
              onSelected: (_) => setState(() => _idType = opt.$1),
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // ── ID card upload ────────────────────────────────────────────────
        _DocUploadTile(
          label:    '1. ID Card',
          hint:     'Upload a clear photo of your ${_idOptions.firstWhere((o) => o.$1 == _idType).$2}',
          icon:     Icons.badge_outlined,
          image:    _idImage,
          onTap:    () => _pickImage(isId: true),
          disabled: _loading,
        ),

        const SizedBox(height: 12),

        // ── Hati upload ───────────────────────────────────────────────────
        _DocUploadTile(
          label:    '2. Hati (Title Deed)',
          hint:     'Upload a clear photo of your Hati document',
          icon:     Icons.description_outlined,
          image:    _hatiImage,
          onTap:    () => _pickImage(isId: false),
          disabled: _loading,
        ),

        const SizedBox(height: 16),

        // ── Verify button ─────────────────────────────────────────────────
        ElevatedButton.icon(
          onPressed: (_loading || _idImage == null || _hatiImage == null) ? null : _verify,
          icon: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.document_scanner_outlined),
          label: Text(_loading ? 'Reading Documents…' : 'Verify Ownership'),
          style: ElevatedButton.styleFrom(
            padding:         const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),

        if (_statusMsg != null) ...[
          const SizedBox(height: 10),
          Text(_statusMsg!, style: theme.textTheme.bodySmall),
        ],

        if (_result != null) ...[
          const SizedBox(height: 16),
          _FarResultCard(result: _result!),
        ],
      ],
    );
  }

  Widget _infoCard() => Container(
    padding:    const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        Colors.orange.shade50,
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: Colors.orange.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📄 How it works',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('1. Upload your ID card (NIDA / Driving License / Voter ID).',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text('2. Upload your Hati (Title Deed) for this property.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text('3. We read both documents on-device — your data stays private.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text('4. Name match ≥ 70% → Verified ✅',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    ),
  );
}

// ── Upload tile ────────────────────────────────────────────────────────────

class _DocUploadTile extends StatelessWidget {
  final String  label;
  final String  hint;
  final IconData icon;
  final XFile?  image;
  final VoidCallback onTap;
  final bool    disabled;

  const _DocUploadTile({
    required this.label,
    required this.hint,
    required this.icon,
    required this.image,
    required this.onTap,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:     const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        image != null ? Colors.green.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
            color: image != null ? Colors.green.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(image != null ? Icons.check_circle_outline : icon,
                color: image != null ? Colors.green : Colors.grey.shade600,
                size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    image != null ? 'Uploaded: ${image!.name}' : hint,
                    style: TextStyle(
                      fontSize: 12,
                      color: image != null ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.upload_file_outlined,
                color: disabled ? Colors.grey.shade300 : Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

// ── Result card ────────────────────────────────────────────────────────────

class _FarResultCard extends StatelessWidget {
  final VerificationResult result;
  const _FarResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final verified = result.isVerified;
    final color    = verified ? Colors.green : Colors.red;
    final matchPct = result.nameMatchPct ?? 0.0;

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
            Icon(verified ? Icons.verified : Icons.cancel_outlined, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              verified ? 'Ownership Verified ✅' : 'Verification Rejected ❌',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
            ),
          ]),
          const SizedBox(height: 10),
          if (result.idNameExtracted != null && result.idNameExtracted!.isNotEmpty)
            _InfoRow('ID Name',   result.idNameExtracted!),
          if (result.hatiNameExtracted != null && result.hatiNameExtracted!.isNotEmpty)
            _InfoRow('Hati Name', result.hatiNameExtracted!),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 90,
                  child: Text('Name Match', style: TextStyle(fontSize: 13))),
              Expanded(
                child: LinearProgressIndicator(
                  value:           (matchPct / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    matchPct >= 70 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${matchPct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 90,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
        Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}
