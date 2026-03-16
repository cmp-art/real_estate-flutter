// features/chat/presentation/widgets/conversation_selection_manager.dart
import 'package:flutter/material.dart';
import '../../domain/entities/conversation_entity.dart';

class ConversationSelectionManager extends ChangeNotifier {
  final Set<String> _selectedConversationIds = {};
  bool _isSelectionMode = false;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedConversationIds => _selectedConversationIds;
  int get selectedCount => _selectedConversationIds.length;

  bool isSelected(String conversationId) => 
      _selectedConversationIds.contains(conversationId);

  void toggleSelection(ConversationEntity conversation) {
    if (_selectedConversationIds.contains(conversation.id)) {
      _selectedConversationIds.remove(conversation.id);
      if (_selectedConversationIds.isEmpty) {
        exitSelectionMode();
      }
    } else {
      _selectedConversationIds.add(conversation.id);
      if (!_isSelectionMode) {
        _isSelectionMode = true;
      }
    }
    notifyListeners();
  }

  void selectAll(List<ConversationEntity> conversations) {
    _selectedConversationIds.clear();
    _selectedConversationIds.addAll(conversations.map((c) => c.id));
    _isSelectionMode = true;
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedConversationIds.clear();
    notifyListeners();
  }
}