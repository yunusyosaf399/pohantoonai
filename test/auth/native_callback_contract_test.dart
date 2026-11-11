import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/config/supabase_configuration.dart';

/// Static native-config regression checks. Do not feed real OAuth code or
/// session tokens into these tests: these cover routing only, not login.
void main() {
  test('all native platforms register one identical Auth callback scheme', () {
    expect(SupabaseConfiguration.mobileRedirect,
        'pohantoonai://auth-callback');

    final android = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(android, contains('android:scheme="pohantoonai"'));
    expect(android, contains('android:host="auth-callback"'));
    expect(android, contains('android:launchMode="singleTop"'));
    expect(android, contains('android:name="flutter_deeplinking_enabled"'));
    expect(android, contains('android:value="false"'));

    for (final file in [
      'ios/Runner/Info.plist',
      'macos/Runner/Info.plist',
    ]) {
      final plist = File(file).readAsStringSync();
      expect(plist, contains('<key>CFBundleURLSchemes</key>'));
      expect(plist, contains('<string>pohantoonai</string>'));
      expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>'));
      expect(plist, contains('<false/>'));
    }
  });

  test('unpackaged Windows runner registers and forwards Auth links', () {
    final windows = File('windows/runner/main.cpp').readAsStringSync();
    expect(windows, contains('SendAppLinkToInstance()'));
    expect(windows, contains('RegisterPohantoonAuthProtocol()'));
    expect(windows, contains('Software\\\\Classes\\\\pohantoonai'));
    expect(windows, contains('URL Protocol'));
    expect(windows, contains('KEY_SET_VALUE'));
    expect(windows, contains('HKEY_CURRENT_USER'));
  });
}
