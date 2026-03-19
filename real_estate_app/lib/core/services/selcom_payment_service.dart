// lib/core/services/selcom_payment_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../features/subscriptions/data/models/subscription_model.dart';
import '../config/payment_config.dart';
import '../utils/logger.dart';

class SelcomPaymentService {
  /// Process payment with Selcom.
  ///
  /// Pass [amountOverride] for one-off payments (e.g. ad fund top-ups) where
  /// the amount is chosen by the user rather than derived from a subscription tier.
  /// If omitted the amount is looked up from [PaymentConfig] for the given [tier].
  Future<PaymentResult> processPayment({
    required String userId,
    required String userEmail,
    required String userPhone,
    required SubscriptionTier tier,
    required String billingCycle,
    required String? paymentMethod,
    int? amountOverride,
  }) async {
    try {
      logger.d('Processing Selcom payment - User: $userId, Tier: ${tier.name}, Method: $paymentMethod');

      // Check if demo mode
      if (PaymentConfig.backendUrl == 'DEMO_MODE') {
        logger.w('DEMO MODE - Simulating payment');
        return await _simulatePayment(userId, tier, billingCycle, paymentMethod);
      }

      // Amount: use override (ad funds) or tier price (subscription).
      final amount = amountOverride ?? PaymentConfig.getPrice(tier.name);
      final orderId = 'SUB_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // Get Selcom method code
      final selcomCode = PaymentConfig.getSelcomCode(paymentMethod ?? 'mobile_money');

      logger.d('Amount: ${PaymentConfig.currencySymbol}$amount, Order ID: $orderId');

      // Build payment data based on method.
      // NOTE: vendor/api_key/secret are NOT sent from the client — the backend
      // reads them from its own server-side .env file (process.env.SELCOM_VENDOR etc.)
      Map<String, dynamic> paymentData = {
        'order_id': orderId,
        'amount': amount,
        'currency': PaymentConfig.currency,
        'payment_method': selcomCode,
        'webhook_url': '${PaymentConfig.backendUrl}/selcom/webhook',
        'redirect_url': '${PaymentConfig.backendUrl}/selcom/callback',
        'metadata': {
          'user_id': userId,
          'tier': tier.name,
          'billing_cycle': billingCycle,
        },
      };

      // Add method-specific data
      if (paymentMethod == 'mobile_money') {
        final cleanPhone = _cleanPhoneNumber(userPhone);
        if (cleanPhone.isEmpty) {
          logger.e('Invalid phone number for mobile money payment');
          return PaymentResult(
            success: false,
            message: 'Please enter a valid phone number',
          );
        }
        paymentData['buyer_phone'] = cleanPhone;
      } else if (paymentMethod == 'card' || paymentMethod == 'bank') {
        paymentData['buyer_email'] = userEmail;
      }

      // Call backend to initialize Selcom payment
      final response = await http.post(
        Uri.parse('${PaymentConfig.backendUrl}/selcom/initialize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(paymentData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          logger.d('Payment initialized successfully');
          return PaymentResult(
            success: true,
            paymentUrl: data['payment_url'],
            paymentId: data['order_id'] ?? orderId,
            provider: 'selcom',
            message: 'Payment initialized',
          );
        }

        // Parse backend error message
        final backendMsg = data['message'] as String? ?? '';
        final userMsg = backendMsg.isNotEmpty ? backendMsg : 'Payment setup failed. Please try again.';
        logger.e('Payment backend error: $backendMsg');
        return PaymentResult(success: false, message: userMsg);
      }

      // HTTP error — map to user-friendly message
      final String userFacingError;
      switch (response.statusCode) {
        case 400: userFacingError = 'Invalid payment details. Please check and retry.'; break;
        case 401: userFacingError = 'Payment service not configured. Contact support.'; break;
        case 500: userFacingError = 'Payment service temporarily unavailable. Try again.'; break;
        case 503: userFacingError = 'Payment service is down. Please try again later.'; break;
        default:  userFacingError = 'Payment initialization failed (${response.statusCode}). Please try again.';
      }
      logger.e('Payment init failed — HTTP ${response.statusCode}');
      return PaymentResult(success: false, message: userFacingError);
    } catch (e, stackTrace) {
      logger.e('Selcom payment error', error: e, stackTrace: stackTrace);
      // Never expose exception details to user
      final isNetworkError = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('connection');
      return PaymentResult(
        success: false,
        message: isNetworkError
            ? 'No internet connection. Please check your network and try again.'
            : 'Payment could not be started. Please try again.',
      );
    }
  }

  /// Verify payment with Selcom
  Future<bool> verifyPayment({
    required String paymentId,
  }) async {
    try {
      logger.d('Verifying Selcom payment: $paymentId');

      // Check if demo mode
      if (PaymentConfig.backendUrl == 'DEMO_MODE') {
        logger.w('DEMO MODE - Auto-verifying payment');
        await Future.delayed(const Duration(seconds: 1));
        return true;
      }

      // Call backend to verify payment
      final response = await http.post(
        Uri.parse('${PaymentConfig.backendUrl}/selcom/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transaction_id': paymentId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isSuccess = data['status'] == 'successful';
        
        if (isSuccess) {
          logger.d('Payment verified successfully');
        } else {
          logger.w('Payment verification failed');
        }
        return isSuccess;
      }

      logger.e('Verification request failed - Status: ${response.statusCode}');
      return false;
    } catch (e, stackTrace) {
      logger.e('Selcom verification error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Clean phone number to Tanzania format
  String _cleanPhoneNumber(String phone) {
    // Remove all non-digits
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Handle different formats
    if (cleaned.startsWith('255')) {
      return '+$cleaned';
    } else if (cleaned.startsWith('0')) {
      return '+255${cleaned.substring(1)}';
    } else if (cleaned.length == 9) {
      return '+255$cleaned';
    }

    return cleaned.isEmpty ? '' : '+$cleaned';
  }

  /// Simulate payment for demo mode
  Future<PaymentResult> _simulatePayment(
    String userId,
    SubscriptionTier tier,
    String billingCycle,
    String? paymentMethod,
  ) async {
    logger.w('Simulating ${paymentMethod ?? 'unknown'} payment in DEMO MODE');
    
    // Simulate different delays for different methods
    if (paymentMethod == 'mobile_money') {
      await Future.delayed(const Duration(seconds: 2));
    } else if (paymentMethod == 'card') {
      await Future.delayed(const Duration(seconds: 3));
    } else {
      await Future.delayed(const Duration(seconds: 2));
    }

    final orderId = 'DEMO_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    logger.d('Demo payment successful - Order: $orderId');

    return PaymentResult(
      success: true,
      paymentUrl: 'demo://payment-success',
      paymentId: orderId,
      provider: 'selcom',
      message: 'Demo payment successful via $paymentMethod',
    );
  }
}

/// Payment result model
class PaymentResult {
  final bool success;
  final String? paymentUrl;
  final String? paymentId;
  final String? provider;
  final String? message;

  PaymentResult({
    required this.success,
    this.paymentUrl,
    this.paymentId,
    this.provider,
    this.message,
  });
}