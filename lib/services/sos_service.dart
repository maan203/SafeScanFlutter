import 'package:cloud_firestore/cloud_firestore.dart';
import 'contact_service.dart';
import 'location_service.dart';

class SosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ContactService _contactService = ContactService();
  final LocationService _locationService = LocationService();

  Future<void> triggerSos(String uid) async {
    final position = await _locationService.getCurrentPosition();
    String? address;
    if (position != null) {
      address = await _locationService.getAddressFromPosition(position);
    }

    final contacts = await _contactService.getContacts(uid);

    await _db.collection('sos_events').add({
      'userId': uid,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'address': address,
      'contacts': contacts.map((c) => {'name': c.name, 'phone': c.phone}).toList(),
      'triggeredAt': Timestamp.now(),
      'resolved': false,
    });

    await _db.collection('users').doc(uid).collection('alerts').add({
      'title': 'SOS Triggered',
      'body': address != null
          ? 'Emergency alert sent from $address'
          : 'Emergency alert sent to ${contacts.length} contacts',
      'type': 'sos',
      'location': address,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> resolveSos(String sosId, String uid) async {
    await _db.collection('sos_events').doc(sosId).update({'resolved': true});
    await _db.collection('users').doc(uid).collection('alerts').add({
      'title': 'SOS Resolved',
      'body': 'Your emergency alert has been marked as resolved',
      'type': 'sos',
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }
}
