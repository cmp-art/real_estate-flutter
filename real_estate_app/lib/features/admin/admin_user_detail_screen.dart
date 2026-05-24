// lib/features/admin/presentation/screens/admin_user_detail_screen.dart
//
// Tap any user row in the Users tab → opens this screen.
// Shows: Profile · Properties · Campaigns (creatives nested inside each campaign)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/theme_config.dart';
import '../../../../core/services/admin_service.dart';
import 'admin_property_detail_screen.dart';
import 'admin_dashboard_screen.dart' show adminServiceProvider;
import '../../../../core/utils/responsive_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class AdminUserDetails {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String subscriptionTier;
  final bool isActive;
  final bool isVerified;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? lastSignIn;
  final String? deactivationReason;

  final int totalProperties;
  final int activeProperties;
  final int totalCampaigns;
  final int activeCampaigns;
  final int totalCreatives;
  final int pendingCreatives;

  final double advertiserBalance;
  final double totalCampaignSpent;
  final double totalSubscriptionSpent;

  final List<Map<String, dynamic>> properties;
  final List<Map<String, dynamic>> campaigns;
  final List<Map<String, dynamic>> creatives;
  final List<Map<String, dynamic>> subscriptions;

  const AdminUserDetails({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.subscriptionTier,
    required this.isActive,
    required this.isVerified,
    this.phone,
    this.avatarUrl,
    this.createdAt,
    this.lastSignIn,
    this.deactivationReason,
    required this.totalProperties,
    required this.activeProperties,
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.totalCreatives,
    required this.pendingCreatives,
    required this.advertiserBalance,
    required this.totalCampaignSpent,
    required this.totalSubscriptionSpent,
    required this.properties,
    required this.campaigns,
    required this.creatives,
    required this.subscriptions,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE EXTENSION
// Each query has its own try/catch so one failing table never kills the screen.
// ─────────────────────────────────────────────────────────────────────────────

extension AdminUserDetailsExtension on AdminService {
  Future<AdminUserDetails?> getUserDetails(String userId) async {
    final db = Supabase.instance.client;

    // ── 1. Profile — the only REQUIRED query ────────────────────────────────
    Map<String, dynamic>? profile;
    try {
      profile = await db
          .from('admin_all_accounts')
          .select()
          .eq('id', userId)
          .maybeSingle();
      debugPrint('✅ profile loaded: ${profile?.keys.toList()}');
    } catch (e) {
      debugPrint('❌ profile query failed: $e');
      // Try fallback via user_profiles directly
      try {
        profile = await db
            .from('user_profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        debugPrint('✅ profile fallback loaded');
      } catch (e2) {
        debugPrint('❌ profile fallback also failed: $e2');
        return null;
      }
    }
    if (profile == null) {
      debugPrint('❌ profile is null for userId=$userId');
      return null;
    }

    // ── 2. Properties ────────────────────────────────────────────────────────
    List<Map<String, dynamic>> props = [];
    try {
      final raw = await db
          .from('admin_all_properties')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      props = List<Map<String, dynamic>>.from(raw as List);
      debugPrint('✅ properties loaded: ${props.length}');
    } catch (e) {
      debugPrint('❌ properties query failed: $e');
      // Fallback: query properties table directly
      try {
        final raw = await db
            .from('properties')
            .select('id, title, property_type, listing_type, price, '
                'location, status, deleted_at, created_at, images')
            .eq('owner_id', userId)
            .order('created_at', ascending: false)
            .limit(50);
        props = List<Map<String, dynamic>>.from(raw as List);
        debugPrint('✅ properties fallback loaded: ${props.length}');
      } catch (e2) {
        debugPrint('❌ properties fallback also failed: $e2');
      }
    }

    // Advertiser balance (populated in step 3 below)
    double balance = 0;
    double totalSpent = 0;

    // ── 3. Campaigns ─────────────────────────────────────────────────────────
    // ad_campaigns.advertiser_id → advertisers.id (NOT auth user id).
    // Correct column name: campaign_objective (NOT objective).
    List<Map<String, dynamic>> campaigns = [];
    String? advertiserId;
    try {
      // Get the advertiser row for this user from 'advertisers' table.
      // Correct columns: account_balance, total_spent (from sql3 schema).
      final advRaw = await db
          .from('advertisers')
          .select('id, account_balance, total_spent, status, company_name')
          .eq('user_id', userId)
          .maybeSingle();
      if (advRaw != null) {
        advertiserId = advRaw['id'] as String?;
        balance = (advRaw['account_balance'] as num?)?.toDouble() ?? 0;
        totalSpent = (advRaw['total_spent'] as num?)?.toDouble() ?? 0;
        debugPrint('✅ advertiser loaded: $advertiserId');
      }
    } catch (e) {
      debugPrint('❌ advertisers query failed: $e');
    }

    if (advertiserId != null) {
      try {
        // Correct column: campaign_objective (NOT objective)
        final raw = await db
            .from('ad_campaigns')
            .select('id, campaign_name, status, campaign_objective, '
                'total_budget, spent_amount, impressions_count, clicks_count, '
                'start_date, end_date, created_at, deleted_at')
            .eq('advertiser_id', advertiserId)
            .order('created_at', ascending: false)
            .limit(50);
        campaigns = List<Map<String, dynamic>>.from(raw as List);
        debugPrint('✅ campaigns loaded: ${campaigns.length}');
      } catch (e) {
        debugPrint('❌ campaigns query failed: $e');
      }
    }

    // ── 4. Creatives ─────────────────────────────────────────────────────────
    // Schema: ad_creatives has NO 'title' and NO 'advertiser_id' column.
    // Correct columns: headline, impressions, clicks.
    List<Map<String, dynamic>> creatives = [];
    if (advertiserId != null && campaigns.isNotEmpty) {
      try {
        final campaignIds = campaigns.map((c) => c['id'] as String).toList();
        final raw = await db
            .from('ad_creatives')
            .select('''
              id, campaign_id, ad_format, headline, description,
              call_to_action, image_url, logo_url, landing_url,
              status, is_approved,
              impressions, clicks, created_at, deleted_at, deletion_reason,
              ad_campaigns (
                advertiser_id,
                advertisers ( company_name )
              )
            ''')
            .inFilter('campaign_id', campaignIds)
            .order('created_at', ascending: false)
            .limit(50);
        creatives = List<Map<String, dynamic>>.from(raw as List);
        debugPrint('✅ creatives loaded: ${creatives.length}');
      } catch (e) {
        debugPrint('❌ creatives query failed: $e');
      }
    }

    // ── 5. Subscriptions ─────────────────────────────────────────────────────
    List<Map<String, dynamic>> subs = [];
    try {
      // Correct schema (sql1): user_subscriptions has 'tier' (TEXT), NOT 'tier_name'.
      // No 'tier_price_usd' column - that's only in the admin view.
      final raw = await db
          .from('user_subscriptions')
          .select('id, tier, status, '
              'started_at, expires_at, auto_renew, '
              'cancelled_at, cancellation_reason')
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(20);
      subs = List<Map<String, dynamic>>.from(raw as List);
      debugPrint('✅ subscriptions loaded: ${subs.length}');
    } catch (e) {
      debugPrint('❌ subscriptions query failed (table may not exist): $e');
    }

    // ── 6. Advertiser balance ─────────────────────────────────────────────────
    // NOTE: 'advertiser_accounts' table does NOT exist.
    // The correct table is 'advertisers' (balance was already loaded in step 3 above).
    // Balance already loaded from advertisers table in step 3.
    // Fallback: compute total spent from campaigns if advertiser row was missing.
    if (advertiserId == null && campaigns.isNotEmpty) {
      totalSpent = campaigns.fold(0.0,
          (acc, c) => acc + ((c['spent_amount'] as num?)?.toDouble() ?? 0));
      debugPrint('✅ total spent computed from campaigns: \$totalSpent');
    }

    final totalSubSpent = subs.fold<double>(0, (acc, s) {
      return acc + (0.0);
    });

    // ── Helper: resolve email from profile ────────────────────────────────────
    // admin_all_accounts uses 'email'; user_profiles fallback may not have it
    final email = profile['email'] as String? ?? '';

    return AdminUserDetails(
      id: userId,
      email: email,
      fullName: profile['full_name'] as String? ?? '—',
      role: profile['role'] as String? ?? 'user',
      subscriptionTier: profile['current_tier'] as String? ?? 'free',
      isActive: profile['is_active'] as bool? ?? true,
      isVerified: profile['is_verified'] as bool? ?? false,
      phone: profile['phone'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      createdAt: _parseDate(profile['auth_created_at'] ?? profile['created_at']),
      lastSignIn: _parseDate(profile['last_sign_in_at'] ?? profile['last_login_at']),
      deactivationReason: profile['deactivation_reason'] as String?,
      totalProperties: props.length,
      activeProperties:
          props.where((p) => p['deleted_at'] == null).length,
      totalCampaigns: campaigns.length,
      activeCampaigns: campaigns
          .where((c) => c['status'] == 'running' && c['deleted_at'] == null)
          .length,
      totalCreatives: creatives.length,
      pendingCreatives: creatives
          .where((c) => c['is_approved'] == false && c['status'] == 'paused' && c['deleted_at'] == null)
          .length,
      advertiserBalance: balance,
      totalCampaignSpent: totalSpent,
      totalSubscriptionSpent: totalSubSpent,
      properties: props,
      campaigns: campaigns,
      creatives: creatives,
      subscriptions: subs,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? displayEmail;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    this.displayEmail,
  });

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState
    extends ConsumerState<AdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  AdminUserDetails? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(adminServiceProvider);
      final details = await svc.getUserDetails(widget.userId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
        if (details == null) {
          _error =
              'Could not load user details.\nCheck debug console for details.';
        }
      });
    } catch (e) {
      debugPrint('AdminUserDetailScreen load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error: $e';
      });
    }
  }

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleBan() async {
    if (_details == null) return;
    final svc = ref.read(adminServiceProvider);
    if (_details!.isActive) {
      final reason = await _inputDialog(
          'Ban User', 'Reason (optional):',
          isRequired: false);
      final ok = await svc.banUser(_details!.id, reason: reason);
      if (mounted) _snack(ok ? 'User banned' : 'Failed to ban user', ok);
    } else {
      final ok = await svc.unbanUser(_details!.id);
      if (mounted) _snack(ok ? 'User unbanned' : 'Failed to unban', ok);
    }
    _load();
  }

  Future<void> _changeRole() async {
    if (_details == null) return;
    final roles = [
      UserRole.user,
      UserRole.agent,
      UserRole.advertiser,
      UserRole.moderator,
      UserRole.admin,
    ];
    UserRole selected = UserRole.fromString(_details!.role);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: ThemeConfig.getCardColor(context),
          title: Text('Change Role',
              style: TextStyle(
                  color: ThemeConfig.getTextPrimaryColor(context))),
          content: DropdownButtonFormField<UserRole>(
            initialValue: selected,
            dropdownColor: ThemeConfig.getCardColor(context),
            style: TextStyle(
                color: ThemeConfig.getTextPrimaryColor(context)),
            decoration:
                const InputDecoration(border: OutlineInputBorder()),
            items: roles
                .map((r) =>
                    DropdownMenuItem(value: r, child: Text(r.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) setS(() => selected = v);
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(context),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final svc = ref.read(adminServiceProvider);
    final ok = await svc.updateUserRole(
        userId: _details!.id, role: selected);
    if (mounted) _snack(ok ? 'Role updated' : 'Failed', ok);
    _load();
  }

  Future<void> _sendNotification() async {
    if (_details == null) return;
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text('Send Notification',
            style: TextStyle(
                color: ThemeConfig.getTextPrimaryColor(context))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            style: TextStyle(
                color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                labelText: 'Title', border: OutlineInputBorder()),
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(
            controller: msgCtrl,
            style: TextStyle(
                color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                labelText: 'Message', border: OutlineInputBorder()),
            maxLines: 3,
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
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
    if (sent != true || titleCtrl.text.trim().isEmpty) return;
    final svc = ref.read(adminServiceProvider);
    final ok = await svc.sendNotificationToUser(
      userId: _details!.id,
      title: titleCtrl.text.trim(),
      message: msgCtrl.text.trim(),
    );
    if (mounted) _snack(ok ? 'Notification sent' : 'Failed to send', ok);
  }

  Future<String?> _inputDialog(String title, String hint,
      {bool isRequired = true}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeConfig.getCardColor(context),
        title: Text(title,
            style: TextStyle(
                color: ThemeConfig.getTextPrimaryColor(context))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
              color: ThemeConfig.getTextPrimaryColor(context)),
          decoration: InputDecoration(
              hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(context),
                foregroundColor: Colors.white),
            onPressed: () {
              if (isRequired && ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? ThemeConfig.successColor : ThemeConfig.errorColor,
    ));
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appBarBg = ThemeConfig.getColor(context,
        lightColor: ThemeConfig.lightAppBarBackground,
        darkColor: ThemeConfig.darkAppBarBackground);
    final appBarFg = ThemeConfig.getColor(context,
        lightColor: ThemeConfig.lightAppBarForeground,
        darkColor: ThemeConfig.darkAppBarForeground);

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: appBarBg,
        iconTheme: IconThemeData(color: appBarFg),
        title: Text(
          widget.displayEmail ?? widget.userId,
          style: TextStyle(
              color: appBarFg,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
              fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_loading && _details != null) ...[
            IconButton(
              icon: Icon(Icons.notifications_rounded, color: appBarFg),
              tooltip: 'Send Notification',
              onPressed: _sendNotification,
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: appBarFg),
              color: ThemeConfig.getCardColor(context),
              onSelected: (v) {
                if (v == 'ban') _toggleBan();
                if (v == 'role') _changeRole();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'ban',
                  child: Row(children: [
                    Icon(
                      _details!.isActive
                          ? Icons.block
                          : Icons.check_circle,
                      color: _details!.isActive
                          ? ThemeConfig.errorColor
                          : ThemeConfig.successColor,
                      size: 18,
                    ),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                    Text(
                      _details!.isActive ? 'Ban User' : 'Unban User',
                      style: TextStyle(
                          color: ThemeConfig.getTextPrimaryColor(
                              context)),
                    ),
                  ]),
                ),
                PopupMenuItem(
                  value: 'role',
                  child: Row(children: [
                    Icon(Icons.manage_accounts,
                        size: 18,
                        color:
                            ThemeConfig.getTextPrimaryColor(context)),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                    Text('Change Role',
                        style: TextStyle(
                            color: ThemeConfig.getTextPrimaryColor(
                                context))),
                  ]),
                ),
              ],
            ),
          ],
        ],
        bottom: (_loading || _error != null)
            ? null
            : TabBar(
                controller: _tab,
                labelColor: appBarFg,
                unselectedLabelColor: appBarFg.withOpacity(0.6),
                indicatorColor: appBarFg,
                isScrollable: true,
                tabs: [
                  const Tab(
                      icon: Icon(Icons.person_rounded),
                      text: 'Profile'),
                  Tab(
                    icon: const Icon(Icons.home_rounded),
                    text:
                        'Properties (${_details?.totalProperties ?? 0})',
                  ),
                  Tab(
                    icon: const Icon(Icons.campaign_rounded),
                    text:
                        'Campaigns (${_details?.totalCampaigns ?? 0})',
                  ),

                ],
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(
              color: ThemeConfig.getPrimaryColor(context)));
    }
    if (_error != null || _details == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 56,
                    color: ThemeConfig.errorColor.withOpacity(0.5)),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                Text(
                  _error ?? 'Could not load user details.',
                  style: TextStyle(
                      color:
                          ThemeConfig.getTextSecondaryColor(context)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          ThemeConfig.getPrimaryColor(context),
                      foregroundColor: Colors.white),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ]),
        ),
      );
    }

    return TabBarView(
      controller: _tab,
      children: [
        _ProfileTab(details: _details!, onRefresh: _load),
        _PropertiesTab(details: _details!),
        _CampaignsTab(details: _details!),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — PROFILE
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatelessWidget {
  final AdminUserDetails details;
  final VoidCallback onRefresh;
  const _ProfileTab({required this.details, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        details.isActive ? ThemeConfig.successColor : ThemeConfig.errorColor;
    final primary = ThemeConfig.getPrimaryColor(context);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + name ────────────────────────────────────────
              Row(children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: statusColor.withOpacity(0.12),
                  backgroundImage: details.avatarUrl != null
                      ? NetworkImage(details.avatarUrl!)
                      : null,
                  child: details.avatarUrl == null
                      ? Text(
                          _initials(details.fullName, details.email),
                          style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 26),
                              fontWeight: FontWeight.bold,
                              color: statusColor),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(details.fullName,
                            style: TextStyle(
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.getTextPrimaryColor(
                                    context))),
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: () => Clipboard.setData(
                              ClipboardData(text: details.email)),
                          child: Row(children: [
                            Flexible(
                              child: Text(details.email,
                                  style: TextStyle(
                                      color: primary,
                                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                                      decoration:
                                          TextDecoration.underline),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded,
                                size: 13, color: primary),
                          ]),
                        ),
                      ]),
                ),
                _StatusBadge(
                    details.isActive ? 'Active' : 'Banned',
                    statusColor),
              ]),

              const SizedBox(height: 20),

              // ── Account info ─────────────────────────────────────────
              const _SectionHeader('Account Info'),
              const SizedBox(height: 10),
              _InfoRow(context, Icons.badge_rounded, 'User ID',
                  details.id,
                  copyable: true),
              _InfoRow(context, Icons.manage_accounts_rounded, 'Role',
                  details.role),
              _InfoRow(context, Icons.card_membership_rounded,
                  'Subscription', details.subscriptionTier),
              if (details.phone != null)
                _InfoRow(context, Icons.phone_rounded, 'Phone',
                    details.phone!),
              _InfoRow(context, Icons.verified_rounded, 'Verified',
                  details.isVerified ? 'Yes' : 'No'),
              _InfoRow(
                  context,
                  Icons.calendar_today_rounded,
                  'Joined',
                  details.createdAt != null
                      ? DateFormat('MMM d, yyyy')
                          .format(details.createdAt!)
                      : '—'),
              _InfoRow(context, Icons.login_rounded, 'Last Sign-in',
                  _fmtDate(details.lastSignIn)),
              if (!details.isActive &&
                  details.deactivationReason != null)
                _InfoRow(
                    context,
                    Icons.warning_amber_rounded,
                    'Ban Reason',
                    details.deactivationReason!,
                    valueColor: ThemeConfig.errorColor),

              const SizedBox(height: 20),

              // ── Activity summary ──────────────────────────────────────
              const _SectionHeader('Activity Summary'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: ResponsiveHelper.getGridColumns(context, mobile: 1, tablet: 2, desktop: 2),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                children: [
                  _MiniStatCard(
                      '${details.activeProperties} / ${details.totalProperties}',
                      'Properties\n(active / total)',
                      Icons.home_rounded,
                      Colors.orange),
                  _MiniStatCard(
                      '${details.activeCampaigns} / ${details.totalCampaigns}',
                      'Campaigns\n(active / total)',
                      Icons.campaign_rounded,
                      Colors.purple),
                  _MiniStatCard(
                      '${details.totalCreatives}',
                      'Creatives\n(${details.pendingCreatives} pending)',
                      Icons.image_rounded,
                      Colors.blue),
                  _MiniStatCard(
                      details.subscriptions.isNotEmpty
                          ? (details.subscriptions.first['status']
                                  as String? ??
                              '—')
                          : 'None',
                      'Subscription\nStatus',
                      Icons.subscriptions_rounded,
                      Colors.indigo),
                ],
              ),

              // ── Finances ─────────────────────────────────────────────
              if (details.advertiserBalance > 0 ||
                  details.totalCampaignSpent > 0 ||
                  details.totalCampaigns > 0) ...[
                const SizedBox(height: 20),
                const _SectionHeader('Finances'),
                const SizedBox(height: 10),
                if (details.advertiserBalance > 0)
                  _FinanceCard(
                      context,
                      'Ad Balance',
                      'TZS ${_fmtNum(details.advertiserBalance)}',
                      Colors.teal),
                if (details.totalCampaignSpent > 0) ...[
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                  _FinanceCard(
                      context,
                      'Total Campaign Spend',
                      'TZS ${_fmtNum(details.totalCampaignSpent)}',
                      Colors.purple),
                ],
                if (details.totalSubscriptionSpent > 0) ...[
                  SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                  _FinanceCard(
                      context,
                      'Subscription Spend',
                      'USD ${_fmtNum(details.totalSubscriptionSpent)}',
                      Colors.indigo),
                ],
              ],

              // ── Subscription history ──────────────────────────────────
              if (details.subscriptions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionHeader('Subscription History'),
                const SizedBox(height: 10),
                ...details.subscriptions
                    .map((s) => _SubTile(context, s)),
              ],

              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
            ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — PROPERTIES
