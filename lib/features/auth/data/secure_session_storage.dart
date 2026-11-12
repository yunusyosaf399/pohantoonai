import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the refreshable Supabase Auth session with Android Keystore-backed
/// encryption, not ordinary shared preferences. No password or access token
/// is ever copied to logging or a custom database table.
///
/// Keep this implementation aligned with supabase_flutter 2.18.x: it uses
/// LocalStorage. Supabase Flutter 3.x introduces AuthAsyncStorage instead.
class AndroidSecureSessionStorage extends LocalStorage {
  AndroidSecureSessionStorage({
    SecureSessionBackend? backend,
    LocalStorage? legacyStorage,
  }) : _backend=backend??const AndroidKeystoreSessionBackend(),
       _legacy=legacyStorage??SharedPreferencesLocalStorage(
         persistSessionKey:supabasePersistSessionKey);

  final SecureSessionBackend _backend;
  final LocalStorage _legacy;

  /// A one-time migration preserves an already-signed-in Android account.
  /// If encrypted storage fails, never fall back to storing NEW sessions
  /// in plaintext preferences.
  @override
  Future<void> initialize() async {
    await _legacy.initialize();
    final encrypted=await _backend.read();
    if(encrypted!=null) {
      // Clean up any plaintext copy left by an interrupted earlier migration.
      await _legacy.removePersistedSession();
      return;
    }
    final old=await _legacy.accessToken();
    if(old==null||old.isEmpty)return;
    await _backend.write(old);
    // Deleting the old value is safe only after verifying the encrypted
    // write succeeded. If interrupted, the next app boot repeats migration.
    if(await _backend.read()!=old) {
      throw StateError('Secure session migration could not be verified.');
    }
    await _legacy.removePersistedSession();
  }

  @override
  Future<String?> accessToken()=>_backend.read();

  @override
  Future<bool> hasAccessToken()=>_backend.contains();

  @override
  Future<void> persistSession(String persistSessionString)=>
      _backend.write(persistSessionString);

  @override
  Future<void> removePersistedSession() async {
    // On explicit sign-out, remove both the encrypted token and any legacy
    // copy so no previous session is resurrected after restarting the app.
    await _backend.delete();
    await _legacy.removePersistedSession();
  }
}

/// Injectable boundary for regression tests without an Android device.
abstract class SecureSessionBackend {
  Future<String?> read();
  Future<bool> contains();
  Future<void> write(String value);
  Future<void> delete();
}

class AndroidKeystoreSessionBackend implements SecureSessionBackend {
  const AndroidKeystoreSessionBackend();

  static const _key='pohantoonai.supabase.auth.session.v1';
  static const _storage=FlutterSecureStorage(
    aOptions:AndroidOptions(encryptedSharedPreferences:true),
  );

  @override
  Future<String?> read()=>_storage.read(key:_key);

  @override
  Future<bool> contains()=>_storage.containsKey(key:_key);

  @override
  Future<void> write(String value)=>
      _storage.write(key:_key,value:value);

  @override
  Future<void> delete()=>_storage.delete(key:_key);
}
