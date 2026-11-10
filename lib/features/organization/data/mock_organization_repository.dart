import 'package:flutter/foundation.dart';

import '../domain/organization_models.dart';

/// Local-only development repository. No database calls, authentication or billing.
class MockOrganizationRepository extends ChangeNotifier {
  final List<SubscriptionPlan> plans = const [
    SubscriptionPlan(
      code: 'starter_demo',
      name: 'Starter Demo',
      summary: 'School essentials for a small campus.',
      studentLimit: 250,
      campusLimit: 1,
      trialDays: 14,
    ),
    SubscriptionPlan(
      code: 'growth_demo',
      name: 'Growth Demo',
      summary: 'Multi-campus school management.',
      studentLimit: 1500,
      campusLimit: 5,
      trialDays: 14,
    ),
    SubscriptionPlan(
      code: 'enterprise_demo',
      name: 'Enterprise Demo',
      summary: 'Expanded academic and operational capabilities.',
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

  List<SchoolOnboardingRequest> get requests => List.unmodifiable(_requests);

  int get submittedCount =>
      _requests.where((r) => r.status == OnboardingStatus.submitted).length;

  int get approvedCount =>
      _requests.where((r) => r.status == OnboardingStatus.approved).length;

  /// Creates a local preview request, not an account, school or subscription.
  void submit(SchoolOnboardingDraft draft) {
    _requests.insert(
      0,
      SchoolOnboardingRequest(
        id: 'DEMO'+(_requests.length+1).toString(),
        schoolName: draft.schoolName,
        ownerName: draft.ownerName,
        contactEmail: draft.contactEmail,
        countryCode: draft.countryCode,
        city: draft.city,
        planCode: draft.planCode,
        studentEstimate: draft.studentEstimate,
        campusEstimate: draft.campusEstimate,
        status: OnboardingStatus.submitted,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
