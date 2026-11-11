import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_configuration.dart';

/// Returns to the *running Flutter application*, not the Supabase project.
/// Web: preserve the origin, port AND hosting base path; drop OAuth query/
/// fragment secrets. Native: use the OS-registered callback protocol.
///
/// The URL must be allowlisted in Supabase Auth → URL Configuration.
/// Google Cloud's callback is a *different* URL ending /auth/v1/callback.
String oauthRedirectForApp({
  required bool isWeb,
  required Uri currentUri,
}) {
  if (!isWeb) return SupabaseConfiguration.mobileRedirect;
  if (currentUri.scheme != 'https' && currentUri.scheme != 'http') {
    throw const FormatException('Flutter Web must run over HTTP or HTTPS.');
  }
  final path = currentUri.path.isEmpty ? '/' : currentUri.path;
  return currentUri.origin + path;
}

abstract class AccountAuthGateway {
  bool get signedIn;
  String? get signedInEmail;
  Stream<bool> get sessionChanges;

  Future<void> signInWithGoogle();
  Future<void> sendEmailLink(String email);
  Future<void> signOut();
}

/// Optional stable Auth identity. A user switching from account A to B
/// without a signed-out event must never see A's in-memory workspace.
/// No email or user-editable metadata is used as a tenant identifier.
abstract class AccountSessionIdentity {
  String? get currentAuthUserId;
  Stream<String?> get sessionIdentityChanges;
}

/// Optional email credential features. Kept separate from AccountAuthGateway
/// so existing OAuth/mock implementations are backward compatible.
abstract class AccountEmailCredentials {
  Stream<void> get passwordRecoveryEvents;
  Future<void> signUpWithPassword(String email,String password);
  Future<void> verifyEmailCode(String email,String code,
      {required bool isSignup});
  Future<void> signInWithPassword(String email,String password);
  Future<void> resendSignupCode(String email);
  Future<void> setAccountPassword(String password);
  Future<void> sendPasswordReset(String email);
}

/// User authentication is handled by Supabase Auth, not application-owned tables.
/// Google provider configuration and email delivery must be configured in dashboard.
class SupabaseAccountAuthGateway
    implements AccountAuthGateway,AccountEmailCredentials,
        AccountSessionIdentity {
  SupabaseAccountAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  String? get currentAuthUserId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get sessionIdentityChanges =>
    _client.auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  bool get signedIn => _client.auth.currentSession != null;

  @override
  String? get signedInEmail => _client.auth.currentUser?.email;

  @override
  Stream<bool> get sessionChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<void> signInWithGoogle() async {
    final opened = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: oauthRedirectForApp(isWeb: kIsWeb, currentUri: Uri.base),
      // Google sign-in must run in a standard browser, not an embedded
      // webview (Google may reject embedded OAuth user agents).
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const AuthException('Could not open Google sign-in. Try again.');
    }
  }

  @override
  Future<void> sendEmailLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
      emailRedirectTo: oauthRedirectForApp(isWeb: kIsWeb, currentUri: Uri.base),
    );
  }

  @override
  Stream<void> get passwordRecoveryEvents =>
    _client.auth.onAuthStateChange
      .where((state)=>state.event==AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> signUpWithPassword(String email,String password) async {
    final response=await _client.auth.signUp(
      email:email.trim(),password:password,
      emailRedirectTo:oauthRedirectForApp(isWeb:kIsWeb,
        currentUri:Uri.base));
    // A session without email confirmation is not a completed registration.
    if(response.session!=null && response.user?.emailConfirmedAt==null) {
      await _client.auth.signOut();
    }
  }

  @override
  Future<void> verifyEmailCode(String email,String code,
      {required bool isSignup}) async {
    final result=await _client.auth.verifyOTP(
      email:email.trim(),token:code.trim(),
      // Current GoTrue email OTP verification uses the email type for
      // both sign-up confirmation and email-code sign-in.
      // Legacy OtpType.signup is deprecated.
      type:OtpType.email);
    if(result.session==null || result.user==null) {
      throw const AuthException('Email verification could not finish.');
    }
  }

  @override
  Future<void> signInWithPassword(String email,String password) async {
    await _client.auth.signInWithPassword(
      email:email.trim(),password:password);
  }

  @override
  Future<void> resendSignupCode(String email) async {
    await _client.auth.resend(type:OtpType.signup,email:email.trim());
  }

  @override
  Future<void> setAccountPassword(String password) async {
    final user=_client.auth.currentUser;
    if(user==null || user.emailConfirmedAt==null) {
      throw const AuthException('Verify your email before setting a password.');
    }
    await _client.auth.updateUser(UserAttributes(password:password));
  }

  @override
  Future<void> sendPasswordReset(String email) =>
    _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo:oauthRedirectForApp(isWeb:kIsWeb,currentUri:Uri.base));

  @override
  Future<void> signOut() => _client.auth.signOut();
}
