import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembered email/password for the "Remember me" login option, backed by
/// the platform keychain/keystore (not plain SharedPreferences, since a
/// password is sensitive). Cleared on sign-out so the next session always
/// starts from a blank login form.
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _emailKey = 'remembered_email';
  static const _passwordKey = 'remembered_password';

  Future<void> save({required String email, required String password}) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<({String email, String password})?> read() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}
