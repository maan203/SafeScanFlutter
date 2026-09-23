import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';
import 'contact_service.dart';
import 'location_service.dart';

/// Result of an SOS trigger: the logged event id plus everything the UI
/// needs to let the user pick WhatsApp or SMS per contact, each pre-filled
/// with the same location-aware message so only a tap on Send is left.
class SosResult {
  final String sosId;
  final List<ContactModel> contacts;
  final String message;
  const SosResult({required this.sosId, required this.contacts, required this.message});
}

class SosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ContactService _contactService = ContactService();
  final LocationService _locationService = LocationService();

  /// [onStatus] reports each stage as it happens so the UI can show real
  /// progress ("Getting your location…", "Notifying your contacts…")
  /// instead of one opaque spinner.
  Future<SosResult> triggerSos(String uid, {void Function(String)? onStatus}) async {
    onStatus?.call('Getting your location…');
    final position = await _locationService.getCurrentPosition();
    String? address;
    if (position != null) {
      address = await _locationService.getAddressFromPosition(position);
    }

    onStatus?.call('Notifying your contacts…');
    final contacts = await _contactService.getContacts(uid);

    final mapsLink = position != null ? 'https://maps.google.com/?q=${position.latitude},${position.longitude}' : null;
    final message = 'SOS! I need help.'
        '${address != null ? ' My location: $address.' : ''}'
        '${mapsLink != null ? ' $mapsLink' : ''}'
        ' Sent via SafeScan.';

    final doc = await _db.collection('sos_events').add({
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
      'body': contacts.isEmpty
          ? 'No emergency contacts to notify, add one in Emergency Contacts'
          : 'Choose WhatsApp or SMS to alert ${contacts.length} contact${contacts.length == 1 ? '' : 's'}, tap Send there to complete it',
      'type': 'sos',
      'location': address,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });

    return SosResult(sosId: doc.id, contacts: contacts, message: message);
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
