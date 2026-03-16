// features/chat/domain/repositories/chat_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

abstract class ChatRepository {
  Future<Either<Failure, List<ConversationEntity>>> getConversations(String userId);
  
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required String userId,
    required String otherUserId,
    required String? propertyId,
  });
  
  Future<Either<Failure, List<MessageEntity>>> getMessages(String conversationId);
  
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String type = 'text',
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  });
  
  Future<Either<Failure, void>> markMessagesAsRead({
    required String conversationId,
    required String userId,
  });
  
  Future<Either<Failure, void>> deleteConversation(String conversationId);
  
  Future<Either<Failure, void>> editMessage({
    required String messageId,
    required String newContent,
  });
  
  Future<Either<Failure, void>> deleteMessage(String messageId);
  
  Future<Either<Failure, void>> deleteMessages(Set<String> messageIds);
  
  // Soft delete - only for current user
  Future<Either<Failure, void>> deleteMessageForMe({
    required String messageId,
    required String userId,
  });
  
  // Soft delete multiple messages - only for current user
  Future<Either<Failure, void>> deleteMessagesForMe({
    required Set<String> messageIds,
    required String userId,
  });
  
  Stream<List<MessageEntity>> subscribeToMessages(String conversationId);
}