// features/chat/presentation/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/app_providers.dart';
import '../../../users/presentation/screens/user_profileview_screen.dart';
import '../providers/chat_providers.dart';
import '../../domain/entities/message_entity.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';
import '../widgets/message_options_handler.dart';
import '../widgets/message_selection_manager.dart';
import '../widgets/reply_message_widget.dart';
import '../../../../core/middleware/feature_gate_middleware.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/responsive_helper.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? propertyId;
  final String? propertyTitle;
  final String? propertyImage;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.propertyId,
    this.propertyTitle,
    this.propertyImage,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showPropertyAttachment = false;
  final MessageSelectionManager _selectionManager = MessageSelectionManager();
  MessageEntity? _replyToMessage;
  String? _tappedMessageId;
  final _logger = AppLogger();

  @override
  void initState() {
    super.initState();
    _logger.d('ChatScreen initialized - Property: ${widget.propertyId}');
    // Fire-and-forget: just commits the DB write, does NOT invalidate
    // conversationsProvider (that happens in dispose to avoid the
    // unread-badge race condition).
    _markMessagesAsRead();
    _checkPropertyAttachment();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _selectionManager.dispose();
    // NOTE: We do NOT call ref.invalidate here — using ref after dispose()
    // throws a StateError. The conversations list is refreshed by
    // _handleConversationTap in conversations_screen.dart immediately after
    // Navigator.push returns, which is the correct and safe place to do it.
    super.dispose();
  }

  Future<void> _checkPropertyAttachment() async {
    _logger.d('🔍 Checking property attachment...');
    if (widget.propertyId != null && widget.propertyTitle != null) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _showPropertyAttachment = true;
        });
      }
    }
  }

  // Only performs the DB write. Does NOT invalidate conversationsProvider.
  // See dispose() for why.
  Future<void> _markMessagesAsRead() async {
    final user = ref.read(authNotifierProvider).value;
    if (user != null) {
      await ref.read(chatNotifierProvider.notifier).markAsRead(
            conversationId: widget.conversationId,
            userId: user.id,
          );
    }
  }

  Future<void> _sendMessage() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    final middleware = ref.read(featureGateMiddlewareProvider);
    final canSend = await middleware.checkFeatureAccess(
      context: context,
      userId: user.id,
      featureName: 'send_messages',
      showUpgradePrompt: true,
    );

    if (!canSend) return;

    final content = _messageController.text.trim();
    if (content.isEmpty && !_showPropertyAttachment) return;

    try {
      String messageContent = content;
      String messageType = 'text';

      if (_showPropertyAttachment) {
        final propertyContent = '${widget.propertyId}|${widget.propertyTitle}';
        if (content.isNotEmpty) {
          messageContent = '$propertyContent|||$content';
          messageType = 'property_text';
        } else {
          messageContent = propertyContent;
          messageType = 'property';
        }
      }

      _messageController.clear();
      if (_showPropertyAttachment) {
        setState(() => _showPropertyAttachment = false);
      }

      final success = await ref.read(chatNotifierProvider.notifier).sendMessage(
            conversationId: widget.conversationId,
            senderId: user.id,
            senderName: user.fullName ?? 'User',
            content: messageContent,
            type: messageType,
            replyToId: _replyToMessage?.id,
            replyToContent: _replyToMessage?.content,
            replyToSenderName: _replyToMessage?.senderName,
          );

      if (success) {
        if (_replyToMessage != null) {
          setState(() => _replyToMessage = null);
        }
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Error sending message');
    }

    final subscriptionService = ref.read(subscriptionServiceProvider);
    await subscriptionService.incrementUsage(
      userId: user.id,
      featureName: 'send_messages',
    );
  }

  // ============================================================================
  // TAP HANDLER - Shows three dots
  // ============================================================================
  void _handleMessageTap(MessageEntity message, bool isMe) {
    setState(() => _tappedMessageId = message.id);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          if (_tappedMessageId == message.id) _tappedMessageId = null;
        });
      }
    });
  }

  // ============================================================================
  // LONG PRESS HANDLER - Selection mode
  // ============================================================================
  void _handleMessageLongPress(MessageEntity message) {
    setState(() => _tappedMessageId = null);
    _selectionManager.toggleSelection(message);
    setState(() {});
  }

  // ============================================================================
  // DELETE MESSAGE
  // ============================================================================
  void _handleDelete(String messageId, bool isHardDelete) async {
    _logger.i('🗑️ DELETE MESSAGE STARTED');

    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    setState(() => _tappedMessageId = null);

    try {
      bool success;
      if (isHardDelete) {
        success = await ref.read(chatNotifierProvider.notifier).deleteMessage(
              messageId: messageId,
              conversationId: widget.conversationId,
            );
      } else {
        success = await ref.read(chatNotifierProvider.notifier).deleteMessageForMe(
              messageId: messageId,
              conversationId: widget.conversationId,
              userId: user.id,
            );
      }

      if (success && mounted) {
        _logger.i('✅ Delete successful');

        ref.invalidate(messagesStreamProvider(widget.conversationId));
        ref.refresh(messagesStreamProvider(widget.conversationId));
        setState(() {});

        SnackbarUtils.showSuccess(
          context,
          isHardDelete
              ? 'Message deleted for everyone'
              : 'Message deleted for you',
        );
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Error deleting message');
    }
  }

  void _handleEdit(String newContent, String messageId) async {
    final success = await ref.read(chatNotifierProvider.notifier).editMessage(
          messageId: messageId,
          conversationId: widget.conversationId,
          newContent: newContent,
        );

    if (success && mounted) {
      ref.invalidate(messagesStreamProvider(widget.conversationId));
      ref.refresh(messagesStreamProvider(widget.conversationId));
      setState(() => _tappedMessageId = null);
      SnackbarUtils.showSuccess(context, 'Message edited successfully');
    }
  }

  void _handleReply(MessageEntity message) {
    setState(() {
      _replyToMessage = message;
      _tappedMessageId = null;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _handleCopy(String content) {
    Clipboard.setData(ClipboardData(text: content));
    setState(() => _tappedMessageId = null);
    SnackbarUtils.showSuccess(context, 'Message copied to clipboard');
  }

  void _navigateToOwnerProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileViewScreen(userId: widget.otherUserId),
      ),
    );
  }

  void _navigateToPropertyDetail(String propertyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailScreen(propertyId: propertyId),
      ),
    );
  }

  void _removePropertyAttachment() =>
      setState(() => _showPropertyAttachment = false);

  void _handleSelectAll(List<MessageEntity> messages) {
    _selectionManager.selectAll(messages);
    setState(() {});
  }

  void _handleDeleteSelected() async {
    if (_selectionManager.selectedCount == 0) return;

    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages'),
        content: Text(
            'Delete ${_selectionManager.selectedCount} message(s) for you?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(chatNotifierProvider.notifier).deleteMessagesForMe(
                messageIds: _selectionManager.selectedMessageIds,
                conversationId: widget.conversationId,
                userId: user.id,
              );

      if (success && mounted) {
        final count = _selectionManager.selectedCount;
        _selectionManager.exitSelectionMode();
        ref.invalidate(messagesStreamProvider(widget.conversationId));
        ref.refresh(messagesStreamProvider(widget.conversationId));
        setState(() {});
        SnackbarUtils.showSuccess(context, '$count message(s) deleted');
      }
    }
  }

  void _showPropertyMessageOptions({
    required BuildContext context,
    required MessageEntity message,
    required bool isMyMessage,
    required bool hasTextMessage,
    required String? textMessage,
    required String? propertyId,
    required String? propertyTitle,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                  margin: const EdgeInsets.only(top: 8)),
              if (hasTextMessage)
                _buildBottomSheetOption(
                    icon: Icons.copy,
                    label: 'Copy text',
                    onTap: () {
                      Navigator.pop(context);
                      _handleCopy(textMessage!);
                    }),
              _buildBottomSheetOption(
                  icon: Icons.reply,
                  label: 'Reply',
                  onTap: () {
                    Navigator.pop(context);
                    _handleReply(message);
                  }),
              _buildBottomSheetOption(
                  icon: Icons.check_circle_outline,
                  label: 'Select',
                  onTap: () {
                    Navigator.pop(context);
                    _selectionManager.toggleSelection(message);
                    setState(() {});
                  }),
              if (isMyMessage && hasTextMessage)
                _buildBottomSheetOption(
                    icon: Icons.edit,
                    label: 'Edit text',
                    onTap: () {
                      Navigator.pop(context);
                      _showEditPropertyTextDialog(context, message,
                          textMessage!, propertyId!, propertyTitle!);
                    }),
              if (isMyMessage) ...[
                _buildBottomSheetOption(
                    icon: Icons.delete_outline,
                    label: 'Delete for me',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(context, message.id, false,
                          'Delete for me', 'Delete this message for you?');
                    }),
                _buildBottomSheetOption(
                    icon: Icons.delete_forever,
                    label: 'Delete for everyone',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(
                          context,
                          message.id,
                          true,
                          'Delete for everyone',
                          'Delete this message for everyone?');
                    }),
              ],
              if (!isMyMessage)
                _buildBottomSheetOption(
                    icon: Icons.delete_outline,
                    label: 'Delete for me',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(context, message.id, false,
                          'Delete for me', 'Delete this message for you?');
                    }),
              _buildBottomSheetOption(
                  icon: Icons.close,
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(icon,
                  color: color ?? (isDark ? Colors.white70 : Colors.black54),
                  size: ResponsiveHelper.getResponsiveIconSize(context)),
              SizedBox(width: ResponsiveHelper.getResponsivePadding(context)),
              Text(label,
                  style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                      color: color ?? (isDark ? Colors.white : Colors.black87),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPropertyTextDialog(BuildContext context, MessageEntity message,
      String currentText, String propertyId, String propertyTitle) {
    final controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.home_work, size: ResponsiveHelper.getResponsiveIconSize(context)),
                  SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
                  Expanded(
                      child: Text(propertyTitle,
                          style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 13),
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis))
                ])),
            SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
            TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Enter message...',
                    border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText != currentText) {
                _handleEdit(
                    '$propertyId|$propertyTitle|||$newText', message.id);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String messageId,
      bool isHardDelete, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Future.delayed(
                  Duration.zero, () => _handleDelete(messageId, isHardDelete));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: isHardDelete ? Colors.red : Colors.orange),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream =
        ref.watch(messagesStreamProvider(widget.conversationId));
    final user = ref.watch(authNotifierProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _selectionManager.isSelectionMode
          ? AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _selectionManager.exitSelectionMode();
                    setState(() {});
                  }),
              title: Text('${_selectionManager.selectedCount} selected'),
              actions: [
                Consumer(builder: (context, ref, child) {
                  final user = ref.watch(authNotifierProvider).value;
                  return user == null
                      ? const SizedBox.shrink()
                      : const QuotaIndicator(featureName: 'send_messages');
                }),
                IconButton(
                    icon: const Icon(Icons.select_all),
                    onPressed: () {
                      final messages = ref
                          .read(messagesStreamProvider(widget.conversationId))
                          .value;
                      if (messages != null) _handleSelectAll(messages);
                    }),
                IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _handleDeleteSelected),
              ],
            )
          : AppBar(
              elevation: 0,
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context)),
              title: GestureDetector(
                onTap: _navigateToOwnerProfile,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).cardColor,
                      backgroundImage: widget.otherUserAvatar != null
                          ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                          : null,
                      child: widget.otherUserAvatar == null
                          ? Text(widget.otherUserName[0].toUpperCase(),
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold))
                          : null,
                    ),
                    SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
                    Expanded(
                        child: Text(widget.otherUserName,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .appBarTheme
                                    .foregroundColor,
                                fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
      body: Column(
        children: [
          Expanded(
            child: messagesStream.when(
              data: (messages) {
                final filteredMessages =
                    messages.where((m) => !m.deletedForMe).toList();
                if (filteredMessages.isEmpty) return _buildEmptyState(isDark);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    final message = filteredMessages[index];
                    final isMe = message.senderId == user?.id;
                    final showDateAbove =
                        index == filteredMessages.length - 1 ||
                            !_isSameDay(message.createdAt,
                                filteredMessages[index + 1].createdAt);

                    return Column(
                      children: [
                        if (showDateAbove)
                          _buildDateSeparator(message.createdAt, isDark),
                        message.type == MessageType.property ||
                                message.type == MessageType.property_text
                            ? _buildPropertyMessageBubble(message, isMe, isDark)
                            : _buildMessageBubbleWithOptions(
                                message, isMe, isDark),
                      ],
                    );
                  },
                );
              },
              loading: () => Center(
                  child: CircularProgressIndicator(
                      color: isDark ? Colors.white : ThemeConfig.primaryColor)),
              error: (_, __) => _buildErrorState(isDark),
            ),
          ),
          if (_replyToMessage != null)
            ReplyMessageWidget(
                replyToMessage: _replyToMessage!,
                onCancel: () => setState(() => _replyToMessage = null)),
          if (_showPropertyAttachment) _buildPropertyAttachmentPreview(isDark),
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  Widget _buildPropertyMessageBubble(
      MessageEntity message, bool isMe, bool isDark) {
    String? propertyId;
    String propertyTitle = '';
    String? textMessage;

    if (message.content.contains('|||')) {
      final parts = message.content.split('|||');
      if (parts.length == 2) {
        final propParts = parts[0].split('|');
        if (propParts.length == 2) {
          propertyId = propParts[0];
          propertyTitle = propParts[1];
        }
        textMessage = parts[1];
      }
    } else if (message.content.contains('|')) {
      final parts = message.content.split('|');
      if (parts.length == 2) {
        propertyId = parts[0];
        propertyTitle = parts[1];
      }
    }

    final hasValidPropertyId = propertyId != null && propertyId.isNotEmpty;
    final hasTextMessage = textMessage != null && textMessage.isNotEmpty;
    final isSelected = _selectionManager.isSelected(message.id);
    final showOptions =
        _tappedMessageId == message.id && !_selectionManager.isSelectionMode;

    return GestureDetector(
      onTap: () => _handleMessageTap(message, isMe),
      onLongPress: () => _handleMessageLongPress(message),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (isMe && showOptions)
              _buildThreeDots(message, isMe, isDark, hasTextMessage,
                  textMessage, propertyId, propertyTitle),
            if (!isMe) ...[
              CircleAvatar(
                  radius: 16,
                  backgroundColor: isDark
                      ? Colors.grey.shade800
                      : ThemeConfig.primaryColor.withOpacity(0.1),
                  backgroundImage: widget.otherUserAvatar != null
                      ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                      : null,
                  child: widget.otherUserAvatar == null
                      ? Text(widget.otherUserName[0].toUpperCase(),
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : ThemeConfig.primaryColor,
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                              fontWeight: FontWeight.bold))
                      : null),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.getDialogWidth(context)),
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(
                            color: ThemeConfig.primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(14))
                    : null,
                padding: isSelected ? const EdgeInsets.all(2) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isMe
                        ? (isDark
                            ? ThemeConfig.primaryColor.withOpacity(0.8)
                            : ThemeConfig.primaryColor)
                        : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(isMe ? 12 : 2),
                        bottomRight: Radius.circular(isMe ? 2 : 12)),
                    border: !isMe
                        ? Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: hasValidPropertyId
                            ? () => _navigateToPropertyDetail(propertyId!)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                          decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.black.withOpacity(0.15)
                                  : (isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color: isMe
                                          ? Colors.white.withOpacity(0.2)
                                          : ThemeConfig.primaryColor
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Icon(Icons.home_work,
                                      size: 24,
                                      color: isMe
                                          ? Colors.white.withOpacity(0.9)
                                          : ThemeConfig.primaryColor)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('Property',
                                        style: TextStyle(
                                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                                            color: isMe
                                                ? Colors.white.withOpacity(0.7)
                                                : (isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600))),
                                    const SizedBox(height: 2),
                                    Text(propertyTitle,
                                        style: TextStyle(
                                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                                            fontWeight: FontWeight.w500,
                                            color: isMe
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.white
                                                    : Colors.black87)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ])),
                              if (hasValidPropertyId)
                                Icon(Icons.open_in_new,
                                    size: 16,
                                    color: isMe
                                        ? Colors.white.withOpacity(0.6)
                                        : (isDark
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                      if (hasTextMessage)
                        Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: Text(textMessage,
                                style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    fontSize: 15))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(Formatters.formatTime(message.createdAt),
                                  style: TextStyle(
                                      color: isMe
                                          ? Colors.white.withOpacity(0.7)
                                          : (isDark
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade600),
                                      fontSize: 11)),
                              if (message.edited == true) ...[
                                const SizedBox(width: 4),
                                Text('(edited)',
                                    style: TextStyle(
                                        color: isMe
                                            ? Colors.white.withOpacity(0.5)
                                            : (isDark
                                                ? Colors.grey.shade600
                                                : Colors.grey.shade500),
                                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                                        fontStyle: FontStyle.italic))
                              ],
                            ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isMe && showOptions)
              _buildThreeDots(message, isMe, isDark, hasTextMessage,
                  textMessage, propertyId, propertyTitle),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubbleWithOptions(
      MessageEntity message, bool isMe, bool isDark) {
    final isSelected = _selectionManager.isSelected(message.id);
    final showOptions =
        _tappedMessageId == message.id && !_selectionManager.isSelectionMode;

    return GestureDetector(
      onTap: () => _handleMessageTap(message, isMe),
      onLongPress: () => _handleMessageLongPress(message),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (isMe && showOptions)
              GestureDetector(
                onTap: () => MessageOptionsHandler.showMessageOptions(
                  context: context,
                  message: message,
                  isMyMessage: isMe,
                  onEdit: (c) => _handleEdit(c, message.id),
                  onDelete: (id, hard) => _handleDelete(id, hard),
                  onReply: _handleReply,
                  onCopy: _handleCopy,
                  onSelect: (msg) {
                    _selectionManager.toggleSelection(msg);
                    setState(() {});
                  },
                ),
                child: Container(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                    margin: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.more_vert,
                        size: 20,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700)),
              ),
            if (!isMe) ...[
              CircleAvatar(
                  radius: 16,
                  backgroundColor: isDark
                      ? Colors.grey.shade800
                      : ThemeConfig.primaryColor.withOpacity(0.1),
                  backgroundImage: widget.otherUserAvatar != null
                      ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                      : null,
                  child: widget.otherUserAvatar == null
                      ? Text(widget.otherUserName[0].toUpperCase(),
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : ThemeConfig.primaryColor,
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                              fontWeight: FontWeight.bold))
                      : null),
              SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
            ],
            Flexible(
              child: Container(
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(
                            color: ThemeConfig.primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(18))
                    : null,
                padding: isSelected ? const EdgeInsets.all(2) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (isDark
                            ? ThemeConfig.primaryColor.withOpacity(0.8)
                            : ThemeConfig.primaryColor)
                        : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyToContent != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                            decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.black.withOpacity(0.2)
                                    : (isDark
                                        ? Colors.grey.shade800.withOpacity(0.5)
                                        : Colors.grey.shade200
                                            .withOpacity(0.7)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border(
                                    left: BorderSide(
                                        color: isMe
                                            ? Colors.white.withOpacity(0.5)
                                            : ThemeConfig.primaryColor,
                                        width: 2))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message.replyToSenderName ?? 'User',
                                      style: TextStyle(
                                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                                          fontWeight: FontWeight.w600,
                                          color: isMe
                                              ? Colors.white.withOpacity(0.9)
                                              : ThemeConfig.primaryColor)),
                                  const SizedBox(height: 2),
                                  Text(message.replyToContent!,
                                      style: TextStyle(
                                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                                          color: isMe
                                              ? Colors.white.withOpacity(0.7)
                                              : (isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade700)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ]),
                          ),
                        Text(message.content,
                            style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white
                                        : ThemeConfig.textPrimaryColor),
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(Formatters.formatTime(message.createdAt),
                              style: TextStyle(
                                  color: isMe
                                      ? Colors.white.withOpacity(0.7)
                                      : (isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600),
                                  fontSize: 11)),
                          if (message.edited == true) ...[
                            const SizedBox(width: 4),
                            Text('(edited)',
                                style: TextStyle(
                                    color: isMe
                                        ? Colors.white.withOpacity(0.5)
                                        : (isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade500),
                                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                                    fontStyle: FontStyle.italic))
                          ],
                        ]),
                      ]),
                ),
              ),
            ),
            if (!isMe && showOptions)
              GestureDetector(
                onTap: () => MessageOptionsHandler.showMessageOptions(
                  context: context,
                  message: message,
                  isMyMessage: isMe,
                  onEdit: (c) => _handleEdit(c, message.id),
                  onDelete: (id, hard) => _handleDelete(id, hard),
                  onReply: _handleReply,
                  onCopy: _handleCopy,
                  onSelect: (msg) {
                    _selectionManager.toggleSelection(msg);
                    setState(() {});
                  },
                ),
                child: Container(
                    padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
                    margin: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.more_vert,
                        size: 20,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreeDots(
      MessageEntity message,
      bool isMe,
      bool isDark,
      bool hasTextMessage,
      String? textMessage,
      String? propertyId,
      String? propertyTitle) {
    return GestureDetector(
      onTap: () => _showPropertyMessageOptions(
        context: context,
        message: message,
        isMyMessage: isMe,
        hasTextMessage: hasTextMessage,
        textMessage: textMessage,
        propertyId: propertyId,
        propertyTitle: propertyTitle,
      ),
      child: Container(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
          margin: EdgeInsets.only(right: isMe ? 4 : 0, left: !isMe ? 4 : 0),
          child: Icon(Icons.more_vert,
              size: 20,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
    );
  }

  Widget _buildPropertyAttachmentPreview(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: EdgeInsets.all(ResponsiveHelper.getResponsiveSpacing(context)),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100)),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: widget.propertyImage != null
                ? CachedNetworkImage(
                    imageUrl: widget.propertyImage!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                        width: 40, height: 40, color: Colors.grey.shade300),
                    errorWidget: (c, u, e) => Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.shade300,
                        child: Icon(Icons.home_work,
                            size: ResponsiveHelper.getResponsiveIconSize(context))))
                : Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey.shade300,
                    child: Icon(Icons.home_work,
                        size: ResponsiveHelper.getResponsiveIconSize(context)))),
        SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.link,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text('Property',
                style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 11),
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600))
          ]),
          const SizedBox(height: 2),
          Text(widget.propertyTitle!,
              style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ])),
        IconButton(
            icon: Icon(Icons.close,
                size: 20,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            onPressed: _removePropertyAttachment,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
      ]),
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Expanded(
            child: Divider(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
        Padding(
            padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getResponsiveHorizontalPadding(context)),
            child: Text(Formatters.formatDate(date),
                style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                    fontWeight: FontWeight.w500))),
        Expanded(
            child: Divider(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
      ]),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: EdgeInsets.all(
          ResponsiveHelper.getResponsiveSpacing(context, multiplier: 1.5)),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2))
      ]),
      child: SafeArea(
        child: Row(children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal:
                      ResponsiveHelper.getResponsiveHorizontalPadding(context)),
              decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle:
                        Theme.of(context).inputDecorationTheme.hintStyle,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12)),
                maxLines: null,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: ResponsiveHelper.getResponsiveSpacing(context)),
          Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle),
              child: IconButton(
                  icon: Icon(Icons.send,
                      color: Colors.white,
                      size: ResponsiveHelper.getResponsiveIconSize(context)),
                  onPressed: _sendMessage)),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline,
            size: 64, color: Theme.of(context).disabledColor),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
        Text('No messages yet',
            style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                fontSize: 16)),
        SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context)),
        Text('Start the conversation!',
            style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                fontSize: 14)),
      ]));

  Widget _buildErrorState(bool isDark) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline,
            size: 48, color: isDark ? Colors.red.shade300 : Colors.red),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
        Text('Failed to load messages',
            style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
      ]));

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  // ─────────────────────────────────────────────────────────────
  // RESPONSIVE LAYOUT HELPERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildResponsiveLayout(BuildContext context, Widget child) {
    if (ResponsiveHelper.isMobile(context)) {
      return child;
    }
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: ResponsiveHelper.getMaxContentWidth(context, isWide: true),
        ),
        child: child,
      ),
    );
  }

  int _getResponsiveColumns(BuildContext context) {
    return ResponsiveHelper.getGridColumns(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }

  Widget _buildResponsiveRowOrColumn({
    required BuildContext context,
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    if (ResponsiveHelper.isMobile(context)) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children.map((child) => Expanded(child: child)).toList(),
    );
  }
}