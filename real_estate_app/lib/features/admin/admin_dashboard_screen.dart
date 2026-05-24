// lib/features/admin/presentation/screens/admin_dashboard_screen.dart
// PART 1 OF 2: Overview + Users Tabs
// Complete admin dashboard with all users visible and property media management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_archive_screen.dart';
import 'admin_ad_detail_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_error_logs_screen.dart';
import 'admin_broadcast_screen.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/services/admin_service.dart';
import 'admin_property_detail_screen.dart';
import 'admin_user_detail_screen.dart';

// ─────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────

final adminServiceProvider =
    Provider((ref) => AdminService(Supabase.instance.client));

// ─────────────────────────────────────────────────────────────
// ROOT SCREEN
// ─────────────────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _isAdmin = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _checkAccess();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final ok = await ref.read(adminServiceProvider).isCurrentUserAdmin();
    if (mounted) setState(() { _isAdmin = ok; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: ThemeConfig.getBackgroundColor(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: ThemeConfig.getBackgroundColor(context),
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 72,
                  color: ThemeConfig.errorColor.withOpacity(0.7)),
              const SizedBox(height: 16),
              Text('Access Denied',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getTextPrimaryColor(context))),
              const SizedBox(height: 8),
              Text('Admin privileges required.',
                  style: TextStyle(
                      color: ThemeConfig.getTextSecondaryColor(context))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: ThemeConfig.getColor(context,
            lightColor: ThemeConfig.lightAppBarBackground,
            darkColor: ThemeConfig.darkAppBarBackground),
        title: Row(children: [
          Icon(Icons.admin_panel_settings_rounded,
              color: ThemeConfig.getColor(context,
                  lightColor: ThemeConfig.lightAppBarForeground,
                  darkColor: ThemeConfig.darkAppBarForeground),
              size: 24),
          const SizedBox(width: 10),
          Text('Admin Dashboard',
              style: TextStyle(
                  color: ThemeConfig.getColor(context,
                      lightColor: ThemeConfig.lightAppBarForeground,
                      darkColor: ThemeConfig.darkAppBarForeground),
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.flag_rounded,
                color: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightAppBarForeground,
                    darkColor: ThemeConfig.darkAppBarForeground)),
            tooltip: 'Reports',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminReportsScreen())),
          ),
          IconButton(
            icon: Icon(Icons.bug_report_rounded,
                color: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightAppBarForeground,
                    darkColor: ThemeConfig.darkAppBarForeground)),
            tooltip: 'Error Logs',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminErrorLogsScreen())),
          ),
          IconButton(
            icon: Icon(Icons.campaign_rounded,
                color: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightAppBarForeground,
                    darkColor: ThemeConfig.darkAppBarForeground)),
            tooltip: 'Broadcast',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())),
          ),
          IconButton(
            icon: Icon(Icons.archive_rounded,
                color: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightAppBarForeground,
                    darkColor: ThemeConfig.darkAppBarForeground)),
            tooltip: 'Archive & Records',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminArchiveScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: ThemeConfig.getColor(context,
              lightColor: ThemeConfig.lightAppBarForeground,
              darkColor: ThemeConfig.darkAppBarForeground),
          unselectedLabelColor: ThemeConfig.getColor(context,
              lightColor: ThemeConfig.lightAppBarForeground,
              darkColor: ThemeConfig.darkAppBarForeground).withOpacity(0.6),
          indicatorColor: ThemeConfig.getColor(context,
              lightColor: ThemeConfig.lightAppBarForeground,
              darkColor: ThemeConfig.darkAppBarForeground),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Overview'),
            Tab(icon: Icon(Icons.people_rounded), text: 'Users'),
            Tab(icon: Icon(Icons.home_work_rounded), text: 'Properties'),
            Tab(icon: Icon(Icons.ads_click_rounded), text: 'Ads'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _OverviewTab(),
          _UsersTab(),
          _PropertiesTab(),
          _AdsTab(),
          _AnalyticsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1: OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();
  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  AdminDashboardStats? _stats;
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = ref.read(adminServiceProvider);
    final results = await Future.wait([svc.getDashboardStats(), svc.getPendingReview()]);
    if (mounted) {
      setState(() {
        _stats = results[0] as AdminDashboardStats?;
        _pending = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView(context);
    return RefreshIndicator(
      onRefresh: _load,
      color: ThemeConfig.getPrimaryColor(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_stats != null) ...[
            const _SectionHeader('📊 Platform Overview'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _StatCard('Total Users', '${_stats!.totalUsers}',
                    Icons.people_rounded, Colors.blue),
                _StatCard('New (30d)', '${_stats!.newUsers30d}',
                    Icons.person_add_rounded, Colors.green),
                _StatCard('Properties', '${_stats!.totalProperties}',
                    Icons.home_rounded, Colors.orange),
                _StatCard('Active Campaigns', '${_stats!.activeCampaigns}',
                    Icons.campaign_rounded, Colors.purple),
                _StatCard('Pending Ads', '${_stats!.pendingAds}',
                    Icons.pending_actions_rounded, Colors.amber),
                _StatCard('Ad Revenue', 'TZS ${_formatNum(_stats!.totalAdRevenue)}',
                    Icons.monetization_on_rounded, Colors.teal),
                _StatCard('Active Subscriptions', '${_stats!.activeSubscriptions}',
                    Icons.card_membership_rounded, Colors.indigo),
                _StatCard('Admin Actions (24h)', '${_stats!.adminActions24h}',
                    Icons.security_rounded, Colors.deepOrange),
              ],
            ),
          ],
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader('⏳ Pending Review (${_pending.length})'),
            const SizedBox(height: 12),
            ..._pending.take(5).map((item) {
              final type = item['content_type'] as String? ?? 'ad_creative';
              final title = item['headline'] as String? ?? item['campaign_name'] as String? ?? 'Untitled';
              final source = item['advertiser_email'] as String? ?? item['advertiser_company'] as String? ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: ThemeConfig.getCardColor(context),
                child: ListTile(
                  leading: Icon(
                    type == 'ad_creative' ? Icons.image_rounded : Icons.home_rounded,
                    color: ThemeConfig.warningColor,
                  ),
                  title: Text(title,
                      style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context),
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(source,
                      style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context))),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThemeConfig.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(type.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 10,
                            color: ThemeConfig.warningColor,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2: USERS — shows ALL auth.users (not just those with profiles)
// ═══════════════════════════════════════════════════════════════════════════

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading   = true;
  bool _loadingMore = false;
  bool _hasMore   = true;          // false when last page returned < _pageSize rows
  int  _offset    = 0;
  static const int _pageSize = 50;

  final _searchCtrl = TextEditingController();
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  /// Full reload (search / filter change, pull-to-refresh)
  Future<void> _load() async {
    setState(() { _loading = true; _offset = 0; _hasMore = true; });
    final page = await ref.read(adminServiceProvider).getAllUsers(
      limit:          _pageSize,
      offset:         0,
      searchQuery:    _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      includeDeleted: _filter == 'deleted',
    );
    if (!mounted) return;
    final filtered = _applyLocalFilter(page);
    setState(() {
      _users   = filtered;
      _offset  = page.length;          // track raw page size, not filtered
      _hasMore = page.length == _pageSize;
      _loading = false;
    });
  }

  /// Append next page (infinite scroll / "Load more" button)
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final page = await ref.read(adminServiceProvider).getAllUsers(
      limit:          _pageSize,
      offset:         _offset,
      searchQuery:    _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      includeDeleted: _filter == 'deleted',
    );
    if (!mounted) return;
    final filtered = _applyLocalFilter(page);
    setState(() {
      _users.addAll(filtered);
      _offset  += page.length;
      _hasMore  = page.length == _pageSize;
      _loadingMore = false;
    });
  }

  List<Map<String, dynamic>> _applyLocalFilter(List<Map<String, dynamic>> all) {
    if (_filter == 'banned') return all.where((u) => u['is_active'] == false).toList();
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: ThemeConfig.getCardColor(context),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                hintStyle: TextStyle(color: ThemeConfig.getTextSecondaryColor(context)),
                prefixIcon: Icon(Icons.search, size: 20,
                    color: ThemeConfig.getTextSecondaryColor(context)),
                filled: true,
                fillColor: ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightInputFill,
                    darkColor: ThemeConfig.darkInputFill),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ThemeConfig.getColor(context,
                        lightColor: ThemeConfig.lightBorder,
                        darkColor: ThemeConfig.darkBorder))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ThemeConfig.getColor(context,
                        lightColor: ThemeConfig.lightBorder,
                        darkColor: ThemeConfig.darkBorder))),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _searchCtrl.clear(); _load(); })
                    : null,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 8),
          _DropFilter(
            options: const {'all': 'All', 'banned': 'Banned', 'deleted': 'Deleted'},
            selected: _filter,
            onChanged: (v) { setState(() => _filter = v); _load(); },
          ),
        ]),
      ),
      // User count banner
      if (!_loading)
        Container(
          width: double.infinity,
          color: ThemeConfig.getPrimaryColor(context).withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            '${_users.length} user${_users.length != 1 ? 's' : ''} loaded${_hasMore ? ' (scroll for more)' : ''}',
            style: TextStyle(
                fontSize: 12,
                color: ThemeConfig.getPrimaryColor(context),
                fontWeight: FontWeight.w600)),
        ),
      if (_loading)
        Expanded(child: _loadingView(context))
      else if (_users.isEmpty)
        Expanded(child: _EmptyCard(
            icon: Icons.people_outline,
            message: 'No users found.',
            color: ThemeConfig.getTextSecondaryColor(context)))
      else
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: ThemeConfig.getPrimaryColor(context),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              // +1 for the "Load more" footer item
              itemCount: _users.length + (_hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                // ── Load More footer ─────────────────────────────────────────
                if (i == _users.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton.icon(
                              onPressed: _loadMore,
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Load more'),
                            ),
                    ),
                  );
                }

                final u = _users[i];
                final isActive = u['is_active'] as bool? ?? true;
                final isDeleted = u['is_deleted'] as bool? ?? false;
                final email = u['email'] as String? ?? 'Unknown';
                final name = u['full_name'] as String? ?? '—';
                final role = u['role'] as String? ?? 'user';
                final tier = u['current_tier'] as String? ?? 'free';
                final propCount = u['total_properties'] as int? ?? 0;
                final lastSignIn = u['last_sign_in_at'] as String?;
                final statusColor = isDeleted ? ThemeConfig.errorColor
                    : (!isActive ? ThemeConfig.warningColor : ThemeConfig.successColor);
                final statusLabel = isDeleted ? 'Deleted'
                    : (!isActive ? 'Banned' : 'Active');

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: ThemeConfig.getCardColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDeleted
                        ? ThemeConfig.errorColor.withOpacity(0.3)
                        : (!isActive ? ThemeConfig.warningColor.withOpacity(0.3)
                            : ThemeConfig.getColor(context,
                                lightColor: ThemeConfig.lightBorder,
                                darkColor: ThemeConfig.darkBorder))),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Text(
                        (name != '—' ? name[0] : email[0]).toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(email,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                            color: ThemeConfig.getTextPrimaryColor(context)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$name • $role • $tier • $propCount properties',
                          style: TextStyle(fontSize: 12,
                              color: ThemeConfig.getTextSecondaryColor(context)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(statusLabel,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                  color: statusColor)),
                        ),
                        if (lastSignIn != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Last: ${_formatDate(DateTime.tryParse(lastSignIn))}',
                            style: TextStyle(fontSize: 10,
                                color: ThemeConfig.getTextSecondaryColor(context)),
                          ),
                        ],
                      ]),
                    ]),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminUserDetailScreen(
                          userId: u['id'] as String,
                          displayEmail: u['email'] as String?,
                        ),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: ThemeConfig.getTextSecondaryColor(context)),
                      color: ThemeConfig.getCardColor(context),
                      onSelected: (v) async {
                        if (v == 'ban')    { await _toggleBan(u); _load(); }
                        if (v == 'role')   { await _showRoleDialog(u); _load(); }
                        if (v == 'notify') { await _showNotifyDialog(u); }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'ban', child: Row(children: [
                          Icon(isActive ? Icons.block : Icons.check_circle,
                              color: isActive ? ThemeConfig.errorColor : ThemeConfig.successColor,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Ban User' : 'Unban User',
                              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
                        ])),
                        PopupMenuItem(value: 'role', child: Row(children: [
                          Icon(Icons.manage_accounts, size: 18,
                              color: ThemeConfig.getTextPrimaryColor(context)),
                          const SizedBox(width: 8),
                          Text('Change Role',
                              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
                        ])),
                        PopupMenuItem(value: 'notify', child: Row(children: [
                          Icon(Icons.notifications_rounded, size: 18,
                              color: ThemeConfig.getPrimaryColor(context)),
                          const SizedBox(width: 8),
                          Text('Send Notification',
                              style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
                        ])),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
    ]);
  }

  Future<void> _toggleBan(Map<String, dynamic> u) async {
    final svc = ref.read(adminServiceProvider);
    final isActive = u['is_active'] as bool? ?? true;
    if (isActive) {
      final reason = await _inputDialog(
          'Ban User',
          'Reason for banning (optional):',
          isRequired: false);
      final ok = await svc.banUser(u['id'] as String, reason: reason);
      if (mounted) _snack(ok ? 'User banned and notified' : 'Failed to ban user', ok);
    } else {
      final ok = await svc.unbanUser(u['id'] as String);
      if (mounted) _snack(ok ? 'User unbanned and notified' : 'Failed to unban user', ok);
    }
  }

  Future<void> _showNotifyDialog(Map<String, dynamic> u) async {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Send Notification to ${u['email'] ?? 'User'}',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context),
                fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: msgCtrl,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                labelText: 'Message', border: OutlineInputBorder()),
            maxLines: 3,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (sent == true && titleCtrl.text.isNotEmpty && msgCtrl.text.isNotEmpty) {
      final ok = await ref.read(adminServiceProvider).sendNotificationToUser(
        userId: u['id'] as String,
        title: titleCtrl.text.trim(),
        message: msgCtrl.text.trim(),
        type: 'admin_message',
      );
      if (mounted) _snack(ok ? 'Notification sent!' : 'Failed to send notification', ok);
    }
  }

  Future<String?> _inputDialog(String title, String hint,
      {bool isRequired = true}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text(title,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: InputDecoration(hintText: hint,
              border: const OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRoleDialog(Map<String, dynamic> u) async {
    final roles = [
      UserRole.user, UserRole.agent, UserRole.advertiser,
      UserRole.moderator, UserRole.admin
    ];
    final selected = await showDialog<UserRole>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Change Role',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles.map((r) => ListTile(
            title: Text(r.value,
                style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
            onTap: () => Navigator.pop(ctx, r),
          )).toList(),
        ),
      ),
    );
    if (selected != null) {
      final ok = await ref.read(adminServiceProvider).updateUserRole(
          userId: u['id'] as String, role: selected);
      if (mounted) _snack(ok ? 'Role updated' : 'Failed to update role', ok);
    }
  }

  void _snack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ThemeConfig.successColor : ThemeConfig.errorColor,
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: PROPERTIES — with full image + video gallery + management
// ═══════════════════════════════════════════════════════════════════════════

