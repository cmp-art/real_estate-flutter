// lib/features/properties/presentation/widgets/trust_badge_widget.dart
//
// Reusable trust / verification badge shown on property listing cards
// and in the property detail screen.
//
// Maps [isOwnerVerified] (stored in Supabase) to the appropriate badge:
//   true  → 🟢 "VERIFIED"
//   false → no badge (clean — don't scare buyers with a red badge)
//
// Used by: property_list_card.dart, property_card.dart,
//          property_detail_screen.dart, admin_property_detail_screen.dart

import 'package:flutter/material.dart';

class TrustBadgeWidget extends StatelessWidget {
  final bool isVerified;

  /// If [compact] is true, shows just the icon + label without the border
  /// container — useful for tight spaces inside cards.
  final bool compact;

  const TrustBadgeWidget({
    super.key,
    required this.isVerified,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, color: Colors.white, size: 11),
          const SizedBox(width: 3),
          const Text(
            'VERIFIED',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color:        Colors.green.shade700,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: Colors.white, size: 11),
          SizedBox(width: 3),
          Text(
            'VERIFIED',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// A larger inline badge used in property detail / admin screens.
class TrustBadgeLarge extends StatelessWidget {
  final bool isVerified;
  const TrustBadgeLarge({super.key, required this.isVerified});

  @override
  Widget build(BuildContext context) {
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: Colors.green.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Text(
              'Identity Verified',
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.bold,
                color:      Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_outline, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            'Unverified Listing',
            style: TextStyle(
              fontSize:   13,
              color:      Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
