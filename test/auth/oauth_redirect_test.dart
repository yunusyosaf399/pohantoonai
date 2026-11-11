import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';

void main() {
  test('OAuth callback for Flutter Web uses current dev origin and port', () {
    expect(
      oauthRedirectForApp(
        isWeb: true,
        currentUri: Uri.parse('http://localhost:53719/#/welcome'),
      ),
      'http://localhost:53719',
    );
  });

  test('OAuth callback for hosted Web strips routes and tokens', () {
    expect(
      oauthRedirectForApp(
        isWeb: true,
        currentUri: Uri.parse('https://app.example.org/schools?tab=all#secret'),
      ),
      'https://app.example.org',
    );
  });

  test('OAuth callback for native uses registered app deep link', () {
    expect(
      oauthRedirectForApp(
        isWeb: false,
        currentUri: Uri.parse('https://unrelated.example.org'),
      ),
      'pohantoonai://auth-callback',
    );
  });
}