class _PropertiesTab extends ConsumerStatefulWidget {
  const _PropertiesTab();
  @override
  ConsumerState<_PropertiesTab> createState() => _PropertiesTabState();
}

// Filter values
const _kFilterAll          = 'all';
const _kFilterDeleted      = 'deleted';
const _kFilterUserDeleted  = 'user_deleted';
const _kFilterAdminDeleted = 'admin_deleted';

class _PropertiesTabState extends ConsumerState<_PropertiesTab> {
  List<Map<String, dynamic>> _props = [];
  bool _loading     = true;
  bool _loadingMore = false;
  bool _hasMore     = true;
  int  _offset      = 0;
  static const int _pageSize = 50;

  final _searchCtrl = TextEditingController();
  String _deleteFilter = _kFilterAll;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _offset = 0; _hasMore = true; });
    final data = await ref.read(adminServiceProvider).getAllPropertiesAdmin(
      limit:            _pageSize,
      offset:           0,
      deletedOnly:      _deleteFilter == _kFilterDeleted,
      userDeletedOnly:  _deleteFilter == _kFilterUserDeleted,
      adminDeletedOnly: _deleteFilter == _kFilterAdminDeleted,
      searchQuery: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
    );
    if (mounted) {
      setState(() {
      _props   = data;
      _offset  = data.length;
      _hasMore = data.length == _pageSize;
      _loading = false;
    });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final data = await ref.read(adminServiceProvider).getAllPropertiesAdmin(
      limit:            _pageSize,
      offset:           _offset,
      deletedOnly:      _deleteFilter == _kFilterDeleted,
      userDeletedOnly:  _deleteFilter == _kFilterUserDeleted,
      adminDeletedOnly: _deleteFilter == _kFilterAdminDeleted,
      searchQuery: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
    );
    if (mounted) {
      setState(() {
      _props.addAll(data);
      _offset  += data.length;
      _hasMore  = data.length == _pageSize;
      _loadingMore = false;
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: ThemeConfig.getCardColor(context),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(children: [
          // Search bar
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
                decoration: InputDecoration(
                  hintText: 'Search properties…',
                  hintStyle: TextStyle(color: ThemeConfig.getTextSecondaryColor(context)),
                  prefixIcon: Icon(Icons.search, size: 20,
                      color: ThemeConfig.getTextSecondaryColor(context)),
                  filled: true,
                  fillColor: ThemeConfig.getColor(context,
                      lightColor: ThemeConfig.lightInputFill,
                      darkColor: ThemeConfig.darkInputFill),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18),
                          onPressed: () { _searchCtrl.clear(); _load(); })
                      : null,
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip(
                label: 'All',
                icon: Icons.home_work_rounded,
                selected: _deleteFilter == _kFilterAll,
                color: ThemeConfig.getPrimaryColor(context),
                onTap: () { setState(() => _deleteFilter = _kFilterAll); _load(); },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'All Deleted',
                icon: Icons.delete_rounded,
                selected: _deleteFilter == _kFilterDeleted,
                color: ThemeConfig.errorColor,
                onTap: () { setState(() => _deleteFilter = _kFilterDeleted); _load(); },
              ),
              const SizedBox(width: 8),
              // ── KEY CHIP: user-deleted properties ──
              _FilterChip(
                label: 'Deleted by User',
                icon: Icons.person_remove_rounded,
                selected: _deleteFilter == _kFilterUserDeleted,
                color: Colors.orange,
                onTap: () { setState(() => _deleteFilter = _kFilterUserDeleted); _load(); },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Deleted by Admin',
                icon: Icons.admin_panel_settings_rounded,
                selected: _deleteFilter == _kFilterAdminDeleted,
                color: Colors.purple,
                onTap: () { setState(() => _deleteFilter = _kFilterAdminDeleted); _load(); },
              ),
              const SizedBox(width: 12),
              if (!_loading)
                Text('${_props.length} found${_hasMore ? ' (scroll for more)' : ''}',
                    style: TextStyle(fontSize: 12,
                        color: ThemeConfig.getPrimaryColor(context),
                        fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      if (_loading)
        Expanded(child: _loadingView(context))
      else if (_props.isEmpty)
        Expanded(child: _EmptyCard(
            icon: Icons.home_outlined,
            message: 'No properties found.',
            color: ThemeConfig.getTextSecondaryColor(context)))
      else
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: ThemeConfig.getPrimaryColor(context),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _props.length + (_hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                // ── Load More footer ──────────────────────────────────────
                if (i == _props.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton.icon(
                              onPressed: _loadMore,
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Load more'),
                            ),
                    ),
                  );
                }

                final p = _props[i];
                final isDeleted = p['is_deleted'] as bool? ?? false;
                final deletedByUser = p['deleted_by_user'] as bool? ?? false;
                final isFeatured = p['is_featured'] as bool? ?? false;
                final isVerified = p['is_verified'] as bool? ?? false;
                final isOwnerVerified = p['is_owner_verified'] as bool? ?? false;
                final verificationMethod = p['verification_method'] as String?;
                final images = (p['images'] as List?)?.cast<String>() ?? [];
                final videos = (p['videos'] as List?)?.cast<String>() ?? [];
                final mediaCount = images.length + videos.length;
                final price = (p['price'] as num?)?.toDouble() ?? 0;
                final ownerName = p['owner_name'] as String? ?? '—';
                final ownerEmail = p['owner_email'] as String? ?? '—';

                // Determine card accent color based on who deleted
                final Color cardAccent = isDeleted
                    ? (deletedByUser ? Colors.orange : ThemeConfig.errorColor)
                    : Colors.transparent;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isDeleted
                      ? cardAccent.withOpacity(0.05)
                      : ThemeConfig.getCardColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDeleted
                        ? cardAccent.withOpacity(0.4)
                        : ThemeConfig.getColor(context,
                            lightColor: ThemeConfig.lightBorder,
                            darkColor: ThemeConfig.darkBorder)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── "Deleted by User" banner — shown only for user-deleted ──
                    if (isDeleted && deletedByUser)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          border: Border(
                            bottom: BorderSide(color: Colors.orange.withOpacity(0.3)),
                          ),
                        ),
                        child: Row(children: [
                          const Icon(Icons.person_remove_rounded,
                              size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          const Text('Deleted by property owner',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange)),
                          const Spacer(),
                          if (p['deleted_at'] != null)
                            Text(_fmtDate(p['deleted_at'] as String),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.withOpacity(0.8))),
                        ]),
                      ),
                    // ── "Deleted by Admin" banner ──
                    if (isDeleted && !deletedByUser)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: ThemeConfig.errorColor.withOpacity(0.12),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          border: Border(
                            bottom: BorderSide(
                                color: ThemeConfig.errorColor.withOpacity(0.3)),
                          ),
                        ),
                        child: Row(children: [
                          const Icon(Icons.admin_panel_settings_rounded,
                              size: 14, color: ThemeConfig.errorColor),
                          const SizedBox(width: 6),
                          const Text('Deleted by admin',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeConfig.errorColor)),
                          const Spacer(),
                          if (p['deleted_at'] != null)
                            Text(_fmtDate(p['deleted_at'] as String),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: ThemeConfig.errorColor.withOpacity(0.8))),
                        ]),
                      ),
                    // Thumbnail row if media exists
                    if (images.isNotEmpty || videos.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: (images.length + videos.length).clamp(0, 6),
                          itemBuilder: (_, idx) {
                            final isVideo = idx >= images.length;
                            final url = isVideo
                                ? videos[idx - images.length]
                                : images[idx];
                            return GestureDetector(
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) =>
                                      AdminPropertyDetailScreen(property: p))),
                              child: Container(
                                width: 64,
                                height: 64,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: ThemeConfig.getColor(context,
                                      lightColor: ThemeConfig.lightBorder,
                                      darkColor: ThemeConfig.darkBorder),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (!isVideo)
                                        Image.network(url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.broken_image))
                                      else
                                        Container(
                                          color: Colors.black87,
                                          child: const Icon(Icons.play_circle_fill_rounded,
                                              color: Colors.white, size: 32)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Row(children: [
                        Expanded(
                          child: Text(p['title'] as String? ?? 'Untitled',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                                  color: isDeleted
                                      ? (deletedByUser ? Colors.orange : ThemeConfig.errorColor)
                                      : ThemeConfig.getTextPrimaryColor(context)),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (isFeatured)
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        if (isVerified)
                          const Icon(Icons.verified_rounded, color: Colors.blue, size: 16),
                        if (isOwnerVerified)
                          Tooltip(
                            message: 'Owner Verified'
                                '${verificationMethod != null ? " (${verificationMethod == "near_owner" ? "Near" : "Far"})" : ""}',
                            child: const Icon(Icons.verified_user_rounded,
                                color: Colors.green, size: 16),
                          ),
                        if (isDeleted && deletedByUser)
                          const Tooltip(
                            message: 'Deleted by owner',
                            child: Icon(Icons.person_remove_rounded,
                                color: Colors.orange, size: 16),
                          ),
                        if (isDeleted && !deletedByUser)
                          const Tooltip(
                            message: 'Deleted by admin',
                            child: Icon(Icons.delete_rounded,
                                color: ThemeConfig.errorColor, size: 16),
                          ),
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p['location'] ?? '—'} • TZS ${_formatNum(price)}',
                            style: TextStyle(fontSize: 12,
                                color: ThemeConfig.getTextSecondaryColor(context))),
                        Text('Owner: $ownerName ($ownerEmail)',
                            style: TextStyle(fontSize: 11,
                                color: ThemeConfig.getTextSecondaryColor(context)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (mediaCount > 0)
                          Text('📷 ${images.length} photos  🎬 ${videos.length} videos',
                              style: TextStyle(fontSize: 11,
                                  color: ThemeConfig.getPrimaryColor(context))),
                        if (isOwnerVerified)
                          Text(
                            '🔐 Owner verified'
                            '${verificationMethod == "near_owner" ? " · GPS+Photo" : verificationMethod == "far_owner" ? " · ID+Hati" : ""}',
                            style: const TextStyle(fontSize: 11, color: Colors.green,
                                fontWeight: FontWeight.w500),
                          ),
                      ]),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: ThemeConfig.getTextSecondaryColor(context)),
                        color: ThemeConfig.getCardColor(context),
                        onSelected: (v) async {
                          if (v == 'view')    { _viewProperty(p); }
                          if (v == 'delete')  { await _deleteProperty(p); }
                          if (v == 'restore') { await _restoreProperty(p); }
                          if (v == 'feature') { await _toggleFeature(p); }
                          if (v == 'verify')  { await _toggleVerify(p); }
                          if (v == 'notify')  { await _notifyOwner(p); }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'view', child: _menuItem(Icons.visibility_rounded, 'View Details')),
                          if (!isDeleted) ...[
                            PopupMenuItem(value: 'feature', child: _menuItem(
                                isFeatured ? Icons.star_border_rounded : Icons.star_rounded,
                                isFeatured ? 'Unfeature' : 'Feature')),
                            PopupMenuItem(value: 'verify', child: _menuItem(
                                isVerified ? Icons.verified_rounded : Icons.verified_outlined,
                                isVerified ? 'Remove Verification' : 'Verify Property')),
                            PopupMenuItem(value: 'notify', child: _menuItem(
                                Icons.notifications_rounded, 'Notify Owner')),
                            const PopupMenuDivider(),
                            PopupMenuItem(value: 'delete', child: _menuItem(
                                Icons.delete_outline_rounded, 'Delete Property',
                                color: ThemeConfig.errorColor)),
                          ] else
                            PopupMenuItem(value: 'restore', child: _menuItem(
                                Icons.restore_rounded, 'Restore Property',
                                color: ThemeConfig.successColor)),
                        ],
                      ),
                    ),
                    if (isDeleted && p['deletion_reason'] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ThemeConfig.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: ThemeConfig.errorColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Reason: ${p['deletion_reason']}',
                                  style: const TextStyle(fontSize: 11,
                                      color: ThemeConfig.errorColor)),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
        ),
    ]);
  }

  void _viewProperty(Map<String, dynamic> p) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => AdminPropertyDetailScreen(property: p)));
  }

  Future<void> _deleteProperty(Map<String, dynamic> p) async {
    final reason = await _inputDialog('Delete Property',
        'Enter reason for deletion (optional):');
    if (!mounted) return;
    final result = await ref.read(adminServiceProvider)
        .adminDeleteProperty(p['id'] as String, reason: reason);
    if (!mounted) return;
    _snack(result['message'] as String? ?? (result['success'] == true
        ? 'Property deleted and owner notified'
        : 'Failed: ${result['error']}'),
        result['success'] == true);
    _load();
  }

  Future<void> _restoreProperty(Map<String, dynamic> p) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Restore "${p['title'] ?? 'Property'}"',
            style: TextStyle(
                color: ThemeConfig.getTextPrimaryColor(context), fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'The property will be made visible again and the owner will be notified.',
            style: TextStyle(
                color: ThemeConfig.getTextSecondaryColor(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
                hintText: 'Note to owner (optional)',
                border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.successColor,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref.read(adminServiceProvider).adminRestoreProperty(
        p['id'] as String,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
    if (!mounted) return;
    _snack(
        result['message'] as String? ??
            (result['success'] == true
                ? 'Property restored and owner notified'
                : 'Failed: ${result['error']}'),
        result['success'] == true);
    _load();
  }

  Future<void> _toggleFeature(Map<String, dynamic> p) async {
    final isFeatured = p['is_featured'] as bool? ?? false;
    final ok = await ref.read(adminServiceProvider)
        .adminFeatureProperty(p['id'] as String, featured: !isFeatured);
    if (!mounted) return;
    _snack(ok
        ? (!isFeatured ? 'Property featured! Owner notified.' : 'Feature removed. Owner notified.')
        : 'Failed', ok);
    _load();
  }

  Future<void> _toggleVerify(Map<String, dynamic> p) async {
    final isVerified = p['is_verified'] as bool? ?? false;
    final ok = await ref.read(adminServiceProvider)
        .adminVerifyProperty(p['id'] as String, verified: !isVerified);
    if (!mounted) return;
    _snack(ok
        ? (!isVerified ? 'Property verified! Owner notified.' : 'Verification removed. Owner notified.')
        : 'Failed', ok);
    _load();
  }

  Future<void> _notifyOwner(Map<String, dynamic> p) async {
    final msgCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Notify Owner of "${p['title'] ?? 'Property'}"',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context), fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title',
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: msgCtrl, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message',
                  border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (sent == true && titleCtrl.text.isNotEmpty && msgCtrl.text.isNotEmpty) {
      final ok = await ref.read(adminServiceProvider).sendNotificationToUser(
        userId: p['owner_id'] as String,
        title: titleCtrl.text.trim(),
        message: msgCtrl.text.trim(),
        type: 'admin_message',
        data: {'property_id': p['id']},
      );
      if (mounted) _snack(ok ? 'Notification sent!' : 'Failed to send', ok);
    }
  }

  Future<String?> _inputDialog(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text(title,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: InputDecoration(hintText: hint,
              border: const OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(children: [
      Icon(icon, size: 18,
          color: color ?? ThemeConfig.getTextPrimaryColor(context)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
          color: color ?? ThemeConfig.getTextPrimaryColor(context))),
    ]);
  }

  void _snack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ThemeConfig.successColor : ThemeConfig.errorColor,
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 4: ADS — creative list, approve/reject/feature controls
// ═══════════════════════════════════════════════════════════════════════════
class _AdsTab extends ConsumerStatefulWidget {
  const _AdsTab();
  @override
  ConsumerState<_AdsTab> createState() => _AdsTabState();
}

class _AdsTabState extends ConsumerState<_AdsTab> {
  List<Map<String, dynamic>> _allCreatives = [];
  bool _loading     = true;
  bool _loadingMore = false;
  bool _hasMore     = true;
  int  _offset      = 0;
  static const int _pageSize = 50;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all'; // all | active | rejected | deleted | pending

  List<Map<String, dynamic>> get _filtered {
    var list = _allCreatives;
    // Status filter
    if (_filterStatus != 'all') {
      list = list.where((ad) {
        final isDeleted  = ad['deleted_at'] != null;
        final isApproved = ad['is_approved'] as bool? ?? false;
        final status     = ad['status']      as String? ?? '';
        if (_filterStatus == 'deleted')  return isDeleted;
        if (_filterStatus == 'active')   return !isDeleted && isApproved;
        if (_filterStatus == 'rejected') return !isDeleted && status == 'rejected';
        if (_filterStatus == 'pending')  return !isDeleted && !isApproved && status != 'rejected';
        return true;
      }).toList();
    }
    // Search
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((ad) {
      final headline = (ad['headline'] as String? ?? '').toLowerCase();
      final company  = (ad['advertiser_company'] as String? ?? ad['company_name'] as String? ?? '').toLowerCase();
      final status   = (ad['status'] as String? ?? '').toLowerCase();
      return headline.contains(q) || company.contains(q) || status.contains(q);
    }).toList();
  }

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
    setState(() { _loading = true; _offset = 0; _hasMore = true; });
    final svc = ref.read(adminServiceProvider);
    final creatives = await svc.getAllCreativesAdmin(limit: _pageSize, offset: 0);
    if (mounted) {
      setState(() {
        _allCreatives = creatives;
        _offset  = creatives.length;
        _hasMore = creatives.length == _pageSize;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final svc = ref.read(adminServiceProvider);
    final creatives = await svc.getAllCreativesAdmin(limit: _pageSize, offset: _offset);
    if (mounted) {
      setState(() {
        _allCreatives.addAll(creatives);
        _offset  += creatives.length;
        _hasMore  = creatives.length == _pageSize;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView(context);
    final filtered = _filtered;

    return Column(children: [
      // ── Search bar ───────────────────────────────────────────────────────
      Container(
        color: ThemeConfig.getCardColor(context),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: InputDecoration(
            hintText: 'Search ads by headline, company or status…',
            hintStyle: TextStyle(color: ThemeConfig.getTextSecondaryColor(context)),
            prefixIcon: Icon(Icons.search, size: 20,
                color: ThemeConfig.getTextSecondaryColor(context)),
            filled: true,
            fillColor: ThemeConfig.getColor(context,
                lightColor: ThemeConfig.lightInputFill,
                darkColor: ThemeConfig.darkInputFill),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    })
                : null,
          ),
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
        ),
      ),

      // ── Filter chips ─────────────────────────────────────────────────────
      Container(
        color: ThemeConfig.getCardColor(context),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('all',      'All (${_allCreatives.length})'),
            const SizedBox(width: 8),
            _filterChip('active',   'Active'),
            const SizedBox(width: 8),
            _filterChip('rejected', 'Rejected'),
            const SizedBox(width: 8),
            _filterChip('deleted',  'Deleted'),
          ]),
        ),
      ),

      // ── List ─────────────────────────────────────────────────────────────
      Expanded(
        child: filtered.isEmpty
            ? _EmptyCard(
                icon: Icons.image_not_supported_outlined,
                message: _searchQuery.isEmpty
                    ? 'No ads found.'
                    : 'No ads match "$_searchQuery".',
                color: ThemeConfig.warningColor)
            : RefreshIndicator(
                onRefresh: _load,
                color: ThemeConfig.getPrimaryColor(context),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length + (_hasMore && _searchQuery.isEmpty && _filterStatus == 'all' ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == filtered.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : OutlinedButton.icon(
                                  onPressed: _loadMore,
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('Load more'),
                                ),
                        ),
                      );
                    }
                    return _buildAdCard(filtered[i]);
                  },
                ),
              ),
      ),
    ]);
  }

  Widget _filterChip(String value, String label) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? ThemeConfig.getPrimaryColor(context)
              : ThemeConfig.getColor(context,
                  lightColor: ThemeConfig.lightInputFill,
                  darkColor: ThemeConfig.darkInputFill),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? ThemeConfig.getPrimaryColor(context)
                : ThemeConfig.getColor(context,
                    lightColor: ThemeConfig.lightBorder,
                    darkColor: ThemeConfig.darkBorder),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : ThemeConfig.getTextSecondaryColor(context))),
      ),
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final headline   = ad['headline']   as String? ?? 'Ad';
    final company    = ad['advertiser_company'] as String? ?? ad['company_name'] as String? ?? '—';
    final imageUrl   = ad['image_url']  as String?;
    final mediaType  = ad['media_type'] as String? ?? 'image';
    final isDeleted  = ad['deleted_at'] != null;
    final isApproved = ad['is_approved'] as bool? ?? false;
    final status     = ad['status']     as String? ?? '—';
    final aiApproved = ad['ai_approved'] as bool?;
    final aiConf     = ad['ai_confidence'] as int?;

    // Status color
    Color statusColor = ThemeConfig.warningColor;
    String statusLabel = status.toUpperCase();
    if (isDeleted) {
      statusColor = ThemeConfig.errorColor;
      statusLabel = 'DELETED';
    } else if (isApproved) {
      statusColor = ThemeConfig.successColor;
      statusLabel = 'ACTIVE';
    } else if (status == 'rejected') {
      statusColor = ThemeConfig.errorColor;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDeleted
          ? ThemeConfig.errorColor.withOpacity(0.05)
          : ThemeConfig.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => AdminAdDetailScreen(ad: ad)))
            .then((_) => _load()),
        borderRadius: BorderRadius.circular(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Media preview
          if (imageUrl != null) _buildMediaPreview(imageUrl, mediaType),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Headline row
              Row(children: [
                Expanded(
                  child: Text(headline,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: ThemeConfig.getTextPrimaryColor(context))),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: statusColor)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(company,
                  style: TextStyle(fontSize: 12,
                      color: ThemeConfig.getTextSecondaryColor(context))),

              // AI result badge
              const SizedBox(height: 8),
              if (aiApproved != null)
                Row(children: [
                  Icon(
                    aiApproved ? Icons.auto_awesome_rounded : Icons.block_rounded,
                    size: 13,
                    color: aiApproved ? Colors.teal : ThemeConfig.errorColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    aiApproved
                        ? 'AI Approved${aiConf != null ? " ($aiConf%)" : ""}'
                        : 'AI Rejected${aiConf != null ? " ($aiConf%)" : ""}',
                    style: TextStyle(
                        fontSize: 11,
                        color: aiApproved ? Colors.teal : ThemeConfig.errorColor,
                        fontWeight: FontWeight.w500),
                  ),
                ]),

              // Action buttons row
              const SizedBox(height: 10),
              Row(children: [
                if (!isDeleted && !isApproved && status != 'rejected')
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                      onPressed: () => _approveAd(ad['id'] as String),
                    ),
                  ),
                if (!isDeleted && !isApproved && status != 'rejected')
                  const SizedBox(width: 8),
                if (!isDeleted && !isApproved)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: ThemeConfig.errorColor,
                          side: BorderSide(
                              color: ThemeConfig.errorColor.withOpacity(0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                      onPressed: () => _rejectAd(ad['id'] as String),
                    ),
                  ),
                if (!isDeleted) ...[
                  if (!isApproved) const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: ThemeConfig.getTextSecondaryColor(context)),
                    color: ThemeConfig.getCardColor(context),
                    onSelected: (v) async {
                      if (v == 'delete')  await _deleteCreative(ad);
                      if (v == 'approve') await _approveAd(ad['id'] as String);
                      if (v == 'reject')  await _rejectAd(ad['id'] as String);
                    },
                    itemBuilder: (_) => [
                      if (isApproved) ...[
                        PopupMenuItem(value: 'reject',
                            child: _menuItem(Icons.cancel_rounded, 'Revoke Approval',
                                color: ThemeConfig.warningColor)),
                        const PopupMenuDivider(),
                      ],
                      if (status == 'rejected')
                        PopupMenuItem(value: 'approve',
                            child: _menuItem(Icons.check_circle_rounded, 'Override & Approve',
                                color: ThemeConfig.successColor)),
                      PopupMenuItem(value: 'delete',
                          child: _menuItem(Icons.delete_outline_rounded, 'Delete Ad',
                              color: ThemeConfig.errorColor)),
                    ],
                  ),
                ] else
                  TextButton.icon(
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Restore', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: ThemeConfig.successColor),
                    onPressed: () => _restoreCreative(ad),
                  ),
              ]),
              if (isDeleted && ad['deletion_reason'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Reason: ${ad['deletion_reason']}',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic,
                          color: ThemeConfig.errorColor.withOpacity(0.8))),
                ),
              if (!isDeleted && ad['rejection_reason'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Rejected: ${ad['rejection_reason']}',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic,
                          color: ThemeConfig.errorColor.withOpacity(0.8))),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildMediaPreview(String imageUrl, String mediaType) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: mediaType == 'video'
          ? Container(
              height: 120,
              color: Colors.black87,
              child: Stack(alignment: Alignment.center, children: [
                if (imageUrl.isNotEmpty)
                  Image.network(imageUrl, height: 120, width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
              ]),
            )
          : Image.network(imageUrl, height: 120, width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  height: 60, color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image))),
    );
  }

  Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(children: [
      Icon(icon, size: 16, color: color ?? ThemeConfig.getTextPrimaryColor(context)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
          color: color ?? ThemeConfig.getTextPrimaryColor(context))),
    ]);
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _approveAd(String id) async {
    final ok = await ref.read(adminServiceProvider).approveAd(id);
    if (!mounted) return;
    _snack(ok ? 'Ad approved! Campaign is now running.' : 'Failed to approve', ok);
    _load();
  }

  Future<void> _rejectAd(String id) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Reject Ad',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: const InputDecoration(
              hintText: 'Reason for rejection (required)',
              border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor, foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.isNotEmpty) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    final ok = await ref.read(adminServiceProvider).rejectAd(id, reason);
    if (!mounted) return;
    _snack(ok ? 'Ad rejected' : 'Failed to reject', ok);
    _load();
  }

  Future<void> _deleteCreative(Map<String, dynamic> ad) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Delete Ad',
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('This will remove the ad and notify the advertiser.',
              style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context))),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                hintText: 'Reason (optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref.read(adminServiceProvider).adminDeleteCreative(
      ad['id'] as String,
      reason: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
    );
    if (!mounted) return;
    _snack(
      result['message'] as String? ??
          (result['success'] == true ? 'Ad deleted.' : 'Failed: ${result['error']}'),
      result['success'] == true,
    );
    _load();
  }

  Future<void> _restoreCreative(Map<String, dynamic> ad) async {
    final result = await ref.read(adminServiceProvider).adminRestoreCreative(
      ad['id'] as String,
    );
    if (!mounted) return;
    _snack(
      result['message'] as String? ??
          (result['success'] == true ? 'Ad restored.' : 'Failed: ${result['error']}'),
      result['success'] == true,
    );
    _load();
  }

  void _snack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ThemeConfig.successColor : ThemeConfig.errorColor,
    ));
  }
}

