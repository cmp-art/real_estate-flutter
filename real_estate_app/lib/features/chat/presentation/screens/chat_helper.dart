// features/chat/presentation/screens/chat_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../presentation/providers/chat_providers.dart';
import '../../presentation/screens/chat_screen.dart';

class ChatHelper {
  /// Start a conversation with another user (property optional)
  static Future<void> startConversation({
    required BuildContext context,
    required WidgetRef ref,
    required String currentUserId,
    required String currentUserName,
    required String ownerId,
    required String ownerName,
    String? ownerAvatar,
    String? propertyId,
    String? propertyTitle,
    String? propertyImage,
  }) async {
    logger.d('ChatHelper.startConversation - User: $currentUserId, Owner: $ownerId, Property: $propertyId');

    // Validation
    if (currentUserId.isEmpty) {
      logger.e('Current user ID is empty');
      if (context.mounted) {
        SnackbarUtils.showError(context, 'User authentication error');
      }
      return;
    }

    if (ownerId.isEmpty) {
      logger.e('Owner ID is empty');
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Invalid user');
      }
      return;
    }

    if (currentUserId == ownerId) {
      logger.w('User trying to message themselves');
      if (context.mounted) {
        SnackbarUtils.showInfo(context, 'You cannot message yourself');
      }
      return;
    }

    if (!context.mounted) return;

    try {
      final conversation = await ref
          .read(chatNotifierProvider.notifier)
          .createConversation(
            userId: currentUserId,
            otherUserId: ownerId,
            propertyId: propertyId,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              logger.w('Conversation creation timeout');
              return null;
            },
          );

      if (!context.mounted) return;

      if (conversation != null) {
        logger.d('Conversation created/retrieved: ${conversation.id}');
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              otherUserId: ownerId,
              otherUserName: ownerName,
              otherUserAvatar: ownerAvatar,
              propertyId: propertyId,
              propertyTitle: propertyTitle,
              propertyImage: propertyImage,
            ),
          ),
        );
      } else {
        SnackbarUtils.showError(
          context, 
          'Failed to start conversation. Please try again.'
        );
      }
    } catch (e, stackTrace) {
      logger.e('Exception in startConversation', error: e, stackTrace: stackTrace);
      
      if (context.mounted) {
        SnackbarUtils.showError(
          context, 
          'Error: ${e.toString().replaceAll('Exception: ', '')}'
        );
      }
    }
  }

  /// Check if user can message
  static bool canMessage({
    required String? currentUserId,
    required String ownerId,
  }) {
    final canMsg = currentUserId != null && currentUserId != ownerId;
    return canMsg;
  }
}