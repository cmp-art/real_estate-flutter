// features/chat/data/datasources/chat_remote_datasource.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatRemoteDataSource {
  final SupabaseClient supabaseClient;

  ChatRemoteDataSource(this.supabaseClient);

  // Number of messages to load per page (pagination fix for egress)
  static const int _messagePageSize = 50;

  // ============================================================================
  // GET CONVERSATIONS — OPTIMISED: 4 DB queries total (was O(3n) N+1)
  // ============================================================================
  Future<List<ConversationModel>> getConversations(String userId) async {
    try {
      logger.d('Fetching conversations for user: $userId');

      // Query 1 – all conversations with embedded property snippet
      final conversationsData = await supabaseClient
          .from(AppConstants.conversationsTable)
          .select('''
            *,
            property:property_id (
              id,
              title,
              images
            )
          ''')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      if ((conversationsData as List).isEmpty) return [];

      final convIds = conversationsData
          .map<String>((c) => c['id'] as String)
          .toList();

      // Query 2 – user's soft-deleted message IDs (flat set for O(1) lookup)
      final deletedMessageIds = await _getUserDeletedMessages(userId);

      // Query 3 – batch-fetch ALL "other users" in one round-trip
      final otherUserIds = conversationsData
          .map<String>((c) =>
              c['user1_id'] == userId ? c['user2_id'] : c['user1_id'])
          .toSet()
          .toList();

      final usersRaw = await supabaseClient
          .from(AppConstants.usersTable)
          .select('id, full_name, avatar_url')
          .inFilter('id', otherUserIds)
          .timeout(const Duration(seconds: 5));

      final usersMap = <String, Map<String, dynamic>>{
        for (final u in (usersRaw as List)) u['id'] as String: u,
      };

      // Query 4 – batch-fetch ALL unread messages across ALL conversations at once
      final unreadRaw = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('id, conversation_id')
          .inFilter('conversation_id', convIds)
          .eq('is_read', false)
          .neq('sender_id', userId)
          .timeout(const Duration(seconds: 5));

      // Group unread counts by conversation_id (excluding soft-deleted)
      final unreadByConv = <String, int>{};
      for (final msg in (unreadRaw as List)) {
        final msgId  = msg['id']              as String;
        final convId = msg['conversation_id'] as String;
        if (!deletedMessageIds.contains(msgId)) {
          unreadByConv[convId] = (unreadByConv[convId] ?? 0) + 1;
        }
      }

      // Build models from already-fetched data — zero extra DB calls
      final conversations = <ConversationModel>[];
      for (final conv in conversationsData) {
        try {
          final conversationId = conv['id'] as String;
          final otherUserId = (conv['user1_id'] == userId
              ? conv['user2_id']
              : conv['user1_id']) as String;

          final userData = usersMap[otherUserId] ??
              {'id': otherUserId, 'full_name': 'User', 'avatar_url': null};

          final property = conv['property'];

          conversations.add(ConversationModel.fromJson({
            'id': conversationId,
            'property_id': conv['property_id'],
            'property_title':
                property != null ? property['title'] : 'Direct Message',
            'property_image': property != null &&
                    property['images'] != null &&
                    (property['images'] as List).isNotEmpty
                ? property['images'][0]
                : null,
            'other_user_id': otherUserId,
            'other_user_name': userData['full_name'] ?? 'User',
            'other_user_avatar': userData['avatar_url'],
            'last_message': conv['last_message'],
            'last_message_time': conv['last_message_time'],
            'unread_count': unreadByConv[conversationId] ?? 0,
            'created_at': conv['created_at'],
          }));
        } catch (e) {
          logger.w('Error processing conversation', error: e);
          continue;
        }
      }

      logger.d(
          'Returning ${conversations.length} conversations (4 DB queries total)');
      return conversations;
    } catch (e, s) {
      logger.e('Error in getConversations', error: e, stackTrace: s);
      throw ServerException('Failed to load conversations: ${e.toString()}');
    }
  }

  // ============================================================================
  // GET OR CREATE CONVERSATION
  // ============================================================================
  Future<ConversationModel> getOrCreateConversation({
    required String userId,
    required String otherUserId,
    String? propertyId,
  }) async {
    try {
      logger.d('getOrCreateConversation - User: $userId, Other: $otherUserId');

      final user1 = userId.compareTo(otherUserId) < 0 ? userId : otherUserId;
      final user2 = userId.compareTo(otherUserId) < 0 ? otherUserId : userId;

      final existing = await supabaseClient
          .from(AppConstants.conversationsTable)
          .select()
          .eq('user1_id', user1)
          .eq('user2_id', user2)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );

      if (existing != null) {
        logger.d('Found existing conversation: ${existing['id']}');
        return await _buildConversationModel(existing, userId);
      }

      final now = DateTime.now().toIso8601String();
      final newConversation = await supabaseClient
          .from(AppConstants.conversationsTable)
          .insert({
            'user1_id': user1,
            'user2_id': user2,
            'property_id': propertyId,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single()
          .timeout(const Duration(seconds: 10));

      logger.d('New conversation created: ${newConversation['id']}');
      return await _buildConversationModel(newConversation, userId);
    } catch (e, s) {
      logger.e('Error in getOrCreateConversation', error: e, stackTrace: s);
      throw ServerException('Failed to start conversation: ${e.toString()}');
    }
  }

  // ============================================================================
  // GET MESSAGES — PAGINATED
  // page 0 = most recent _messagePageSize messages (newest at bottom of chat)
  // page 1 = next _messagePageSize older messages, etc.
  // ============================================================================
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int page = 0,
  }) async {
    try {
      final offset = page * _messagePageSize;

      // Fetch newest-first so .range() gives us the most recent messages,
      // then reverse the list so the UI shows oldest→newest (top→bottom).
      final data = await supabaseClient
          .from(AppConstants.messagesTable)
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + _messagePageSize - 1)
          .timeout(const Duration(seconds: 10));

      final userId = supabaseClient.auth.currentUser?.id;

      if (userId == null) {
        return (data as List)
            .reversed
            .map((e) => MessageModel.fromJson(e))
            .toList();
      }

      final deletedMessageIds = await _getUserDeletedMessages(userId);

      return (data as List).reversed.map((e) {
        final messageId = e['id'] as String;
        final messageData = Map<String, dynamic>.from(e);
        messageData['deleted_for_me'] = deletedMessageIds.contains(messageId);
        return MessageModel.fromJson(messageData);
      }).toList();
    } catch (e, s) {
      logger.e('Error loading messages', error: e, stackTrace: s);
      throw ServerException('Failed to load messages: ${e.toString()}');
    }
  }

  // ============================================================================
  // SEND MESSAGE
  // ============================================================================
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String type = 'text',
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      final messageData = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'type': type,
        'is_read': false,
        'created_at': now,
      };

      if (replyToId != null) {
        messageData['reply_to_id'] = replyToId;
        messageData['reply_to_content'] = replyToContent!;
        messageData['reply_to_sender_name'] = replyToSenderName!;
      }

      final message = await supabaseClient
          .from(AppConstants.messagesTable)
          .insert(messageData)
          .select()
          .single()
          .timeout(const Duration(seconds: 10));

      await supabaseClient
          .from(AppConstants.conversationsTable)
          .update({
            'last_message': _formatMessageContent(message),
            'last_message_time': now,
            'updated_at': now,
          })
          .eq('id', conversationId)
          .timeout(const Duration(seconds: 5));

      return MessageModel.fromJson(message);
    } catch (e, s) {
      logger.e('Error sending message', error: e, stackTrace: s);
      throw ServerException('Failed to send message: ${e.toString()}');
    }
  }

  // ============================================================================
  // MARK MESSAGES AS READ
  // FIX: fetch IDs first then update by ID to guarantee RLS allows the write.
  // ============================================================================
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Step 1: fetch IDs of unread messages NOT sent by the current user
      final unreadMessages = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', userId)
          .timeout(const Duration(seconds: 5));

      final unreadIds = (unreadMessages as List)
          .map((m) => m['id'] as String)
          .toList();

      if (unreadIds.isEmpty) {
        logger.d('No unread messages to mark for conversation: $conversationId');
        return;
      }

      // Step 2: update exactly those IDs
      await supabaseClient
          .from(AppConstants.messagesTable)
          .update({'is_read': true})
          .inFilter('id', unreadIds)
          .timeout(const Duration(seconds: 5));

      logger.d('Marked ${unreadIds.length} messages as read in $conversationId');
    } catch (e) {
      logger.w('Error marking messages as read', error: e);
    }
  }

  // ============================================================================
  // SUBSCRIBE TO MESSAGES
  // FIX: deleted message IDs are cached at stream start instead of being
  // re-fetched on every incoming real-time event (was a major egress driver).
  // ============================================================================
  Stream<List<MessageModel>> subscribeToMessages(String conversationId) async* {
    final userId = supabaseClient.auth.currentUser?.id;

    // Cache deleted IDs once at stream start — no extra DB call per message event
    var deletedMessageIds = userId != null
        ? await _getUserDeletedMessages(userId)
        : <String>{};

    try {
      await for (final data in supabaseClient
          .from(AppConstants.messagesTable)
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at')
          .handleError((error) {
            logger.e('Stream error', error: error);
            return [];
          })) {
        if (userId == null) {
          yield data.map((e) => MessageModel.fromJson(e)).toList();
          continue;
        }

        try {
          final messages = data.map((e) {
            final messageData = Map<String, dynamic>.from(e);
            messageData['deleted_for_me'] =
                deletedMessageIds.contains(e['id'] as String);
            return MessageModel.fromJson(messageData);
          }).toList();

          yield messages;
        } catch (e) {
          logger.w('Error filtering deleted messages', error: e);
          yield data.map((e) => MessageModel.fromJson(e)).toList();
        }
      }
    } catch (e, s) {
      logger.e('Error in subscribeToMessages', error: e, stackTrace: s);
      yield [];
    }
  }

  /// Call this after deleteMessageForMe() so the next stream event reflects
  /// the updated set of deleted IDs without a full stream restart.
  Future<Set<String>> refreshDeletedMessages(String userId) =>
      _getUserDeletedMessages(userId);

  // ============================================================================
  // DELETE CONVERSATION (HARD DELETE - ADMIN ONLY)
  // ============================================================================
  Future<void> deleteConversation(String conversationId) async {
    try {
      await supabaseClient
          .from(AppConstants.messagesTable)
          .delete()
          .eq('conversation_id', conversationId)
          .timeout(const Duration(seconds: 10));

      await supabaseClient
          .from(AppConstants.conversationsTable)
          .delete()
          .eq('id', conversationId)
          .timeout(const Duration(seconds: 5));

      logger.d('Conversation deleted: $conversationId');
    } catch (e, s) {
      logger.e('Error deleting conversation', error: e, stackTrace: s);
      throw ServerException('Failed to delete conversation: ${e.toString()}');
    }
  }

  // ============================================================================
  // EDIT MESSAGE
  // ============================================================================
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      await supabaseClient
          .from(AppConstants.messagesTable)
          .update({
            'content': newContent,
            'edited': true,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .timeout(const Duration(seconds: 5));

      logger.d('Message edited: $messageId');
    } catch (e, s) {
      logger.e('Error editing message', error: e, stackTrace: s);
      throw ServerException('Failed to edit message: ${e.toString()}');
    }
  }

  // ============================================================================
  // DELETE MESSAGE (HARD DELETE - FOR EVERYONE)
  // ============================================================================
  Future<void> deleteMessage(String messageId) async {
    try {
      logger.i('🔥 HARD DELETE: Deleting message from database: $messageId');

      final messageData = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('conversation_id, created_at')
          .eq('id', messageId)
          .single();

      final conversationId = messageData['conversation_id'] as String;

      await supabaseClient
          .from(AppConstants.messagesTable)
          .delete()
          .eq('id', messageId)
          .timeout(const Duration(seconds: 5));

      logger.d('✅ Message hard deleted from database: $messageId');

      await _updateConversationLastMessage(conversationId);

      await supabaseClient
          .from('user_deleted_messages')
          .delete()
          .eq('message_id', messageId)
          .timeout(const Duration(seconds: 3));

      logger.d('✅ Cleaned up soft delete records for message: $messageId');
    } catch (e, s) {
      logger.e('Error in deleteMessage', error: e, stackTrace: s);
      throw ServerException('Failed to delete message: ${e.toString()}');
    }
  }

  // ============================================================================
  // DELETE MULTIPLE MESSAGES (HARD DELETE)
  // ============================================================================
  Future<void> deleteMessages(Set<String> messageIds) async {
    try {
      logger.d('Hard deleting ${messageIds.length} messages');

      final messagesData = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('conversation_id')
          .inFilter('id', messageIds.toList());

      final conversationIds = (messagesData as List)
          .map((m) => m['conversation_id'] as String)
          .toSet();

      await supabaseClient
          .from(AppConstants.messagesTable)
          .delete()
          .inFilter('id', messageIds.toList())
          .timeout(const Duration(seconds: 10));

      logger.d('${messageIds.length} messages deleted');

      for (final conversationId in conversationIds) {
        await _updateConversationLastMessage(conversationId);
      }

      await supabaseClient
          .from('user_deleted_messages')
          .delete()
          .inFilter('message_id', messageIds.toList())
          .timeout(const Duration(seconds: 5));
    } catch (e, s) {
      logger.e('Error deleting messages', error: e, stackTrace: s);
      throw ServerException('Failed to delete messages: ${e.toString()}');
    }
  }

  // ============================================================================
  // DELETE MESSAGE FOR ME (SOFT DELETE)
  // ============================================================================
  Future<void> deleteMessageForMe({
    required String messageId,
    required String userId,
  }) async {
    try {
      logger.d('Marking message as deleted for user: $messageId');

      final messageData = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('conversation_id')
          .eq('id', messageId)
          .single();

      final conversationId = messageData['conversation_id'] as String;

      final now = DateTime.now().toIso8601String();
      await supabaseClient
          .from('user_deleted_messages')
          .upsert({
            'message_id': messageId,
            'user_id': userId,
            'deleted_at': now,
          })
          .timeout(const Duration(seconds: 5));

      logger.d('Message marked as deleted for user');

      final allMessages = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('id, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1);

      if ((allMessages as List).isNotEmpty &&
          allMessages.first['id'] == messageId) {
        await _updateConversationLastMessageForUser(conversationId, userId);
      }
    } catch (e, s) {
      logger.e('Error in deleteMessageForMe', error: e, stackTrace: s);
      throw ServerException('Failed to delete message: ${e.toString()}');
    }
  }

  // ============================================================================
  // DELETE MULTIPLE MESSAGES FOR ME (SOFT DELETE)
  // ============================================================================
  Future<void> deleteMessagesForMe({
    required Set<String> messageIds,
    required String userId,
  }) async {
    try {
      logger.d('Marking ${messageIds.length} messages as deleted for user');

      final messagesData = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('id, conversation_id')
          .inFilter('id', messageIds.toList());

      final conversationIds = (messagesData as List)
          .map((m) => m['conversation_id'] as String)
          .toSet();

      final now = DateTime.now().toIso8601String();
      final records = messageIds
          .map((messageId) => {
                'message_id': messageId,
                'user_id': userId,
                'deleted_at': now,
              })
          .toList();

      await supabaseClient
          .from('user_deleted_messages')
          .upsert(records)
          .timeout(const Duration(seconds: 10));

      logger.d('${messageIds.length} messages marked as deleted');

      for (final conversationId in conversationIds) {
        await _updateConversationLastMessageForUser(conversationId, userId);
      }
    } catch (e, s) {
      logger.e('Error in deleteMessagesForMe', error: e, stackTrace: s);
      throw ServerException('Failed to delete messages: ${e.toString()}');
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  Future<ConversationModel> _buildConversationModel(
    Map<String, dynamic> conversationData,
    String currentUserId,
  ) async {
    try {
      final otherUserId = (conversationData['user1_id'] == currentUserId
          ? conversationData['user2_id']
          : conversationData['user1_id']) as String;

      final userData = await _getOtherUserData(otherUserId);

      dynamic property;
      if (conversationData['property_id'] != null) {
        property = await _getPropertyData(conversationData['property_id']);
      }

      final deletedMessageIds = await _getUserDeletedMessages(currentUserId);
      final unreadCount = await _getUnreadCount(
        conversationData['id'],
        currentUserId,
        deletedMessageIds,
      );

      final model = {
        'id': conversationData['id'],
        'property_id': conversationData['property_id'],
        'property_title':
            property != null ? property['title'] : 'Direct Message',
        'property_image': property != null &&
                property['images'] != null &&
                (property['images'] as List).isNotEmpty
            ? property['images'][0]
            : null,
        'other_user_id': otherUserId,
        'other_user_name': userData['full_name'] ?? 'User',
        'other_user_avatar': userData['avatar_url'],
        'last_message': conversationData['last_message'],
        'last_message_time': conversationData['last_message_time'],
        'unread_count': unreadCount,
        'created_at': conversationData['created_at'],
      };

      return ConversationModel.fromJson(model);
    } catch (e, s) {
      logger.e('Error building conversation model', error: e, stackTrace: s);
      throw ServerException('Failed to build conversation: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> _getOtherUserData(String userId) async {
    try {
      final userData = await supabaseClient
          .from(AppConstants.usersTable)
          .select('id, full_name, avatar_url')
          .eq('id', userId)
          .single()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => {
              'id': userId,
              'full_name': 'User',
              'avatar_url': null,
            },
          );

      return userData;
    } catch (e) {
      logger.w('Error fetching user data, using defaults', error: e);
      return {
        'id': userId,
        'full_name': 'User',
        'avatar_url': null,
      };
    }
  }

  Future<Map<String, dynamic>?> _getPropertyData(String propertyId) async {
    try {
      final propertyData = await supabaseClient
          .from(AppConstants.propertiesTable)
          .select('id, title, images')
          .eq('id', propertyId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      if (propertyData != null) {
        logger.d('Property data fetched: ${propertyData['title']}');
        return propertyData;
      }
      return null;
    } catch (e) {
      logger.w('Error fetching property', error: e);
      return null;
    }
  }

  Future<Set<String>> _getUserDeletedMessages(String userId) async {
    try {
      final deletedMessages = await supabaseClient
          .from('user_deleted_messages')
          .select('message_id')
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));

      return (deletedMessages as List)
          .map((e) => e['message_id'] as String)
          .toSet();
    } catch (e) {
      logger.w('Error fetching deleted messages', error: e);
      return {};
    }
  }

  Future<int> _getUnreadCount(
    String conversationId,
    String userId,
    Set<String> deletedMessageIds,
  ) async {
    try {
      final unreadMessages = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', userId)
          .timeout(const Duration(seconds: 3));

      return (unreadMessages as List)
          .where((msg) => !deletedMessageIds.contains(msg['id']))
          .length;
    } catch (e) {
      logger.w('Error calculating unread count', error: e);
      return 0;
    }
  }

  Future<void> _updateConversationLastMessage(String conversationId) async {
    try {
      final lastMessage = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('content, type, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastMessage != null) {
        await supabaseClient
            .from(AppConstants.conversationsTable)
            .update({
              'last_message': _formatMessageContent(lastMessage),
              'last_message_time': lastMessage['created_at'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', conversationId);
      } else {
        await supabaseClient
            .from(AppConstants.conversationsTable)
            .update({
              'last_message': null,
              'last_message_time': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', conversationId);
      }
    } catch (e) {
      logger.w('Error updating conversation last message', error: e);
    }
  }

  Future<void> _updateConversationLastMessageForUser(
    String conversationId,
    String userId,
  ) async {
    try {
      final deletedMessageIds = await _getUserDeletedMessages(userId);

      final allMessages = await supabaseClient
          .from(AppConstants.messagesTable)
          .select('id, content, type, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false);

      final visibleMessages = (allMessages as List)
          .where((msg) => !deletedMessageIds.contains(msg['id']))
          .toList();

      if (visibleMessages.isNotEmpty) {
        final lastMessage = visibleMessages.first;
        await supabaseClient
            .from(AppConstants.conversationsTable)
            .update({
              'last_message': _formatMessageContent(lastMessage),
              'last_message_time': lastMessage['created_at'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', conversationId);
      } else {
        await supabaseClient
            .from(AppConstants.conversationsTable)
            .update({
              'last_message': null,
              'last_message_time': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', conversationId);
      }
    } catch (e) {
      logger.w('Error updating conversation last message for user', error: e);
    }
  }

  String _formatMessageContent(Map<String, dynamic> message) {
    String content = message['content'];
    final type = message['type'];

    if (type == 'property') {
      if (content.contains('|||')) {
        final parts = content.split('|||');
        if (parts.length == 2 && parts[1].isNotEmpty) {
          return parts[1];
        } else if (parts[0].contains('|')) {
          final propParts = parts[0].split('|');
          if (propParts.length == 2) return propParts[1];
        }
      } else if (content.contains('|')) {
        final parts = content.split('|');
        if (parts.length == 2) return parts[1];
      }
    }
    return content;
  }
}
