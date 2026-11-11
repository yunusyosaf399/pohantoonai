import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/onboarding_plan_offer.dart';

abstract class OnboardingPlanRepository {
  Future<List<OnboardingPlanOffer>> loadActivePlans();
  Future<String?> loadSelectedPlanId();
  Future<void> saveSelection(String planId);
}

/// Uses only public, RLS-protected app tables. Never accesses private platform
/// tables, controls subscriptions, or creates a school.
class SupabaseOnboardingPlanRepository implements OnboardingPlanRepository {
  SupabaseOnboardingPlanRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in to choose a plan.');
    return id;
  }

  @override
  Future<List<OnboardingPlanOffer>> loadActivePlans() async {
    _userId;
    final rows = await _client
        .from('onboarding_plan_offers')
        .select('id,code,name,summary,student_limit,campus_limit,'
            'staff_limit,trial_days,is_demo')
        .eq('is_active', true)
        .order('sort_order');
    return [
      for (final row in rows)
        OnboardingPlanOffer.fromJson(row),
    ];
  }

  @override
  Future<String?> loadSelectedPlanId() async {
    final id = _userId;
    final row = await _client
        .from('onboarding_plan_selections')
        .select('selected_plan_id')
        .eq('user_id', id)
        .maybeSingle();
    return row?['selected_plan_id'] as String?;
  }

  @override
  Future<void> saveSelection(String planId) async {
    final id = _userId;
    final row = await _client
        .from('onboarding_plan_selections')
        .upsert({
          'user_id': id,
          'selected_plan_id': planId,
        }, onConflict: 'user_id')
        .select('selected_plan_id')
        .single();
    if (row['selected_plan_id'] != planId) {
      throw StateError('Plan selection was not confirmed.');
    }
  }
}
