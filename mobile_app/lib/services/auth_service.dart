import 'package:firebase_auth/firebase_auth.dart';
import 'package:bell_pepper_app/services/credential_store.dart';

/// Thin wrapper around [FirebaseAuth] so screens depend on this instead of
/// the Firebase SDK directly.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, CredentialStore? credentialStore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _credentialStore = credentialStore ?? CredentialStore();

  final FirebaseAuth _firebaseAuth;
  final CredentialStore _credentialStore;

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

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _credentialStore.clear();
  }
}
