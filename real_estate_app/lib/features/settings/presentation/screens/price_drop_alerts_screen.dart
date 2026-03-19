// lib/features/price_alerts/presentation/screens/price_drop_alerts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/price_drop_alert_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../core/utils/responsive_helper.dart';

final priceDropAlertServiceProvider = Provider<PriceDropAlertService>((ref) {
  // Get supabase from your provider
  final supabase = ref.watch(supabaseProvider);
  return PriceDropAlertService(supabase);
});

final userAlertsProvider = StreamProvider.autoDispose.family<List<PriceDropAlert>, String>(
  (ref, userId) {
    final service = ref.watch(priceDropAlertServiceProvider);
    return service.alertsStream(userId);
  },
);

final unreadNotificationsCountProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, userId) async {
    final service = ref.watch(priceDropAlertServiceProvider);
    return await service.getUnreadCount(userId);
  },
);

/// Screen for managing price drop alerts
class PriceDropAlertsScreen extends ConsumerStatefulWidget {
  const PriceDropAlertsScreen({super.key});

  @override
  ConsumerState<PriceDropAlertsScreen> createState() => _PriceDropAlertsScreenState();
}

class _PriceDropAlertsScreenState extends ConsumerState<PriceDropAlertsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _getCurrentUserId();
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Price Drop Alerts')),
        body: const Center(child: Text('Please sign in to view alerts')),
      );
    }

    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Drop Alerts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'My Alerts', icon: Icon(Icons.notifications_active)),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inbox),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                  const Text('Notifications'),
                  unreadCountAsync.when(
                    data: (count) => count > 0
                        ? Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AlertsTab(userId: userId),
          _NotificationsTab(userId: userId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAlertDialog(context, userId),
        icon: const Icon(Icons.add_alert),
        label: const Text('New Alert'),
      ),
    );
  }

  String? _getCurrentUserId() {
    return ref.read(authNotifierProvider).value?.id;
  }

  void _showCreateAlertDialog(BuildContext context, String userId) {
    // TODO: Implement property selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Price Drop Alert'),
        content: const Text('Select a property to track price drops'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to property selection screen
            },
            child: const Text('Select Property'),
          ),
        ],
      ),
    );
  }
}

/// Tab showing user's active alerts
class _AlertsTab extends ConsumerWidget {
  final String userId;

  const _AlertsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(userAlertsProvider(userId));

    return alertsAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return _AlertCard(alert: alert);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading alerts: $error'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
          Text(
            'No Price Drop Alerts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
          Text(
            'Create alerts to get notified when property prices drop',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 3)),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to property selection
            },
            icon: const Icon(Icons.add_alert),
            label: const Text('Create Your First Alert'),
          ),
        ],
      ),
    );
  }
}

/// Card displaying an individual alert
class _AlertCard extends ConsumerWidget {
  final PriceDropAlert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the current currency from provider
    final currentCurrency = ref.watch(currencyProvider);
    
    final priceDrop = alert.originalPrice - (alert.currentPrice ?? alert.originalPrice);
    final dropPercentage = alert.originalPrice > 0 
        ? (priceDrop / alert.originalPrice * 100) 
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Property ${alert.propertyId.substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context) / 2),
                      Text(
                        'Alert when price drops ${alert.alertThreshold.toStringAsFixed(0)}% or more',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: alert.isActive,
                  onChanged: (value) async {
                    final service = ref.read(priceDropAlertServiceProvider);
                    await service.toggleAlert(
                      alertId: alert.id,
                      isActive: value,
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildPriceInfo(
                    context,
                    'Original Price',
                    CurrencyUtils.formatPrice(alert.originalPrice, currentCurrency),
                    Colors.grey[700]!,
                  ),
                ),
                Expanded(
                  child: _buildPriceInfo(
                    context,
                    'Current Price',
                    CurrencyUtils.formatPrice(
                      alert.currentPrice ?? alert.originalPrice,
                      currentCurrency,
                    ),
                    priceDrop > 0 ? Colors.green : Colors.grey[700]!,
                  ),
                ),
              ],
            ),
            if (priceDrop > 0) ...[
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context) / 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_down, color: Colors.green, size: ResponsiveHelper.getResponsiveIconSize(context)),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                    Text(
                      'Dropped ${dropPercentage.toStringAsFixed(1)}% (${CurrencyUtils.formatPrice(priceDrop, currentCurrency)})',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditDialog(context, ref, alert),
                  icon: Icon(Icons.edit, size: ResponsiveHelper.getResponsiveIconSize(context)),
                  label: const Text('Edit'),
                ),
                SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                TextButton.icon(
                  onPressed: () => _deleteAlert(context, ref, alert),
                  icon: Icon(Icons.delete, size: ResponsiveHelper.getResponsiveIconSize(context)),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInfo(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context) / 2),
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 18),
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, PriceDropAlert alert) {
    final controller = TextEditingController(
      text: alert.alertThreshold.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Alert Threshold'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Threshold (%)',
            suffixText: '%',
            helperText: 'Alert when price drops by this percentage',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final threshold = double.tryParse(controller.text);
              if (threshold != null && threshold > 0) {
                final service = ref.read(priceDropAlertServiceProvider);
                await service.updateAlertThreshold(
                  alertId: alert.id,
                  newThreshold: threshold,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alert updated successfully')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteAlert(BuildContext context, WidgetRef ref, PriceDropAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alert'),
        content: const Text('Are you sure you want to delete this price drop alert?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(priceDropAlertServiceProvider);
              await service.deleteAlert(alert.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alert deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Tab showing price drop notifications
class _NotificationsTab extends ConsumerStatefulWidget {
  final String userId;

  const _NotificationsTab({required this.userId});

  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PriceDropNotification>>(
      future: _loadNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: ResponsiveHelper.getResponsiveIconSize(context), color: Colors.grey),
                SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
                const Text('No notifications yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _NotificationCard(notification: notification);
          },
        );
      },
    );
  }

  Future<List<PriceDropNotification>> _loadNotifications() async {
    final service = ref.read(priceDropAlertServiceProvider);
    return await service.getNotifications(userId: widget.userId);
  }
}

class _NotificationCard extends ConsumerWidget {
  final PriceDropNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead ? null : Colors.blue.withOpacity(0.05),
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            final service = ref.read(priceDropAlertServiceProvider);
            await service.markNotificationAsRead(notification.id);
          }
          // Navigate to property details
        },
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_down, color: Colors.green),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead 
                            ? FontWeight.normal 
                            : FontWeight.bold,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                      ),
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Text(notification.message),
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Text(
                _formatDate(notification.createdAt),
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

