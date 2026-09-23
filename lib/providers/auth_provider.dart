import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      return false; // user closed the account picker without choosing one
    } on FirebaseAuthException catch (e) {
      _error = e.code == 'account-exists-with-different-credential'
          ? 'An account already exists with this email using a different sign-in method.'
          : _friendlyError(e.code);
      return false;
    } on PlatformException catch (e) {
      _error = switch (e.code) {
        'sign_in_canceled' || 'popup_closed' => null,
        'network_error' => 'No internet connection. Please try again.',
        'sign_in_failed' =>
          'Google Sign-In failed. This usually means Google Sign-In isn\'t fully configured for this app build. Please try again or use email sign-in.',
        _ => 'Google Sign-In failed: ${e.message ?? e.code}',
      };
      return false;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
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
      case 'user-not-found':
      case 'wrong-password':
      // Modern Firebase Auth returns this single code for both a wrong
      // password and an unknown email, to avoid revealing which one it was.
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password.';
      case 'user-disabled': return 'This account has been disabled. Contact support for help.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password': return 'Password must be at least 8 characters and include both letters and numbers.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'network-request-failed': return 'No internet connection. Please check your network and try again.';
      case 'too-many-requests': return 'Too many attempts. Please wait a moment and try again.';
      case 'requires-recent-login': return 'Please sign in again to continue.';
      case 'operation-not-allowed': return 'This sign-in method is not enabled. Please contact support.';
      default: return 'Something went wrong ($code). Please try again.';
    }
  }
}
