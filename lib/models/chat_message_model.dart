import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? '',
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
