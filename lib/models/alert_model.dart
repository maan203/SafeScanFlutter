import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType { scan, sos, location, lostFound, parking, incident, emergency }

class AlertModel {
  final String id;
  final String title;
  final String body;
  final AlertType type;
  final bool isRead;
  final DateTime createdAt;
  final String? assetId;
  final String? location;

  const AlertModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.assetId,
    this.location,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: AlertType.values.firstWhere(
        (e) => e.name == (d['type'] ?? 'scan'),
        orElse: () => AlertType.scan,
      ),
      isRead: d['isRead'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assetId: d['assetId'],
      location: d['location'],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type.name,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
        'assetId': assetId,
        'location': location,
      };

  AlertModel copyWith({bool? isRead}) {
    return AlertModel(
      id: id,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      assetId: assetId,
      location: location,
    );
  }

  IconData get icon {
    switch (type) {
      case AlertType.scan: return Icons.qr_code_scanner_rounded;
      case AlertType.sos: return Icons.warning_rounded;
      case AlertType.location: return Icons.location_on_rounded;
      case AlertType.lostFound: return Icons.search_rounded;
      case AlertType.parking: return Icons.local_parking_rounded;
      case AlertType.incident: return Icons.report_gmailerrorred_rounded;
      case AlertType.emergency: return Icons.emergency_rounded;
    }
  }

  Color get color {
    switch (type) {
      case AlertType.scan: return const Color(0xFF22C55E);
      case AlertType.sos: return const Color(0xFFEF4444);
      case AlertType.location: return const Color(0xFF3B82F6);
      case AlertType.lostFound: return const Color(0xFF8B5CF6);
      case AlertType.parking: return const Color(0xFFF59E0B);
      case AlertType.incident: return const Color(0xFFEF4444);
      case AlertType.emergency: return const Color(0xFFB91C1C);
    }
  }
}
