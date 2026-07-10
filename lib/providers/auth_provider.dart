import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get isAnonymous => _service.isAnonymous;

  AuthProvider() {
    _service.authStateChanges.listen(_onAuthChanged);
  }

  void _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
    } else {
      _user = await _service.getCurrentUserModel();
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.signIn(email, password);
      _status = AuthStatus.authenticated;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.signUp(name, email, password);
      _status = AuthStatus.authenticated;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.signInWithGoogle();
      if (_user != null) {
        _status = AuthStatus.authenticated;
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> continueAsGuest(String displayName) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.signInAnonymously(displayName);
      _status = AuthStatus.authenticated;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.code == 'operation-not-allowed'
          ? 'Anonymous sign-in is not enabled for this Firebase project. Enable it in Firebase Console → Authentication → Sign-in method.'
          : _friendlyError(e.code);
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.resetPassword(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _status = AuthStatus.unauthenticated;
    _user = null;
    notifyListeners();
  }

  void refreshUser() async {
    if (_service.currentUser == null) return;
    _user = await _service.getCurrentUserModel();
    notifyListeners();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'network-request-failed': return 'No internet connection.';
      case 'too-many-requests': return 'Too many attempts. Try again later.';
      default: return 'Something went wrong. Please try again.';
    }
  }
}
