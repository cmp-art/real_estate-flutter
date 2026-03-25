// lib/features/advertising/presentation/screens/campaign_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/services/direct_ad_models.dart';
import '../provider/ad_providers.dart';
import 'create_creative_screen.dart';
import 'refund_screen.dart';
import 'invoice_screen.dart';
import '../../../../core/utils/responsive_helper.dart';

class CampaignDetailsScreen extends ConsumerStatefulWidget {
  final AdCampaign campaign;
  final String advertiserId;
  final Advertiser advertiser;

  const CampaignDetailsScreen({
    super.key,
    required this.campaign,
    required this.advertiserId,
    required this.advertiser,
  });

  @override
  ConsumerState<CampaignDetailsScreen> createState() =>
      _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState
    extends ConsumerState<CampaignDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AdCreative> _creatives = [];
  bool _isLoadingCreatives = true;
  bool _isActioning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCreatives();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------
  Future<void> _loadCreatives() async {
    setState(() => _isLoadingCreatives = true);
    try {
      final adService = ref.read(directAdServiceProvider);
      final creatives = await adService.getCreatives(widget.campaign.id);
      if (mounted) {
        setState(() {
          _creatives = creatives;
          _isLoadingCreatives = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading creatives: $e');
      if (mounted) setState(() => _isLoadingCreatives = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Campaign actions
  // ---------------------------------------------------------------------------
  Future<void> _pauseCampaign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pause Campaign?'),
        content: const Text(
            'This campaign will stop serving ads immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.warningColor,
                foregroundColor: Colors.white),
            child: const Text('Pause'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _setCampaignStatus('paused');
  }

  Future<void> _resumeCampaign() async {
    await _setCampaignStatus('running');
  }

  Future<void> _setCampaignStatus(String status) async {
    setState(() => _isActioning = true);
    try {
      final adService = ref.read(directAdServiceProvider);
      await adService.updateCampaignStatus(
        campaignId: widget.campaign.id,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                status == 'paused' ? 'Campaign paused' : 'Campaign resumed'),
            backgroundColor: ThemeConfig.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete campaign
  // ---------------------------------------------------------------------------
  Future<void> _deleteCampaign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${widget.campaign.campaignName}" will be permanently removed.',
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
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
                      'preserved for billing records. '
                      'This cannot be undone.',
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
            icon: Icon(Icons.delete_forever_rounded, size: ResponsiveHelper.getResponsiveIconSize(context)),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) return;

    setState(() => _isActioning = true);
    try {
      final adService = ref.read(directAdServiceProvider);
      final result = await adService.softDeleteCampaign(
        campaignId: widget.campaign.id,
        userId: supabaseUser.id,
        reason: 'Deleted by advertiser',
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign deleted successfully'),
            backgroundColor: ThemeConfig.successColor,
          ),
        );
        Navigator.pop(context, 'deleted');
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
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete creative
  // ---------------------------------------------------------------------------
  Future<void> _deleteCreative(AdCreative creative) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ad Creative?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${creative.headline}" will be removed from this campaign.'),
            const SizedBox(height: 10),
            Text(
              '${creative.impressions} impressions • ${creative.clicks} clicks',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Container(
              padding: const EdgeInsets.all(10),
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
                      size: 14, color: ThemeConfig.infoColor),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All impression and click history is preserved.',
                      style: TextStyle(fontSize: 11),
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
            icon: Icon(Icons.delete_rounded, size: ResponsiveHelper.getResponsiveIconSize(context)),
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
      final result = await adService.softDeleteCreative(
        creativeId: creative.id,
        userId: supabaseUser.id,
        reason: 'Deleted by advertiser',
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad creative deleted'),
            backgroundColor: ThemeConfig.successColor,
          ),
        );
        _loadCreatives();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to delete creative'),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: ThemeConfig.errorColor),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final appBarFg = ThemeConfig.getColor(
      context,
      lightColor: ThemeConfig.lightAppBarForeground,
      darkColor: ThemeConfig.darkAppBarForeground,
    );

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          widget.campaign.campaignName,
          style: TextStyle(
            color: appBarFg,
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightAppBarBackground,
          darkColor: ThemeConfig.darkAppBarBackground,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: appBarFg,
          unselectedLabelColor: appBarFg.withOpacity(0.6),
          indicatorColor: appBarFg,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Creatives'),
            Tab(text: 'Performance'),
          ],
        ),
        actions: [
          if (_isActioning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else ...[
            if (widget.campaign.isPaused)
              IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: appBarFg),
                onPressed: _resumeCampaign,
                tooltip: 'Resume Campaign',
              )
            else if (widget.campaign.isRunning)
              IconButton(
                icon: Icon(Icons.pause_rounded, color: appBarFg),
                onPressed: _pauseCampaign,
                tooltip: 'Pause Campaign',
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: appBarFg),
              onSelected: (v) async {
                if (v == 'delete') {
                  _deleteCampaign();
                } else if (v == 'refund') {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RefundScreen(
                        campaign: widget.campaign,
                        advertiserId: widget.advertiserId,
                      ),
                    ),
                  );
                  if (result == true && mounted) Navigator.pop(context, true);
                } else if (v == 'invoice') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceScreen(
                        campaign: widget.campaign,
                        advertiser: widget.advertiser,
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'invoice',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          color: ThemeConfig.getPrimaryColor(context),
                          size: ResponsiveHelper.getResponsiveIconSize(context)),
                      const SizedBox(width: 10),
                      const Text('View Invoice'),
                    ],
                  ),
                ),
                if ((widget.campaign.totalBudget - widget.campaign.spentAmount) > 0)
                  PopupMenuItem<String>(
                    value: 'refund',
                    child: Row(
                      children: [
                        Icon(Icons.undo_rounded,
                            color: Colors.orange,
                            size: ResponsiveHelper.getResponsiveIconSize(context)),
                        const SizedBox(width: 10),
                        const Text('Request Refund',
                            style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded,
                          color: Colors.red, size: ResponsiveHelper.getResponsiveIconSize(context)),
                      const SizedBox(width: 10),
                      const Text('Delete Campaign',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildCreativesTab(),
          _buildPerformanceTab(),
        ],
      ),
      floatingActionButton:
          (widget.campaign.isRunning || widget.campaign.isPaused)
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateCreativeScreen(
                          campaignId: widget.campaign.id,
                          campaign: widget.campaign,
                        ),
                      ),
                    );
                    if (result != null && mounted) _loadCreatives();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Creative'),
                  backgroundColor: ThemeConfig.getPrimaryColor(context),
                  foregroundColor: Colors.white,
                )
              : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Overview tab
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab() {
    final formatter =
        NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);
    final statusColor = _statusColor(widget.campaign.status);

    final hPad = ResponsiveHelper.getContentHorizontalPadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: ResponsiveHelper.getResponsivePadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: statusColor.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_statusIcon(widget.campaign.status),
                        color: statusColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.campaign.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusDescription(widget.campaign.status),
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                            color:
                                ThemeConfig.getTextSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

          // Budget card
          _buildSectionCard(
            title: 'Budget',
            child: Column(
              children: [
                _buildRow('Daily Budget',
                    formatter.format(widget.campaign.dailyBudget)),
                const SizedBox(height: 10),
                _buildRow('Total Budget',
                    formatter.format(widget.campaign.totalBudget)),
                const SizedBox(height: 10),
                _buildRow(
                  'Spent',
                  formatter.format(widget.campaign.spentAmount),
                  valueColor: ThemeConfig.errorColor,
                ),
                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: widget.campaign.budgetUsagePercentage / 100,
                    minHeight: 8,
                    backgroundColor: ThemeConfig.getColor(
                      context,
                      lightColor: ThemeConfig.lightInputFill,
                      darkColor: ThemeConfig.darkInputFill,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeConfig.getPrimaryColor(context)),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${widget.campaign.budgetUsagePercentage.toStringAsFixed(1)}% used',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                      color: ThemeConfig.getTextSecondaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

          // Campaign details card
          _buildSectionCard(
            title: 'Campaign Details',
            child: Column(
              children: [
                _buildRow('Objective',
                    _formatObjective(widget.campaign.campaignObjective)),
                const SizedBox(height: 10),
                _buildRow(
                  'Bidding',
                  '${widget.campaign.biddingStrategy.toUpperCase()} — '
                      '${formatter.format(widget.campaign.bidAmount)}',
                ),
                const SizedBox(height: 10),
                _buildRow(
                  'Start Date',
                  DateFormat('MMM d, yyyy').format(widget.campaign.startDate),
                ),
                const SizedBox(height: 10),
                _buildRow(
                  'End Date',
                  DateFormat('MMM d, yyyy').format(widget.campaign.endDate),
                ),
                const SizedBox(height: 10),
                _buildRow('Days Remaining',
                    '${widget.campaign.daysRemaining} days'),
              ],
            ),
          ),

          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

          // Targeting card
          if (widget.campaign.targetPropertyTypes.isNotEmpty ||
              widget.campaign.targetLocations.isNotEmpty)
            _buildSectionCard(
              title: 'Targeting',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.campaign.targetPropertyTypes.isNotEmpty) ...[
                    Text(
                      'Property Types',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                        fontWeight: FontWeight.w600,
                        color: ThemeConfig.getTextSecondaryColor(context),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.campaign.targetPropertyTypes
                          .map((t) => _buildChip(t,
                              ThemeConfig.getPrimaryColor(context)))
                          .toList(),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                  ],
                  if (widget.campaign.targetLocations.isNotEmpty) ...[
                    Text(
                      'Locations',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                        fontWeight: FontWeight.w600,
                        color: ThemeConfig.getTextSecondaryColor(context),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.campaign.targetLocations
                          .map((l) =>
                              _buildChip(l, ThemeConfig.infoColor))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Creatives tab
  // ---------------------------------------------------------------------------
  Widget _buildCreativesTab() {
    if (_isLoadingCreatives) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_creatives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 64,
                color: ThemeConfig.getTextSecondaryColor(context)),
            SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
            Text(
              'No ad creatives yet',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateCreativeScreen(
                      campaignId: widget.campaign.id,
                      campaign: widget.campaign,
                    ),
                  ),
                );
                if (result != null && mounted) _loadCreatives();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Creative'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    final isMobile = ResponsiveHelper.isMobile(context);
    final hPad = ResponsiveHelper.getContentHorizontalPadding(context);

    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.all(hPad),
        itemCount: _creatives.length,
        itemBuilder: (context, i) => _buildCreativeCard(_creatives[i]),
      );
    }

    // Tablet / Desktop: 2-column Wrap layout
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              final cardWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _creatives
                    .map((c) => SizedBox(
                          width: cardWidth,
                          child: _buildCreativeCard(c),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCreativeCard(AdCreative creative) {
    return _CreativeCard(
      creative: creative,
      onDelete: () => _deleteCreative(creative),
    );
  }

  // ---------------------------------------------------------------------------
  // Performance tab
  // ---------------------------------------------------------------------------
  Widget _buildPerformanceTab() {
    final formatter =
        NumberFormat.currency(symbol: 'TSh ', decimalDigits: 0);

    final hPad2 = ResponsiveHelper.getContentHorizontalPadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad2, vertical: ResponsiveHelper.getResponsivePadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
        children: [
          _buildSectionCard(
            title: 'Performance Metrics',
            child: Column(
              children: [
                _buildMetricRow(Icons.visibility_outlined, 'Impressions',
                    '${widget.campaign.impressionsCount}'),
                const SizedBox(height: 14),
                _buildMetricRow(Icons.touch_app_outlined, 'Clicks',
                    '${widget.campaign.clicksCount}'),
                const SizedBox(height: 14),
                _buildMetricRow(Icons.trending_up_rounded, 'CTR',
                    '${widget.campaign.ctr.toStringAsFixed(2)}%'),
                const SizedBox(height: 14),
                _buildMetricRow(
                    Icons.monetization_on_outlined,
                    'Actual CPC',
                    formatter.format(widget.campaign.cpcActual)),
                const SizedBox(height: 14),
                _buildMetricRow(
                    Icons.check_circle_outline_rounded,
                    'Conversions',
                    '${widget.campaign.conversionsCount}'),
                const SizedBox(height: 14),
                _buildMetricRow(
                    Icons.percent_rounded,
                    'Conversion Rate',
                    '${widget.campaign.conversionRate.toStringAsFixed(2)}%'),
              ],
            ),
          ),
          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          _buildSectionCard(
            title: 'Cost Summary',
            child: Column(
              children: [
                _buildRow('Total Budget',
                    formatter.format(widget.campaign.totalBudget)),
                const SizedBox(height: 10),
                _buildRow('Amount Spent',
                    formatter.format(widget.campaign.spentAmount)),
                const SizedBox(height: 10),
                _buildRow(
                  'Remaining',
                  formatter.format(
                      widget.campaign.totalBudget -
                          widget.campaign.spentAmount),
                  valueColor: ThemeConfig.successColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared UI helpers
  // ---------------------------------------------------------------------------
  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
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
              title,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                fontWeight: FontWeight.bold,
                color: ThemeConfig.getTextPrimaryColor(context),
              ),
            ),
            Divider(
              height: 20,
              color: ThemeConfig.getColor(
                context,
                lightColor: ThemeConfig.lightDivider,
                darkColor: ThemeConfig.darkDivider,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
            color: ThemeConfig.getTextSecondaryColor(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
            fontWeight: FontWeight.w600,
            color: valueColor ?? ThemeConfig.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
          decoration: BoxDecoration(
            color: ThemeConfig.getPrimaryColor(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18,
              color: ThemeConfig.getPrimaryColor(context)),
        ),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
              color: ThemeConfig.getTextSecondaryColor(context),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
            fontWeight: FontWeight.bold,
            color: ThemeConfig.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: color),
      side: BorderSide(color: color.withOpacity(0.3)),
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
      case 'out_of_budget':
        return ThemeConfig.errorColor;
      default:
        return ThemeConfig.getTextSecondaryColor(context);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return Icons.play_circle_filled_rounded;
      case 'paused':
        return Icons.pause_circle_filled_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'out_of_budget':
        return Icons.error_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _statusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return 'Your campaign is actively serving ads';
      case 'paused':
        return 'Campaign is temporarily stopped';
      case 'completed':
        return 'Campaign has ended';
      case 'out_of_budget':
        return 'Campaign ran out of budget';
      case 'pending_review':
        return 'Awaiting admin review before going live';
      case 'rejected':
        return 'Campaign was rejected';
      default:
        return 'Campaign status: ${status.replaceAll('_', ' ')}';
    }
  }

  String _formatObjective(String objective) {
    return objective
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-creative card widget
// ─────────────────────────────────────────────────────────────────────────────

class _CreativeCard extends StatefulWidget {
  final AdCreative creative;
  final VoidCallback onDelete;

  const _CreativeCard({
    required this.creative,
    required this.onDelete,
  });

  @override
  State<_CreativeCard> createState() => _CreativeCardState();
}

class _CreativeCardState extends State<_CreativeCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openLandingUrl() async {
    final raw = widget.creative.landingUrl;
    if (raw.isEmpty) return;
    try {
      final uri = Uri.parse(raw);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final creative = widget.creative;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openLandingUrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Media (image) ───────────────────────────────────────────
            Stack(
              children: [
                _buildMedia(context, creative),
                // "Tap to open" hint overlay at bottom of media
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            color: Colors.white70, size: ResponsiveHelper.getResponsiveIconSize(context)),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to open landing page',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Header row: approval + media-type badge + delete ────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
              child: Row(
                children: [
                  _approvalChip(creative),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: ResponsiveHelper.getResponsiveIconSize(context)),
                    onPressed: widget.onDelete,
                    tooltip: 'Delete creative',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),

            // ── Headline + description + CTA ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + headline
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (creative.logoUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: creative.logoUrl!,
                            width: 26,
                            height: 26,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                      ],
                      Expanded(
                        child: Text(
                          creative.headline,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
                            fontWeight: FontWeight.bold,
                            color:
                                ThemeConfig.getTextPrimaryColor(context),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (creative.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      creative.description!,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                        color: ThemeConfig.getTextSecondaryColor(context),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  // CTA pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: ThemeConfig.getPrimaryColor(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      creative.callToAction,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // Landing URL preview
                  if (creative.landingUrl.isNotEmpty) ...[
                    SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                    Row(
                      children: [
                        Icon(Icons.link_rounded,
                            size: 13,
                            color:
                                ThemeConfig.getTextSecondaryColor(context)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            creative.landingUrl,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                              color: ThemeConfig.getTextSecondaryColor(
                                  context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Stats row ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: ThemeConfig.getColor(
                  context,
                  lightColor: ThemeConfig.lightInputFill,
                  darkColor: ThemeConfig.darkInputFill,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCell(context, Icons.visibility_outlined,
                      'Impressions', '${creative.impressions}'),
                  _divider(context),
                  _statCell(context, Icons.touch_app_outlined, 'Clicks',
                      '${creative.clicks}'),
                  _divider(context),
                  _statCell(context, Icons.trending_up_rounded, 'CTR',
                      '${creative.ctr.toStringAsFixed(2)}%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Media builder ─────────────────────────────────────────────────────────

  Widget _buildMedia(BuildContext context, AdCreative creative) {
    return CachedNetworkImage(
      imageUrl: creative.imageUrl,
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 200,
        color: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightInputFill,
          darkColor: ThemeConfig.darkInputFill,
        ),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ThemeConfig.getPrimaryColor(context),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 200,
        color: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightInputFill,
          darkColor: ThemeConfig.darkInputFill,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 48,
                color: ThemeConfig.getTextSecondaryColor(context)),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Text(
              'Media unavailable',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────

  Widget _approvalChip(AdCreative creative) {
    final approved = creative.isApproved;
    final color =
        approved ? ThemeConfig.successColor : ThemeConfig.warningColor;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        approved ? 'APPROVED' : 'PENDING REVIEW',
        style: TextStyle(
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _statCell(
      BuildContext context, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon,
            size: 17,
            color: ThemeConfig.getTextSecondaryColor(context)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
            fontWeight: FontWeight.bold,
            color: ThemeConfig.getTextPrimaryColor(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
            color: ThemeConfig.getTextSecondaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: ThemeConfig.getColor(
          context,
          lightColor: ThemeConfig.lightDivider,
          darkColor: ThemeConfig.darkDivider,
        ),
      );

  // ─────────────────────────────────────────────────────────────
  // RESPONSIVE LAYOUT HELPERS
  // ─────────────────────────────────────────────────────────────
  
  /// Build responsive layout based on screen size
  Widget _buildResponsiveLayout(BuildContext context, Widget child) {
    if (ResponsiveHelper.isMobile(context)) {
      return child;
    }
    
    // Center content on larger screens with max width
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: ResponsiveHelper.getMaxContentWidth(context, isWide: true),
        ),
        child: child,
      ),
    );
  }
  
  /// Get responsive column count for grids
  int _getResponsiveColumns(BuildContext context) {
    return ResponsiveHelper.getGridColumns(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }
  
  /// Build responsive row/column based on screen size
  Widget _buildResponsiveRowOrColumn({
    required BuildContext context,
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    if (ResponsiveHelper.isMobile(context)) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }
    
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children.map((child) => Expanded(child: child)).toList(),
    );
  }

}