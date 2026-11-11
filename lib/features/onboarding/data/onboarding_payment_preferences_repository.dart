import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/onboarding_payment_preferences.dart';

abstract class OnboardingPaymentPreferencesRepository {
  Future<OnboardingPaymentPreferences?> load();
  Future<OnboardingPaymentPreferences> save(
    OnboardingPaymentPreferences preferences);
}

/// Authenticated account-only access. No service-role key or payments APIs.
/// The server rejects unreviewed or stale school plans/drafts.
class SupabaseOnboardingPaymentPreferencesRepository
    implements OnboardingPaymentPreferencesRepository {
  const SupabaseOnboardingPaymentPreferencesRepository(this.client);
  final SupabaseClient client;

  String get userId {
    final id = client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthException('Sign in to save your billing preferences.');
    }
    return id;
  }

  @override
  Future<OnboardingPaymentPreferences?> load() async {
    final id = userId;
    final row = await client
        .from('onboarding_payment_preferences')
        .select()
        .eq('user_id', id)
        .maybeSingle();
    return row == null ? null : OnboardingPaymentPreferences.fromJson(row);
  }

  @override
  Future<OnboardingPaymentPreferences> save(
      OnboardingPaymentPreferences preferences) async {
    final validation = preferences.validate();
    if (validation.isNotEmpty) throw StateError(validation.join(' '));
    final id = userId;
    final row = await client
        .from('onboarding_payment_preferences')
        .upsert({
          'user_id': id,
          ...preferences.toJson(),
        }, onConflict: 'user_id')
        .select()
        .single();
    return OnboardingPaymentPreferences.fromJson(row);
  }
}
