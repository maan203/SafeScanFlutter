import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<String?> getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [p.subLocality, p.locality, p.administrativeArea]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      return parts.take(2).join(', ');
    } catch (_) {
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  Future<void> startSharingLocation(String uid, List<String> contactIds) async {
    final pos = await getCurrentPosition();
    if (pos == null) return;
    final address = await getAddressFromPosition(pos);
    await _db.collection('live_locations').doc(uid).set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'address': address,
      'isSharing': true,
      'sharedWith': contactIds,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> stopSharingLocation(String uid) async {
    await _db.collection('live_locations').doc(uid).update({
      'isSharing': false,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateLiveLocation(String uid, Position position) async {
    final address = await getAddressFromPosition(position);
    await _db.collection('live_locations').doc(uid).update({
      'lat': position.latitude,
      'lng': position.longitude,
      'address': address,
      'updatedAt': Timestamp.now(),
    });
  }

  Stream<DocumentSnapshot> watchLocation(String uid) {
    return _db.collection('live_locations').doc(uid).snapshots();
  }
}
