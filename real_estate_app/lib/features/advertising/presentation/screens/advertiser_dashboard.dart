// lib/features/advertising/presentation/screens/advertiser_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/theme_config.dart';
      // ← single source of truth
import '../../../../core/services/direct_ad_models.dart';
import '../provider/ad_providers.dart';
import 'add_funds_screen.dart';
import 'create_campaign_screen.dart';
import 'campaign_details_screen.dart';
import 'billing_history_screen.dart';

class AdvertiserDashboard extends ConsumerStatefulWidget {
  const AdvertiserDashboard({super.key});

  @override
  ConsumerState<AdvertiserDashboard> createState() =>
      _AdvertiserDashboardState();
}

class _AdvertiserDashboardState extends ConsumerState<AdvertiserDashboard> {
  Advertiser? _advertiser;
  AdvertiserStats? _stats;
  List<AdCampaign> _campaigns = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adService = ref.read(directAdServiceProvider);
      final supabaseUser = Supabase.instance.client.auth.currentUser;

      if (supabaseUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated. Please sign in.';
        });
        return;
      }

      final advertiser = await adService.ensureAdvertiserExists(
        userId: supabaseUser.id,
        email: supabaseUser.email!,
        fullName: supabaseUser.userMetadata?['full_name'] as String?,
        phone: supabaseUser.phone,
      );

      if (advertiser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to create advertiser account';
        });
        return;
      }

      final campaigns = await adService.getCampaigns(advertiser.id);
      final stats = await adService.getAdvertiserStats(advertiser.id);

      if (mounted) {
        setState(() {
          _advertiser = advertiser;
          _campaigns = campaigns;
          _stats = stats;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load advertiser data';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete campaign (soft-delete via RPC)
  // ---------------------------------------------------------------------------
  Future<void> _deleteCampaign(AdCampaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${campaign.campaignName}" will be removed from your dashboard.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeConfig.infoColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ThemeConfig.infoColor.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: ThemeConfig.infoColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All spend, impressions and click history are '
                      'preserved for billing records.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.errorColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) return;

    try {
      final adService = ref.read(directAdServiceProvider);
      final result = await adService.softDeleteCampaign(
        campaignId: campaign.id,
        userId: supabaseUser.id,
        reason: 'Deleted by advertiser from dashboard',
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign deleted successfully'),
            backgroundColor: ThemeConfig.successColor,
          ),
        );
        _loadDashboardData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to delete campaign'),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------
  Future<void> _navigateToAddFunds() async {
    if (_advertiser == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFundsScreen(advertiser: _advertiser!),
      ),
    );
    if (result == true && mounted) _loadDashboardData();
  }

  void _viewBillingHistory() {
    if (_advertiser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BillingHistoryScreen(advertiserId: _advertiser!.id),
      ),
    );
  }

  Future<void> _navigateToCreateCampaign() async {
    if (_advertiser == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCampaignScreen(
          advertiserId: _advertiser!.id,
          currentBalance: _advertiser!.accountBalance,
          advertiser: _advertiser!,
        ),
      ),
    );
    if (result != null && mounted) _loadDashboardData();
  }

  Future<void> _viewCampaignDetails(AdCampaign campaign) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignDetailsScreen(
          campaign: campaign,
          advertiserId: _advertiser!.id,
        ),
      ),
    );
    // true  = paused / resumed inside details
    // 'deleted' = campaign deleted inside details
    if ((result == true || result == 'deleted') && mounted) {
      _loadDashboardData();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Advertiser Dashboard',
          style: TextStyle(
            color: ThemeConfig.getColor(
              context,
              lightColor: ThemeConfig.lightAppBarForeground,
              darkColor: ThemeConfig.darkAppBarForeground,
            ),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightAppBarBackground,
          darkColor: ThemeConfig.darkAppBarBackground,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: ThemeConfig.getColor(
                context,
                lightColor: ThemeConfig.lightAppBarForeground,
                darkColor: ThemeConfig.darkAppBarForeground,
              ),
            ),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton:
          _advertiser != null && _advertiser!.canCreateCampaigns
              ? FloatingActionButton.extended(
                  onPressed: _navigateToCreateCampaign,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Campaign'),
                  backgroundColor: ThemeConfig.getPrimaryColor(context),
                  foregroundColor: Colors.white,
                )
              : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Body states
  // ---------------------------------------------------------------------------
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Dashboard...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 64, color: ThemeConfig.errorColor),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: ThemeConfig.getTextSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(context),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_advertiser == null) {
      return const Center(child: Text('Unable to load advertiser data'));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: ThemeConfig.getPrimaryColor(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 16),
            _buildQuickActionsCard(),
            const SizedBox(height: 16),
            if (_stats != null) ...[
              _buildStatsCard(),
              const SizedBox(height: 24),
            ],
            _buildCampaignsSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Balance card
  // ---------------------------------------------------------------------------
  Widget _buildBalanceCard() {
    final formatter =
        NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);
    final isLowBalance = _advertiser!.accountBalance < 10000;

    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ThemeConfig.getPrimaryColor(context),
              ThemeConfig.getPrimaryColor(context).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const Spacer(),
                if (isLowBalance)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ThemeConfig.warningColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Low Balance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Account Balance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatter.format(_advertiser!.accountBalance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Total Spent: ${formatter.format(_advertiser!.totalSpent)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder,
          ),
        ),
      ),
      color: ThemeConfig.getCardColor(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ThemeConfig.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.add_card_rounded,
                    label: 'Add Funds',
                    color: ThemeConfig.successColor,
                    onTap: _navigateToAddFunds,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Billing History',
                    color: ThemeConfig.infoColor,
                    onTap: _viewBillingHistory,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ThemeConfig.getTextPrimaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats card
  // ---------------------------------------------------------------------------
  Widget _buildStatsCard() {
    final stats = _stats!;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder,
          ),
        ),
      ),
      color: ThemeConfig.getCardColor(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ThemeConfig.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCell(
                    Icons.visibility_outlined,
                    'Impressions',
                    NumberFormat.compact().format(stats.totalImpressions),
                  ),
                ),
                Expanded(
                  child: _buildStatCell(
                    Icons.touch_app_outlined,
                    'Clicks',
                    NumberFormat.compact().format(stats.totalClicks),
                  ),
                ),
                Expanded(
                  child: _buildStatCell(
                    Icons.campaign_outlined,
                    'Active',
                    '${stats.activeCampaigns}',
                  ),
                ),
                Expanded(
                  child: _buildStatCell(
                    Icons.trending_up_rounded,
                    'Avg CTR',
                    '${stats.averageCtr.toStringAsFixed(2)}%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCell(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 24, color: ThemeConfig.getPrimaryColor(context)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ThemeConfig.getTextPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: ThemeConfig.getTextSecondaryColor(context),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Campaigns section
  // ---------------------------------------------------------------------------
  Widget _buildCampaignsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Campaigns',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ThemeConfig.getTextPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 12),
        if (_campaigns.isEmpty)
          _buildEmptyCampaigns()
        else
          ..._campaigns.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCampaignCard(c),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCampaigns() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder,
          ),
        ),
      ),
      color: ThemeConfig.getCardColor(context),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 64,
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
              const SizedBox(height: 16),
              Text(
                'No campaigns yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ThemeConfig.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first campaign to start advertising',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: ThemeConfig.getTextSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToCreateCampaign,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Campaign'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignCard(AdCampaign campaign) {
    final formatter =
        NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);
    final statusColor = _statusColor(campaign.status);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ThemeConfig.getColor(
            context,
            lightColor: ThemeConfig.lightBorder,
            darkColor: ThemeConfig.darkBorder,
          ),
        ),
      ),
      color: ThemeConfig.getCardColor(context),
      child: InkWell(
        onTap: () => _viewCampaignDetails(campaign),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name row + status chip + menu
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.campaignName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ThemeConfig.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      campaign.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: ThemeConfig.getTextSecondaryColor(context),
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'delete') _deleteCampaign(campaign);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever_rounded,
                                color: Colors.red, size: 20),
                            SizedBox(width: 10),
                            Text('Delete Campaign',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Approval badge
              _buildApprovalBadge(campaign.status),

              const SizedBox(height: 12),

              // Metrics row
              Row(
                children: [
                  _buildMiniMetric(
                      'Budget', formatter.format(campaign.totalBudget)),
                  _buildMiniMetric(
                      'Impressions',
                      NumberFormat.compact()
                          .format(campaign.impressionsCount)),
                  _buildMiniMetric(
                      'CTR', '${campaign.ctr.toStringAsFixed(2)}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    // Color-code CTR: green >1%, yellow 0.5-1%, red <0.5%
    Color valueColor = ThemeConfig.getTextPrimaryColor(context);
    if (label == 'CTR') {
      final ctr = double.tryParse(value.replaceAll('%', '')) ?? 0;
      if (ctr >= 1.0) {
        valueColor = Colors.green.shade600;
      } else if (ctr >= 0.5)  valueColor = Colors.orange.shade600;
      else                  valueColor = Colors.red.shade500;
    }
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: ThemeConfig.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalBadge(String status) {
    final s = status.toLowerCase();
    final bool approved =
        s == 'running' || s == 'paused' || s == 'completed';
    final bool rejected = s == 'rejected';

    final IconData icon;
    final String label;
    final Color color;

    if (approved) {
      icon = Icons.verified_rounded;
      label = 'Ad Approved';
      color = ThemeConfig.successColor;
    } else if (rejected) {
      icon = Icons.cancel_rounded;
      label = 'Ad Rejected';
      color = ThemeConfig.errorColor;
    } else {
      icon = Icons.hourglass_top_rounded;
      label = 'Pending Admin Review';
      color = ThemeConfig.warningColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return ThemeConfig.successColor;
      case 'paused':
        return ThemeConfig.warningColor;
      case 'completed':
        return ThemeConfig.infoColor;
      case 'rejected':
      case 'cancelled':
        return ThemeConfig.errorColor;
      default:
        return ThemeConfig.getTextSecondaryColor(context);
    }
  }
}

// ---------------------------------------------------------------------------
// PROVIDERS
// All providers (directAdServiceProvider, supabaseClientProvider,
// subscriptionServiceProvider) are defined in:
//   lib/core/providers/ad_providers.dart
// Never redefine them here — Riverpod would treat them as different singletons.
// ---------------------------------------------------------------------------