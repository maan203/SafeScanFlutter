import 'package:flutter/material.dart';
import '../services/contact_service.dart';
import '../models/contact_model.dart';

class ContactsProvider extends ChangeNotifier {
  final ContactService _service = ContactService();

  List<ContactModel> _contacts = [];
  bool _loading = false;
  String? _error;

  List<ContactModel> get contacts => _contacts;
  bool get loading => _loading;
  String? get error => _error;
  ContactModel? get primary =>
      _contacts.where((c) => c.isPrimary).firstOrNull;

  void watchContacts(String uid) {
    _loading = true;
    notifyListeners();
    _service.watchContacts(uid).listen(
      (list) {
        _contacts = list;
        _loading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> addContact(String uid, ContactModel contact) async {
    try {
      await _service.addContact(uid, contact);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteContact(String uid, String contactId) async {
    try {
      await _service.deleteContact(uid, contactId);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setPrimary(String uid, String contactId) async {
    try {
      await _service.setPrimary(uid, contactId);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
