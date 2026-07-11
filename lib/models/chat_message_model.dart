import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageType { text, image, location }

class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final ChatMessageType type;
  final String? imageBase64;
  final double? lat;
  final double? lng;
  final String? locationLabel;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.type = ChatMessageType.text,
    this.imageBase64,
    this.lat,
    this.lng,
    this.locationLabel,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? '',
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: ChatMessageType.values.firstWhere(
        (e) => e.name == (d['type'] ?? 'text'),
        orElse: () => ChatMessageType.text,
      ),
      imageBase64: d['imageBase64'],
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      locationLabel: d['locationLabel'],
    );
  }
}
