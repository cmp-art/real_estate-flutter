// lib/features/advertising/presentation/screens/add_funds_selcom_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/direct_ad_models.dart';
    
import '../../../../core/services/selcom_payment_service.dart';
import '../../../subscriptions/data/models/subscription_model.dart';
import '../provider/ad_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

class AddFundsScreen extends ConsumerStatefulWidget {
  final Advertiser advertiser;

  const AddFundsScreen({
    super.key,
    required this.advertiser,
  });

  @override
  ConsumerState<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends ConsumerState<AddFundsScreen>
    with WidgetsBindingObserver {  // ← observe app lifecycle for background payment fix
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  String _paymentMethod = 'mobile_money';
  bool _isProcessing = false;

  // Track pending payment for background reconciliation
  String? _pendingTransactionId;
  double? _pendingAmount;

  // Predefined amounts in TZS
  final List<double> _quickAmounts = [
    10000,
    25000,
    50000,
    100000,
    250000,
    500000,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // register for lifecycle events
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Called when app resumes from background.
  /// If a payment was pending when the app was backgrounded, attempt to
  /// verify it server-side so funds are always credited even if polling timed out.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _pendingTransactionId != null &&
        _pendingAmount != null) {
      _reconcileBackgroundPayment();
    }
  }

  Future<void> _reconcileBackgroundPayment() async {
    final txId = _pendingTransactionId;
    final amount = _pendingAmount;
    if (txId == null || amount == null) return;

    debugPrint('🔄 App resumed — reconciling pending payment: $txId');
    final adService = ref.read(directAdServiceProvider);
    final success = await adService.verifyAndCompletePayment(
      transactionId: txId,
      providerReference: txId,
      amount: amount,
      advertiserId: widget.advertiser.id,
    );

    if (success && mounted) {
      _pendingTransactionId = null;
      _pendingAmount = null;
      _showSuccessDialog(amount);
      Navigator.pop(context, true); // refresh dashboard
    }
  }

