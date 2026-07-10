import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asset_model.dart';
import '../models/chat_model.dart';
import '../models/chat_message_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _chats => _db.collection('chats');

  Future<ChatModel?> findExistingChat(String assetId, String finderId) async {
    final snap = await _chats
        .where('assetId', isEqualTo: assetId)
        .where('finderId', isEqualTo: finderId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ChatModel.fromFirestore(snap.docs.first);
  }

  Future<ChatModel> startChat({
    required AssetModel asset,
    required String finderId,
    required String finderName,
  }) async {
    final existing = await findExistingChat(asset.id, finderId);
    if (existing != null) return existing;

    final name = finderName.trim().isEmpty ? 'Guest' : finderName.trim();
    final now = Timestamp.now();
    final openingMessage = '$name found your ${asset.name} and wants to arrange the return.';

    final doc = await _chats.add({
      'assetId': asset.id,
      'assetName': asset.name,
      'assetType': asset.type,
      'ownerId': asset.userId,
      'ownerName': asset.userName,
      'finderId': finderId,
      'finderName': name,
      'isClosed': false,
      'createdAt': now,
      'lastMessageAt': now,
      'lastMessageText': openingMessage,
      'lastMessageSenderId': finderId,
    });

    await doc.collection('messages').add({
      'senderId': finderId,
      'senderName': name,
      'text': openingMessage,
      'createdAt': now,
    });

    final snap = await doc.get();
    return ChatModel.fromFirestore(snap);
  }

  Future<ChatModel?> getChat(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    if (!doc.exists) return null;
    return ChatModel.fromFirestore(doc);
  }

  /// All chats where this uid is either the asset owner or the finder.
  Stream<List<ChatModel>> watchChats(String uid) {
    final ownerStream = _chats.where('ownerId', isEqualTo: uid).snapshots();
    final finderStream = _chats.where('finderId', isEqualTo: uid).snapshots();

    late final StreamController<List<ChatModel>> controller;
    List<ChatModel> ownerChats = [];
    List<ChatModel> finderChats = [];
    bool ownerLoaded = false;
    bool finderLoaded = false;

    void emit() {
      if (!ownerLoaded || !finderLoaded) return;
      final merged = {for (final c in [...ownerChats, ...finderChats]) c.id: c}.values.toList();
      merged.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      controller.add(merged);
    }

    controller = StreamController<List<ChatModel>>.broadcast(
      onListen: () {
        ownerStream.listen((s) {
          ownerChats = s.docs.map(ChatModel.fromFirestore).toList();
          ownerLoaded = true;
          emit();
        }, onError: controller.addError);
        finderStream.listen((s) {
          finderChats = s.docs.map(ChatModel.fromFirestore).toList();
          finderLoaded = true;
          emit();
        }, onError: controller.addError);
      },
    );
    return controller.stream;
  }

  Stream<List<ChatMessageModel>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(ChatMessageModel.fromFirestore).toList());
  }

  Future<void> sendMessage(String chatId, String senderId, String senderName, String text) async {
    final chatRef = _chats.doc(chatId);
    final now = Timestamp.now();
    await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': now,
    });
    await chatRef.update({'lastMessageAt': now, 'lastMessageText': text, 'lastMessageSenderId': senderId});
  }

  Future<void> closeChat(String chatId) async {
    await _chats.doc(chatId).update({'isClosed': true});
  }

  /// Only closed (resolved) chats can be deleted — an open conversation
  /// shouldn't disappear out from under the other participant.
  Future<void> deleteChat(String chatId) async {
    await _chats.doc(chatId).delete();
  }
}
