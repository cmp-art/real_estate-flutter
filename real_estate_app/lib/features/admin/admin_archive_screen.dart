// lib/features/admin/presentation/screens/admin_archive_screen.dart
// Full admin archive: deleted campaigns, cancelled subscriptions,
// deactivated accounts, deleted properties, and revenue reports.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/admin_service.dart';
import 'admin_dashboard_screen.dart';
import '../../../../core/utils/responsive_helper.dart'; // for adminServiceProvider


// ─────────────────────────────────────────────────────────────────────────────
// ROUTE
// ─────────────────────────────────────────────────────────────────────────────

class AdminArchiveScreen extends ConsumerStatefulWidget {
  const AdminArchiveScreen({super.key});

  @override
  ConsumerState<AdminArchiveScreen> createState() =>
      _AdminArchiveScreenState();
}

class _AdminArchiveScreenState extends ConsumerState<AdminArchiveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AdminArchiveStats? _archiveStats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final stats =
        await ref.read(adminServiceProvider).getArchiveStats();
    if (mounted) {
      setState(() {
        _archiveStats = stats;
        _loadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive & Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh stats',
            onPressed: _loadStats,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: 'Campaigns'),
            Tab(icon: Icon(Icons.subscriptions), text: 'Subscriptions'),
            Tab(icon: Icon(Icons.people), text: 'Accounts'),
            Tab(icon: Icon(Icons.home_work), text: 'Properties'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Revenue'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary bar
          if (_archiveStats != null) _buildStatsSummary(_archiveStats!),
          if (_loadingStats)
            const LinearProgressIndicator(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _DeletedCampaignsTab(),
                _CancelledSubscriptionsTab(),
                _AllAccountsTab(),
                _DeletedPropertiesTab(),
                _RevenueReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(AdminArchiveStats stats) {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryChip(
                label: 'Deleted Campaigns',
                value: '${stats.deletedCampaigns}',
                color: Colors.red),
            _SummaryChip(
                label: 'Cancelled Subs',
                value: '${stats.cancelledSubscriptions}',
                color: Colors.orange),
            _SummaryChip(
                label: 'Inactive Accounts',
                value: '${stats.deactivatedAccounts + stats.deletedAccounts}',
                color: Colors.grey),
            _SummaryChip(
                label: 'Deleted Props',
                value: '${stats.deletedProperties}',
                color: Colors.brown),
            _SummaryChip(
                label: 'Total Ad Revenue',
                value: 'TZS ${_fmt(stats.totalAdRevenueTzs)}',
                color: Colors.green),
            _SummaryChip(
                label: 'Sub Revenue',
                value: '\$${stats.totalSubscriptionRevenueUsd.toStringAsFixed(0)}',
                color: Colors.blue),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: DELETED CAMPAIGNS
// ─────────────────────────────────────────────────────────────────────────────

class _DeletedCampaignsTab extends ConsumerStatefulWidget {
  const _DeletedCampaignsTab();
  @override
  ConsumerState<_DeletedCampaignsTab> createState() =>
      _DeletedCampaignsTabState();
}

class _DeletedCampaignsTabState
    extends ConsumerState<_DeletedCampaignsTab> {
  List<ArchivedCampaign> _campaigns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ref
        .read(adminServiceProvider)
        .getDeletedCampaigns(limit: 100);
    if (mounted) {
      setState(() {
        _campaigns = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_campaigns.isEmpty) {
      return const Center(child: Text('No deleted campaigns found.'));
    }

    return Column(
      children: [
        _SectionHeader(
          title: '${_campaigns.length} Deleted Campaigns',
          subtitle: 'All financial & performance data is preserved.',
          icon: Icons.campaign,
          color: Colors.red,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              itemCount: _campaigns.length,
              itemBuilder: (ctx, i) =>
                  _ArchivedCampaignCard(campaign: _campaigns[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArchivedCampaignCard extends StatelessWidget {
  final ArchivedCampaign campaign;

  const _ArchivedCampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final deletedAt = campaign.deletedAt != null
        ? DateFormat('d MMM y, HH:mm').format(campaign.deletedAt!)
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(Icons.campaign, color: Colors.red, size: ResponsiveHelper.getResponsiveIconSize(context)),
        ),
        title: Text(campaign.campaignName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${campaign.advertiserCompany} · Deleted $deletedAt',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _InfoRow('Advertiser Email', campaign.advertiserEmail),
                _InfoRow('Total Budget',
                    'TZS ${campaign.totalBudget.toStringAsFixed(0)}'),
                _InfoRow('Amount Spent',
                    'TZS ${campaign.spentAmount.toStringAsFixed(0)}'),
                _InfoRow('Budget Used',
                    '${campaign.budgetUtilizationPercent.toStringAsFixed(1)}%'),
                _InfoRow('Impressions',
                    campaign.impressionsCount.toString()),
                _InfoRow('Clicks', campaign.clicksCount.toString()),
                _InfoRow('Created',
                    DateFormat('d MMM y').format(campaign.createdAt)),
                if (campaign.deletionReason != null)
                  _InfoRow('Deletion Reason', campaign.deletionReason!,
                      highlight: true),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user,
                          color: Colors.green, size: ResponsiveHelper.getResponsiveIconSize(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All impression, click, and billing records are permanently preserved for legal and tax compliance.',
                          style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: CANCELLED SUBSCRIPTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _CancelledSubscriptionsTab extends ConsumerStatefulWidget {
  const _CancelledSubscriptionsTab();
  @override
  ConsumerState<_CancelledSubscriptionsTab> createState() =>
      _CancelledSubscriptionsTabState();
}

class _CancelledSubscriptionsTabState
    extends ConsumerState<_CancelledSubscriptionsTab> {
  List<CancelledSubscription> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ref
        .read(adminServiceProvider)
        .getCancelledSubscriptions(limit: 100);
    if (mounted) {
      setState(() {
        _subs = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_subs.isEmpty) {
      return const Center(child: Text('No cancelled subscriptions.'));
    }

    final byTier = <String, List<CancelledSubscription>>{};
    for (final sub in _subs) {
      byTier.putIfAbsent(sub.tierName, () => []).add(sub);
    }

    return Column(
      children: [
        _SectionHeader(
          title: '${_subs.length} Cancelled Subscriptions',
          subtitle:
              'Used for churn analysis, legal compliance, and revenue tracking.',
          icon: Icons.subscriptions,
          color: Colors.orange,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: byTier.entries.map((e) {
              final revenue = e.value.fold<double>(
                  0, (sum, s) => sum + s.tierPrice);
              return Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                    child: Column(
                      children: [
                        Text(e.key.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                        Text('${e.value.length} cancelled',
                            style: const TextStyle(fontSize: 11)),
                        Text('\$${revenue.toStringAsFixed(0)} rev',
                            style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: Colors.green[700])),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              itemCount: _subs.length,
              itemBuilder: (ctx, i) =>
                  _CancelledSubCard(sub: _subs[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelledSubCard extends StatelessWidget {
  final CancelledSubscription sub;

  const _CancelledSubCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final cancelledAt = sub.cancelledAt != null
        ? DateFormat('d MMM y').format(sub.cancelledAt!)
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.1),
          child: Text(
            sub.tierName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
                color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(sub.userEmail,
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${sub.tierName} · \$${sub.tierPrice}/mo · ${sub.activeDays} days active',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Cancelled: $cancelledAt${sub.cancellationReason != null ? ' · ${sub.cancellationReason}' : ''}',
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('\$${sub.tierPrice.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700])),
            const Text('revenue', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: ALL ACCOUNTS (including deleted/deactivated)
// ─────────────────────────────────────────────────────────────────────────────

class _AllAccountsTab extends ConsumerStatefulWidget {
  const _AllAccountsTab();
  @override
  ConsumerState<_AllAccountsTab> createState() =>
      _AllAccountsTabState();
}

class _AllAccountsTabState extends ConsumerState<_AllAccountsTab> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String _filter = 'all'; // all, deleted, deactivated
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ref.read(adminServiceProvider).getAllAccountsAdmin(
          limit: 100,
          deletedOnly: _filter == 'deleted',
          deactivatedOnly: _filter == 'deactivated',
          searchQuery:
              _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
        );
    if (mounted) {
      setState(() {
        _accounts = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: 'All User Accounts',
          subtitle:
              'Includes active, deactivated, and deleted accounts for legal/GDPR compliance.',
          icon: Icons.people,
          color: Colors.grey[700]!,
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () {
                    setState(() => _filter = 'all');
                    _load();
                  }),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              _FilterChip(
                  label: 'Deactivated',
                  selected: _filter == 'deactivated',
                  color: Colors.orange,
                  onTap: () {
                    setState(() => _filter = 'deactivated');
                    _load();
                  }),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              _FilterChip(
                  label: 'Deleted',
                  selected: _filter == 'deleted',
                  color: Colors.red,
                  onTap: () {
                    setState(() => _filter = 'deleted');
                    _load();
                  }),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by email or name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _load();
                      })
                  : null,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        if (_loading)
          const Expanded(
              child: Center(child: CircularProgressIndicator()))
        else if (_accounts.isEmpty)
          const Expanded(child: Center(child: Text('No accounts found.')))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                itemCount: _accounts.length,
                itemBuilder: (ctx, i) =>
                    _AccountCard(account: _accounts[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final isDeleted = account['is_deleted'] == true;
    final isActive = account['is_active'] as bool? ?? true;
    final email = account['email'] as String? ?? 'No email';
    final name = account['full_name'] as String? ?? 'Unknown';
    final tier = account['current_tier'] as String? ?? 'free';
    final ltv =
        (account['lifetime_subscription_value'] as num?)?.toDouble() ??
            0.0;
    final createdAt = account['auth_created_at'] != null
        ? DateFormat('d MMM y')
            .format(DateTime.parse(account['auth_created_at'] as String))
        : account['created_at'] != null
            ? DateFormat('d MMM y')
                .format(DateTime.parse(account['created_at'] as String))
            : 'Unknown';

    Color statusColor = Colors.green;
    String statusLabel = 'Active';
    if (isDeleted) {
      statusColor = Colors.red;
      statusLabel = 'Deleted';
    } else if (!isActive) {
      statusColor = Colors.orange;
      statusLabel = 'Deactivated';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDeleted ? Colors.red.withOpacity(0.03) : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            isDeleted ? Icons.person_off : Icons.person,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(email,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('$name · $tier · Joined $createdAt'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
                color: statusColor,
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _InfoRow('User ID', account['id'] as String? ?? '—'),
                _InfoRow('Role', account['role'] as String? ?? 'user'),
                _InfoRow('Current Tier', tier),
                _InfoRow('Lifetime Sub Value', '\$${ltv.toStringAsFixed(2)}'),
                _InfoRow(
                    'Total Properties',
                    '${account['total_properties'] ?? 0} (${account['deleted_properties'] ?? 0} deleted)'),
                _InfoRow(
                    'Advertiser Status',
                    account['advertiser_status'] as String? ?? 'N/A'),
                if (account['advertiser_total_spent'] != null)
                  _InfoRow(
                    'Ad Spend',
                    'TZS ${(account['advertiser_total_spent'] as num).toStringAsFixed(0)}',
                  ),
                if (account['deactivated_at'] != null)
                  _InfoRow(
                    'Deactivated At',
                    DateFormat('d MMM y, HH:mm').format(
                        DateTime.parse(account['deactivated_at'] as String)),
                    highlight: true,
                  ),
                if (account['deactivation_reason'] != null)
                  _InfoRow('Deactivation Reason',
                      account['deactivation_reason'] as String,
                      highlight: true),
                if (account['deleted_at'] != null)
                  _InfoRow(
                    'Deleted At',
                    DateFormat('d MMM y, HH:mm').format(
                        DateTime.parse(account['deleted_at'] as String)),
                    highlight: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4: DELETED PROPERTIES — with working restore
// ─────────────────────────────────────────────────────────────────────────────

class _DeletedPropertiesTab extends ConsumerStatefulWidget {
  const _DeletedPropertiesTab();
  @override
  ConsumerState<_DeletedPropertiesTab> createState() =>
      _DeletedPropertiesTabState();
}

class _DeletedPropertiesTabState
    extends ConsumerState<_DeletedPropertiesTab> {
  List<Map<String, dynamic>> _properties = [];
  bool _loading = true;

  // Filter: 'all' | 'user' | 'admin'
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ref
        .read(adminServiceProvider)
        .getAllPropertiesAdmin(
          limit: 200,
          deletedOnly: _filter == 'all',
          userDeletedOnly: _filter == 'user',
          adminDeletedOnly: _filter == 'admin',
        );
    if (mounted) {
      setState(() {
        _properties = data;
        _loading = false;
      });
    }
  }

  Future<void> _restoreProperty(Map<String, dynamic> p) async {
    final title = p['title'] as String? ?? 'this property';
    final deletedByUser  = p['deleted_by_user'] == true;
    final deletedByAdmin = p['deleted_by_admin'] != null;

    final whoDeleted = deletedByUser
        ? 'deleted by the owner'
        : deletedByAdmin
            ? 'deleted by an admin'
            : 'deleted';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Property'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restore "$title"?'),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This listing was $whoDeleted. The owner will be notified when restored.',
                      style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.orange),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(adminServiceProvider)
        .adminRestoreProperty(p['id'] as String,
            note: 'Property reinstated by admin');

    if (!mounted) return;

    final success = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        result['message'] as String? ??
            (success
                ? 'Property restored and owner notified!'
                : 'Failed to restore: ${result['error'] ?? 'Unknown error'}'),
      ),
      backgroundColor: success ? Colors.green : Colors.red,
    ));

    if (success) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              _buildFilterChip('all',   'All Deleted',  Icons.delete_sweep,          Colors.red),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              _buildFilterChip('user',  'By User',      Icons.person_off,             Colors.orange),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              _buildFilterChip('admin', 'By Admin',     Icons.admin_panel_settings,   Colors.purple),
            ],
          ),
        ),
        const Divider(height: 1),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_properties.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_work, size: 48, color: Colors.grey[400]),
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                  Text(
                    _filter == 'user'
                        ? 'No properties deleted by users.'
                        : _filter == 'admin'
                            ? 'No properties deleted by admins.'
                            : 'No deleted properties found.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                _SectionHeader(
                  title: '${_properties.length} '
                      '${_filter == "user" ? "User-Deleted" : _filter == "admin" ? "Admin-Deleted" : "Deleted"}'
                      ' Properties',
                  subtitle: 'Soft-deleted — can be restored. Owner is notified on restore.',
                  icon: Icons.home_work,
                  color: Colors.brown,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                      itemCount: _properties.length,
                      itemBuilder: (ctx, i) => _buildPropertyCard(_properties[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon, Color color) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        if (_filter != value) {
          setState(() => _filter = value);
          _load();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.withOpacity(0.4),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : Colors.grey[600]),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> p) {
    final deletedAt = p['deleted_at'] != null
        ? DateFormat('d MMM y, HH:mm').format(DateTime.parse(p['deleted_at'] as String))
        : 'Unknown';
    final images = (p['images'] as List?)?.cast<String>() ?? [];
    final videos = (p['videos'] as List?)?.cast<String>() ?? [];
    final mediaCount = images.length + videos.length;

    final deletedByUser  = p['deleted_by_user'] == true;
    final deletedByAdmin = p['deleted_by_admin'] != null;

    final Color badgeColor;
    final String badgeLabel;
    final IconData badgeIcon;

    if (deletedByUser) {
      badgeColor = Colors.orange;
      badgeLabel = 'By owner';
      badgeIcon  = Icons.person_off;
    } else if (deletedByAdmin) {
      badgeColor = Colors.purple;
      badgeLabel = 'By admin';
      badgeIcon  = Icons.admin_panel_settings;
    } else {
      badgeColor = Colors.red;
      badgeLabel = 'Deleted';
      badgeIcon  = Icons.delete;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: badgeColor.withOpacity(0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                itemCount: images.length.clamp(0, 5),
                itemBuilder: (_, idx) => Container(
                  width: 56,
                  margin: const EdgeInsets.only(right: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      images[idx],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: ResponsiveHelper.getResponsiveIconSize(context)),
                    ),
                  ),
                ),
              ),
            ),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: badgeColor.withOpacity(0.12),
              child: Icon(Icons.home_work, color: badgeColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    p['title'] as String? ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 11, color: badgeColor),
                      const SizedBox(width: 3),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                          color: badgeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p['owner_email'] ?? 'Unknown'} · ${p['location'] ?? '—'}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Deleted: $deletedAt'
                  '${p['deletion_reason'] != null ? '  · ${p['deletion_reason']}' : ''}',
                  style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: badgeColor.withOpacity(0.8)),
                ),
                if (mediaCount > 0)
                  Text(
                    '${images.length} photos  ${videos.length} videos',
                    style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: Colors.grey),
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'restore') await _restoreProperty(p);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(Icons.restore, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Restore & Notify Owner'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5: REVENUE REPORTS
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueReportTab extends ConsumerStatefulWidget {
  const _RevenueReportTab();
  @override
  ConsumerState<_RevenueReportTab> createState() =>
      _RevenueReportTabState();
}

class _RevenueReportTabState extends ConsumerState<_RevenueReportTab>
    with SingleTickerProviderStateMixin {
  late TabController _innerTab;
  List<Map<String, dynamic>> _subRevenue = [];
  List<Map<String, dynamic>> _adRevenue = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final adminService = ref.read(adminServiceProvider);
    final results = await Future.wait([
      adminService.getSubscriptionRevenueReport(),
      adminService.getAdRevenueReport(),
    ]);
    if (mounted) {
      setState(() {
        _subRevenue = results[0];
        _adRevenue = results[1];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: 'Revenue Reports',
          subtitle:
              'For tax, finance, and business improvement analysis.',
          icon: Icons.bar_chart,
          color: Colors.green[700]!,
        ),
        TabBar(
          controller: _innerTab,
          labelColor: Colors.green[700],
          tabs: const [
            Tab(text: 'Subscription Revenue'),
            Tab(text: 'Ad Revenue'),
          ],
        ),
        if (_loading)
          const Expanded(
              child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: TabBarView(
              controller: _innerTab,
              children: [
                _buildSubRevenueList(),
                _buildAdRevenueList(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubRevenueList() {
    if (_subRevenue.isEmpty) {
      return const Center(child: Text('No subscription revenue data.'));
    }

    final byMonth = <String, List<Map<String, dynamic>>>{};
    for (final row in _subRevenue) {
      final month = row['revenue_month'] as String? ?? 'Unknown';
      byMonth.putIfAbsent(month, () => []).add(row);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        children: byMonth.entries.map((entry) {
          final rows = entry.value;
          final totalRevenue = rows.fold<double>(
            0,
            (sum, r) =>
                sum +
                ((r['new_subscriptions'] as int? ?? 0) *
                    (r['tier_price_usd'] as num? ?? 0).toDouble()),
          );
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(
                _formatMonth(entry.key),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                '\$${totalRevenue.toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.green[700], fontWeight: FontWeight.bold),
              ),
              children: rows.map((row) {
                final newSubs = row['new_subscriptions'] as int? ?? 0;
                final price =
                    (row['tier_price_usd'] as num?)?.toDouble() ?? 0.0;
                final cancelled = row['cancellations'] as int? ?? 0;
                final active = row['currently_active'] as int? ?? 0;
                return ListTile(
                  title: Text(
                      (row['tier'] as String? ?? '').toUpperCase()),
                  subtitle: Text(
                      '$newSubs new · $cancelled cancelled · $active active'),
                  trailing: Text('\$${(newSubs * price).toStringAsFixed(2)}'),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdRevenueList() {
    if (_adRevenue.isEmpty) {
      return const Center(child: Text('No ad revenue data.'));
    }

    final byMonth = <String, List<Map<String, dynamic>>>{};
    for (final row in _adRevenue) {
      final month = row['revenue_month'] as String? ?? 'Unknown';
      byMonth.putIfAbsent(month, () => []).add(row);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        children: byMonth.entries.map((entry) {
          final rows = entry.value;
          final totalRevenue = rows.fold<double>(
              0,
              (sum, r) =>
                  sum +
                  ((r['total_revenue_tzs'] as num?)?.toDouble() ?? 0.0));

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(
                _formatMonth(entry.key),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                'TZS ${_fmt(totalRevenue)}',
                style: TextStyle(
                    color: Colors.green[700], fontWeight: FontWeight.bold),
              ),
              children: rows.map((row) {
                final impressionRev =
                    (row['impression_revenue_tzs'] as num?)?.toDouble() ??
                        0.0;
                final clickRev =
                    (row['click_revenue_tzs'] as num?)?.toDouble() ?? 0.0;
                final isDeleted = row['campaign_deleted'] as bool? ?? false;
                return ListTile(
                  title: Row(
                    children: [
                      Expanded(
                          child: Text(row['campaign_name'] as String? ?? '—',
                              style: const TextStyle(fontSize: 13))),
                      if (isDeleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('DELETED',
                              style: TextStyle(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10), color: Colors.red)),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${row['impressions'] ?? 0} impr · ${row['clicks'] ?? 0} clicks · '
                    'Impr: TZS ${_fmt(impressionRev)} · Click: TZS ${_fmt(clickRev)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatMonth(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: ResponsiveHelper.getResponsiveIconSize(context)),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16)),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                color: highlight ? Colors.red[700] : null,
                fontWeight:
                    highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13)),
          Text(label,
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10), color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : c,
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
          ),
        ),
      ),
    );
  }

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