// ═══════════════════════════════════════════════════════════════════════════

class _PropertiesTab extends StatelessWidget {
  final AdminUserDetails details;
  const _PropertiesTab({required this.details});

  @override
  Widget build(BuildContext context) {
    final props = details.properties;
    if (props.isEmpty) {
      return const _EmptyState(
          Icons.home_work_outlined, 'No properties found');
    }

    return ListView.builder(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
      itemCount: props.length,
      itemBuilder: (_, i) {
        final p = props[i];
        final isDeleted = (p['deleted_at'] != null) ||
            (p['is_deleted'] as bool? ?? false);
        final status = p['status'] as String? ?? 'unknown';
        final isFeatured = p['is_featured'] as bool? ?? false;
        final isVerified = p['is_verified'] as bool? ?? false;

        final statusColor = isDeleted
            ? ThemeConfig.errorColor
            : status == 'available'
                ? ThemeConfig.successColor
                : ThemeConfig.warningColor;

        // images is List<String> in admin_all_properties
        final images =
            (p['images'] as List?)?.cast<String>() ?? <String>[];
        final thumb = images.isNotEmpty ? images.first : null;
        final price = (p['price'] as num?)?.toDouble() ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: ThemeConfig.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor.withOpacity(0.25)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      AdminPropertyDetailScreen(property: p)),
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumb != null
                  ? Image.network(
                      thumb,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _PropIconBox(statusColor),
                    )
                  : _PropIconBox(statusColor),
            ),
            title: Row(children: [
              Expanded(
                child: Text(
                  p['title'] as String? ?? 'Untitled',
                  style: TextStyle(
                      color: ThemeConfig.getTextPrimaryColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isFeatured)
                Icon(Icons.star_rounded,
                    color: Colors.amber, size: ResponsiveHelper.getResponsiveIconSize(context)),
              if (isVerified)
                Icon(Icons.verified_rounded,
                    color: Colors.blue, size: ResponsiveHelper.getResponsiveIconSize(context)),
            ]),
            subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  Text(
                    [
                      if ((p['property_type'] as String?) != null)
                        p['property_type'] as String,
                      if ((p['listing_type'] as String?) != null)
                        p['listing_type'] as String,
                      'TZS ${_fmtNum(price)}',
                    ].join(' · '),
                    style: TextStyle(
                        color:
                            ThemeConfig.getTextSecondaryColor(context),
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    _StatusBadge(
                        isDeleted ? 'Deleted' : status, statusColor),
                    const SizedBox(width: 6),
                    Text(
                      _fmtDate(_parseDate(p['created_at'])),
                      style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                          color: ThemeConfig.getTextSecondaryColor(
                              context)),
                    ),
                  ]),
                ]),
            trailing: Icon(Icons.chevron_right,
                color: ThemeConfig.getTextSecondaryColor(context)),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — CAMPAIGNS  (creatives nested inside, styled like DirectAdWidget)
// ═══════════════════════════════════════════════════════════════════════════

class _CampaignsTab extends ConsumerStatefulWidget {
  final AdminUserDetails details;
  const _CampaignsTab({required this.details});

