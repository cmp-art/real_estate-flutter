// features/chat/presentation/providers/chat_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../core/utils/logger.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/chat_repository_impl.dart';

// Chat Data Source Provider
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource(supabase);
});

// Chat Repository Provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.read(chatRemoteDataSourceProvider));
});

// Tracks conversation IDs that have been optimistically marked as read locally.
// This lets the badge disappear instantly on tap without waiting for a DB round-trip.
// The set is cleared when conversationsProvider re-fetches and returns fresh data.
final locallyReadConversationsProvider =
    StateProvider<Set<String>>((ref) => {});

// Conversations Provider
final conversationsProvider = FutureProvider<List<ConversationEntity>>((ref) async {
  final user = ref.watch(authNotifierProvider).value;
  if (user == null) return [];

  final repository = ref.read(chatRepositoryProvider);
  final result = await repository.getConversations(user.id);

  // After a fresh fetch from the DB, clear the optimistic local-read set.
  // This prevents stale "locally read" state from masking genuinely new messages
  // that arrive after the user has already tapped into a conversation.
  ref.read(locallyReadConversationsProvider.notifier).state = {};

  return result.fold(
    (failure) => [],
    (conversations) => conversations,
  );
});

// Messages Provider for a specific conversation
final messagesProvider = FutureProvider.family<List<MessageEntity>, String>(
  (ref, conversationId) async {
    final repository = ref.read(chatRepositoryProvider);
    final result = await repository.getMessages(conversationId);

    return result.fold(
      (failure) => [],
      (messages) => messages,
    );
  },
);

