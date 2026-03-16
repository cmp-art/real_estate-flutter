// features/chat/domain/entities/message_entity.dart

import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  image,
  property, 
  property_text, 
}

class MessageEntity extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final bool isRead;
  final DateTime createdAt;
  final bool? edited;
  final DateTime? editedAt;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool deletedForMe; // NEW: Track if message is deleted for current user

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.type = MessageType.text,
    this.isRead = false,
    required this.createdAt,
    this.edited,
    this.editedAt,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    this.deletedForMe = false, // Default to false
  });

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        senderName,
        content,
        type,
        isRead,
        createdAt,
        edited,
        editedAt,
        replyToId,
        replyToContent,
        replyToSenderName,
        deletedForMe,
      ];

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    MessageType? type,
    bool? isRead,
    DateTime? createdAt,
    bool? edited,
    DateTime? editedAt,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
    bool? deletedForMe,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      edited: edited ?? this.edited,
      editedAt: editedAt ?? this.editedAt,
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      deletedForMe: deletedForMe ?? this.deletedForMe,
    );
  }

  // Helper method to check if message should be shown to current user
  bool shouldShowToUser(String currentUserId) {
    // If message is deleted for current user, don't show it
    if (deletedForMe) {
      return false;
    }
    
    // For now, show all non-deleted messages
    // In the future, you might add more logic here
    return true;
  }

  // Check if this is the current user's message
  bool isMyMessage(String currentUserId) {
    return senderId == currentUserId;
  }
}