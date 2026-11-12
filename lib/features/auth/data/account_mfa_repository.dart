import 'package:supabase_flutter/supabase_flutter.dart';

/// Non-secret session state only. TOTP secrets/codes must never be persisted
/// in app tables, analytics, logs, or user metadata.
class AccountTotpFactor {
  const AccountTotpFactor({required this.id,required this.label});
  final String id;
  final String label;
}

class AccountMfaStatus {
  const AccountMfaStatus({
    required this.needsChallenge,
    required this.isAal2,
    required this.factors,
  });
  final bool needsChallenge;
  final bool isAal2;
  final List<AccountTotpFactor> factors;
}

class AccountTotpEnrollment {
  const AccountTotpEnrollment({
    required this.factorId,
    required this.secret,
    required this.otpauthUri,
  });
  final String factorId, secret, otpauthUri;
}

abstract class AccountMfaRepository {
  /// Must fail closed on any Auth or network error.
  Future<AccountMfaStatus> status();
  Future<AccountTotpEnrollment> enroll();
  Future<void> verify(String factorId,String code);
  Future<void> unenroll(String factorId);
  Future<void> cancelEnrollment(String factorId);
}

/// Supabase Auth owns auth.mfa_factors, challenges and TOTP verification.
/// The Flutter client uses only a publishable key; no service_role privileges.
class SupabaseAccountMfaRepository implements AccountMfaRepository {
  const SupabaseAccountMfaRepository(this.client);
  final SupabaseClient client;

  String _uid() {
    final user=client.auth.currentUser;
    if(user==null || client.auth.currentSession==null) {
      throw const AuthException('Sign in before managing two-factor authentication.');
    }
    return user.id;
  }

  @override
  Future<AccountMfaStatus> status() async {
    _uid();
    final aal=client.auth.mfa.getAuthenticatorAssuranceLevel();
    final res=await client.auth.mfa.listFactors();
    // Public Supabase Auth APIs return only verified TOTP factors here.
    final factors=res.totp.map((factor)=>AccountTotpFactor(
      id:factor.id,label:'Authenticator app')).toList();
    // The AAL value can be a String or an enum in different gotrue releases;
    // .toString() works for either without depending on internal classes.
    final current=aal.currentLevel.toString().toLowerCase();
    final next=aal.nextLevel.toString().toLowerCase();
    return AccountMfaStatus(
      needsChallenge: next.contains('aal2') && !current.contains('aal2'),
      isAal2:current.contains('aal2'),
      factors:factors,
    );
  }

  @override
  Future<AccountTotpEnrollment> enroll() async {
    _uid();
    final response=await client.auth.mfa.enroll(
      factorType:FactorType.totp,
      issuer:'Pohantoon AI',
      friendlyName:'Pohantoon AI Authenticator',
    );
    // A valid TOTP secret comes ONLY from Supabase Auth. Construct the
    // standards-compliant QR URI locally; never put it in URL logs.
    final totp=response.totp;
    if(totp==null) {
      throw const AuthException('Supabase did not return TOTP enrollment data.');
    }
    final secret=totp.secret;
    final email=client.auth.currentUser?.email ?? 'account';
    final otpauth='otpauth://totp/' +
      Uri.encodeComponent('Pohantoon AI') + ':' + Uri.encodeComponent(email) +
      '?secret=' + Uri.encodeComponent(secret) +
      '&issuer=' + Uri.encodeComponent('Pohantoon AI') +
      '&algorithm=SHA1&digits=6&period=30';
    return AccountTotpEnrollment(
      factorId:response.id,
      secret:secret,
      otpauthUri:otpauth,
    );
  }

  @override
  Future<void> verify(String factorId,String code) async {
    _uid();
    if(factorId.isEmpty || !RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw const FormatException('Enter the six-digit authenticator code.');
    }
    await client.auth.mfa.challengeAndVerify(
      factorId:factorId,code:code.trim());
    // challengeAndVerify refreshes the JWT to aal2 on success.
    final state=await status();
    if(!state.isAal2) {
      throw const AuthException('Two-factor verification was not completed.');
    }
  }

  @override
  Future<void> cancelEnrollment(String factorId) async {
    _uid();
    if(factorId.isEmpty) return;
    // Only the factor ID returned by this session's unverified enrollment
    // should be passed here. Supabase Auth checks factor ownership.
    await client.auth.mfa.unenroll(factorId);
  }

  @override
  Future<void> unenroll(String factorId) async {
    _uid();
    if(factorId.isEmpty)throw const FormatException('Invalid authenticator.');
    final current=await status();
    if(!current.isAal2) {
      throw const AuthException(
        'Verify your authenticator before removing a factor.');
    }
    await client.auth.mfa.unenroll(factorId);
  }
}
