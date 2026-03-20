import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/guest_prompt_dialog.dart';
import '../../../../presentation/providers/auth_provider.dart';

import '../providers/favorite_providers.dart';

class FavoriteButton extends ConsumerWidget {
  final String propertyId;
  final double size;

  const FavoriteButton({
    super.key,
    required this.propertyId,
    this.size = 24, 
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).value;
    
    if (user == null) {
      return IconButton(
        onPressed: () => GuestPromptDialog.show(
          context,
          title: 'Save to Favorites',
          message: 'Sign in or create a free account to save properties.',
        ),
        icon: Icon(Icons.favorite_border, size: size, color: Colors.grey),
      );
    }

    final isFavoriteAsync = ref.watch(isFavoriteProvider(propertyId));

    return isFavoriteAsync.when(
      data: (isFavorite) {
        return IconButton(
          onPressed: () async {
            final success = await ref.read(favoriteNotifierProvider.notifier).toggleFavorite(
                  userId: user.id,
                  propertyId: propertyId,
                  currentStatus: isFavorite,
                );

            if (success) {
              ref.invalidate(isFavoriteProvider(propertyId));
              ref.invalidate(favoritePropertiesProvider);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFavorite ? 'Removed from favorites' : 'Added to favorites',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            }
          },
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : null,
            size: size,
          ),
        );
      },
      loading: () => SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}