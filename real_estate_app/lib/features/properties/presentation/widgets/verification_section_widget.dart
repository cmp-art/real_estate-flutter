// lib/features/properties/presentation/widgets/verification_section_widget.dart
//
// Ownership verification section for the property create form.
//
// Placed at the bottom of the form, above the Submit button.
// Shows a method selector (Near Owner / Far Owner), then renders the
// relevant sub-widget.
//
// Usage:
//   VerificationSectionWidget(
//     listingPhotos: _selectedImages,      // XFile list (not yet uploaded)
//     onVerified:    (r) => setState(() => _verificationResult = r),
//     onLocationCaptured: (lat, lng) => setState(() {
//       _propertyLat = lat;
//       _propertyLng = lng;
//     }),
//   )

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/verification_result.dart';
import 'far_owner_widget.dart';
import 'near_owner_widget.dart';

enum _OwnerMethod { near, far }

class VerificationSectionWidget extends StatefulWidget {
  final List<XFile> listingPhotos;

  /// Called every time a verification attempt completes (pass or fail).
  final void Function(VerificationResult) onVerified;

  /// Called when the near-owner GPS capture completes so the parent can
  /// store lat/lng on the property entity.
  final void Function(double lat, double lng)? onLocationCaptured;

  const VerificationSectionWidget({
    super.key,
    required this.listingPhotos,
    required this.onVerified,
    this.onLocationCaptured,
  });

  @override
  State<VerificationSectionWidget> createState() =>
      _VerificationSectionWidgetState();
}

class _VerificationSectionWidgetState
    extends State<VerificationSectionWidget> {
  _OwnerMethod?       _method;
  VerificationResult? _result;

  void _handleResult(VerificationResult r) {
    setState(() => _result = r);
    widget.onVerified(r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ───────────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.security, size: 20),
            const SizedBox(width: 8),
            Text(
              'Ownership Verification',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_result != null) _StatusBadge(verified: _result!.isVerified),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Prove you own this property before publishing. '
          'Choose the method that applies to you.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: Colors.grey.shade600),
        ),

        const SizedBox(height: 14),

        // ── Method selector ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _MethodCard(
                icon:     Icons.location_on_outlined,
                title:    'I\'m Near\nthe Property',
                subtitle: 'GPS + live photo',
                selected: _method == _OwnerMethod.near,
                onTap:    () => setState(() {
                  _method = _OwnerMethod.near;
                  _result = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MethodCard(
                icon:     Icons.document_scanner_outlined,
                title:    'I\'m Far from\nthe Property',
                subtitle: 'ID card + Hati',
                selected: _method == _OwnerMethod.far,
                onTap:    () => setState(() {
                  _method = _OwnerMethod.far;
                  _result = null;
                }),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        // ── Active verification widget ───────────────────────────────────
        if (_method == _OwnerMethod.near)
          NearOwnerWidget(
            key:               const ValueKey('near'),
            listingPhotos:     widget.listingPhotos,
            onResult:          _handleResult,
            onLocationCaptured: widget.onLocationCaptured,
          )
        else if (_method == _OwnerMethod.far)
          FarOwnerWidget(
            key:      const ValueKey('far'),
            onResult: _handleResult,
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Select a method above to begin verification.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Method card ────────────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final bool         selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color   = selected ? primary : Colors.grey.shade400;

    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:    const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        selected
              ? primary.withValues(alpha: 0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:      selected ? primary : Colors.black87,
                fontSize:   13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool verified;
  const _StatusBadge({required this.verified});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: verified ? Colors.green.shade100 : Colors.red.shade100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: verified ? Colors.green.shade400 : Colors.red.shade400,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.verified : Icons.cancel_outlined,
          size:  14,
          color: verified ? Colors.green.shade700 : Colors.red.shade700,
        ),
        const SizedBox(width: 4),
        Text(
          verified ? 'Verified' : 'Rejected',
          style: TextStyle(
            fontSize:   12,
            fontWeight: FontWeight.bold,
            color:      verified ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ],
    ),
  );
}
