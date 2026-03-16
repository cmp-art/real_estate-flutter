// lib/core/config/ad_config.dart
//
// Central configuration for the DIRECT AD SYSTEM (self-serve, Supabase-backed).
//
// ⚠️  The previous version of this file configured Google AdMob, which is NOT
// used in this app.  AdMob integration has been removed to avoid dead code and
// confusing import errors.  If you want to add AdMob in the future, create a
// separate admob_config.dart rather than mixing it here.
//
// This file is the single source of truth for:
//   • Ad display settings (frequency per tier, density limits)
//   • Pricing benchmarks (used only for estimates — actual billing is server-side)
//   • Screen-level ad placement rules

/// Direct-ad display and pricing configuration.
///
/// All values here must stay in sync with:
///   - DirectAdService.getAdFrequencyForUser()
///   - DirectAdAlgorithm constants
///   - PropertyListScreen._adFrequency default
class AdConfig {
  AdConfig._();

  // ══════════════════════════════════════════════════════════════════════════
  // AD FREQUENCY PER SUBSCRIPTION TIER
  // ══════════════════════════════════════════════════════════════════════════

  /// Free tier: 1 ad for every 7 property slots (~14% density).
  /// Stays within Google Play / Apple App Store recommended ≤16% native ad
  /// density guideline.
  static const int adFrequencyFree = 7;

  /// Basic tier: 1 ad for every 12 property slots (~8% density).
  /// Lighter experience as a benefit over free.
  static const int adFrequencyBasic = 12;

  /// Pro tier: 0 — no ads shown.
  static const int adFrequencyPro = 0;

  // ══════════════════════════════════════════════════════════════════════════
  // AD POOL REFRESH
  // ══════════════════════════════════════════════════════════════════════════

  /// Reload eligible ads from the server after this many minutes of inactivity.
  /// Ensures campaigns that exhaust their daily budget mid-session stop showing.
  static const int adPoolRefreshMinutes = 15;

  // ══════════════════════════════════════════════════════════════════════════
  // PRICING BENCHMARKS  (for estimate UI only — not used for billing)
  // ══════════════════════════════════════════════════════════════════════════

  /// Conservative CTR for Tanzania real-estate audience (1.5%).
  static const double estimatedCtrPercent = 1.5;

  /// Minimum CPM bid in TZS.
  static const double minBidCpm = 1500.0;

  /// Minimum CPC bid in TZS.
  static const double minBidCpc = 400.0;

  // ══════════════════════════════════════════════════════════════════════════
  // SCREEN PLACEMENT RULES
  // ══════════════════════════════════════════════════════════════════════════

  /// Screens where inline (native-card) ads are injected.
  static const List<String> inlineAdScreens = [
    'property_list',
    'search_results',
    'favorites',
  ];

  /// Maximum number of ad slots rendered per screen render.
  /// Prevents an extremely long list from serving dozens of ads to one user.
  static const int maxAdsPerScreen = 10;

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION LIMITS
  // ══════════════════════════════════════════════════════════════════════════

  /// Maximum distinct ad impressions recorded per session.
  static const int maxImpressionsPerSession = 50;

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION HELPER
  // ══════════════════════════════════════════════════════════════════════════

  /// Sanity-check that frequency constants are internally consistent.
  static bool validate() {
    assert(adFrequencyFree > 0, 'Free frequency must be > 0');
    assert(adFrequencyBasic > adFrequencyFree,
        'Basic frequency must be less dense than free (higher number = less frequent)');
    assert(adFrequencyPro == 0, 'Pro must have no ads');
    assert(estimatedCtrPercent > 0 && estimatedCtrPercent < 100);
    assert(minBidCpm > 0 && minBidCpc > 0);
    return true;
  }
}