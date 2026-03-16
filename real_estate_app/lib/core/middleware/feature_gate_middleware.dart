// lib/core/middleware/feature_gate_middleware.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/settings/presentation/providers/app_providers.dart';
import '../../features/subscriptions/data/models/subscription_model.dart';
import '../../features/subscriptions/presentation/screens/subscription_screen.dart' ;
import '../algorithm/access_control_algorithm.dart';
//import '../../features/subscriptions/presentation/screens/subscription_screen.dart';

/// Middleware to gate features based on subscription tier
class FeatureGateMiddleware {
  final AccessControlAlgorithm _accessControl;

  FeatureGateMiddleware(this._accessControl);

  /// Check if user can access a feature and handle accordingly
  Future<bool> checkFeatureAccess({
    required BuildContext context,
    required String userId,
    required String featureName,
    Map<String, dynamic>? additionalContext,
    bool showUpgradePrompt = true,
  }) async {
    final result = await _accessControl.canAccessFeature(
      userId: userId,
      featureName: featureName,
      additionalContext: additionalContext,
    );

    if (result.canAccess) {
      return true;
    }

    if (showUpgradePrompt && result.requiresUpgrade) {
      _showUpgradeDialog(
        context: context,
        reason: result.reason ?? 'This feature requires an upgrade',
        suggestedTier: result.suggestedTier,
        currentUsage: result.currentUsage,
        maxUsage: result.maxUsage,
      );
    }

    return false;
  }

  /// Show upgrade dialog
  void _showUpgradeDialog({
    required BuildContext context,
    required String reason,
    required SubscriptionTier? suggestedTier,
    int? currentUsage,
    int? maxUsage,
  }) {
    showDialog(
      context: context,
      builder: (context) => UpgradeDialog(
        reason: reason,
        suggestedTier: suggestedTier,
        currentUsage: currentUsage,
        maxUsage: maxUsage,
      ),
    );
  }
}

/// Upgrade dialog widget
class UpgradeDialog extends StatelessWidget {
  final String reason;
  final SubscriptionTier? suggestedTier;
  final int? currentUsage;
  final int? maxUsage;

  const UpgradeDialog({
    super.key,
    required this.reason,
    this.suggestedTier,
    this.currentUsage,
    this.maxUsage,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upgrade Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reason),
          if (currentUsage != null && maxUsage != null) ...[
            const SizedBox(height: 16),
            Text(
              'Current usage: $currentUsage/$maxUsage',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (suggestedTier != null) ...[
            const SizedBox(height: 16),
            Text(
              'Upgrade to ${suggestedTier!.displayName} to continue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SubscriptionScreen(),
              ),
            );
          },
          child: const Text('Upgrade Now'),
        ),
      ],
    );
  }
}

/// Widget wrapper that checks feature access
class FeatureGate extends ConsumerWidget {
  final String featureName;
  final Widget child;
  final Widget? fallback;
  final Map<String, dynamic>? additionalContext;

  const FeatureGate({
    super.key,
    required this.featureName,
    required this.child,
    this.fallback,
    this.additionalContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current user and subscription state from providers
    final user = ref.watch(currentUserProvider);
    final subscription = ref.watch(userSubscriptionProvider);

    if (user == null) {
      return fallback ?? const SizedBox.shrink();
    }

    return FutureBuilder<FeatureAccessResult>(
      future: ref.read(accessControlProvider).canAccessFeature(
            userId: user.id,
            featureName: featureName,
            additionalContext: additionalContext,
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final result = snapshot.data!;

        if (result.canAccess) {
          return child;
        }

        return fallback ??
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    result.reason ?? 'Feature not available',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (result.requiresUpgrade) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Upgrade to ${result.suggestedTier?.displayName ?? "Premium"}',
                      ),
                    ),
                  ],
                ],
              ),
            );
      },
    );
  }
}

/// Quota indicator widget
class QuotaIndicator extends ConsumerWidget {
  final String featureName;
  final bool showDetails;

  const QuotaIndicator({
    super.key,
    required this.featureName,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<FeatureAccessResult>(
      future: ref.read(accessControlProvider).canAccessFeature(
            userId: user.id,
            featureName: featureName,
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final result = snapshot.data!;

        if (result.maxUsage == null || result.maxUsage == -1) {
          // Unlimited quota
          return const SizedBox.shrink();
        }

        final percentage = result.usagePercentage;
        final isNearLimit = result.isNearLimit;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isNearLimit ? Colors.orange.shade100 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNearLimit ? Icons.warning : Icons.info_outline,
                size: 16,
                color: isNearLimit ? Colors.orange : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                '${result.currentUsage}/${result.maxUsage}',
                style: TextStyle(
                  color: isNearLimit ? Colors.orange.shade900 : Colors.blue.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showDetails) ...[
                const SizedBox(width: 8),
                Text(
                  '(${percentage.toStringAsFixed(0)}%)',
                  style: TextStyle(
                    color: isNearLimit ? Colors.orange.shade900 : Colors.blue.shade900,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// Providers (add these to your app_providers.dart)
final currentUserProvider = StateProvider<User?>((ref) => null);
final userSubscriptionProvider = StateProvider<UserSubscription?>((ref) => null);
final accessControlProvider = Provider<AccessControlAlgorithm>((ref) {
  final subscriptionService = ref.read(subscriptionServiceProvider);
  return AccessControlAlgorithm(subscriptionService);
});