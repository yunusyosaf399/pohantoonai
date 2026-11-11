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

/// User authentication is handled by Supabase Auth, not application-owned tables.
/// Google provider configuration and email delivery must be configured in dashboard.
class SupabaseAccountAuthGateway implements AccountAuthGateway {
  SupabaseAccountAuthGateway(this._client);

  final SupabaseClient _client;

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
  Future<void> signOut() => _client.auth.signOut();
}
