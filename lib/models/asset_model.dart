import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssetModel {
  final String id;
  final String name;
  final String type;
  final String? description;
  final String? phone;
  final String? rewardMessage;
  final bool showPhone;
  final bool showEmail;
  final bool isActive;
  final int scanCount;
  final DateTime createdAt;
  final String userId;

  const AssetModel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.phone,
    this.rewardMessage,
    this.showPhone = true,
    this.showEmail = true,
    this.isActive = true,
    this.scanCount = 0,
    required this.createdAt,
    required this.userId,
  });

  factory AssetModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AssetModel(
      id: doc.id,
      name: d['name'] ?? '',
      type: d['type'] ?? 'Other',
      description: d['description'],
      phone: d['phone'],
      rewardMessage: d['rewardMessage'],
      showPhone: d['showPhone'] ?? true,
      showEmail: d['showEmail'] ?? true,
      isActive: d['isActive'] ?? true,
      scanCount: d['scanCount'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: d['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'description': description,
        'phone': phone,
        'rewardMessage': rewardMessage,
        'showPhone': showPhone,
        'showEmail': showEmail,
        'isActive': isActive,
        'scanCount': scanCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'userId': userId,
      };

  AssetModel copyWith({bool? isActive, int? scanCount}) {
    return AssetModel(
      id: id,
      name: name,
      type: type,
      description: description,
      phone: phone,
      rewardMessage: rewardMessage,
      showPhone: showPhone,
      showEmail: showEmail,
      isActive: isActive ?? this.isActive,
      scanCount: scanCount ?? this.scanCount,
      createdAt: createdAt,
      userId: userId,
    );
  }

  IconData get icon {
    switch (type) {
      case 'Vehicle': return Icons.directions_car_outlined;
      case 'Bicycle': return Icons.pedal_bike_outlined;
      case 'Laptop': return Icons.laptop_outlined;
      case 'Bag': return Icons.backpack_outlined;
      case 'Pet': return Icons.pets_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }

  Color get color {
    switch (type) {
      case 'Vehicle': return const Color(0xFF3B82F6);
      case 'Bicycle': return const Color(0xFF22C55E);
      case 'Laptop': return const Color(0xFF8B5CF6);
      case 'Bag': return const Color(0xFFF59E0B);
      case 'Pet': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }
}
