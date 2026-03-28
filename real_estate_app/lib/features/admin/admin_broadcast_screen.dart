// lib/features/admin/admin_broadcast_screen.dart
// Send a notification to all users at once.
// Uses admin_send_notification RPC per user (batched).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/theme_config.dart';
import 'admin_dashboard_screen.dart' show adminServiceProvider;

class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _titleCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  bool _sending = false;
  int  _sent    = 0;
  int  _total   = 0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Broadcast'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will send a notification to ALL users.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeConfig.infoColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ThemeConfig.infoColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleCtrl.text.trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _messageCtrl.text.trim(),
                    style: const TextStyle(fontSize: 13),
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
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(ctx),
                foregroundColor: Colors.white),
            child: const Text('Send to All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _sending = true;
      _sent    = 0;
      _total   = 0;
    });

    try {
      // Fetch all user IDs
      final users = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .limit(10000) as List<dynamic>;

      setState(() => _total = users.length);

      final title   = _titleCtrl.text.trim();
      final message = _messageCtrl.text.trim();
      final svc     = ref.read(adminServiceProvider);

      // Send in batches of 20 to avoid timeouts
      for (int i = 0; i < users.length; i++) {
        final userId = users[i]['id'] as String;
        await svc.sendNotificationToUser(
          userId: userId,
          title: title,
          message: message,
          type: 'broadcast',
        );
        if (mounted) setState(() => _sent = i + 1);
      }

      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Broadcast sent to $_sent users.'),
        backgroundColor: ThemeConfig.successColor,
        behavior: SnackBarBehavior.floating,
      ));

      // Clear form
      _titleCtrl.clear();
      _messageCtrl.clear();
      setState(() { _sent = 0; _total = 0; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: ThemeConfig.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = ThemeConfig.getPrimaryColor(context);
    const radius  = 12.0;

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(context),
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.campaign_rounded, size: 22),
          SizedBox(width: 8),
          Text('Broadcast Notification'),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ThemeConfig.infoColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: ThemeConfig.infoColor.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: ThemeConfig.infoColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This message will be sent as a push notification to ALL active users. '
                        'Use for announcements, maintenance notices, or new features.',
                        style: TextStyle(
                          fontSize: 13,
                          color: ThemeConfig.getTextSecondaryColor(context),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Notification Title',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ThemeConfig.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. App Update Available',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius / 2)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 20),

              // Message
              Text(
                'Message',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ThemeConfig.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'e.g. We have added new search filters — update the app to try them!',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(radius / 2)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Message is required'
                    : null,
              ),
              const SizedBox(height: 32),

              // Progress indicator (while sending)
              if (_sending && _total > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sending $_sent / $_total...',
                      style: TextStyle(
                          color: ThemeConfig.getTextSecondaryColor(context),
                          fontSize: 13),
                    ),
                    Text(
                      '${(_total > 0 ? (_sent / _total * 100) : 0).toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _total > 0 ? _sent / _total : null,
                    minHeight: 6,
                    backgroundColor: primary.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Send button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: _sending
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _sending ? 'Sending…' : 'Send to All Users',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
