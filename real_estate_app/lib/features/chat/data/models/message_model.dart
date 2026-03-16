// features/chat/data/models/message_model.dart
import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.senderName,
    required super.content,
    super.type,
    super.isRead,
    required super.createdAt,
    super.edited,
    super.editedAt,
    super.replyToId,
    super.replyToContent,
    super.replyToSenderName,
    super.deletedForMe,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? 'User',
      content: json['content'] as String,
      type: _messageTypeFromString(json['type'] as String? ?? 'text'),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      edited: json['edited'] as bool?,
      editedAt: json['edited_at'] != null 
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      replyToId: json['reply_to_id'] as String?,
      replyToContent: json['reply_to_content'] as String?,
      replyToSenderName: json['reply_to_sender_name'] as String?,
      deletedForMe: json['deleted_for_me'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'type': _messageTypeToString(type),
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'edited': edited,
      'edited_at': editedAt?.toIso8601String(),
      'reply_to_id': replyToId,
      'reply_to_content': replyToContent,
      'reply_to_sender_name': replyToSenderName,
      'deleted_for_me': deletedForMe,
    };
  }

  static MessageType _messageTypeFromString(String type) {
  switch (type.toLowerCase()) {
    case 'image':
      return MessageType.image;
    case 'property':
      return MessageType.property;
    case 'property_text':
      return MessageType.property_text;
    case 'text':
    default:
      return MessageType.text;
  }
}

static String _messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.text:
      return 'text';
    case MessageType.image:
      return 'image';
    case MessageType.property:
      return 'property';
    case MessageType.property_text:
      return 'property_text';
  }
}
}