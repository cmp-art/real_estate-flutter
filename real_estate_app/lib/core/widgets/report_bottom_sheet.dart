import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/report_service.dart';
import '../config/theme_config.dart';
import '../utils/snackbar_utils.dart';
import '../../presentation/providers/auth_provider.dart';

class ReportBottomSheet extends ConsumerStatefulWidget {
  final String? propertyId;
  final String? creativeId;
  final String? campaignId;

  const ReportBottomSheet._({
    super.key,
    this.propertyId,
    this.creativeId,
    this.campaignId,
  });

  factory ReportBottomSheet.property({Key? key, required String propertyId}) =>
      ReportBottomSheet._(key: key, propertyId: propertyId);

  factory ReportBottomSheet.ad({
    Key? key,
    required String creativeId,
    required String campaignId,
  }) =>
      ReportBottomSheet._(key: key, creativeId: creativeId, campaignId: campaignId);

  static Future<void> showProperty(BuildContext context, String propertyId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBottomSheet.property(propertyId: propertyId),
    );
  }

  static Future<void> showAd(
      BuildContext context, String creativeId, String campaignId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBottomSheet.ad(creativeId: creativeId, campaignId: campaignId),
    );
  }

  @override
  ConsumerState<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<ReportBottomSheet> {
  String? _selectedReason;
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isPropertyReport => widget.propertyId != null;

  List<Map<String, String>> get _reasons => _isPropertyReport
      ? [
          {'value': 'scam', 'label': 'This is a scam'},
          {'value': 'wrong_info', 'label': 'Wrong or misleading information'},
          {'value': 'duplicate', 'label': 'Duplicate listing'},
          {'value': 'inappropriate', 'label': 'Inappropriate content'},
          {'value': 'other', 'label': 'Other'},
        ]
      : [
          {'value': 'scam', 'label': 'This is a scam'},
          {'value': 'misleading', 'label': 'Misleading advertisement'},
          {'value': 'inappropriate', 'label': 'Inappropriate content'},
          {'value': 'spam', 'label': 'Spam'},
          {'value': 'other', 'label': 'Other'},
        ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);

    final user = ref.read(authNotifierProvider).value;
    final service = ReportService(Supabase.instance.client);

    ReportResult result;
    if (_isPropertyReport) {
      result = await service.reportProperty(
        propertyId: widget.propertyId!,
        reporterId: user?.id,
        reason: _selectedReason!,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
    } else {
      result = await service.reportAd(
        creativeId: widget.creativeId!,
        campaignId: widget.campaignId!,
        reporterId: user?.id,
        reason: _selectedReason!,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
      );
    }

    if (!mounted) return;
    Navigator.pop(context);

    switch (result) {
      case ReportResult.success:
        SnackbarUtils.showSuccess(
            context, 'Report submitted. Thank you for helping keep Patamjengo safe.');
        break;
      case ReportResult.alreadyReported:
        SnackbarUtils.showError(
            context, 'You have already reported this in the last 24 hours.');
        break;
      case ReportResult.error:
        SnackbarUtils.showError(context, 'Could not submit report. Please try again.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.flag_outlined, color: Colors.red[600], size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _isPropertyReport ? 'Report Listing' : 'Report Ad',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Help us keep Patamjengo safe and trustworthy.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              ..._reasons.map((r) => RadioListTile<String>(
                    value: r['value']!,
                    groupValue: _selectedReason,
                    onChanged: (v) => setState(() => _selectedReason = v),
                    title: Text(
                      r['label']!,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    activeColor: ThemeConfig.primaryColor,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 2,
                maxLength: 300,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400]),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedReason == null || _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        isDark ? Colors.grey[700] : Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit Report',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
