import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../models/chat_model.dart';

class ChatsProvider extends ChangeNotifier {
  final ChatService _service = ChatService();

  List<ChatModel> _chats = [];
  bool _loading = false;
  String? _error;
  bool _firstLoad = true;
  final Map<String, DateTime> _seenLastMessageAt = {};

  List<ChatModel> get chats => _chats;
  bool get loading => _loading;
  String? get error => _error;
  int get openCount => _chats.where((c) => !c.isClosed).length;

  void watchChats(String uid) {
    _loading = true;
    notifyListeners();
    _service.watchChats(uid).listen(
      (list) {
        if (_firstLoad) {
          for (final chat in list) {
            _seenLastMessageAt[chat.id] = chat.lastMessageAt;
          }
          _firstLoad = false;
        } else {
          for (final chat in list) {
            final seen = _seenLastMessageAt[chat.id];
            final isNewMessage = seen == null || chat.lastMessageAt.isAfter(seen);
            if (isNewMessage && chat.lastMessageSenderId.isNotEmpty && chat.lastMessageSenderId != uid) {
              NotificationService.instance.show(
                title: '${chat.otherPartyName(uid)} · ${chat.assetName}',
                body: chat.lastMessageText,
              );
            }
            _seenLastMessageAt[chat.id] = chat.lastMessageAt;
          }
        }
        _chats = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }
}
