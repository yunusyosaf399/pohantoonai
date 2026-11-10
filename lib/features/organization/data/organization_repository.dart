import '../domain/organization_models.dart';

/// Domain snapshot, independent of widgets, platforms or Supabase credentials.
class OrganizationSnapshot {
  const OrganizationSnapshot({
    required this.plans,
    required this.requests,
  });

  final List<SubscriptionPlan> plans;
  final List<SchoolOnboardingRequest> requests;
}

enum OrganizationFailureCode { unavailable, permissionDenied, invalidInput, unknown }

/// Never show raw database, SQL, credentials or stack traces to end users.
class OrganizationFailure implements Exception {
  const OrganizationFailure(this.code, this.message);

  final OrganizationFailureCode code;
  final String message;

  @override
  String toString() => message;
}

abstract class OrganizationRepository {
  Future<OrganizationSnapshot> load();
  Future<SchoolOnboardingRequest> submit(SchoolOnboardingDraft draft);
}
