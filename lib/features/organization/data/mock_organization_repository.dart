import '../domain/organization_models.dart';
import 'organization_repository.dart';

/// Deterministic, in-memory development store. No Supabase reads or writes.
class MockOrganizationRepository implements OrganizationRepository {
  final List<SubscriptionPlan> _plans = const [
    SubscriptionPlan(
      code: 'starter_demo',
      name: 'Starter Demo',
      summary: 'Essential tools for a single-campus school.',
      studentLimit: 250,
      campusLimit: 1,
      trialDays: 14,
    ),
    SubscriptionPlan(
      code: 'growth_demo',
      name: 'Growth Demo',
      summary: 'Manage growing teams and multiple campuses.',
      studentLimit: 1500,
      campusLimit: 5,
      trialDays: 14,
    ),
    SubscriptionPlan(
      code: 'enterprise_demo',
      name: 'Enterprise Demo',
      summary: 'All supported school operations in one workspace.',
      studentLimit: null,
      campusLimit: null,
      trialDays: 30,
    ),
  ];

  final List<SchoolOnboardingRequest> _requests = [
    SchoolOnboardingRequest(
      id: 'SAMPLE01',
      schoolName: 'Sample Learning Academy',
      ownerName: 'Sample School Owner',
      contactEmail: 'school@example.invalid',
      countryCode: 'SA',
      city: 'Sample City',
      planCode: 'starter_demo',
      studentEstimate: 180,
      campusEstimate: 1,
      status: OnboardingStatus.submitted,
      createdAt: DateTime(2026, 11, 10),
    ),
  ];

  @override
  Future<OrganizationSnapshot> load() async {
    // Async boundary matches the eventual authenticated API implementation.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return OrganizationSnapshot(
      plans: List.unmodifiable(_plans),
      requests: List.unmodifiable(_requests),
    );
  }

  @override
  Future<SchoolOnboardingRequest> submit(SchoolOnboardingDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final selected = _plans.where((p) => p.code == draft.planCode);
    if (selected.isEmpty) {
      throw const OrganizationFailure(
        OrganizationFailureCode.invalidInput,
        'The selected plan is no longer available. Choose another plan.',
      );
    }
    final plan = selected.first;
    if (draft.schoolName.trim().isEmpty ||
        draft.ownerName.trim().isEmpty ||
        draft.contactEmail.trim().isEmpty ||
        !draft.contactEmail.contains('@') ||
        draft.city.trim().isEmpty ||
        draft.countryCode.trim().length != 2 ||
        draft.studentEstimate < 1 ||
        draft.campusEstimate < 1) {
      throw const OrganizationFailure(
        OrganizationFailureCode.invalidInput,
        'Check the required school information and try again.',
      );
    }
    if ((plan.studentLimit != null &&
            draft.studentEstimate > plan.studentLimit!) ||
        (plan.campusLimit != null &&
            draft.campusEstimate > plan.campusLimit!)) {
      throw const OrganizationFailure(
        OrganizationFailureCode.invalidInput,
        'This plan does not cover the estimated students or campuses.',
      );
    }
    final request = SchoolOnboardingRequest(
      id: 'DEMO' + (_requests.length + 1).toString().padLeft(3, '0'),
      schoolName: draft.schoolName.trim(),
      ownerName: draft.ownerName.trim(),
      contactEmail: draft.contactEmail.trim(),
      countryCode: draft.countryCode.trim().toUpperCase(),
      city: draft.city.trim(),
      planCode: draft.planCode,
      studentEstimate: draft.studentEstimate,
      campusEstimate: draft.campusEstimate,
      status: OnboardingStatus.submitted,
      createdAt: DateTime.now(),
    );
    _requests.insert(0, request);
    return request;
  }
}
