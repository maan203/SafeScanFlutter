import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String assetId;
  final String assetName;
  final String assetType;
  final String ownerId;
  final String ownerName;
  final String finderId;
  final String finderName;
  final bool isClosed;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String lastMessageText;
  final String lastMessageSenderId;

  const ChatModel({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.assetType,
    required this.ownerId,
    required this.ownerName,
    required this.finderId,
    required this.finderName,
    required this.isClosed,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessageText,
    required this.lastMessageSenderId,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      assetId: d['assetId'] ?? '',
      assetName: d['assetName'] ?? '',
      assetType: d['assetType'] ?? 'Other',
      ownerId: d['ownerId'] ?? '',
      ownerName: d['ownerName'] ?? 'Owner',
      finderId: d['finderId'] ?? '',
      finderName: d['finderName'] ?? 'Guest',
      isClosed: d['isClosed'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageText: d['lastMessageText'] ?? '',
      lastMessageSenderId: d['lastMessageSenderId'] ?? '',
    );
  }

  String otherPartyName(String uid) => uid == ownerId ? finderName : ownerName;

  IconData get assetIcon {
    switch (assetType) {
      case 'Vehicle': return Icons.directions_car_outlined;
      case 'Bicycle': return Icons.pedal_bike_outlined;
      case 'Laptop': return Icons.laptop_outlined;
      case 'Bag': return Icons.backpack_outlined;
      case 'Pet': return Icons.pets_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }
}
