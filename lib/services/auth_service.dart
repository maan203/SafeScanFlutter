import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _fetchUserModel(cred.user!.uid);
  }

  Future<UserModel?> signUp(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = UserModel(
      uid: cred.user!.uid,
      name: name.trim(),
      email: email.trim(),
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(user.uid).set(user.toMap());
    return user;
  }

  Future<UserModel?> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final gAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final uid = cred.user!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      final user = UserModel(
        uid: uid,
        name: cred.user!.displayName ?? 'User',
        email: cred.user!.email ?? '',
        photoUrl: cred.user!.photoURL,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(uid).set(user.toMap());
      return user;
    }
    return UserModel.fromFirestore(doc);
  }

  /// Signs in without a real account — used by someone who scanned a
  /// found-item QR code and wants to chat with the owner without creating
  /// a full SafeScan account. Free (Firebase Anonymous Auth), persists on
  /// this device until they explicitly sign out.
  Future<UserModel?> signInAnonymously(String displayName) async {
    final existing = _auth.currentUser;
    if (existing != null && existing.isAnonymous) {
      return _fetchUserModel(existing.uid);
    }
    final cred = await _auth.signInAnonymously();
    final uid = cred.user!.uid;
    final user = UserModel(
      uid: uid,
      name: displayName.trim().isEmpty ? 'Guest' : displayName.trim(),
      email: '',
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(uid).set(user.toMap());
    return user;
  }

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserModel?> _fetchUserModel(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchUserModel(user.uid);
  }

  Future<void> updateProfile(String uid, {String? name, String? photoUrl}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (updates.isNotEmpty) {
      await _db.collection('users').doc(uid).update(updates);
    }
  }
}
