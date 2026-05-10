import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _col(String uid) =>
      _db.collection('users').doc(uid).collection('alerts');

  Stream<List<AlertModel>> watchAlerts(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AlertModel.fromFirestore).toList());
  }

  Future<void> markRead(String uid, String alertId) async {
    await _col(uid).doc(alertId).update({'isRead': true});
  }

  Future<void> markAllRead(String uid) async {
    final batch = _db.batch();
    final unread = await _col(uid).where('isRead', isEqualTo: false).get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> addAlert(String uid, AlertModel alert) async {
    await _col(uid).add(alert.toMap());
  }
}
