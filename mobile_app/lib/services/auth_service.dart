import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around [FirebaseAuth] so screens depend on this instead of
/// the Firebase SDK directly.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(fullName.trim());
    return credential;
  }

  /// Lets the "Continue as Demo User" button work without an account.
  /// Requires Anonymous sign-in to be enabled in the Firebase console.
  Future<UserCredential> signInAsDemoUser() {
    return _firebaseAuth.signInAnonymously();
  }

  Future<void> signOut() => _firebaseAuth.signOut();
}