class _AnalyticsTab extends ConsumerStatefulWidget {
  const _AnalyticsTab();
  @override
  ConsumerState<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<_AnalyticsTab> {
  AdminArchiveStats? _stats;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await ref.read(adminServiceProvider).getArchiveStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView(context);
    if (_stats == null) {
      return _EmptyCard(
          icon: Icons.analytics_outlined,
          message: 'Could not load analytics.',
          color: ThemeConfig.getTextSecondaryColor(context));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: ThemeConfig.getPrimaryColor(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionHeader('👥 User Accounts'),
          const SizedBox(height: 12),
          _StatsRow([
            _StatItem('Total', '${_stats!.totalAccounts}', Colors.blue),
            _StatItem('Active', '${_stats!.activeAccounts}', Colors.green),
            _StatItem('Banned', '${_stats!.deactivatedAccounts}', Colors.orange),
            _StatItem('Deleted', '${_stats!.deletedAccounts}', Colors.red),
          ]),
          const SizedBox(height: 20),
          const _SectionHeader('🏠 Properties'),
          const SizedBox(height: 12),
          _StatsRow([
            _StatItem('Total', '${_stats!.totalProperties}', Colors.blue),
            _StatItem('Active', '${_stats!.activeProperties}', Colors.green),
            _StatItem('Deleted', '${_stats!.deletedProperties}', Colors.red),
          ]),
          const SizedBox(height: 20),
          const _SectionHeader('💳 Subscriptions'),
          const SizedBox(height: 12),
          _StatsRow([
            _StatItem('Total', '${_stats!.totalSubscriptions}', Colors.blue),
            _StatItem('Active', '${_stats!.activeSubscriptions}', Colors.green),
            _StatItem('Cancelled', '${_stats!.cancelledSubscriptions}', Colors.orange),
            _StatItem('Expired', '${_stats!.expiredSubscriptions}', Colors.red),
          ]),
          const SizedBox(height: 12),
          _InfoCard('Subscription Revenue',
              'USD ${_formatNum(_stats!.totalSubscriptionRevenueUsd)}',
              Colors.indigo),
          const SizedBox(height: 20),
          const _SectionHeader('📣 Ad Campaigns'),
          const SizedBox(height: 12),
          _StatsRow([
            _StatItem('Total', '${_stats!.totalCampaigns}', Colors.blue),
            _StatItem('Active', '${_stats!.activeCampaigns}', Colors.green),
            _StatItem('Deleted', '${_stats!.deletedCampaigns}', Colors.red),
          ]),
          const SizedBox(height: 12),
          _InfoCard('Campaign Spend', 'TZS ${_formatNum(_stats!.totalCampaignSpendTzs)}',
              Colors.teal),
          const SizedBox(height: 8),
          _InfoCard('Impression Revenue',
              'TZS ${_formatNum(_stats!.totalImpressionRevenueTzs)}', Colors.cyan),
          const SizedBox(height: 8),
          _InfoCard('Click Revenue',
              'TZS ${_formatNum(_stats!.totalClickRevenueTzs)}', Colors.blue),
          const SizedBox(height: 20),
          const _SectionHeader('🎨 Ad Creatives'),
          const SizedBox(height: 12),
          _StatsRow([
            _StatItem('Total', '${_stats!.totalCreatives}', Colors.blue),
            _StatItem('Pending', '${_stats!.pendingApproval}', Colors.orange),
            _StatItem('Deleted', '${_stats!.deletedCreatives}', Colors.red),
          ]),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}



// ═══════════════════════════════════════════════════════════════════════════
// SHARED HELPERS & WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

Widget _loadingView(BuildContext context) {
  return Center(child: CircularProgressIndicator(
      color: ThemeConfig.getPrimaryColor(context)));
}

String _formatNum(double n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}

/// Format an ISO date string for compact display on property cards
String _fmtDate(String s) {
  try {
    return DateFormat('MMM d, yyyy').format(DateTime.parse(s));
  } catch (_) {
    return s;
  }
}

// ── Filter chip used by the Properties tab ──────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: selected ? color : color.withOpacity(0.6)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : color.withOpacity(0.7))),
        ]),
      ),
    );
  }
}

String _formatDate(DateTime? d) {
  if (d == null) return 'Never';
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d, yyyy').format(d);
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
            color: ThemeConfig.getTextPrimaryColor(context)));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeConfig.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const Spacer(),
        Text(value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: ThemeConfig.getTextPrimaryColor(context))),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 12,
                color: ThemeConfig.getTextSecondaryColor(context))),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsRow(this.items);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: item.color.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: item.color)),
            Text(item.label,
                style: TextStyle(fontSize: 11,
                    color: ThemeConfig.getTextSecondaryColor(context))),
          ]),
        ),
      )).toList(),
    );
  }
}

class _StatItem {
  final String label, value;
  final Color color;
  const _StatItem(this.label, this.value, this.color);
}

class _InfoCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(color: ThemeConfig.getTextSecondaryColor(context))),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _EmptyCard({required this.icon, required this.message, required this.color});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 56, color: color.withOpacity(0.4)),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: color, fontSize: 16)),
      ]),
    );
  }
}

class _DropFilter extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _DropFilter({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selected,
      underline: const SizedBox(),
      style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context), fontSize: 13),
      dropdownColor: ThemeConfig.getCardColor(context),
      items: options.entries.map((e) => DropdownMenuItem(
          value: e.key, child: Text(e.value))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}