// features/chat/presentation/screens/conversations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../providers/chat_providers.dart';
import '../../domain/entities/conversation_entity.dart';
import 'chat_screen.dart';
import '../../../users/presentation/screens/user_search_screen.dart';
import '../widgets/conversation_selection_manager.dart';
import '../../../../core/utils/responsive_helper.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  final ConversationSelectionManager _selectionManager = ConversationSelectionManager();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    
    _selectionManager.addListener(() {
      setState(() {});
    });
  }

  // ✅ FIX: Removed didChangeDependencies that caused an infinite refresh loop.
  // It was calling ref.refresh(conversationsProvider) on every dependency change
  // which triggered constant re-fetches and caused the screen to get stuck.

  @override
  void dispose() {
    _searchController.removeListener(() {});
    _searchController.dispose();
    _searchFocusNode.dispose();
    _selectionManager.dispose();
    super.dispose();
  }

  List<ConversationEntity> _filterConversations(List<ConversationEntity> conversations) {
    if (_searchQuery.isEmpty) return conversations;
    
    return conversations.where((conversation) {
      final query = _searchQuery.toLowerCase();
      return conversation.otherUserName.toLowerCase().contains(query) ||
             conversation.propertyTitle.toLowerCase().contains(query) ||
             (conversation.lastMessage?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _deleteSelectedConversations() async {
    if (_selectionManager.selectedCount == 0) return;

    logger.d('Bulk delete conversations: ${_selectionManager.selectedCount} selected');

    final user = ref.read(authNotifierProvider).value;
    if (user == null) {
      logger.e('User not authenticated');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Conversations',
          style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectionManager.selectedCount} conversation${_selectionManager.selectedCount > 1 ? 's' : ''}?\n\nThey will be removed from your view only.',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete for me'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      DialogUtils.showLoadingDialog(context, message: 'Deleting conversations...');

      try {
        final success = await ref.read(chatNotifierProvider.notifier).deleteConversationsForMe(
          conversationIds: _selectionManager.selectedConversationIds,
          userId: user.id,
        );

        if (mounted) {
          DialogUtils.hideLoadingDialog(context);
        }

        if (success && mounted) {
          final count = _selectionManager.selectedCount;
          _selectionManager.exitSelectionMode();
          
          SnackbarUtils.showSuccess(
            context,
            '$count conversation${count > 1 ? 's' : ''} deleted for you',
          );
        } else if (mounted) {
          SnackbarUtils.showError(context, 'Failed to delete conversations');
        }
      } catch (e) {
        logger.e('Exception during bulk delete', error: e);
        
        if (mounted) {
          DialogUtils.hideLoadingDialog(context);
          SnackbarUtils.showError(context, 'Error: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _handleConversationTap(ConversationEntity conversation) async {
    if (_selectionManager.isSelectionMode) {
      _selectionManager.toggleSelection(conversation);
      return;
    }

    final String? propertyId = conversation.propertyId;
    final String? propertyTitle = conversation.propertyTitle != 'Direct Message'
        ? conversation.propertyTitle
        : null;
    final String? propertyImage = conversation.propertyImage;

    // OPTIMISTIC UNREAD FIX: Clear the badge instantly in the UI, then
    // AWAIT the DB write so it is fully committed before we navigate.
    // This guarantees that when the post-pop invalidation re-fetches
    // conversations, the DB already reflects is_read = true and the
    // badge stays gone.
    if (conversation.unreadCount > 0) {
      ref.read(locallyReadConversationsProvider.notifier).update(
        (set) => {...set, conversation.id},
      );

      final user = ref.read(authNotifierProvider).value;
      if (user != null) {
        // Awaited so the DB write completes before Navigator.push opens the screen.
        await ref.read(chatNotifierProvider.notifier).markAsRead(
          conversationId: conversation.id,
          userId: user.id,
        );
      }
    }

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.id,
          otherUserId: conversation.otherUserId,
          otherUserName: conversation.otherUserName,
          otherUserAvatar: conversation.otherUserAvatar,
          propertyId: propertyId,
          propertyTitle: propertyTitle,
          propertyImage: propertyImage,
        ),
      ),
    );

    // Re-sync after returning from chat to reflect any new messages received.
    // markAsRead is already committed above, so this fetch will see the correct
    // unread count and the badge will not reappear.
    if (mounted) {
      ref.invalidate(conversationsProvider);
    }
  }

  void _handleConversationLongPress(ConversationEntity conversation) {
    _selectionManager.toggleSelection(conversation);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = true;
      Future.delayed(const Duration(milliseconds: 100), () {
        _searchFocusNode.requestFocus();
      });
    });
  }

  void _exitSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
      _searchFocusNode.unfocus();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _searchFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final unreadCount = ref.watch(unreadMessagesCountProvider);
    // ✅ Optimistic read tracking — badges clear instantly on tap
    final locallyReadIds = ref.watch(locallyReadConversationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    // Get themed colors using ThemeConfig helpers
    final appBarForegroundColor = ThemeConfig.getColor(
      context,
      lightColor: ThemeConfig.lightAppBarForeground,
      darkColor: ThemeConfig.darkAppBarForeground,
    );
    
    final inputFillColor = ThemeConfig.getColor(
      context,
      lightColor: ThemeConfig.lightInputFill,
      darkColor: ThemeConfig.darkInputFill,
    );
    
    final textPrimaryColor = ThemeConfig.getTextPrimaryColor(context);
    final textSecondaryColor = ThemeConfig.getTextSecondaryColor(context);

    return Scaffold(
      appBar: _selectionManager.isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: Icon(Icons.close, color: appBarForegroundColor),
                onPressed: () {
                  _selectionManager.exitSelectionMode();
                  setState(() {});
                },
              ),
              title: Text(
                '${_selectionManager.selectedCount} selected',
                style: TextStyle(color: appBarForegroundColor),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.select_all, color: appBarForegroundColor),
                  onPressed: () {
                    final conversations = ref.read(conversationsProvider).value;
                    if (conversations != null && conversations.isNotEmpty) {
                      final filtered = _filterConversations(conversations);
                      _selectionManager.selectAll(filtered);
                    }
                  },
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: appBarForegroundColor),
                  onPressed: _deleteSelectedConversations,
                  tooltip: 'Delete Selected',
                ),
              ],
            )
          : AppBar(
              leading: _isSearching
                  ? IconButton(
                      icon: Icon(Icons.arrow_back, color: appBarForegroundColor),
                      onPressed: _exitSearch,
                      tooltip: 'Back',
                    )
                  : null,
              title: _isSearching
                  ? Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: inputFillColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search conversations...',
                          hintStyle: TextStyle(
                            color: textSecondaryColor,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: textSecondaryColor,
                                    size: 20,
                                  ),
                                  onPressed: _clearSearch,
                                  tooltip: 'Clear search',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Messages',
                          style: TextStyle(
                            color: appBarForegroundColor,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (unreadCount > 0)
                          Text(
                            '$unreadCount unread',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                              fontWeight: FontWeight.normal,
                              color: appBarForegroundColor.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
              actions: [
                if (!_isSearching) ...[
                  IconButton(
                    icon: Icon(Icons.search, color: appBarForegroundColor),
                    tooltip: 'Search Conversations',
                    onPressed: _toggleSearch,
                  ),
                  IconButton(
                    icon: Icon(Icons.person_search, color: appBarForegroundColor),
                    tooltip: 'Search Users',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserSearchScreen(),
                        ),
                      );
                    },
                  ),
                ]
              ],
            ),
      body: conversationsAsync.when(
        data: (conversations) {
          final filteredConversations = _filterConversations(conversations);
          
          if (conversations.isEmpty) {
            return EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No Conversations',
              message: 'Start a conversation by messaging a user.',
              actionText: 'Search Users',
              onActionPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserSearchScreen(),
                  ),
                );
              },
            );
          }

          if (filteredConversations.isEmpty && _searchQuery.isNotEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: 'No Results',
              message: 'No conversations found for "$_searchQuery"',
              actionText: 'Clear Search',
              onActionPressed: _clearSearch,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(conversationsProvider);
              // Small delay so the loading state is visible
              await Future.delayed(const Duration(milliseconds: 100));
            },
            color: ThemeConfig.getPrimaryColor(context),
            child: ListView.separated(
              itemCount: filteredConversations.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 88,
                color: isDark ? ThemeConfig.darkDivider : ThemeConfig.lightDivider,
              ),
              itemBuilder: (context, index) {
                final conversation = filteredConversations[index];
                final isSelected = _selectionManager.isSelected(conversation.id);
                // ✅ If locally marked read, treat unreadCount as 0 for display
                final isLocallyRead = locallyReadIds.contains(conversation.id);
                
                return _ConversationTile(
                  conversation: conversation,
                  isSelected: isSelected,
                  isSelectionMode: _selectionManager.isSelectionMode,
                  isLocallyRead: isLocallyRead,
                  onTap: () => _handleConversationTap(conversation),
                  onLongPress: () => _handleConversationLongPress(conversation),
                );
              },
            ),
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading conversations...'),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: theme.colorScheme.error),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              Text(
                'Error loading conversations',
                style: TextStyle(color: textPrimaryColor),
              ),
              SizedBox(height: ResponsiveHelper.getResponsivePadding(context)),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(conversationsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(context),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isLocallyRead;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isLocallyRead,
    required this.onTap,
    required this.onLongPress,
  });

  // ✅ Effective unread count: 0 if optimistically marked read, else real count
  int get _effectiveUnread => isLocallyRead ? 0 : conversation.unreadCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPropertyMessage = conversation.lastMessage == conversation.propertyTitle &&
                              conversation.propertyId != null;
    final theme = Theme.of(context);
    
    // Get themed colors
    final primaryColor = ThemeConfig.getPrimaryColor(context);
    final textPrimaryColor = ThemeConfig.getTextPrimaryColor(context);
    final textSecondaryColor = ThemeConfig.getTextSecondaryColor(context);
    final cardColor = ThemeConfig.getCardColor(context);

    return Container(
      decoration: isSelected
          ? BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              border: Border.all(
                color: primaryColor,
                width: 2,
              ),
            )
          : null,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Stack(
          children: [
            if (isSelectionMode)
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: primaryColor,
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: textSecondaryColor,
                    width: 1.5,
                  ),
                ),
              )
            else
              CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                backgroundImage: conversation.otherUserAvatar != null
                    ? CachedNetworkImageProvider(conversation.otherUserAvatar!)
                    : null,
                child: conversation.otherUserAvatar == null
                    ? Text(
                        conversation.otherUserName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 20),
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      )
                    : null,
              ),
            if (_effectiveUnread > 0 && !isSelectionMode)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935), // errorColor
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    _effectiveUnread > 9 ? '9+' : '$_effectiveUnread',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 10),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.otherUserName,
                style: TextStyle(
                  fontWeight: _effectiveUnread > 0 
                      ? FontWeight.bold 
                      : FontWeight.w600,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 16),
                  color: textPrimaryColor,
                ),
              ),
            ),
            if (conversation.lastMessageTime != null && !isSelectionMode)
              Text(
                _formatLastMessageTime(conversation.lastMessageTime!),
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 12),
                  color: _effectiveUnread > 0
                      ? primaryColor
                      : textSecondaryColor,
                  fontWeight: _effectiveUnread > 0 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                ),
              ),
          ],
        ),
        subtitle: conversation.lastMessage != null
            ? Row(
                children: [
                  if (isPropertyMessage) ...[
                    Icon(
                      Icons.home_work,
                      size: 16,
                      color: _effectiveUnread > 0
                          ? primaryColor
                          : textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      isPropertyMessage 
                          ? 'Property: ${conversation.lastMessage}'
                          : conversation.lastMessage!,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, mobile: 14),
                        color: _effectiveUnread > 0
                            ? textPrimaryColor
                            : textSecondaryColor,
                        fontWeight: _effectiveUnread > 0 
                            ? FontWeight.w500 
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  String _formatLastMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$displayHour:$minute $period';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year.toString().substring(2)}';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RESPONSIVE LAYOUT HELPERS
  // ─────────────────────────────────────────────────────────────
  
  /// Build responsive layout based on screen size
  Widget _buildResponsiveLayout(BuildContext context, Widget child) {
    if (ResponsiveHelper.isMobile(context)) {
      return child;
    }
    
    // Center content on larger screens with max width
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: ResponsiveHelper.getMaxContentWidth(context, isWide: true),
        ),
        child: child,
      ),
    );
  }
  
  /// Get responsive column count for grids
  int _getResponsiveColumns(BuildContext context) {
    return ResponsiveHelper.getGridColumns(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );
  }
  
  /// Build responsive row/column based on screen size
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