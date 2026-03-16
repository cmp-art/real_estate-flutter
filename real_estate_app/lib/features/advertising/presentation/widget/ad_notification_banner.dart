// lib/features/advertising/presentation/widgets/ad_notification_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../core/services/direct_ad_service.dart';
import '../provider/ad_providers.dart'; // AdNotification type

class AdNotificationBanner extends ConsumerStatefulWidget {
  final String userId;
  const AdNotificationBanner({super.key, required this.userId});

  @override
  ConsumerState<AdNotificationBanner> createState() =>
      _AdNotificationBannerState();
}

class _AdNotificationBannerState extends ConsumerState<AdNotificationBanner> {
  // Fixed: was List<Map<String,dynamic>> — getAdNotifications() returns List<AdNotification>
  List<AdNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final adService = ref.read(directAdServiceProvider);
    final notifs = await adService.getAdNotifications(widget.userId);
    if (mounted) {
      setState(() {
        _notifications = notifs.where((n) => !n.isRead).toList();
        _loading = false;
      });
    }
  }

  Future<void> _markRead(String notifId) async {
    final adService = ref.read(directAdServiceProvider);
    await adService.markNotificationRead(notifId);
    if (mounted) {
      setState(() => _notifications.removeWhere((n) => n.id == notifId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _notifications.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _notifications
          .map((n) => _NotificationTile(
                notification: n,
                onDismiss: () => _markRead(n.id),
              ))
          .toList(),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AdNotification notification;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    IconData icon;

    switch (notification.type) {
      case 'ad_approved':
        bgColor     = const Color(0xFFECFDF5);
        borderColor = const Color(0xFF10B981);
        icon        = Icons.check_circle_rounded;
        break;
      case 'ad_rejected':
        bgColor     = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFEF4444);
        icon        = Icons.cancel_rounded;
        break;
      case 'payment_confirmed':
        bgColor     = const Color(0xFFEFF6FF);
        borderColor = const Color(0xFF3B82F6);
        icon        = Icons.payments_rounded;
        break;
      default:
        bgColor     = const Color(0xFFF9FAFB);
        borderColor = const Color(0xFF6B7280);
        icon        = Icons.notifications_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: borderColor,
                  ),
                ),
                if (notification.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded,
                size: 18, color: borderColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}