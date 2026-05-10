import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';

class ContactService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _col(String uid) =>
      _db.collection('users').doc(uid).collection('contacts');

  Stream<List<ContactModel>> watchContacts(String uid) {
    return _col(uid)
        .snapshots()
        .map((s) => s.docs.map(ContactModel.fromFirestore).toList());
  }

  Future<void> addContact(String uid, ContactModel contact) async {
    await _col(uid).add(contact.toMap());
  }

  Future<void> deleteContact(String uid, String contactId) async {
    await _col(uid).doc(contactId).delete();
  }

  Future<void> setPrimary(String uid, String contactId) async {
    final batch = _db.batch();
    final all = await _col(uid).get();
    for (final doc in all.docs) {
      batch.update(doc.reference, {'isPrimary': doc.id == contactId});
    }
    await batch.commit();
  }

  Future<List<ContactModel>> getContacts(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs.map(ContactModel.fromFirestore).toList();
  }
}
