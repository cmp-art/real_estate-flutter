// features/chat/presentation/widgets/reply_message_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../domain/entities/message_entity.dart';
import '../../../../core/utils/responsive_helper.dart';

class ReplyMessageWidget extends ConsumerWidget {
  final MessageEntity replyToMessage;
  final VoidCallback onCancel;

  const ReplyMessageWidget({
    super.key,
    required this.replyToMessage,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authNotifierProvider).value;
    
    // Check if replying to own message
    final isMyMessage = currentUser?.id == replyToMessage.senderId;
    final displayName = isMyMessage ? 'You' : replyToMessage.senderName;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(ResponsiveHelper.getResponsiveBorderRadius(context)),
        border: const Border(
          left: BorderSide(
            color: ThemeConfig.primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    fontWeight: FontWeight.w600,
                    color: ThemeConfig.primaryColor,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context) / 2),
                Text(
                  replyToMessage.type == MessageType.property
                      ? '🏠 Property: ${_getPropertyTitle(replyToMessage.content)}'
                      : replyToMessage.content,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: ResponsiveHelper.getResponsiveIconSize(context),
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }

  String _getPropertyTitle(String content) {
    // Handle property_text format: propertyId|propertyTitle|||text
    if (content.contains('|||')) {
      final mainParts = content.split('|||');
      if (mainParts.isNotEmpty && mainParts[0].contains('|')) {
        final propertyParts = mainParts[0].split('|');
        if (propertyParts.length == 2) {
          return propertyParts[1];
        }
      }
    }
    // Handle property format: propertyId|propertyTitle
    else if (content.contains('|')) {
      final parts = content.split('|');
      if (parts.length == 2) {
        return parts[1];
      }
    }
    return content;
  }
}