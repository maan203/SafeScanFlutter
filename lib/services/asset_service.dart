import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asset_model.dart';
import 'sms_util.dart';

/// Result of an emergency relay — tells the UI whether an SMS composer
/// was actually opened, so it doesn't falsely claim contacts were alerted.
class EmergencyRelayResult {
  final int contactCount;
  final bool smsComposerOpened;
  const EmergencyRelayResult({required this.contactCount, required this.smsComposerOpened});
}

class AssetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _assets => _db.collection('assets');

  Stream<List<AssetModel>> watchAssets(String uid) {
    // Sorted client-side rather than via .orderBy() so this doesn't require
    // a composite Firestore index on (userId, createdAt).
    return _assets.where('userId', isEqualTo: uid).snapshots().map((s) {
      final list = s.docs.map(AssetModel.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<AssetModel> addAsset(String uid, AssetModel asset) async {
    await _assets.add(asset.toMap());
    return asset.copyWith();
  }

  Future<void> updateAsset(String uid, String assetId, Map<String, dynamic> data) async {
    await _assets.doc(assetId).update(data);
  }

  Future<void> deleteAsset(String uid, String assetId) async {
    await _assets.doc(assetId).delete();
  }

  Future<void> toggleActive(String uid, String assetId, bool isActive) async {
    await _assets.doc(assetId).update({'isActive': isActive});
  }

  Future<AssetModel?> getAsset(String uid, String assetId) async {
    final doc = await _assets.doc(assetId).get();
    if (!doc.exists) return null;
    return AssetModel.fromFirestore(doc);
  }

  /// Looked up by anyone who scans the QR code — no ownership check.
  /// Used by the public "found this item" screen.
  Future<AssetModel?> getPublicAsset(String assetId) async {
    final doc = await _assets.doc(assetId).get();
    if (!doc.exists) return null;
    return AssetModel.fromFirestore(doc);
  }

  /// Called when someone (owner or a stranger) scans an asset's QR code.
  /// Writes a scan event and notifies the owner via an alert doc.
  Future<void> recordScan(AssetModel asset, String? location) async {
    await _assets.doc(asset.id).update({
      'scanCount': FieldValue.increment(1),
    });
    await _db.collection('scan_events').add({
      'assetId': asset.id,
      'ownerId': asset.userId,
      'location': location,
      'scannedAt': Timestamp.now(),
    });
    await _db.collection('users').doc(asset.userId).collection('alerts').add({
      'title': 'Your QR was scanned',
      'body': location != null ? 'Scanned at $location' : 'Your asset QR code was just scanned',
      'type': 'scan',
      'assetId': asset.id,
      'location': location,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  /// Someone who scanned this QR believes there's a real emergency
  /// (accident, injury, lost child) and can't reach the owner directly.
  /// Relays straight to the owner's own emergency contacts via SMS —
  /// the same free, one-tap-to-send mechanism used by the SOS feature —
  /// and separately logs an alert for the owner in case they're fine.
  Future<EmergencyRelayResult> triggerEmergencyRelay(AssetModel asset, String? location, String? mapsLink) async {
    final numbers = asset.emergencyContacts.map((c) => c.phone).where((p) => p.isNotEmpty).toList();

    bool smsOpened = false;
    if (numbers.isNotEmpty) {
      final message = 'EMERGENCY: Someone scanned a SafeScan QR code on ${asset.userName}\'s ${asset.name}'
          '${location != null ? ' near $location' : ''} and believes there may be an emergency '
          '(accident, injury, or a lost person).'
          '${mapsLink != null ? ' Location: $mapsLink' : ''}'
          ' Sent via SafeScan.';
      smsOpened = await openSmsComposer(numbers, message);
    }

    await _db.collection('users').doc(asset.userId).collection('alerts').add({
      'title': 'Emergency reported for ${asset.name}',
      'body': smsOpened
          ? 'Someone scanned this QR in a possible emergency and texted ${numbers.length} of your emergency contact${numbers.length == 1 ? '' : 's'}.'
          : numbers.isEmpty
              ? 'Someone scanned this QR in a possible emergency, but no emergency contacts are set up for this asset.'
              : 'Someone scanned this QR in a possible emergency, but their messaging app could not be opened automatically.',
      'type': 'emergency',
      'assetId': asset.id,
      'location': location,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });

    return EmergencyRelayResult(contactCount: numbers.length, smsComposerOpened: smsOpened);
  }
}