  @override
  ConsumerState<_CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends ConsumerState<_CampaignsTab> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final campaigns = widget.details.campaigns;
    if (campaigns.isEmpty) {
      return const _EmptyState(Icons.campaign_outlined, 'No campaigns found');
    }
    return ListView.builder(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
      itemCount: campaigns.length,
      itemBuilder: (_, i) => _buildCampaignCard(context, campaigns[i]),
    );
  }

  // ── Campaign header card ────────────────────────────────────────────────────
  Widget _buildCampaignCard(BuildContext context, Map<String, dynamic> campaign) {
    final cid = campaign['id'] as String? ?? '';
    final isExpanded = _expanded.contains(cid);
    final isDeleted = campaign['deleted_at'] != null;
    final status = campaign['status'] as String? ?? 'unknown';
    final statusColor = isDeleted
        ? ThemeConfig.errorColor
        : status == 'active' || status == 'running'
            ? ThemeConfig.successColor
            : status == 'paused'
                ? ThemeConfig.warningColor
                : Colors.grey;

    final budget = (campaign['total_budget'] as num?)?.toDouble() ?? 0;
    final spent = (campaign['spent_amount'] as num?)?.toDouble() ?? 0;
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final impressions = (campaign['impressions_count'] as num?)?.toInt() ?? 0;
    final clicks = (campaign['clicks_count'] as num?)?.toInt() ?? 0;
    final ctr = impressions > 0
        ? (clicks / impressions * 100).toStringAsFixed(1)
        : '0.0';

    final creatives = widget.details.creatives
        .where((cr) => cr['campaign_id'] == cid)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDeleted
          ? ThemeConfig.errorColor.withOpacity(0.06)
          : ThemeConfig.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Tappable campaign header ──────────────────────────────────────────
        InkWell(
          onTap: () => setState(() {
            isExpanded ? _expanded.remove(cid) : _expanded.add(cid);
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.campaign_rounded, color: statusColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                Expanded(
                  child: Text(
                    campaign['campaign_name'] as String? ?? 'Unnamed',
                    style: TextStyle(
                      color: ThemeConfig.getTextPrimaryColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(isDeleted ? 'Deleted' : status, statusColor),
                const SizedBox(width: 6),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: ThemeConfig.getTextSecondaryColor(context),
                ),
              ]),
              const SizedBox(height: 10),
              // Budget progress bar
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      minHeight: 6,
                      backgroundColor: ThemeConfig
                          .getTextSecondaryColor(context)
                          .withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          pct > 0.9 ? ThemeConfig.errorColor : statusColor),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                      color: ThemeConfig.getTextSecondaryColor(context)),
                ),
              ]),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Wrap(spacing: 10, runSpacing: 4, children: [
                _Chip('Budget TZS ${_fmtNum(budget)}', context),
                _Chip('Spent TZS ${_fmtNum(spent)}', context),
                _Chip('${_fmtNum(impressions.toDouble())} imp', context),
                _Chip('$clicks clicks', context),
                _Chip('CTR $ctr%', context),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                if ((campaign['campaign_objective'] as String?) != null) ...[
                  Text(
                    campaign['campaign_objective'] as String,
                    style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                        color: ThemeConfig.getTextSecondaryColor(context)),
                  ),
                  Text('  ·  ',
                      style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                          color: ThemeConfig.getTextSecondaryColor(context))),
                ],
                Text(
                  'Created ${_fmtDate(_parseDate(campaign['created_at']))}',
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                      color: ThemeConfig.getTextSecondaryColor(context)),
                ),
                const Spacer(),
                Text(
                  '${creatives.length} creative${creatives.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                      fontWeight: FontWeight.w500,
                      color: statusColor),
                ),
              ]),
            ]),
          ),
        ),

        // ── Creatives list (expanded) — DirectAdWidget style ──────────────────
        if (isExpanded) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: ThemeConfig.getTextSecondaryColor(context).withOpacity(0.12),
          ),
          if (creatives.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No creatives for this campaign',
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                      color: ThemeConfig.getTextSecondaryColor(context)),
                ),
              ),
            )
          else
            ...creatives.map((cr) => _AdCreativeCard(
                  ad: cr,
                  onApprove: (id) => _approveAd(id),
                  onReject: (id) => _rejectAd(id),
                  onDelete: (ad) => _deleteCreative(ad),
                  onRestore: (ad) => _restoreCreative(ad),
                )),
        ],
      ]),
    );
  }

  // ── Actions (call adminServiceProvider) ──────────────────────────────────────

  Future<void> _approveAd(String id) async {
    final ok = await ref.read(adminServiceProvider).approveAd(id);
    if (!mounted) return;
    _snack(ok ? 'Ad approved! Campaign is now running.' : 'Failed to approve', ok);
    setState(() {});
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor,
                foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.isNotEmpty) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    final ok = await ref.read(adminServiceProvider).rejectAd(id, reason);
    if (!mounted) return;
    _snack(ok ? 'Ad rejected' : 'Failed to reject', ok);
    setState(() {});
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
              style: TextStyle(
                  color: ThemeConfig.getTextSecondaryColor(context))),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
          TextField(
            controller: ctrl,
            style: TextStyle(color: ThemeConfig.getTextPrimaryColor(context)),
            decoration: const InputDecoration(
                hintText: 'Reason (optional)',
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
                backgroundColor: ThemeConfig.errorColor,
                foregroundColor: Colors.white),
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
          (result['success'] == true
              ? 'Ad deleted. Advertiser notified.'
              : 'Failed: ${result['error']}'),
      result['success'] == true,
    );
    setState(() {});
  }

  Future<void> _restoreCreative(Map<String, dynamic> ad) async {
    final result =
        await ref.read(adminServiceProvider).adminRestoreCreative(ad['id'] as String);
    if (!mounted) return;
    _snack(
      result['message'] as String? ??
          (result['success'] == true
              ? 'Ad restored. Pending review.'
              : 'Failed: ${result['error']}'),
      result['success'] == true,
    );
    setState(() {});
  }

  void _snack(String msg, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? ThemeConfig.successColor : ThemeConfig.errorColor,
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AD CREATIVE CARD — mirrors DirectAdWidget exactly:
//   • CachedNetworkImage 220 px  •  VideoPlayer auto-play  •  url_launcher tap
// ═══════════════════════════════════════════════════════════════════════════

class _AdCreativeCard extends StatefulWidget {
  final Map<String, dynamic> ad;
  final void Function(String id) onApprove;
  final void Function(String id) onReject;
  final void Function(Map<String, dynamic> ad) onDelete;
  final void Function(Map<String, dynamic> ad) onRestore;

  const _AdCreativeCard({
    required this.ad,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
    required this.onRestore,
  });

  @override
  State<_AdCreativeCard> createState() => _AdCreativeCardState();
}

class _AdCreativeCardState extends State<_AdCreativeCard> {

  // ── Extract company name from nested join or flat field ─────────────────────
  String _companyName() {
    final ad = widget.ad;
    // Try flat field first (admin_all_creatives view)
    final flat = ad['advertiser_company'] as String? ?? ad['company_name'] as String?;
    if (flat != null && flat.isNotEmpty) return flat;
    // Try nested join: ad_campaigns -> advertisers -> company_name
    try {
      final campaign = ad['ad_campaigns'] as Map<String, dynamic>?;
      final advertiser = campaign?['advertisers'] as Map<String, dynamic>?;
      return advertiser?['company_name'] as String? ?? '—';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _openUrl() async {
    final url = widget.ad['landing_url'] as String?;
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('URL launch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final headline = ad['headline'] as String? ?? 'Ad';
    final company = _companyName();
    final imageUrl = ad['image_url'] as String?;
    final description = ad['description'] as String?;
    final callToAction = ad['call_to_action'] as String?;
    final landingUrl = ad['landing_url'] as String?;
    final logoUrl = ad['logo_url'] as String?;
    final isDeleted = ad['deleted_at'] != null;
    final isApproved = ad['is_approved'] as bool? ?? false;
    final status = ad['status'] as String? ?? '—';
    final hasLanding = landingUrl != null && landingUrl.isNotEmpty;

    Color statusColor = ThemeConfig.warningColor;
    if (isDeleted) {
      statusColor = ThemeConfig.errorColor;
    } else if (isApproved) {
      statusColor = ThemeConfig.successColor;
    } else if (status == 'rejected') {
      statusColor = ThemeConfig.errorColor;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDeleted ? ThemeConfig.errorColor.withOpacity(0.04) : null,
        border: Border(
          bottom: BorderSide(
            color: ThemeConfig.getTextSecondaryColor(context).withOpacity(0.12),
          ),
        ),
      ),
      child: InkWell(
        onTap: hasLanding ? _openUrl : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Media ─────────────────────────────────────────────────────────
          _buildMedia(imageUrl, context),

          // ── Sponsored label + ⋮ menu ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 0),
            child: Row(children: [
              Icon(Icons.info_outline,
                  size: 12,
                  color: ThemeConfig.getTextSecondaryColor(context)),
              const SizedBox(width: 4),
              Text('Sponsored',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                    fontWeight: FontWeight.w600,
                    color: ThemeConfig.getTextSecondaryColor(context),
                    letterSpacing: 0.5,
                  )),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    size: 20,
                    color: ThemeConfig.getTextSecondaryColor(context)),
                color: ThemeConfig.getCardColor(context),
                onSelected: (v) {
                  if (v == 'delete') widget.onDelete(ad);
                  if (v == 'restore') widget.onRestore(ad);
                  if (v == 'approve') widget.onApprove(ad['id'] as String);
                  if (v == 'reject') widget.onReject(ad['id'] as String);
                },
                itemBuilder: (_) => [
                  if (!isDeleted) ...[
                    if (!isApproved && status != 'rejected')
                      PopupMenuItem(
                        value: 'approve',
                        child: _popupItem(Icons.check_circle_rounded, 'Approve',
                            ThemeConfig.successColor, context),
                      ),
                    if (!isApproved)
                      PopupMenuItem(
                        value: 'reject',
                        child: _popupItem(Icons.cancel_rounded, 'Reject',
                            ThemeConfig.warningColor, context),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: _popupItem(Icons.delete_outline_rounded, 'Delete Ad',
                          ThemeConfig.errorColor, context),
                    ),
                  ] else
                    PopupMenuItem(
                      value: 'restore',
                      child: _popupItem(Icons.restore_rounded, 'Restore Ad',
                          ThemeConfig.successColor, context),
                    ),
                ],
              ),
            ]),
          ),

          // ── Ad content ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Headline + logo
              Row(children: [
                if (logoUrl != null && logoUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: logoUrl,
                      width: 26,
                      height: 26,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                ],
                Expanded(
                  child: Text(
                    headline,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getTextPrimaryColor(context),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),

              // Company name
              const SizedBox(height: 3),
              Text(company,
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                      color: ThemeConfig.getTextSecondaryColor(context))),

              // Description
              if (description != null && description.isNotEmpty) ...[
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                    color: ThemeConfig.getTextSecondaryColor(context),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Status badge
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDeleted ? 'DELETED' : status.toUpperCase(),
                    style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                        fontWeight: FontWeight.bold,
                        color: statusColor),
                  ),
                ),
              ]),

              // CTA button — only when landing URL is present
              if (hasLanding) ...[
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(
                      (callToAction != null && callToAction.isNotEmpty)
                          ? callToAction
                          : 'Learn More',
                      style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              // Deletion reason
              if (isDeleted && ad['deletion_reason'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Reason: ${ad['deletion_reason']}',
                    style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                        fontStyle: FontStyle.italic,
                        color: ThemeConfig.errorColor.withOpacity(0.8)),
                  ),
                ),

              const SizedBox(height: 14),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Media widget ─────────────────────────────────────────────────────────────
  Widget _buildMedia(String? imageUrl, BuildContext context) {
    final url = imageUrl ?? '';
    if (url.isEmpty) {
      return Container(
        height: 220,
        color: ThemeConfig.getTextSecondaryColor(context).withOpacity(0.08),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_not_supported_outlined,
              size: 48,
              color: ThemeConfig.getTextSecondaryColor(context).withOpacity(0.4)),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text('No image',
              style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: ThemeConfig.getTextSecondaryColor(context))),
        ]),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: 220,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: 220,
        color: ThemeConfig.getTextSecondaryColor(context).withOpacity(0.08),
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ThemeConfig.getPrimaryColor(context)),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 220,
        color: ThemeConfig.getTextSecondaryColor(context).withOpacity(0.08),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_not_supported_outlined,
              size: 48,
              color: ThemeConfig.getTextSecondaryColor(context).withOpacity(0.4)),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text('Ad media unavailable',
              style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: ThemeConfig.getTextSecondaryColor(context),
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _popupItem(IconData icon, String label, Color color, BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
      Text(label, style: TextStyle(color: color)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 15),
          fontWeight: FontWeight.bold,
          color: ThemeConfig.getTextPrimaryColor(context)));
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                fontWeight: FontWeight.bold,
                color: color)),
      );
}

