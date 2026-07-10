import 'package:cloud_firestore/cloud_firestore.dart';
import 'contact_service.dart';
import 'location_service.dart';
import 'sms_util.dart';

/// Result of an SOS trigger — tells the UI whether an SMS composer was
/// actually opened, so it doesn't falsely claim the alert was "sent"
/// (no permission-free way exists to send SMS with zero user interaction).
class SosResult {
  final int contactCount;
  final bool smsComposerOpened;
  const SosResult({required this.contactCount, required this.smsComposerOpened});
}

class SosService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ContactService _contactService = ContactService();
  final LocationService _locationService = LocationService();

  Future<SosResult> triggerSos(String uid) async {
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

    bool smsOpened = false;
    final numbers = contacts.map((c) => c.phone).where((p) => p.isNotEmpty).toList();
    if (numbers.isNotEmpty) {
      final mapsLink = position != null
          ? 'https://maps.google.com/?q=${position.latitude},${position.longitude}'
          : null;
      final message = 'SOS! I need help.'
          '${address != null ? ' My location: $address.' : ''}'
          '${mapsLink != null ? ' $mapsLink' : ''}'
          ' Sent via SafeScan.';
      smsOpened = await openSmsComposer(numbers, message);
    }

    await _db.collection('users').doc(uid).collection('alerts').add({
      'title': 'SOS Triggered',
      'body': smsOpened
          ? 'Messaging app opened to alert ${contacts.length} contact${contacts.length == 1 ? '' : 's'} — tap Send there to complete it'
          : contacts.isEmpty
              ? 'No emergency contacts to notify — add one in Emergency Contacts'
              : 'Could not open messaging app automatically',
      'type': 'sos',
      'location': address,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });

    return SosResult(contactCount: contacts.length, smsComposerOpened: smsOpened);
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
