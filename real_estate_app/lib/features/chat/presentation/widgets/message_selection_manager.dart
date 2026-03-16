// features/chat/presentation/widgets/message_selection_manager.dart
import 'package:flutter/material.dart';
import '../../domain/entities/message_entity.dart';

class MessageSelectionManager extends ChangeNotifier {
  final Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedMessageIds => _selectedMessageIds;
  int get selectedCount => _selectedMessageIds.length;

  bool isSelected(String messageId) => _selectedMessageIds.contains(messageId);

  void toggleSelection(MessageEntity message) {
    if (_selectedMessageIds.contains(message.id)) {
      _selectedMessageIds.remove(message.id);
      if (_selectedMessageIds.isEmpty) {
        exitSelectionMode();
      }
    } else {
      _selectedMessageIds.add(message.id);
      if (!_isSelectionMode) {
        _isSelectionMode = true;
      }
    }
    notifyListeners();
  }

  void selectAll(List<MessageEntity> messages) {
    // Select ALL messages, not just user's messages
    _selectedMessageIds.clear();
    _selectedMessageIds.addAll(messages.map((m) => m.id));
    _isSelectionMode = true;
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedMessageIds.clear();
    notifyListeners();
  }

  void deleteSelected(Function(Set<String>) onDelete) {
    if (_selectedMessageIds.isNotEmpty) {
      onDelete(_selectedMessageIds);
      exitSelectionMode();
    }
  }
}