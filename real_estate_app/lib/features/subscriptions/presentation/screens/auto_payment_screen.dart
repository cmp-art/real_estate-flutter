// lib/features/subscriptions/presentation/screens/auto_payment_screen.dart
// SIMPLIFIED VERSION - NO COUNTRY, JUST PAYMENT METHODS

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/selcom_payment_service.dart';
import '../../../../core/config/payment_config.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../data/models/subscription_model.dart';
import '../../../../features/settings/presentation/providers/app_providers.dart';
import 'payment_webview_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class AutoPaymentScreen extends ConsumerStatefulWidget {
  final SubscriptionTier tier;
  final String billingCycle;

  const AutoPaymentScreen({
    super.key,
    required this.tier,
    this.billingCycle = 'monthly',
  });

  @override
  ConsumerState<AutoPaymentScreen> createState() => _AutoPaymentScreenState();
}

class _AutoPaymentScreenState extends ConsumerState<AutoPaymentScreen> {
  String? _selectedMethod;
  bool _isProcessing = false;
  final _phoneController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillPhone();
  }

  void _prefillPhone() {
    final user = ref.read(authNotifierProvider).value;
    if (user?.phone != null && user!.phone!.isNotEmpty) {
      // Extract local number from international format
      String phone = user.phone!;
      if (phone.startsWith('+255')) {
        phone = '0${phone.substring(4)}';
      }
      _phoneController.text = phone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  int get _price => widget.billingCycle == 'yearly'
      ? widget.tier.yearlyPriceTzs
      : widget.tier.monthlyPriceTzs;

  String get _cycleLabel =>
      widget.billingCycle == 'yearly' ? 'mwaka' : 'mwezi';

  @override
  Widget build(BuildContext context) {
    final price = _price;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Payment Method'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Subscription Info Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
              ),
            ),
            child: Column(
              children: [
                Text(
                  widget.tier.displayName,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 28),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                Text(
                  'TSh ${_fmt(price)}',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 48),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '/$_cycleLabel',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Payment Methods
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Chagua Njia ya Malipo',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                
                ..._buildPaymentMethods(),
                
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                
                // Show input fields based on selected method
                if (_selectedMethod != null) ..._buildPaymentInputs(),
              ],
            ),
          ),

          // Pay Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedMethod == null || _isProcessing
                    ? null
                    : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                  ),
                  elevation: _selectedMethod == null ? 0 : 2,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Lipa TSh ${_fmt(price)}',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPaymentMethods() {
    return PaymentConfig.availableMethods.map((method) {
      final methodInfo = PaymentConfig.paymentMethods[method];
      if (methodInfo == null) return const SizedBox.shrink();

      final isSelected = _selectedMethod == method;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
          side: BorderSide(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => setState(() => _selectedMethod = method),
          borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                  ),
                  child: Center(
                    child: Text(
                      methodInfo['icon'] as String,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        methodInfo['name'] as String,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        methodInfo['description'] as String,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.blue : Colors.grey[400],
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPaymentInputs() {
    final methodInfo = PaymentConfig.paymentMethods[_selectedMethod];
    if (methodInfo == null) return [];

    switch (_selectedMethod) {
      case 'mobile_money':
        return [
          const Divider(height: 32),
          Text(
            'Ingiza Nambari ya Simu',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: '0712 345 678',
              prefixIcon: const Icon(Icons.phone),
              prefixText: '+255 ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text(
            'Inafanya kazi na M-Pesa, Tigo Pesa, Airtel Money, Halopesa',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
              color: Colors.grey[600],
            ),
          ),
        ];

      case 'card':
        return [
          const Divider(height: 32),
          Text(
            'Ingiza Maelezo ya Kadi',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              _CardNumberFormatter(),
            ],
            decoration: InputDecoration(
              hintText: '1234 5678 9012 3456',
              prefixIcon: const Icon(Icons.credit_card),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardExpiryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _ExpiryDateFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: 'MM/YY',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              Expanded(
                child: TextField(
                  controller: _cardCvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    hintText: 'CVV',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ),
            ],
          ),
        ];

      case 'bank':
        return [
          const Divider(height: 32),
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                Expanded(
                  child: Text(
                    'Utaelekezwa kwenye benki yako ili kukamilisha malipo',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];

      default:
        return [];
    }
  }

  Future<void> _handlePayment() async {
    // Validate based on payment method
    if (_selectedMethod == 'mobile_money') {
      if (_phoneController.text.trim().isEmpty) {
        _showError('Please enter your mobile number');
        return;
      }
      if (_phoneController.text.trim().length < 9) {
        _showError('Please enter a valid phone number');
        return;
      }
    } else if (_selectedMethod == 'card') {
      if (_cardNumberController.text.trim().isEmpty) {
        _showError('Please enter card number');
        return;
      }
      if (_cardExpiryController.text.trim().isEmpty) {
        _showError('Please enter expiry date');
        return;
      }
      if (_cardCvvController.text.trim().isEmpty) {
        _showError('Please enter CVV');
        return;
      }
    }

    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      final paymentService = SelcomPaymentService();

      // Build payment data based on method
      String paymentData = '';
      if (_selectedMethod == 'mobile_money') {
        String phone = _phoneController.text.trim();
        if (!phone.startsWith('0') && !phone.startsWith('+')) {
          phone = '0$phone';
        }
        paymentData = phone;
      } else if (_selectedMethod == 'card') {
        paymentData = _cardNumberController.text.replaceAll(' ', '');
      }

      final result = await paymentService.processPayment(
        userId: user.id,
        userEmail: user.email,
        userPhone: paymentData.isNotEmpty ? paymentData : user.email,
        tier: widget.tier,
        billingCycle: widget.billingCycle,
        paymentMethod: _selectedMethod,
      );

      if (!mounted) return;

      if (result.success && result.paymentUrl != null) {
        // Navigate to payment webview
        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewScreen(
              paymentUrl: result.paymentUrl!,
              paymentId: result.paymentId!,
              provider: result.provider ?? 'selcom',
            ),
          ),
        );

        if (success == true && mounted) {
          // Activate the subscription in Supabase now that payment is confirmed.
          // Without this call the user stays on the Free tier despite paying.
          await ref
              .read(subscriptionNotifierProvider(user.id).notifier)
              .upgrade(
                tier: widget.tier,
                paymentProviderId: result.paymentId!,
              );
          if (mounted) Navigator.of(context).pop(true);
        }
      } else {
        _showError(result.message ?? 'Payment initialization failed');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Card number formatter
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

// Expiry date formatter
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    
    if (text.length <= 2) {
      return newValue;
    }
    
    final buffer = StringBuffer();
    buffer.write(text.substring(0, 2));
    buffer.write('/');
    buffer.write(text.substring(2, text.length > 4 ? 4 : text.length));
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}