// Messages Stream Provider for real-time updates
final messagesStreamProvider = StreamProvider.autoDispose.family<List<MessageEntity>, String>(
  (ref, conversationId) {
    final repository = ref.read(chatRepositoryProvider);

    return repository.subscribeToMessages(conversationId).handleError((error) {
      logger.e('Stream provider error', error: error);
      return <MessageEntity>[];
    });
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// CHAT MESSAGES — reliable display source (replaces watching the raw stream)
//
// The chat view used to render straight off the realtime .stream(). When
// realtime is unavailable that stream errors and the datasource yields an empty
// list, which made every sent message "disappear". Instead this notifier:
//   1. fetches the messages once via getMessages() — reliable on native, web
//      AND pwa,
//   2. subscribes to realtime as a BEST-EFFORT live feed (errors are ignored,
//      and a spurious empty emission never blanks a non-empty conversation),
//   3. shows freshly-sent messages optimistically by their real DB id, so they
//      appear instantly even when realtime is down.
// ─────────────────────────────────────────────────────────────────────────────
class ChatMessagesNotifier
    extends StateNotifier<AsyncValue<List<MessageEntity>>> {
  ChatMessagesNotifier(this._repository, this.conversationId)
      : super(const AsyncValue.loading()) {
    _init();
  }

  final ChatRepository _repository;
  final String conversationId;

  StreamSubscription<List<MessageEntity>>? _sub;
  List<MessageEntity> _server = const [];
  final List<MessageEntity> _pending = [];

  Future<void> _init() async {
    // 1) Reliable initial fetch.
    final result = await _repository.getMessages(conversationId);
    result.fold(
      (failure) {
        if (_server.isEmpty && _pending.isEmpty) {
          state = AsyncValue.error(failure.message, StackTrace.current);
        }
      },
      (messages) {
        _server = messages;
        _emit();
      },
    );

    // 2) Best-effort realtime. Never let it blank an existing list or surface
    //    an error — the fetched messages above are the source of truth.
    _sub = _repository.subscribeToMessages(conversationId).listen(
      (messages) {
        if (messages.isEmpty && _server.isNotEmpty) return; // ignore error []
        _server = messages;
        _reconcilePending();
        _emit();
      },
      onError: (_) {/* keep last known good state */},
      cancelOnError: false,
    );
  }

  /// Optimistically show a just-sent (already persisted, real-id) message.
  void addLocal(MessageEntity message) {
    final exists = _server.any((m) => m.id == message.id) ||
        _pending.any((m) => m.id == message.id);
    if (exists) return;
    _pending.add(message);
    _emit();
  }

  /// Send + optimistically display. Returns the saved message, or null on error.
  Future<MessageEntity?> send({
    required String senderId,
    required String senderName,
    required String content,
    String type = 'text',
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    final result = await _repository.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );
    return result.fold(
      (failure) {
        logger.e('sendMessage failed', error: failure.message);
        return null;
      },
      (message) {
        addLocal(message);
        return message;
      },
    );
  }

  /// Re-fetch from the server (after an edit / delete).
  Future<void> reload() async {
    final result = await _repository.getMessages(conversationId);
    result.fold((_) {}, (messages) {
      _server = messages;
      _reconcilePending();
      _emit();
    });
  }

  void _reconcilePending() {
    if (_pending.isEmpty) return;
    final serverIds = _server.map((m) => m.id).toSet();
    _pending.removeWhere((m) => serverIds.contains(m.id));
  }

  void _emit() {
    final byId = <String, MessageEntity>{};
    for (final m in _server) {
      byId[m.id] = m;
    }
    for (final m in _pending) {
      byId.putIfAbsent(m.id, () => m);
    }
    // Newest first — the chat ListView is reverse:true, so index 0 sits at the
    // bottom where the most recent message belongs.
    final merged = byId.values.where((m) => !m.deletedForMe).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) state = AsyncValue.data(merged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final chatMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, AsyncValue<List<MessageEntity>>, String>(
  (ref, conversationId) =>
      ChatMessagesNotifier(ref.read(chatRepositoryProvider), conversationId),
);

// Chat Notifier for managing chat operations
class ChatNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repository;
  final Ref _ref;

  ChatNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  // Send a message (with optional type and reply parameters)
  Future<bool> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String type = 'text',
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    state = const AsyncValue.loading();

    final result = await _repository.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        logger.e('Failed to send message', error: failure.message);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _refreshMessageProviders(conversationId);
        return true;
      },
    );
  }

  // Delete conversation for current user only (soft delete)
  Future<bool> deleteConversationForMe({
    required String conversationId,
    required String userId,
  }) async {
    try {
      logger.d('Soft deleting conversation: $conversationId for user: $userId');

      state = const AsyncValue.loading();

      final messagesResult = await _repository.getMessages(conversationId);

      return await messagesResult.fold(
        (failure) {
          logger.e('Failed to get messages', error: failure.message);
          state = AsyncValue.error(failure.message, StackTrace.current);
          return false;
        },
        (messages) async {
          if (messages.isEmpty) {
            state = const AsyncValue.data(null);
            _ref.invalidate(conversationsProvider);
            return true;
          }

          final messageIds = messages
              .where((m) => !m.deletedForMe)
              .map((m) => m.id)
              .toSet();

          if (messageIds.isEmpty) {
            state = const AsyncValue.data(null);
            _ref.invalidate(conversationsProvider);
            return true;
          }

          final result = await _repository.deleteMessagesForMe(
            messageIds: messageIds,
            userId: userId,
          );

          return result.fold(
            (failure) {
              logger.e('Failed to delete messages', error: failure.message);
              state = AsyncValue.error(failure.message, StackTrace.current);
              return false;
            },
            (_) {
              state = const AsyncValue.data(null);
              _ref.invalidate(conversationsProvider);
              Future.delayed(const Duration(milliseconds: 200), () {
                _ref.refresh(conversationsProvider);
              });
              logger.d('Conversation soft deleted successfully: $conversationId');
              return true;
            },
          );
        },
      );
    } catch (e, stackTrace) {
      logger.e('Exception in deleteConversationForMe', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  // Delete multiple conversations for current user only (soft delete)
  Future<bool> deleteConversationsForMe({
    required Set<String> conversationIds,
    required String userId,
  }) async {
    try {
      logger.d('Soft deleting ${conversationIds.length} conversations for user: $userId');

      state = const AsyncValue.loading();

      int successCount = 0;

      for (final conversationId in conversationIds) {
        final success = await deleteConversationForMe(
          conversationId: conversationId,
          userId: userId,
        );

        if (success) {
          successCount++;
        }
      }

      if (successCount > 0) {
        _ref.invalidate(conversationsProvider);
        await Future.delayed(const Duration(milliseconds: 300));
        _ref.refresh(conversationsProvider);
        state = const AsyncValue.data(null);
        logger.d('Successfully deleted $successCount/${conversationIds.length} conversations');
        return true;
      }

      state = AsyncValue.error('Failed to delete conversations', StackTrace.current);
      return false;
    } catch (e, stackTrace) {
      logger.e('Exception in deleteConversationsForMe', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  // FIX: markAsRead performs ONLY the DB write — it does NOT invalidate
  // conversationsProvider. Invalidating mid-chat caused a race condition:
  //   1. User taps conversation → locallyReadConversationsProvider adds id (badge gone)
  //   2. markAsRead fires → invalidates conversationsProvider
  //   3. conversationsProvider re-fetches → clears locallyRead set
  //   4. If DB write hasn't committed yet, fresh fetch returns unread_count > 0
  //   5. Badge reappears 🐛
  //
  // Solution: The caller (ChatScreen.dispose) is responsible for triggering
  // the conversations refresh AFTER the screen closes and the DB write is done.
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _repository.markMessagesAsRead(
        conversationId: conversationId,
        userId: userId,
      );
      logger.d('markAsRead DB write complete for: $conversationId');
    } catch (e) {
      logger.w('markAsRead failed silently', error: e);
    }
    // ✅ Do NOT invalidate conversationsProvider here.
    // ChatScreen.dispose() handles the refresh after the user exits.
  }

  // Create or get conversation
  Future<ConversationEntity?> createConversation({
    required String userId,
    required String otherUserId,
    required String? propertyId,
  }) async {
    state = const AsyncValue.loading();

    final result = await _repository.getOrCreateConversation(
      userId: userId,
      otherUserId: otherUserId,
      propertyId: propertyId,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        logger.e('Failed to create conversation', error: failure.message);
        return null;
      },
      (conversation) {
        state = const AsyncValue.data(null);
        _ref.invalidate(conversationsProvider);
        return conversation;
      },
    );
  }

  // Delete conversation (hard delete - admin only)
  Future<bool> deleteConversation(String conversationId) async {
    state = const AsyncValue.loading();

    final result = await _repository.deleteConversation(conversationId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        logger.e('Failed to delete conversation', error: failure.message);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(conversationsProvider);
        return true;
      },
    );
  }

  // Edit message
  Future<bool> editMessage({
    required String messageId,
    required String conversationId,
    required String newContent,
  }) async {
    state = const AsyncValue.loading();

    final result = await _repository.editMessage(
      messageId: messageId,
      newContent: newContent,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        logger.e('Failed to edit message', error: failure.message);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _refreshMessageProviders(conversationId);
        return true;
      },
    );
  }

  // HARD DELETE - Delete for everyone
  Future<bool> deleteMessage({
    required String messageId,
    required String conversationId,
  }) async {
    try {
      logger.i('🔥 HARD DELETE - Deleting message for everyone: $messageId');

      final result = await _repository.deleteMessage(messageId);

      return result.fold(
        (failure) {
          state = AsyncValue.error(failure.message, StackTrace.current);
          logger.e('Failed to hard delete message', error: failure.message);
          return false;
        },
        (_) {
          state = const AsyncValue.data(null);
          _refreshMessageProviders(conversationId);
          logger.i('✅ Hard delete successful');
          return true;
        },
      );
    } catch (e, stackTrace) {
      logger.e('Exception in deleteMessage', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  // SOFT DELETE - Delete for me only
  Future<bool> deleteMessageForMe({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    try {
      logger.i('🗑️ SOFT DELETE - Deleting message for me only: $messageId');

      final result = await _repository.deleteMessageForMe(
        messageId: messageId,
        userId: userId,
      );

      return result.fold(
        (failure) {
          state = AsyncValue.error(failure.message, StackTrace.current);
          logger.e('Failed to soft delete message', error: failure.message);
          return false;
        },
        (_) {
          state = const AsyncValue.data(null);
          _refreshMessageProviders(conversationId);
          logger.i('✅ Soft delete successful');
          return true;
        },
      );
    } catch (e, stackTrace) {
      logger.e('Exception in deleteMessageForMe', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  // Delete multiple messages (hard delete)
  Future<bool> deleteMessages({
    required Set<String> messageIds,
    required String conversationId,
  }) async {
    state = const AsyncValue.loading();

    final result = await _repository.deleteMessages(messageIds);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        logger.e('Failed to delete messages', error: failure.message);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        _refreshMessageProviders(conversationId);
        return true;
      },
    );
  }

  // Soft delete multiple messages - only for current user
  Future<bool> deleteMessagesForMe({
    required Set<String> messageIds,
    required String conversationId,
    required String userId,
  }) async {
    try {
      final result = await _repository.deleteMessagesForMe(
        messageIds: messageIds,
        userId: userId,
      );

      return result.fold(
        (failure) {
          state = AsyncValue.error(failure.message, StackTrace.current);
          logger.e('Failed to soft delete messages', error: failure.message);
          return false;
        },
        (_) {
          state = const AsyncValue.data(null);
          _refreshMessageProviders(conversationId);
          return true;
        },
      );
    } catch (e, stackTrace) {
      logger.e('Exception in deleteMessagesForMe', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  // Refreshes only the message-level providers for a conversation.
  // Does NOT touch conversationsProvider — that is handled by ChatScreen.dispose
  // to avoid the unread-badge race condition.
  //
  // With `messages` published to Supabase Realtime (see PART 6 in sql5), the
  // open chat stream receives the INSERT/UPDATE/DELETE live, so the message
  // appears on its own. A SINGLE invalidate re-subscribes and re-fetches the
  // snapshot as a safety net. We deliberately do NOT also call refresh() right
  // after: invalidate + refresh tore the realtime channel down and re-created
  // it back-to-back, which could drop the very event carrying the new message.
  void _refreshMessageProviders(String conversationId) {
    _ref.invalidate(messagesStreamProvider(conversationId));
    _ref.invalidate(messagesProvider(conversationId));
  }
}

final chatNotifierProvider = StateNotifierProvider<ChatNotifier, AsyncValue<void>>((ref) {
  return ChatNotifier(ref.read(chatRepositoryProvider), ref);
});

// Total unread messages count provider — accounts for optimistic local reads
// so the bottom nav badge clears the moment the user taps a conversation.
final unreadMessagesCountProvider = Provider<int>((ref) {
  final conversationsAsync = ref.watch(conversationsProvider);
  final locallyRead = ref.watch(locallyReadConversationsProvider);

  return conversationsAsync.when(
    data: (conversations) {
      return conversations.fold<int>(
        0,
        (sum, conversation) {
          // If optimistically marked read, treat its unread count as 0
          if (locallyRead.contains(conversation.id)) return sum;
          return sum + conversation.unreadCount;
        },
      );
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});