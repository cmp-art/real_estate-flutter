// lib/features/admin/admin_reports_screen.dart
// Admin screen to view and act on user-submitted property reports.
// Actions: dismiss report, remove listing, warn user.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/theme_config.dart';
import 'admin_dashboard_screen.dart' show adminServiceProvider;

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String _filter = 'pending'; // pending | resolved | all

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch reports (simple query — no join, max compatibility)
      final rawReports = await Supabase.instance.client
          .from('property_reports')
          .select('id, reason, created_at, status, property_id, reported_by')
          .order('created_at', ascending: false)
          .limit(200) as List<dynamic>;

      final reports = rawReports.cast<Map<String, dynamic>>();

      // 2. Collect unique property IDs and reporter IDs
      final propertyIds = reports
          .map((r) => r['property_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final reporterIds = reports
          .map((r) => r['reported_by'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      // 3. Batch-fetch properties and reporter profiles
      final Map<String, Map<String, dynamic>> propertiesMap = {};
      final Map<String, Map<String, dynamic>> reportersMap  = {};

      if (propertyIds.isNotEmpty) {
        final props = await Supabase.instance.client
            .from('properties')
            .select('id, title, owner_id, status')
            .inFilter('id', propertyIds) as List<dynamic>;
        for (final p in props.cast<Map<String, dynamic>>()) {
          propertiesMap[p['id'] as String] = p;
        }
      }

      if (reporterIds.isNotEmpty) {
        final profiles = await Supabase.instance.client
            .from('user_profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', reporterIds) as List<dynamic>;
        for (final p in profiles.cast<Map<String, dynamic>>()) {
          reportersMap[p['id'] as String] = p;
        }
      }

      // 4. Merge into enriched report list
      final enriched = reports.map((r) {
        final pid = r['property_id'] as String?;
        final rid = r['reported_by']  as String?;
        return {
          ...r,
          'properties':    pid != null ? propertiesMap[pid] : null,
          'user_profiles': rid != null ? reportersMap[rid]  : null,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _reports = enriched;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load reports: $e', isError: true);
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _reports;
    return _reports
        .where((r) => (r['status'] as String? ?? 'pending') == _filter)
        .toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _dismiss(Map<String, dynamic> report) async {
    try {
      await Supabase.instance.client
          .from('property_reports')
          .update({'status': 'resolved'})
          .eq('id', report['id'] as String);
      _snack('Report dismissed.', isError: false);
      _load();
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  Future<void> _removeListing(Map<String, dynamic> report) async {
    final property = report['properties'] as Map<String, dynamic>?;
    if (property == null) return;
    final propertyId = property['id'] as String? ?? '';
    final propertyTitle = property['title'] as String? ?? 'this listing';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Listing'),
        content: Text(
          'Remove "$propertyTitle" and mark the report as resolved?\n\n'
          'The owner will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.errorColor,
                foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final result = await ref
          .read(adminServiceProvider)
          .adminDeleteProperty(propertyId, reason: 'Removed following user report.');
      if (result['success'] == true) {
        await Supabase.instance.client
            .from('property_reports')
            .update({'status': 'resolved'})
            .eq('id', report['id'] as String);
        _snack('Listing removed and report resolved.', isError: false);
        _load();
      } else {
        _snack('Failed: ${result['error']}', isError: true);
      }
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  Future<void> _warnUser(Map<String, dynamic> report) async {
    final reporterId = report['reported_by'] as String?;
    final property   = report['properties'] as Map<String, dynamic>?;
    final ownerId    = property?['owner_id'] as String?;

    if (ownerId == null) {
      _snack('Cannot identify the listing owner.', isError: true);
      return;
    }

    final msgCtrl = TextEditingController(
      text: 'Your listing has received a report. '
            'Please review our community guidelines and update your listing accordingly.',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Warning to Owner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Message to send:'),
            const SizedBox(height: 8),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(adminServiceProvider).sendNotificationToUser(
        userId: ownerId,
        title: 'Listing Warning',
        message: msgCtrl.text.trim(),
      );
      await Supabase.instance.client
          .from('property_reports')
          .update({'status': 'resolved'})
          .eq('id', report['id'] as String);
      _snack('Warning sent and report resolved.', isError: false);
      _load();
    } catch (e) {
      _snack('Failed to send warning: $e', isError: true);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.flag_rounded, size: 22),
          const SizedBox(width: 8),
          const Text('Reports'),
          if (_reports.isNotEmpty) ...[
            const SizedBox(width: 8),
            _Badge(
              count: _reports
                  .where((r) => (r['status'] as String? ?? 'pending') == 'pending')
                  .length,
              color: ThemeConfig.errorColor,
            ),
          ],
        ]),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: ThemeConfig.getCardColor(context),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              _FilterChip(
                label: 'Pending',
                selected: _filter == 'pending',
                color: ThemeConfig.warningColor,
                onTap: () => setState(() => _filter = 'pending'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Resolved',
                selected: _filter == 'resolved',
                color: ThemeConfig.successColor,
                onTap: () => setState(() => _filter = 'resolved'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'All (${_reports.length})',
                selected: _filter == 'all',
                color: ThemeConfig.getPrimaryColor(context),
                onTap: () => setState(() => _filter = 'all'),
              ),
            ]),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 64,
                                color: ThemeConfig.successColor.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'pending'
                                  ? 'No pending reports'
                                  : 'No reports found',
                              style: TextStyle(
                                  color: ThemeConfig.getTextSecondaryColor(context)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: ThemeConfig.getPrimaryColor(context),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _ReportCard(
                            report: filtered[i],
                            onDismiss: () => _dismiss(filtered[i]),
                            onRemoveListing: () => _removeListing(filtered[i]),
                            onWarnUser: () => _warnUser(filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? ThemeConfig.errorColor : ThemeConfig.successColor,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Card
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onDismiss;
  final VoidCallback onRemoveListing;
  final VoidCallback onWarnUser;

  const _ReportCard({
    required this.report,
    required this.onDismiss,
    required this.onRemoveListing,
    required this.onWarnUser,
  });

  @override
  Widget build(BuildContext context) {
    final property      = report['properties'] as Map<String, dynamic>?;
    final reporter      = report['user_profiles'] as Map<String, dynamic>?;
    final title         = property?['title'] as String? ?? 'Unknown listing';
    final reporterName  = reporter?['full_name'] as String? ?? 'Anonymous';
    final reason        = report['reason'] as String? ?? '—';
    final status        = report['status'] as String? ?? 'pending';
    final createdAt     = report['created_at'] as String?;
    final isPending     = status == 'pending';

    final date = createdAt != null
        ? DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(createdAt).toLocal())
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isPending
          ? ThemeConfig.warningColor.withOpacity(0.04)
          : ThemeConfig.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPending
              ? ThemeConfig.warningColor.withOpacity(0.3)
              : ThemeConfig.getColor(context,
                  lightColor: ThemeConfig.lightBorder,
                  darkColor: ThemeConfig.darkBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: ThemeConfig.getTextPrimaryColor(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Reported by $reporterName',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeConfig.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPending
                        ? ThemeConfig.warningColor.withOpacity(0.12)
                        : ThemeConfig.successColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPending
                          ? ThemeConfig.warningColor.withOpacity(0.4)
                          : ThemeConfig.successColor.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPending
                          ? ThemeConfig.warningColor
                          : ThemeConfig.successColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Reason chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ThemeConfig.errorColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reason: $reason',
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeConfig.errorColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 6),
            Text(
              date,
              style: TextStyle(
                fontSize: 11,
                color: ThemeConfig.getTextSecondaryColor(context),
              ),
            ),

            // Action buttons (only for pending)
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(children: [
                // Dismiss
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ThemeConfig.successColor,
                      side: BorderSide(
                          color: ThemeConfig.successColor.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: onDismiss,
                  ),
                ),
                const SizedBox(width: 8),
                // Warn
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.warning_amber_rounded, size: 15),
                    label: const Text('Warn', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ThemeConfig.warningColor,
                      side: BorderSide(
                          color: ThemeConfig.warningColor.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: onWarnUser,
                  ),
                ),
                const SizedBox(width: 8),
                // Remove
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 15),
                    label: const Text('Remove', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: onRemoveListing,
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade400,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : ThemeConfig.getTextSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}
