// features/subscriptions/presentation/screens/payment_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../../../core/services/integrated_payment_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/responsive_helper.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String paymentId;
  final String provider;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.paymentId,
    required this.provider,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  static const String _tag = 'PaymentWebView';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _checkPaymentCompletion(url);
          },
          onWebResourceError: (WebResourceError error) {
            logger.e('WebView error', error: error.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentCompletion(String url) {
    if (url.contains('/callback') || 
        url.contains('/success') ||
        url.contains('status=successful') ||
        url.contains('status=success')) {
      logger.d('Payment callback detected');
      _verifyPayment();
    }
  }

  Future<void> _verifyPayment() async {
    if (_isVerifying) return;

    setState(() => _isVerifying = true);

    try {
      final paymentService = IntegratedPaymentService();
      final isVerified = await paymentService.verifyPayment(
        paymentId: widget.paymentId,
        provider: widget.provider,
      );

      if (!mounted) return;

      if (isVerified) {
        logger.d('Payment verified successfully');
        _showPaymentSuccess();
      } else {
        logger.w('Payment verification failed');
        _showPaymentFailed();
      }
    } catch (e, stack) {
      logger.e('Verification error', error: e, stackTrace: stack);
      if (mounted) _showPaymentFailed();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showPaymentSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: ResponsiveHelper.getResponsiveIconSize(context)),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            const Text('Payment Successful!'),
          ],
        ),
        content: const Text(
          'Your subscription has been activated successfully.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showPaymentFailed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: ResponsiveHelper.getResponsiveIconSize(context)),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            const Text('Payment Failed'),
          ],
        ),
        content: const Text(
          'Your payment could not be processed. Please try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Payment?'),
                content: const Text(
                  'Are you sure you want to cancel this payment?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop(false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Yes, Cancel'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: SpinKitFadingCircle(
                  color: Colors.blue,
                  size: 50.0,
                ),
              ),
            ),
          if (_isVerifying)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SpinKitFadingCircle(
                          color: Colors.blue,
                          size: 50.0,
                        ),
                        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                        Text(
                          'Verifying payment...',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}