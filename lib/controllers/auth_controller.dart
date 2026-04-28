import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;
  final FirestoreService _cloud = FirestoreService.instance;

  String? _errorMessage;
  bool _busy = false;

  String? get errorMessage => _errorMessage;
  bool get busy => _busy;
  Stream<User?> get authState => _auth.authState;
  User? get currentUser => _auth.currentUser;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _errorMessage = null;
    _setBusy(true);
    try {
      final cred = await _auth.signIn(email, password);
      final user = cred.user;
      if (user != null) {
        await _cloud.ensureProfile(
          uid: user.uid,
          email: user.email ?? email,
        );
      }
      return true;
    } catch (e) {
      _errorMessage = _auth.mapAuthError(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> register(String email, String password) async {
    _errorMessage = null;
    _setBusy(true);
    try {
      final cred = await _auth.register(email, password);
      final user = cred.user;
      if (user != null) {
        await _cloud.ensureProfile(
          uid: user.uid,
          email: user.email ?? email,
        );
      }
      return true;
    } catch (e) {
      _errorMessage = _auth.mapAuthError(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _errorMessage = null;
    _setBusy(true);
    try {
      await _auth.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _errorMessage = _auth.mapAuthError(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<bool> deleteAccount(String password) async {
    _errorMessage = null;
    _setBusy(true);
    try {
      await _auth.deleteAccount(password);
      return true;
    } catch (e) {
      _errorMessage = _auth.mapAuthError(e);
      return false;
    } finally {
      _setBusy(false);
    }
  }
}
