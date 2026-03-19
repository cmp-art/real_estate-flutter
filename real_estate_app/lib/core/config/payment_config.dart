// lib/core/config/payment_config.dart
// SELCOM PAYMENT CONFIGURATION
//
// SECURITY MODEL:
//   Flutter app  →  POST /selcom/initialize  →  Your Node.js backend
//                                               ↓
//                                        Selcom API (credentials server-side only)
//
// The Flutter app ONLY needs SELCOM_BACKEND_URL (in assets/.env).
// SELCOM_VENDOR, SELCOM_API_KEY, and SELCOM_API_SECRET must NEVER be
// in this file or assets/.env — they live only in real_estate_app_backend/.env.
//
// Required key in assets/.env:
//   SELCOM_BACKEND_URL=https://your-backend.up.railway.app
//
// Leave SELCOM_BACKEND_URL empty → DEMO_MODE (no real payments).

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentConfig {
  // ── Backend URL ──────────────────────────────────────────────────────────
  // Your Node.js / Railway backend that proxies Selcom requests.
  // DEMO_MODE skips real payment processing (for UI testing only).
  // NEVER deploy to production with DEMO_MODE.
  static String get backendUrl {
    final url = dotenv.env['SELCOM_BACKEND_URL'] ?? '';
    if (url.isEmpty) {
      // Warn loudly in debug; fail silently in release (payment will show error)
      if (kDebugMode) {
        // ignore: avoid_print
        debugPrint(
          '⚠️  SELCOM_BACKEND_URL not set in .env — payments are in DEMO mode.'
          ' Set SELCOM_BACKEND_URL=https://your-backend.railway.app to enable.',
        );
      }
      return 'DEMO_MODE';
    }
    return url;
  }

  /// True only when no backend URL is configured.
  static bool get isDemoMode => backendUrl == 'DEMO_MODE';

  // ── Selcom credentials — REMOVED FROM CLIENT (security fix) ────────────
  //
  // selcomVendor, selcomApiKey, selcomApiSecret are intentionally removed.
  // Putting them in the Flutter app/assets/.env would expose them to anyone
  // who extracts the APK or PWA bundle.
  //
  // ➡  WHERE TO PUT THEM:
  //    Open  real_estate_app_backend/.env  and fill in:
  //      SELCOM_VENDOR=your_vendor_id
  //      SELCOM_API_KEY=your_api_key
  //      SELCOM_API_SECRET=your_api_secret
  //    That file lives only on your backend server, never shipped in the app.

  // ── Bei za Usajili (TZS) — Subscription Pricing ──────────────────────────
  // Pro ya Mwezi: TZS 10,000  (~$4)
  // Pro ya Mwaka: TZS 120,000 (~$46) — akiba ya miezi 2
  static const int proMonthlyPrice  = 15000;   // TSh 15,000/month
  static const int proYearlyPrice   = 120000;  // TZS 120,000/mwaka (save 33%)
  static const int freePrice        = 0;

  static const Map<String, int> pricing = {
    'free':          freePrice,
    'pro':          proMonthlyPrice,
    'pro_monthly':  proMonthlyPrice,
    'pro_yearly':    proYearlyPrice,
  };

  static int getPrice(String tier) => pricing[tier.toLowerCase()] ?? 0;

  static const String currency = 'TZS';
  static const String currencySymbol = 'TSh';

  // ── Selcom payment methods ────────────────────────────────────────────────
  static const Map<String, Map<String, String>> paymentMethods = {
    'mobile_money': {
      'name': 'Pesa ya Simu',
      'icon': '📱',
      'description': 'Lipa kwa M-Pesa, Tigo Pesa, Airtel Money au Halopesa',
      'code': 'MOBILE',
      'type': 'mobile',
    },
    'bank': {
      'name': 'Benki',
      'icon': '🏦',
      'description': 'Lipa moja kwa moja kutoka benki yako (CRDB, NMB, n.k.)',
      'code': 'BANK',
      'type': 'bank',
    },
    'card': {
      'name': 'Kadi ya Benki',
      'icon': '💳',
      'description': 'Lipa kwa Visa au Mastercard',
      'code': 'CARD',
      'type': 'card',
    },
  };

  static List<String> get availableMethods => paymentMethods.keys.toList();

  static String getSelcomCode(String method) =>
      paymentMethods[method]?['code'] ?? 'MOBILE';

  static bool requiresPhone(String method) =>
      paymentMethods[method]?['type'] == 'mobile';
}
