// features/chat/presentation/widgets/message_options_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/message_entity.dart';
import '../../../../core/utils/responsive_helper.dart';

class MessageOptionsHandler {
  static void showMessageOptions({
    required BuildContext context,
    required MessageEntity message,
    required bool isMyMessage,
    required Function(String) onEdit,
    required Function(String, bool) onDelete, // Updated: includes isHardDelete parameter
    required Function(MessageEntity) onReply,
    required Function(String) onCopy,
    required Function(MessageEntity) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),

              // Copy option (for text messages only)
              if (message.type == MessageType.text)
                _buildOption(
                  context: context,
                  icon: Icons.copy,
                  label: 'Copy',
                  onTap: () {
                    Navigator.pop(context);
                    onCopy(message.content);
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),

              // Reply option (for all messages)
              _buildOption(
                context: context,
                icon: Icons.reply,
                label: 'Reply',
                onTap: () {
                  Navigator.pop(context);
                  onReply(message);
                },
              ),

              // Select option (for all messages)
              _buildOption(
                context: context,
                icon: Icons.check_circle_outline,
                label: 'Select',
                onTap: () {
                  Navigator.pop(context);
                  onSelect(message);
                },
              ),

              // Edit option (only for my text messages)
              if (isMyMessage && message.type == MessageType.text)
                _buildOption(
                  context: context,
                  icon: Icons.edit,
                  label: 'Edit',
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(context, message, onEdit);
                  },
                ),

              // FOR MY MESSAGES: Show BOTH delete options
              if (isMyMessage) ...[
                // Delete for me (soft delete)
                _buildOption(
                  context: context,
                  icon: Icons.delete_outline,
                  label: 'Delete for me',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(
                      context,
                      message,
                      onDelete,
                      false, // isHardDelete = false (soft delete)
                      'Delete for me',
                      'Are you sure you want to delete this message? It will only be removed from your view.',
                    );
                  },
                ),
                // Delete for everyone (hard delete)
                _buildOption(
                  context: context,
                  icon: Icons.delete_forever,
                  label: 'Delete for everyone',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(
                      context,
                      message,
                      onDelete,
                      true, // isHardDelete = true (hard delete)
                      'Delete for everyone',
                      'Are you sure you want to delete this message for everyone? This action cannot be undone.',
                    );
                  },
                ),
              ],

              // FOR OTHER USER'S MESSAGES: Show only "Delete for me"
              if (!isMyMessage)
                _buildOption(
                  context: context,
                  icon: Icons.delete_outline,
                  label: 'Delete for me',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(
                      context,
                      message,
                      onDelete,
                      false, // isHardDelete = false (soft delete)
                      'Delete for me',
                      'Are you sure you want to delete this message? It will only be removed from your view.',
                    );
                  },
                ),

              // Cancel button
              _buildOption(
                context: context,
                icon: Icons.close,
                label: 'Cancel',
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: color ?? (isDark ? Colors.white70 : Colors.black54),
                size: ResponsiveHelper.getResponsiveIconSize(context),
              ),
              SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
              Text(
                label,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                  color: color ?? (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showEditDialog(
    BuildContext context,
    MessageEntity message,
    Function(String) onEdit,
  ) {
    final controller = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLines: 4,
            minLines: 1,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter message...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                onEdit(newContent);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static void _showDeleteConfirmation(
    BuildContext context,
    MessageEntity message,
    Function(String, bool) onDelete,
    bool isHardDelete,
    String title,
    String content,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Close the dialog first
              Navigator.pop(context);

              // Then call the delete callback with the message ID and delete type
              Future.delayed(Duration.zero, () {
                onDelete(message.id, isHardDelete);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isHardDelete ? Colors.red : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}