  void _selectQuickAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);

    setState(() => _isProcessing = true);

    try {
      // Initialize Selcom payment
      final selcomService = SelcomPaymentService();
      
      // Get user info
      final userEmail = widget.advertiser.email;
      final userPhone = _phoneController.text.isNotEmpty 
          ? _phoneController.text 
          : widget.advertiser.phone;

      debugPrint('💳 Processing Selcom payment - Amount: TZS $amount');

      final result = await selcomService.processPayment(
        userId: widget.advertiser.userId ?? widget.advertiser.id,
        userEmail: userEmail,
        userPhone: userPhone,
        tier: _mapAmountToTier(amount),
        billingCycle: 'once', // One-time payment for ad funds
        paymentMethod: _paymentMethod,
      );

      if (result.success) {
        debugPrint('✅ Payment initialized: ${result.paymentId}');

        // Store pending payment details BEFORE opening the URL.
        // If the user backgrounds the app, didChangeAppLifecycleState will
        // reconcile the payment when they return.
        _pendingTransactionId = result.paymentId;
        _pendingAmount = amount;

        // If payment URL exists, open it
        if (result.paymentUrl != null && result.paymentUrl != 'demo://payment-success') {
          await _openPaymentUrl(result.paymentUrl!);
        }

        // Start polling for payment verification
        await _pollPaymentStatus(result.paymentId!);
      } else {
        throw Exception(result.message ?? 'Payment initialization failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openPaymentUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching payment URL: $e');
    }
  }

  Future<void> _pollPaymentStatus(String paymentId) async {
    // Show loading dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Verifying payment...'),
            const SizedBox(height: 8),
            Text(
              'Please complete the payment on your device',
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Poll for payment status (max 2 minutes)
    const maxAttempts = 24; // 24 * 5 seconds = 2 minutes
    int attempts = 0;

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 5));
      attempts++;

      try {
        final selcomService = SelcomPaymentService();
        final isVerified = await selcomService.verifyPayment(
          paymentId: paymentId,
        );

        if (isVerified) {
          // Payment successful - record it
          final amount = double.parse(_amountController.text);
          await _recordSuccessfulPayment(paymentId, amount);
          _pendingTransactionId = null; // clear — no need for background reconciliation
          _pendingAmount = null;
          
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            Navigator.pop(context, true); // Return to dashboard with success
            _showSuccessDialog(amount);
          }
          return;
        }
      } catch (e) {
        debugPrint('Error verifying payment: $e');
      }
    }

    // Timeout
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verification timeout. Please check your transaction status.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _recordSuccessfulPayment(String transactionId, double amount) async {
    try {
      final adService = ref.read(directAdServiceProvider);
      
      await adService.processPayment(
        advertiserId: widget.advertiser.id,
        amount: amount,
        transactionId: transactionId,
        paymentMethod: _paymentMethod,
        providerReference: transactionId,
      );

      debugPrint('✅ Payment recorded in database');
    } catch (e) {
      debugPrint('Error recording payment: $e');
    }
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: ResponsiveHelper.getResponsiveIconSize(context)),
            const SizedBox(width: 12),
            const Text('Malipo Yamefanikiwa!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TSh ${amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 24), fontWeight: FontWeight.bold),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            const Text('imeongezwa kwenye akaunti yako'),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            Text(
              'Salio Jipya: TSh ${(widget.advertiser.accountBalance + amount).toStringAsFixed(0)}',
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14), color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // Map amount to a subscription tier (for Selcom integration)
  SubscriptionTier _mapAmountToTier(double amount) {
    // This is just for the payment metadata
    // We're not actually subscribing, just adding funds
    return SubscriptionTier.free;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ongeza Fedha'),
      ),
      body: SingleChildScrollView(
        // Responsive container for better layout on larger screens
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Balance
              Card(
                color: theme.primaryColor.withOpacity(0.1),
                child: Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salio la Sasa',
                            style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14), color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                      Text(
                        formatter.format(widget.advertiser.accountBalance),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 24),
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

              // Quick Amount Selection
              Text(
                'Kiasi cha Haraka',
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w600),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amount) {
                  final selected = _amountController.text == amount.toStringAsFixed(0);
                  return InkWell(
                    onTap: () => _selectQuickAmount(amount),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected 
                            ? theme.primaryColor 
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatter.format(amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

              // Custom Amount
              Text(
                'Au Ingiza Kiasi Chako',
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w600),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (TZS)',
                  hintText: '50000',
                  border: OutlineInputBorder(),
                  prefixText: 'TZS ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 10000) {
                    return 'Minimum amount is TZS 10,000';
                  }
                  if (amount > 10000000) {
                    return 'Maximum amount is TZS 10,000,000';
                  }
                  return null;
                },
              ),

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),

              // Payment Method
              Text(
                'Njia ya Malipo',
                style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.w600),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              _buildPaymentMethodCard(
                icon: Icons.phone_android,
                title: 'Pesa ya Simu',
                subtitle: 'M-Pesa, Tigo Pesa, Airtel Money, Halopesa',
                value: 'mobile_money',
                color: Colors.green,
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              _buildPaymentMethodCard(
                icon: Icons.credit_card,
                title: 'Kadi ya Benki',
                subtitle: 'Visa, Mastercard',
                value: 'card',
                color: Colors.blue,
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              _buildPaymentMethodCard(
                icon: Icons.account_balance,
                title: 'Benki',
                subtitle: 'CRDB, NMB, n.k.',
                value: 'bank',
                color: Colors.orange,
              ),

              // Phone number for mobile money
              if (_paymentMethod == 'mobile_money') ...[
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '0712345678',
                    border: OutlineInputBorder(),
                    prefixText: '+255 ',
                    helperText: 'Enter your mobile money number',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (_paymentMethod == 'mobile_money') {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your mobile number';
                      }
                      final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
                      if (cleaned.length < 9) {
                        return 'Please enter a valid mobile number';
                      }
                    }
                    return null;
                  },
                ),
              ],

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),

              // Pay Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                    backgroundColor: theme.primaryColor,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          _amountController.text.isNotEmpty
                              ? 'Pay ${formatter.format(double.tryParse(_amountController.text) ?? 0)}'
                              : 'Add Funds',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

              // Info Card
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                          const Text(
                            'Maelezo ya Malipo',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                      const Text('• Malipo yanafanywa na Selcom'),
                      const Text('• Fedha zinapatikana mara moja baada ya malipo'),
                      const Text('• Kiwango cha chini: TSh 10,000'),
                      const Text('• Miamala yote ni salama na imesimbwa'),
                      const Text('• Fedha ambazo hazijatumika hazirejeshewe'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color color,
  }) {
    final isSelected = _paymentMethod == value;

    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}

// Providers are defined in lib/core/providers/ad_providers.dart
// Do NOT redefine directAdServiceProvider here.