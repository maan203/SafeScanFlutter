import 'package:cloud_firestore/cloud_firestore.dart';

class ContactModel {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  const ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    this.isPrimary = false,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory ContactModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ContactModel(
      id: doc.id,
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      relation: d['relation'] ?? 'Contact',
      isPrimary: d['isPrimary'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'relation': relation,
        'isPrimary': isPrimary,
      };

  ContactModel copyWith({bool? isPrimary}) {
    return ContactModel(
      id: id,
      name: name,
      phone: phone,
      relation: relation,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
