import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_configuration.dart';

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
      redirectTo: kIsWeb ? null : SupabaseConfiguration.mobileRedirect,
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
      emailRedirectTo: kIsWeb ? null : SupabaseConfiguration.mobileRedirect,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
