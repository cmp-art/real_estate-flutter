// lib/features/advertising/presentation/screens/refund_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/services/direct_ad_models.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../provider/ad_providers.dart';

class RefundScreen extends ConsumerStatefulWidget {
  final AdCampaign campaign;
  final String advertiserId;

  const RefundScreen({
    super.key,
    required this.campaign,
    required this.advertiserId,
  });

  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();

  // 'balance' = instant wallet credit | 'cash' = mobile money payout
  String _refundType = 'balance';
  bool _isSubmitting = false;

  final _fmt = NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);

  double get _unspent =>
      (widget.campaign.totalBudget - widget.campaign.spentAmount)
          .clamp(0.0, double.infinity);

  @override
  void dispose() {
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final svc = ref.read(directAdServiceProvider);
    try {
      if (_refundType == 'balance') {
        await svc.requestBalanceRefund(
          advertiserId: widget.advertiserId,
          campaignId: widget.campaign.id,
          amount: _unspent,
        );
        if (mounted) {
          _showSuccess(
            '${_fmt.format(_unspent)} has been returned to your wallet.',
          );
        }
      } else {
        await svc.requestCashRefund(
          advertiserId: widget.advertiserId,
          campaignId: widget.campaign.id,
          amount: _unspent,
          phone: _phoneController.text.trim(),
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        );
        if (mounted) {
          _showSuccess(
            'Refund request submitted. We will send ${_fmt.format(_unspent)} '
            'to ${_phoneController.text.trim()} within 1–3 business days.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: ThemeConfig.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccess(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeConfig.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: ThemeConfig.successColor, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Refund Requested',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // tell caller to refresh
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.successColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = ResponsiveHelper.getContentHorizontalPadding(context);

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Request Refund'),
        backgroundColor: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightAppBarBackground,
          darkColor: ThemeConfig.darkAppBarBackground,
        ),
        foregroundColor: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightAppBarForeground,
          darkColor: ThemeConfig.darkAppBarForeground,
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Unspent summary ────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ThemeConfig.getPrimaryColor(context),
                          ThemeConfig.getPrimaryColor(context).withOpacity(0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Refundable Amount',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          _fmt.format(_unspent),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _summaryChip(
                                'Total Budget',
                                _fmt.format(widget.campaign.totalBudget)),
                            const SizedBox(width: 12),
                            _summaryChip(
                                'Spent',
                                _fmt.format(widget.campaign.spentAmount)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Refund type ────────────────────────────────────────
                  Text('How would you like your refund?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context, mobile: 15))),
                  const SizedBox(height: 12),

                  _RefundTypeCard(
                    title: 'Return to Wallet',
                    subtitle:
                        'Instant — funds go back to your ad account balance and can be used for future campaigns.',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: ThemeConfig.getPrimaryColor(context),
                    selected: _refundType == 'balance',
                    onTap: () => setState(() => _refundType = 'balance'),
                  ),
                  const SizedBox(height: 10),
                  _RefundTypeCard(
                    title: 'Cash Refund (Mobile Money)',
                    subtitle:
                        'We send the amount to your Selcom/M-Pesa/Airtel number. Allow 1–3 business days.',
                    icon: Icons.phone_android_rounded,
                    iconColor: Colors.green,
                    selected: _refundType == 'cash',
                    onTap: () => setState(() => _refundType = 'cash'),
                  ),

                  // ── Cash refund extra fields ───────────────────────────
                  if (_refundType == 'cash') ...[
                    const SizedBox(height: 24),
                    Text('Payment Details',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context, mobile: 15))),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(
                          color: ThemeConfig.getTextPrimaryColor(context)),
                      decoration: InputDecoration(
                        labelText: 'Mobile Money Number',
                        hintText: '0712 345 678',
                        prefixIcon:
                            const Icon(Icons.phone_android_rounded),
                        filled: true,
                        fillColor: ThemeConfig.getColor(context, lightColor: ThemeConfig.lightInputFill, darkColor: ThemeConfig.darkInputFill),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your mobile money number';
                        }
                        if (v.trim().length < 9) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 2,
                      style: TextStyle(
                          color: ThemeConfig.getTextPrimaryColor(context)),
                      decoration: InputDecoration(
                        labelText: 'Reason (optional)',
                        hintText: 'e.g. Campaign ended early, unused budget',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        filled: true,
                        fillColor: ThemeConfig.getColor(context, lightColor: ThemeConfig.lightInputFill, darkColor: ThemeConfig.darkInputFill),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Submit ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting || _unspent <= 0 ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _isSubmitting
                            ? 'Processing...'
                            : _refundType == 'balance'
                                ? 'Return to Wallet'
                                : 'Submit Refund Request',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ),

                  if (_unspent <= 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'No refundable amount — this campaign has used its full budget.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: ThemeConfig.getTextSecondaryColor(context),
                            fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _RefundTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _RefundTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? ThemeConfig.getPrimaryColor(context).withOpacity(0.07)
              : ThemeConfig.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? ThemeConfig.getPrimaryColor(context)
                : ThemeConfig.getColor(
                    context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected
                            ? ThemeConfig.getPrimaryColor(context)
                            : ThemeConfig.getTextPrimaryColor(context),
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeConfig.getTextSecondaryColor(context),
                        height: 1.4,
                      )),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: ThemeConfig.getPrimaryColor(context), size: 22),
          ],
        ),
      ),
    );
  }
}
