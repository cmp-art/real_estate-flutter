// lib/core/services/integrated_payment_service.dart
import '../config/payment_config.dart';
import '../../features/subscriptions/data/models/subscription_model.dart';
import 'selcom_payment_service.dart';
import '../utils/logger.dart';

class IntegratedPaymentService {
  final SelcomPaymentService _selcomService = SelcomPaymentService();
  
  bool get _isDemoMode => PaymentConfig.backendUrl == 'DEMO_MODE';
  
  /// Process payment - Selcom only
  Future<Object> processPayment({
    required String userId,
    required String userEmail,
    required String userPhone,
    required SubscriptionTier tier,
    required String billingCycle,
    String? paymentMethod,
  }) async {
    try {
      logger.d('Processing payment - User: $userId, Tier: ${tier.displayName}, Cycle: $billingCycle');
      
      // Demo mode check
      if (_isDemoMode) {
        logger.w('DEMO MODE: Simulating payment success');
        await Future.delayed(const Duration(seconds: 2));
        
        return PaymentResult(
          success: true,
          paymentId: 'DEMO-${DateTime.now().millisecondsSinceEpoch}',
          paymentUrl: 'demo://payment-success',
          provider: 'demo',
          message: 'Demo payment successful',
        );
      }
      
      // Real payment processing via Selcom
      return await _selcomService.processPayment(
        userId: userId,
        userEmail: userEmail,
        userPhone: userPhone,
        tier: tier,
        billingCycle: billingCycle,
        paymentMethod: paymentMethod,
      );
      
    } catch (e, stackTrace) {
      logger.e('Payment processing error', error: e, stackTrace: stackTrace);
      return PaymentResult(
        success: false,
        message: 'Payment failed: ${e.toString()}',
      );
    }
  }
  
  /// Verify payment completion
  Future<bool> verifyPayment({
    required String paymentId,
    required String provider,
  }) async {
    try {
      logger.d('Verifying payment - ID: $paymentId, Provider: $provider');
      
      // Demo mode always returns true
      if (_isDemoMode) {
        logger.w('DEMO MODE: Auto-verifying payment');
        await Future.delayed(const Duration(seconds: 1));
        return true;
      }
      
      // Real verification via Selcom
      return await _selcomService.verifyPayment(paymentId: paymentId);
      
    } catch (e, stackTrace) {
      logger.e('Payment verification error', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}

/// Payment result model
class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? paymentUrl;
  final String? provider;
  final String? message;
  
  PaymentResult({
    required this.success,
    this.paymentId,
    this.paymentUrl,
    this.provider,
    this.message,
  });
}