class _MiniStatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _MiniStatCard(this.value, this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        decoration: BoxDecoration(
          color: ThemeConfig.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: ResponsiveHelper.getResponsiveIconSize(context)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                      fontWeight: FontWeight.bold,
                      color:
                          ThemeConfig.getTextPrimaryColor(context))),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                      color:
                          ThemeConfig.getTextSecondaryColor(context))),
            ]),
      );
}

class _PropIconBox extends StatelessWidget {
  final Color color;
  const _PropIconBox(this.color);
  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.home_rounded, color: color, size: ResponsiveHelper.getResponsiveIconSize(context)),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState(this.icon, this.message);
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 56,
                  color: ThemeConfig.getTextSecondaryColor(context)
                      .withOpacity(0.4)),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              Text(message,
                  style: TextStyle(
                      color:
                          ThemeConfig.getTextSecondaryColor(context))),
            ]),
      );
}

// ── Functional widget helpers ─────────────────────────────────────────────

Widget _InfoRow(
  BuildContext context,
  IconData icon,
  String label,
  String value, {
  bool copyable = false,
  Color? valueColor,
}) {
  final sec = ThemeConfig.getTextSecondaryColor(context);
  final pri = valueColor ?? ThemeConfig.getTextPrimaryColor(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(children: [
      Icon(icon, size: 18, color: sec),
      const SizedBox(width: 10),
      SizedBox(
          width: 110,
          child:
              Text(label, style: TextStyle(color: sec, fontSize: 13))),
      Expanded(
        child: GestureDetector(
          onTap: copyable
              ? () => Clipboard.setData(ClipboardData(text: value))
              : null,
          child: Text(value,
              style: TextStyle(
                  color: pri,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ),
      if (copyable) Icon(Icons.copy_rounded, size: 12, color: sec),
    ]),
  );
}

Widget _FinanceCard(
        BuildContext context, String label, String value, Color color) =>
    Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color:
                        ThemeConfig.getTextSecondaryColor(context))),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 15)),
          ]),
    );

