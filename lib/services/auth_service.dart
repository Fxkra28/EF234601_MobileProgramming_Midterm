import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final email = user.email;
    if (email == null) {
      throw FirebaseAuthException(
          code: 'no-email', message: 'Account has no email');
    }
    final cred = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(cred);
    await user.delete();
  }

  String mapAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters.';
        case 'network-request-failed':
          return 'Network error — check your connection.';
        case 'too-many-requests':
          return 'Too many attempts. Try again in a few minutes.';
        case 'requires-recent-login':
          return 'Please sign in again to perform this action.';
        default:
          return error.message ?? 'Authentication failed (${error.code}).';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
