import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';

void main() {
  test('web password reset marks its origin without leaking stale URLs', () {
    const base='https://pohantoonai.com/school/app?source=old#fragment';
    final result=passwordRecoveryRedirectForApp(
      isWeb:true,currentUri:Uri.parse(base));
    expect(result,
      'https://pohantoonai.com/school/app?auth_flow=password_recovery');
    expect(isPasswordRecoveryCallback(Uri.parse(result)),isTrue);
  });

  test('native recovery preserves the registered callback scheme/host', () {
    final result=passwordRecoveryRedirectForApp(
      isWeb:false,currentUri:Uri.parse('https://pohantoonai.com/'));
    expect(result,
      'pohantoonai://auth-callback?auth_flow=password_recovery');
    expect(isPasswordRecoveryCallback(Uri.parse(result)),isTrue);
  });

  test('Supabase legacy recovery callback fragments also lock screen', () {
    expect(isPasswordRecoveryCallback(
      Uri.parse('https://pohantoonai.com/#type=recovery&token_type=bearer')),
      isTrue);
    expect(isPasswordRecoveryCallback(
      Uri.parse('pohantoonai://auth-callback?type=recovery')),
      isTrue);
  });

  test('normal OAuth, magic link and query parameters do not trigger reset', () {
    for(final url in [
      'https://pohantoonai.com/?code=pkce-code',
      'https://pohantoonai.com/#type=signup',
      'pohantoonai://auth-callback',
      'https://pohantoonai.com/?auth_flow=other',
    ]) {
      expect(isPasswordRecoveryCallback(Uri.parse(url)),isFalse,
        reason:url);
    }
  });
}