Widget _SubTile(BuildContext context, Map<String, dynamic> s) {
  final status = s['status'] as String? ?? '';
  final statusColor = status == 'active'
      ? ThemeConfig.successColor
      : status == 'cancelled'
          ? ThemeConfig.errorColor
          : ThemeConfig.warningColor;
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: ThemeConfig.getCardColor(context),
    child: ListTile(
      dense: true,
      leading: Icon(Icons.card_membership_rounded,
          color: statusColor, size: ResponsiveHelper.getResponsiveIconSize(context)),
      title: Text(
        s['tier'] as String? ?? '—',
        style: TextStyle(
            color: ThemeConfig.getTextPrimaryColor(context),
            fontWeight: FontWeight.w600,
            fontSize: 14),
      ),
      subtitle: Text(
        'USD ${'—'}  ·  '
        'From ${_fmtDate(_parseDate(s['started_at']))}',
        style: TextStyle(
            color: ThemeConfig.getTextSecondaryColor(context),
            fontSize: 12),
      ),
      trailing: _StatusBadge(status, statusColor),
    ),
  );
}

Widget _Chip(String text, BuildContext context) => Text(text,
    style: TextStyle(
        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
        color: ThemeConfig.getTextSecondaryColor(context)));

// ── Utilities ─────────────────────────────────────────────────────────────

String _initials(String name, String email) {
  if (name != '—' && name.isNotEmpty) return name[0].toUpperCase();
  if (email.isNotEmpty) return email[0].toUpperCase();
  return '?';
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d, yyyy').format(d);
}

String _fmtNum(double n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}