// lib/features/admin/admin_error_logs_screen.dart
// Admin screen showing application error logs stored in app_errors table.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/theme_config.dart';

class AdminErrorLogsScreen extends StatefulWidget {
  const AdminErrorLogsScreen({super.key});

  @override
  State<AdminErrorLogsScreen> createState() => _AdminErrorLogsScreenState();
}

class _AdminErrorLogsScreenState extends State<AdminErrorLogsScreen> {
  List<Map<String, dynamic>> _errors = [];
  bool _loading = true;
  String _severity = 'all'; // all | critical | error | warning

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Filter BEFORE order/limit — required by Supabase query builder
      final base = Supabase.instance.client
          .from('app_errors')
          .select('id, error_type, error_message, screen_name, severity, app_version, device_info, created_at, user_id');

      final filtered = _severity != 'all'
          ? base.eq('severity', _severity)
          : base;

      final data = await filtered
          .order('created_at', ascending: false)
          .limit(300) as List<dynamic>;
      if (mounted) {
        setState(() {
          _errors = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load logs: $e'),
              backgroundColor: ThemeConfig.errorColor));
      }
    }
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return ThemeConfig.errorColor;
      case 'error':    return ThemeConfig.errorColor.withOpacity(0.75);
      case 'warning':  return ThemeConfig.warningColor;
      default:         return ThemeConfig.infoColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.bug_report_rounded, size: 22),
          SizedBox(width: 8),
          Text('Error Logs'),
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
          // Severity filter
          Container(
            color: ThemeConfig.getCardColor(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _chip('all', 'All (${_errors.length})'),
              const SizedBox(width: 8),
              _chip('critical', 'Critical'),
              const SizedBox(width: 8),
              _chip('error', 'Error'),
              const SizedBox(width: 8),
              _chip('warning', 'Warning'),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errors.isEmpty
                    ? Center(
                        child: Text('No errors found',
                            style: TextStyle(
                                color: ThemeConfig.getTextSecondaryColor(context))))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: ThemeConfig.getPrimaryColor(context),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _errors.length,
                          itemBuilder: (_, i) {
                            final e = _errors[i];
                            final sev     = e['severity'] as String? ?? 'error';
                            final type    = e['error_type'] as String? ?? '—';
                            final message = e['error_message'] as String? ?? '—';
                            final screen  = e['screen_name'] as String?;
                            final version = e['app_version'] as String?;
                            final dateStr = e['created_at'] as String?;
                            final date = dateStr != null
                                ? DateFormat('MMM d  HH:mm').format(
                                    DateTime.parse(dateStr).toLocal())
                                : '—';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: ThemeConfig.getCardColor(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                    color: _severityColor(sev).withOpacity(0.3)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onLongPress: () {
                                  // Copy error to clipboard on long press
                                  Clipboard.setData(ClipboardData(
                                      text: '[$sev] $type\n$message'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Copied to clipboard'),
                                        duration: Duration(seconds: 1)),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top row
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _severityColor(sev).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            sev.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _severityColor(sev),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            type,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: ThemeConfig.getTextPrimaryColor(
                                                  context),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          date,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ThemeConfig.getTextSecondaryColor(
                                                context),
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 6),
                                      // Message
                                      Text(
                                        message,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: ThemeConfig.getTextSecondaryColor(
                                              context),
                                          height: 1.4,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      // Meta row
                                      if (screen != null || version != null) ...[
                                        const SizedBox(height: 6),
                                        Row(children: [
                                          if (screen != null) ...[
                                            Icon(Icons.phone_android_rounded,
                                                size: 11,
                                                color: ThemeConfig
                                                    .getTextSecondaryColor(context)),
                                            const SizedBox(width: 3),
                                            Text(screen,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: ThemeConfig
                                                        .getTextSecondaryColor(
                                                            context))),
                                          ],
                                          if (screen != null && version != null)
                                            const SizedBox(width: 12),
                                          if (version != null)
                                            Text('v$version',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: ThemeConfig
                                                        .getTextSecondaryColor(
                                                            context))),
                                        ]),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _severity == value;
    final color = ThemeConfig.getPrimaryColor(context);
    return GestureDetector(
      onTap: () {
        setState(() => _severity = value);
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.grey.shade400),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : ThemeConfig.getTextSecondaryColor(context),
            )),
      ),
    );
  }
}
