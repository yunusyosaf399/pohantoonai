import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';

void main() {
  test('Web callback preserves localhost port and root path', () {
    expect(
      oauthRedirectForApp(
        isWeb: true,
        currentUri: Uri.parse('http://localhost:53719/#/welcome'),
      ),
      'http://localhost:53719/',
    );
  });

  test('Web callback keeps non-root hosting path and removes tokens', () {
    expect(
      oauthRedirectForApp(
        isWeb: true,
        currentUri: Uri.parse(
          'https://app.example.org/pohantoonai/?code=temporary'
          '#access_token=do-not-keep',
        ),
      ),
      'https://app.example.org/pohantoonai/',
    );
  });

  test('Web callback removes OAuth query and fragment from routed URL', () {
    expect(
      oauthRedirectForApp(
        isWeb: true,
        currentUri: Uri.parse(
          'https://app.example.org/schools?tab=all#access_token=secret',
        ),
      ),
      'https://app.example.org/schools',
    );
  });

  test('Web callback rejects non-HTTP schemes', () {
    expect(
      () => oauthRedirectForApp(
        isWeb: true,
        currentUri: Uri.parse('file:///index.html'),
      ),
      throwsFormatException,
    );
  });

  test('Android, iOS, macOS and Windows share a registered callback', () {
    expect(
      oauthRedirectForApp(
        isWeb: false,
        currentUri: Uri.parse('https://unrelated.example.org'),
      ),
      'pohantoonai://auth-callback',
    );
  });
}
