import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../widgets/property_card.dart';
import '../providers/property_providers.dart';
import 'property_detail_screen.dart';

import 'property_create_screen.dart';

class MyPropertiesScreen extends ConsumerWidget {
  const MyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPropertiesAsync = ref.watch(myPropertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Properties'),
      ),
      body: myPropertiesAsync.when(
        data: (properties) {
          if (properties.isEmpty) {
            return EmptyState(
              icon: Icons.home_work_outlined,
              title: 'No Properties Yet',
              message: 'Start by adding your first property.',
              actionText: 'Add Property',
              onActionPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PropertyCreateScreen(),
                  ),
                );
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myPropertiesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: properties.length,
              itemBuilder: (context, index) {
                final property = properties[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PropertyCard(
                    property: property,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PropertyDetailScreen(propertyId: property.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading your properties...'),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PropertyCreateScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Property'),
      ),
    );
  }
}