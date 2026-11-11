import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/onboarding_plan_offer.dart';
import '../domain/school_setup_draft.dart';

/// Acknowledges that the applicant reviewed the current school draft.
/// It does not submit the application, charge money, or grant school access.
abstract class ReviewConfirmationRepository {
  Future<void> confirm({
    required SchoolSetupDraft draft,
    required OnboardingPlanOffer plan,
  });
}

class SupabaseReviewConfirmationRepository
    implements ReviewConfirmationRepository {
  SupabaseReviewConfirmationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> confirm({
    required SchoolSetupDraft draft,
    required OnboardingPlanOffer plan,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to confirm your school information.');
    }
    if (!draft.readyForReview || draft.updatedAt == null) {
      throw StateError('Return to School Setup and save for review first.');
    }

    // This timestamp must match the current DB row exactly. The database
    // trigger also checks selected plan ID and review-ready status atomically.
    final revision = draft.updatedAt!.toUtc().toIso8601String();
    final row = await _client
        .from('onboarding_review_confirmations')
        .upsert({
          'user_id': userId,
          'selected_plan_id': plan.id,
          'reviewed_draft_updated_at': revision,
        }, onConflict: 'user_id')
        .select('selected_plan_id,reviewed_draft_updated_at')
        .single();

    if (row['selected_plan_id'] != plan.id ||
        DateTime.parse(row['reviewed_draft_updated_at'] as String).toUtc() !=
            draft.updatedAt!.toUtc()) {
      throw StateError('School information changed. Review it again.');
    }
  }
}
