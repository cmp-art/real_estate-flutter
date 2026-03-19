// lib/features/subscriptions/presentation/screens/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../data/models/subscription_model.dart';

import '../../../../presentation/providers/auth_provider.dart';
import 'auto_payment_screen.dart';
import '../../../../core/utils/responsive_helper.dart';
// ✅ ADD THIS

/// Subscription management screen
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  SubscriptionTier? _selectedTier;
  bool _isLoading = false;
  bool _yearlyBilling = false; // toggle monthly ↔ yearly
  List<SubscriptionTierInfo> _tiers = [];
  UserSubscription? _currentSubscription;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() => _isLoading = true);

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      
      // Load available tiers
      final tiers = await subscriptionService.getAvailableTiers();
      
      // Load current subscription
      final user = ref.read(authNotifierProvider).value;
      UserSubscription? currentSub;
      if (user != null) {
        currentSub = await subscriptionService.getUserSubscription(user.id);
      }

      setState(() {
        _tiers = tiers;
        _currentSubscription = currentSub;
        _selectedTier = currentSub?.tier;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subscriptions: $e')),
        );
      }
    }
  }

  Future<void> _navigateToPayment(SubscriptionTier tier) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AutoPaymentScreen(
          tier: tier,
          billingCycle: _yearlyBilling ? 'yearly' : 'monthly',
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadSubscriptionData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usajili umewashwa! — Subscription activated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mipango ya Usajili'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        if (_currentSubscription != null) _buildCurrentSubscriptionBanner(),
        // Monthly / Yearly toggle
        _buildBillingToggle(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
            children: [
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              _buildTierCard(SubscriptionTier.free),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              _buildTierCard(SubscriptionTier.pro),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Kila Mwezi', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Switch(
            value: _yearlyBilling,
            onChanged: (v) => setState(() => _yearlyBilling = v),
            activeColor: Colors.green,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kila Mwaka', style: TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Okoa 33%',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSubscriptionBanner() {
    final sub   = _currentSubscription!;
    final tier  = sub.tier;
    final color = _getTierColor(tier);

    final expiresAt  = sub.expiresAt;
    final daysLeft   = expiresAt.difference(DateTime.now()).inDays;
    final expiryText = daysLeft > 365
        ? 'Hai — bila muda'
        : daysLeft > 0
            ? 'Inaisha siku $daysLeft ${daysLeft == 1 ? 'iliyobaki' : 'zilizobaki'} '
              '(${expiresAt.day}/${expiresAt.month}/${expiresAt.year})'
            : 'Usajili umeisha muda';
    final expiryColor = daysLeft <= 7
        ? Colors.red.shade600
        : daysLeft <= 30
            ? Colors.orange.shade600
            : color;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          Text(
            'Mpango Wako wa Sasa',
            style: TextStyle(
              color: color,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tier.displayName,
            style: TextStyle(
              color: color,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            expiryText,
            style: TextStyle(
              color: expiryColor,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
              fontWeight: daysLeft <= 7 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(SubscriptionTier tier) {
    final isCurrent = _currentSubscription?.tier == tier;
    final isSelected = _selectedTier == tier;
    final color = _getTierColor(tier);

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: tier != _currentSubscription?.tier
            ? () {
                setState(() => _selectedTier = tier);
                
                // ✅ NAVIGATE TO PAYMENT for paid tiers
                if (tier != SubscriptionTier.free) {
                  _navigateToPayment(tier);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tier name and badge
              Row(
                children: [
                  Text(
                    tier.displayName,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 24),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                      ),
                      child: Text(
                        'SASA HIVI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (tier == SubscriptionTier.pro && !isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                      ),
                      child: Text(
                        'MAARUFU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              
              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tier == SubscriptionTier.free
                        ? 'Bure'
                        : 'TSh ${_yearlyBilling ? _fmt(tier.yearlyPriceTzs) : _fmt(tier.monthlyPriceTzs)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 32),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (tier != SubscriptionTier.free)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        _yearlyBilling ? '/mwaka' : '/mwezi',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
              // Yearly savings note
              if (tier != SubscriptionTier.free && _yearlyBilling) ...[
                const SizedBox(height: 4),
                Text(
                  'Sawa na TSh ${_fmt(tier.yearlyPriceTzs ~/ 12)}/mwezi — okoa TSh ${_fmt(tier.monthlyPriceTzs * 12 - tier.yearlyPriceTzs)}',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              
              // Description
              Text(
                tier.description,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              
              // Features
              ..._buildFeaturesList(tier),
              
              // ✅ ADD "Subscribe" button for non-current tiers
              if (!isCurrent && tier != SubscriptionTier.free) ...[
                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _navigateToPayment(tier),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                      ),
                    ),
                    child: const Text(
                      'Jiandikishe Sasa',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeaturesList(SubscriptionTier tier) {
    final features = _getFeatures(tier);
    return features
        .map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: _getTierColor(tier),
                    size: 20,
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  /// Format number with thousands separator e.g. 120000 → "120,000"
  String _fmt(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
  }

  List<String> _getFeatures(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return [
          'Tazama mali bila kikomo',
          'Unda hadi matangazo 3 ya picha',
          'Video haitumiki (inahitaji Pro)',
          'Hifadhi hadi vipendwa 5',
          'Tuma hadi ujumbe 20 kwa siku',
          'Vichujio vya msingi vya utafutaji',
          'Ina matangazo ya wengine',
        ];
      case SubscriptionTier.pro:
        return [
          'Tazama mali bila kikomo',
          'Matangazo ya picha bila kikomo',
          'Matangazo ya video bila kikomo',
          'Vipendwa bila kikomo',
          'Ujumbe bila kikomo',
          'Vichujio vya hali ya juu',
          'Hakuna matangazo ya wengine',
          'Nafasi ya kwanza katika matokeo',
          'Beji ya tangazo lililoangaziwa',
          'Takwimu za kina za tangazo lako',
          'Msaada wa kipaumbele',
        ];
    }
  }

  Color _getTierColor(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return Colors.grey;
      case SubscriptionTier.pro:
        return Colors.green;
    }
  }
}