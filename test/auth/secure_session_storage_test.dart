import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/auth/data/secure_session_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeLegacyStorage extends LocalStorage {
  String? saved;
  int deletes=0;
  @override
  Future<void> initialize()async{}
  @override
  Future<String?> accessToken()async=>saved;
  @override
  Future<bool> hasAccessToken()async=>saved!=null;
  @override
  Future<void> persistSession(String value)async{saved=value;}
  @override
  Future<void> removePersistedSession()async{
    deletes++;
    saved=null;
  }
}

class FakeSecureStorage implements SecureSessionBackend {
  String? saved;
  bool throwOnWrite=false;
  @override
  Future<String?> read()async=>saved;
  @override
  Future<bool> contains()async=>saved!=null;
  @override
  Future<void> write(String value)async {
    if(throwOnWrite)throw StateError('secure storage unavailable');
    saved=value;
  }
  @override
  Future<void> delete()async{saved=null;}
}

void main(){
  test('existing Android SharedPreferences session moves to encrypted store',
      () async {
    final old=FakeLegacyStorage()..saved='legacy-session-fixture';
    final encrypted=FakeSecureStorage();
    final storage=AndroidSecureSessionStorage(
      backend:encrypted,legacyStorage:old);
    await storage.initialize();
    expect(await storage.accessToken(),'legacy-session-fixture');
    expect(await storage.hasAccessToken(),isTrue);
    expect(old.saved,isNull);
    expect(old.deletes,1);
  });

  test('new login survives simulated process restart; signout clears all',
      () async {
    final old=FakeLegacyStorage(),encrypted=FakeSecureStorage();
    final first=AndroidSecureSessionStorage(
      backend:encrypted,legacyStorage:old);
    await first.initialize();
    await first.persistSession('rotating-session-token-fixture');
    // The second object simulates the next app process with the SAME
    // device-backed secure store, not a second Supabase sign-in.
    final nextLaunch=AndroidSecureSessionStorage(
      backend:encrypted,legacyStorage:old);
    await nextLaunch.initialize();
    expect(await nextLaunch.accessToken(),'rotating-session-token-fixture');
    expect(await nextLaunch.hasAccessToken(),isTrue);
    await nextLaunch.removePersistedSession();
    final afterLogout=AndroidSecureSessionStorage(
      backend:encrypted,legacyStorage:old);
    await afterLogout.initialize();
    expect(await afterLogout.accessToken(),isNull);
    expect(old.saved,isNull);
  });

  test('migration never deletes only copy after encrypted write fails',
      () async {
    final old=FakeLegacyStorage()..saved='existing-session';
    final encrypted=FakeSecureStorage()..throwOnWrite=true;
    final storage=AndroidSecureSessionStorage(
      backend:encrypted,legacyStorage:old);
    await expectLater(storage.initialize(),throwsStateError);
    expect(old.saved,'existing-session');
    expect(old.deletes,0);
    expect(encrypted.saved,isNull);
  });

  test('existing encrypted session wins over leftover plaintext copy',
      () async {
    final old=FakeLegacyStorage()..saved='outdated-plaintext';
    final encrypted=FakeSecureStorage()..saved='new-encrypted-session';
    final storage=AndroidSecureSessionStorage(
      backend:encrypted,legacyStorage:old);
    await storage.initialize();
    expect(await storage.accessToken(),'new-encrypted-session');
    expect(old.saved,isNull);
  });

  test('explicit logout clears stale old prefs and encrypted session',
      () async {
    final old=FakeLegacyStorage()..saved='old';
    final encrypted=FakeSecureStorage()..saved='new';
    final storage=AndroidSecureSessionStorage(
      backend:encrypted,legacyStorage:old);
    await storage.removePersistedSession();
    expect(await storage.hasAccessToken(),isFalse);
    expect(old.saved,isNull);
  });
}
