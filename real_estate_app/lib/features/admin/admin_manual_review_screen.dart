// features/admin/presentation/screens/admin_manual_review_screen.dart
// ADMIN MANUAL REVIEW — properties and ads that failed AI + rule validation
// Admin can Approve or Reject each item with a reason/note.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../properties/presentation/providers/ai_providers.dart';
import '../../../../core/utils/responsive_helper.dart';

class AdminManualReviewScreen extends ConsumerStatefulWidget {
  const AdminManualReviewScreen({super.key});

  @override
  ConsumerState<AdminManualReviewScreen> createState() =>
      _AdminManualReviewScreenState();
}

class _AdminManualReviewScreenState
    extends ConsumerState<AdminManualReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  List<Map<String, dynamic>> _propertyQueue = [];
  List<Map<String, dynamic>> _adQueue       = [];
  Map<String, int> _stats = {};
  Map<String, dynamic> _fullStats = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = (ref.read(aiValidationServiceProvider));
    final results = await Future.wait([
      svc.getPendingManualReviews(type: 'property'),
      svc.getPendingManualReviews(type: 'ad'),
      svc.getValidationStats(),
      svc.getFullStats(),
    ]);
    if (mounted) {
      setState(() {
      _propertyQueue = results[0] as List<Map<String, dynamic>>;
      _adQueue       = results[1] as List<Map<String, dynamic>>;
      _stats         = results[2] as Map<String, int>;
      _fullStats     = results[3] as Map<String, dynamic>;
      _loading       = false;
    });
    }
  }

  Future<void> _approve(String id, String type) async {
    final noteCtrl = TextEditingController();
    final note = await _showInputDialog(
      title: 'Approve — add a note (optional)',
      ctrl: noteCtrl,
      confirmLabel: 'Approve',
      confirmColor: Colors.green,
    );
    if (note == null) return;

    final svc     = (ref.read(aiValidationServiceProvider));
    final success = await svc.adminApproveManualItem(id, note: note);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✅ Item approved' : '❌ Failed to approve'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      if (success) _load();
    }
  }

  Future<void> _reject(String id, String type) async {
    final reasonCtrl = TextEditingController();
    final reason = await _showInputDialog(
      title: 'Reject — enter reason *',
      ctrl: reasonCtrl,
      confirmLabel: 'Reject',
      confirmColor: Colors.red,
      required: true,
    );
    if (reason == null || reason.isEmpty) return;

    final svc     = (ref.read(aiValidationServiceProvider));
    final success = await svc.adminRejectManualItem(id, reason: reason);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✅ Item rejected' : '❌ Failed to reject'),
        backgroundColor: success ? Colors.orange : Colors.red,
      ));
      if (success) _load();
    }
  }

  Future<String?> _showInputDialog({
    required String title,
    required TextEditingController ctrl,
    required String confirmLabel,
    required Color confirmColor,
    bool required = false,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter text...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () {
              if (required && ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: Text(confirmLabel,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Review Queue'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: 'Properties (${_propertyQueue.length})'),
            Tab(text: 'Ads (${_adQueue.length})'),
            const Tab(text: 'Stats'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _QueueList(
                  items: _propertyQueue,
                  type: 'property',
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _QueueList(
                  items: _adQueue,
                  type: 'ad',
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _StatsPanel(stats: _stats, fullStats: _fullStats),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Queue List
// ─────────────────────────────────────────────────────────────────────────────

class _QueueList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String type;
  final Future<void> Function(String id, String type) onApprove;
  final Future<void> Function(String id, String type) onReject;

  const _QueueList({
    required this.items,
    required this.type,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: Colors.green.shade300),
          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          Text('No pending ${type == 'property' ? 'properties' : 'ads'} to review',
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), color: Colors.grey)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        itemBuilder: (context, index) {
          final item = items[index];
          return _ReviewCard(
            item: item,
            type: type,
            onApprove: () => onApprove(item['id'] as String, type),
            onReject:  () => onReject(item['id'] as String, type),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review Card
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String type;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReviewCard({
    required this.item,
    required this.type,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    // Decode the JSON content_data stored in the queue
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(item['content_data'] as String? ?? '{}') as Map<String, dynamic>;
    } catch (_) {}

    final submittedAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'] as String)
        : null;
    final timeAgo = submittedAt != null
        ? _timeAgo(submittedAt)
        : 'Unknown time';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: type == 'property'
                    ? Colors.blue.shade50
                    : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: type == 'property'
                      ? Colors.blue.shade200
                      : Colors.purple.shade200,
                ),
              ),
              child: Text(
                type == 'property' ? '🏠 Property' : '📢 Ad',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: type == 'property'
                      ? Colors.blue.shade700
                      : Colors.purple.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            Text(timeAgo,
                style:
                    TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: Colors.grey)),
          ]),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),

          // Content fields
          if (type == 'property') ...[
            _field(context, 'Title',       data['title']),
            _field(context, 'Location',    data['location']),
            _field(context, 'Category',    data['category']),
            _field(context, 'Price',       data['price']?.toString()),
            _field(context, 'Description', data['description'], maxLines: 2),
          ] else ...[
            _field(context, 'Headline',    data['headline']),
            _field(context, 'Description', data['description'], maxLines: 2),
            _field(context, 'Company Type',data['company_type']),
            _field(context, 'CTA',         data['call_to_action']),
            _field(context, 'Landing URL', data['landing_url']),
          ],

          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          const Divider(),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),

          // Actions
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text('Reject', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: onReject,
              ),
            ),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text('Approve',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green),
                onPressed: onApprove,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _field(BuildContext context, String label, String? value, {int maxLines = 1}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 90,
          child: Text('$label:',
              style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: Colors.grey,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Panel
// ─────────────────────────────────────────────────────────────────────────────

class _StatsPanel extends StatefulWidget {
  final Map<String, int> stats;
  final Map<String, dynamic> fullStats;
  const _StatsPanel({required this.stats, required this.fullStats});

  @override
  State<_StatsPanel> createState() => _StatsPanelState();
}

class _StatsPanelState extends State<_StatsPanel> {
  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final full  = widget.fullStats;

    final total        = stats['total']        ?? 0;
    final aiApproved   = stats['ai_approved']  ?? 0;
    final aiRejected   = stats['ai_rejected']  ?? 0;
    final ruleApproved = stats['rules_approved'] ?? 0;
    final ruleRejected = stats['rules_rejected'] ?? 0;
    final pending      = stats['pending']      ?? 0;
    final failed       = (full['failed']       as num? ?? 0).toInt();
    final lostLogs     = (full['lost_logs']    as num? ?? 0).toInt();
    final lastHour     = (full['last_hour']    as num? ?? 0).toInt();
    final apiKeyCached = full['api_key_cached'] as bool? ?? false;
    final keyAgeMin    = (full['key_age_minutes'] as num?)?.toInt();

    final aiTotal       = aiApproved + aiRejected;
    final ruleTotal     = ruleApproved + ruleRejected;
    final aiApprovalRate = aiTotal > 0 ? aiApproved / aiTotal : 0.0;
    final ruleApprovalRate = ruleTotal > 0 ? ruleApproved / ruleTotal : 0.0;
    final overallApprovalRate = total > 0 ? (aiApproved + ruleApproved) / total : 0.0;

    // Health stats from monitor
    final health = full['health'] as Map<String, dynamic>? ?? {};
    final isHealthy   = health['healthy']    as bool? ?? true;
    final failCount   = (health['fail_count'] as num? ?? 0).toInt();
    final succCount   = (health['succ_count'] as num? ?? 0).toInt();
    final resetAt     = health['reset_at']   as String?;

    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Health Banner ─────────────────────────────────────────────────
        _healthBanner(context, isHealthy, apiKeyCached, failCount, keyAgeMin),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

        // ── Summary cards row ─────────────────────────────────────────────
        Text('Last 500 Validations',
            style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.bold)),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Row(children: [
          _miniCard(context, 'Total', total.toString(), Icons.analytics_rounded, Colors.blue),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          _miniCard(context, 'Last Hour', lastHour.toString(), Icons.access_time_rounded, Colors.teal),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          _miniCard(context, 'Approval Rate',
              '${(overallApprovalRate * 100).toStringAsFixed(0)}%',
              Icons.thumb_up_rounded, Colors.green),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          _miniCard(context, 'Failed', failed.toString(), Icons.error_rounded,
              failed > 0 ? Colors.red : Colors.grey),
        ]),
        const SizedBox(height: 20),

        // ── AI Layer ───────────────────────────────────────────────────────
        _sectionHeader(context, '🤖 Layer 2 — Claude AI (Haiku)', Colors.blue),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        _layerCard(context, approved: aiApproved,
          rejected: aiRejected,
          total: total,
          approvalRate: aiApprovalRate,
          color: Colors.blue,
          description: 'Primary validator. Checks text + vision for real estate compliance.',
          cost: '~\$0.000003 / call',
        ),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

        // ── Rule Layer ─────────────────────────────────────────────────────
        _sectionHeader(context, '📋 Layer 3 — Rule-based Fallback', Colors.teal),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        _layerCard(context, approved: ruleApproved,
          rejected: ruleRejected,
          total: total,
          approvalRate: ruleApprovalRate,
          color: Colors.teal,
          description: 'Keyword + heuristic scoring. Runs when AI is unavailable or unhealthy.',
          cost: 'Free — no API calls',
        ),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

        // ── Manual Queue ───────────────────────────────────────────────────
        _sectionHeader(context, '👨‍💼 Manual Queue', Colors.purple),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pending > 0
                ? Colors.purple.withOpacity(0.08)
                : Colors.grey.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: pending > 0
                    ? Colors.purple.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(pending > 0 ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                color: pending > 0 ? Colors.purple : Colors.green, size: ResponsiveHelper.getResponsiveIconSize(context)),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                pending > 0 ? '$pending items awaiting review' : 'Queue is clear',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pending > 0 ? Colors.purple : Colors.green),
              ),
              const SizedBox(height: 2),
              Text('Items that failed both AI and rule validation',
                  style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.grey.shade600)),
            ])),
          ]),
        ),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

        // ── Health monitor detail ──────────────────────────────────────────
        _sectionHeader(context, '🔬 AI Health Monitor', isHealthy ? Colors.green : Colors.red),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isHealthy
                ? Colors.green.withOpacity(0.07)
                : Colors.red.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHealthy
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.4),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(isHealthy ? Icons.health_and_safety_rounded : Icons.warning_amber_rounded,
                  color: isHealthy ? Colors.green : Colors.red, size: ResponsiveHelper.getResponsiveIconSize(context)),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
              Text(isHealthy ? 'AI is healthy' : 'AI is degraded — using rule fallback',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isHealthy ? Colors.green : Colors.red)),
            ]),
            const SizedBox(height: 10),
            _healthRow(context, 'API key cached', apiKeyCached ? 'Yes' : 'Missing ⚠️',
                apiKeyCached ? Colors.green : Colors.red),
            if (keyAgeMin != null)
              _healthRow(context, 'Key age', '${keyAgeMin}m (refreshes every 60m)', Colors.grey),
            _healthRow(context, 'Session successes', succCount.toString(), Colors.green),
            _healthRow(context, 'Session failures', failCount.toString(),
                failCount > 0 ? Colors.red : Colors.grey),
            if (resetAt != null)
              _healthRow(context, 'Health reset at', resetAt, Colors.grey),
            if (lostLogs > 0)
              _healthRow(context, 'Lost validation logs', '$lostLogs ⚠️', Colors.orange),
          ]),
        ),
        const SizedBox(height: 20),

        // ── How it works ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue),
              SizedBox(width: 6),
              Text('Validation Pipeline',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ]),
            const SizedBox(height: 10),
            _pipelineStep(context, '1', 'Pre-flight (Layer 1)', 'Size check, screenshot detection', Colors.grey),
            _pipelineStep(context, '2', 'Claude AI — Haiku (Layer 2)', 'Vision + text analysis, real estate gating', Colors.blue),
            _pipelineStep(context, '3', 'Rule-based (Layer 3)', 'Keyword scoring fallback — runs if AI down', Colors.teal),
            _pipelineStep(context, '4', 'Manual queue (Layer 4)', 'Last resort — both AI and rules failed', Colors.purple),
          ]),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 4)),
      ]),
    );
  }

  Widget _healthBanner(BuildContext context, bool healthy, bool apiKey, int fails, int? keyAge) {
    final color = healthy && apiKey ? Colors.green : Colors.red;
    final msg   = healthy && apiKey
        ? 'AI validation is fully operational'
        : !apiKey
            ? 'API key missing — rule-based fallback active'
            : 'AI degraded ($fails failures) — fallback active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(healthy && apiKey ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: color, size: ResponsiveHelper.getResponsiveIconSize(context)),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: TextStyle(fontWeight: FontWeight.bold, color: color))),
      ]),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, Color color) => Row(children: [
    Text(title, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14), fontWeight: FontWeight.bold, color: color)),
  ]);

  Widget _miniCard(BuildContext context, String label, String value, IconData icon, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: ResponsiveHelper.getResponsiveIconSize(context)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16), fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 9), color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ]),
      ));

  Widget _layerCard(BuildContext context, {
    required int approved,
    required int rejected,
    required int total,
    required double approvalRate,
    required Color color,
    required String description,
    required String cost,
  }) {
    final layerTotal = approved + rejected;
    final pct = total > 0 ? layerTotal / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Row(children: [
            _badge(context, '✅ $approved', Colors.green),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
            _badge(context, '❌ $rejected', Colors.red),
            SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
            _badge(context, '${(approvalRate * 100).toStringAsFixed(0)}% approval', color),
          ])),
          Text('${(pct * 100).toStringAsFixed(0)}% of traffic',
              style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: Colors.grey.shade600)),
        ]),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        // Progress bar: share of total validations
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
            minHeight: 6,
          ),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        Text(description, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(cost, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _badge(BuildContext context, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: color, fontWeight: FontWeight.w600)),
  );

  Widget _healthRow(BuildContext context, String label, String value, Color color) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(children: [
      SizedBox(width: 160,
          child: Text(label, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), color: Colors.grey))),
      Text(value, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), fontWeight: FontWeight.w600, color: color)),
    ]),
  );

  Widget _pipelineStep(BuildContext context, String num, String name, String desc, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
        child: Center(child: Text(num,
            style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), fontWeight: FontWeight.bold, color: color))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12), fontWeight: FontWeight.w600)),
        Text(desc, style: TextStyle(fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11), color: Colors.grey.shade600)),
      ])),
    ]),
  );
}

