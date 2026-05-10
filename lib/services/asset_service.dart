import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asset_model.dart';

class AssetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _col(String uid) =>
      _db.collection('users').doc(uid).collection('assets');

  Stream<List<AssetModel>> watchAssets(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AssetModel.fromFirestore).toList());
  }

  Future<AssetModel> addAsset(String uid, AssetModel asset) async {
    await _col(uid).add(asset.toMap());
    return asset.copyWith();
  }

  Future<void> updateAsset(String uid, String assetId, Map<String, dynamic> data) async {
    await _col(uid).doc(assetId).update(data);
  }

  Future<void> deleteAsset(String uid, String assetId) async {
    await _col(uid).doc(assetId).delete();
  }

  Future<void> toggleActive(String uid, String assetId, bool isActive) async {
    await _col(uid).doc(assetId).update({'isActive': isActive});
  }

  Future<AssetModel?> getAsset(String uid, String assetId) async {
    final doc = await _col(uid).doc(assetId).get();
    if (!doc.exists) return null;
    return AssetModel.fromFirestore(doc);
  }

  Future<void> recordScan(String uid, String assetId, String? location) async {
    await _col(uid).doc(assetId).update({
      'scanCount': FieldValue.increment(1),
    });
    await _db.collection('scan_events').add({
      'assetId': assetId,
      'ownerId': uid,
      'location': location,
      'scannedAt': Timestamp.now(),
    });
    await _db.collection('users').doc(uid).collection('alerts').add({
      'title': 'Your QR was scanned',
      'body': location != null ? 'Scanned at $location' : 'Your asset QR code was just scanned',
      'type': 'scan',
      'assetId': assetId,
      'location': location,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }
}
