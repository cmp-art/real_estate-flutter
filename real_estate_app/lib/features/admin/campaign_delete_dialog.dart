// lib/features/advertiser/presentation/widgets/campaign_delete_dialog.dart
// Soft-delete confirmation dialog for campaigns and creatives.
// Explains clearly what "delete" means: stops serving but preserves history.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/direct_ad_models.dart';

import '../../../../presentation/providers/auth_provider.dart';
import '../advertising/presentation/provider/ad_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

// ─────────────────────────────────────────────────────────────
// CAMPAIGN DELETE DIALOG
// ─────────────────────────────────────────────────────────────

/// Shows a confirmation dialog to soft-delete a campaign.
/// Returns `true` if the user confirmed AND the delete succeeded.
Future<bool> showDeleteCampaignDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AdCampaign campaign,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            _CampaignDeleteDialog(campaign: campaign, ref: ref),
      ) ??
      false;
}

/// Shows a confirmation dialog to soft-delete a single creative.
Future<bool> showDeleteCreativeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AdCreative creative,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            _CreativeDeleteDialog(creative: creative, ref: ref),
      ) ??
      false;
}

// ─────────────────────────────────────────────────────────────

class _CampaignDeleteDialog extends ConsumerStatefulWidget {
  final AdCampaign campaign;
  final WidgetRef ref;

  const _CampaignDeleteDialog({
    required this.campaign,
    required this.ref,
  });

  @override
  ConsumerState<_CampaignDeleteDialog> createState() =>
      _CampaignDeleteDialogState();
}

class _CampaignDeleteDialogState
    extends ConsumerState<_CampaignDeleteDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final user = widget.ref.read(authNotifierProvider).value;
      if (user == null) {
        setState(() {
          _error = 'You must be logged in to delete a campaign.';
          _isDeleting = false;
        });
        return;
      }

      final adService = widget.ref.read(directAdServiceProvider);
      final result = await adService.softDeleteCampaign(
        campaignId: widget.campaign.id,
        userId: user.id,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );

      if (result.success) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = result.error ?? 'Failed to delete campaign.';
          _isDeleting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context))),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red),
          ),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          const Expanded(
            child: Text(
              'Delete Campaign',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campaign name
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
              ),
              child: Text(
                widget.campaign.campaignName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // What happens info box
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                border:
                    Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What happens when you delete:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                  SizedBox(height: 8),
                  _BulletPoint(
                    icon: Icons.stop_circle_outlined,
                    text: 'Your ad stops showing to users immediately.',
                    color: Colors.orange,
                  ),
                  _BulletPoint(
                    icon: Icons.history,
                    text:
                        'All impressions, clicks, and performance data are preserved.',
                    color: Colors.green,
                  ),
                  _BulletPoint(
                    icon: Icons.receipt_long,
                    text:
                        'Billing records and money spent remain on file — no refunds are issued.',
                    color: Colors.grey,
                  ),
                  _BulletPoint(
                    icon: Icons.admin_panel_settings,
                    text:
                        'Admin can still see all your campaign data for compliance purposes.',
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Campaign stats summary
            Row(
              children: [
                _StatChip(
                    label: 'Spent',
                    value:
                        'TZS ${widget.campaign.spentAmount.toStringAsFixed(0)}'),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                _StatChip(
                    label: 'Impressions',
                    value:
                        widget.campaign.impressionsCount.toString()),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                _StatChip(
                    label: 'Clicks',
                    value: widget.campaign.clicksCount.toString()),
              ],
            ),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

            // Optional reason
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Campaign goals met, budget exhausted...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment_outlined),
              ),
              maxLines: 2,
              maxLength: 200,
            ),

            if (_error != null) ...[
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isDeleting ? null : _confirmDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          icon: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.delete),
          label: Text(_isDeleting ? 'Deleting...' : 'Delete Campaign'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────

class _CreativeDeleteDialog extends ConsumerStatefulWidget {
  final AdCreative creative;
  final WidgetRef ref;

  const _CreativeDeleteDialog({
    required this.creative,
    required this.ref,
  });

  @override
  ConsumerState<_CreativeDeleteDialog> createState() =>
      _CreativeDeleteDialogState();
}

class _CreativeDeleteDialogState
    extends ConsumerState<_CreativeDeleteDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final user = widget.ref.read(authNotifierProvider).value;
      if (user == null) {
        setState(() {
          _error = 'You must be logged in.';
          _isDeleting = false;
        });
        return;
      }

      final adService = widget.ref.read(directAdServiceProvider);
      final result = await adService.softDeleteCreative(
        creativeId: widget.creative.id,
        userId: user.id,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );

      if (result.success) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = result.error ?? 'Failed to delete ad.';
          _isDeleting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context))),
      title: const Text('Delete Ad Creative'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deleting: "${widget.creative.headline}"'),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Text(
            'This ad will stop showing immediately. All impression and click data is kept on file.',
            style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13), color: Colors.grey),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            maxLength: 200,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isDeleting ? null : _confirmDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Delete Ad'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────

class _BulletPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _BulletPoint({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center),
            Text(label,
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}