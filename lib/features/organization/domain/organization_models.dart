enum OnboardingStatus {
  draft,
  submitted,
  inReview,
  moreInformation,
  approved,
  rejected,
  provisioned,
  cancelled,
}

extension OnboardingStatusLabel on OnboardingStatus {
  String get label => switch (this) {
        OnboardingStatus.draft => 'Draft',
        OnboardingStatus.submitted => 'Submitted',
        OnboardingStatus.inReview => 'In review',
        OnboardingStatus.moreInformation => 'Information required',
        OnboardingStatus.approved => 'Approved',
        OnboardingStatus.rejected => 'Rejected',
        OnboardingStatus.provisioned => 'Provisioned',
        OnboardingStatus.cancelled => 'Cancelled',
      };
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.name,
    required this.summary,
    required this.studentLimit,
    required this.campusLimit,
    required this.trialDays,
  });

  final String code;
  final String name;
  final String summary;
  final int? studentLimit;
  final int? campusLimit;
  final int trialDays;

  String get displayLimits =>
      (studentLimit?.toString() ?? 'Unlimited') + ' students · ' +
      (campusLimit?.toString() ?? 'Unlimited') + ' campuses';
}

class SchoolOnboardingRequest {
  const SchoolOnboardingRequest({
    required this.id,
    required this.schoolName,
    required this.ownerName,
    required this.contactEmail,
    required this.countryCode,
    required this.city,
    required this.planCode,
    required this.studentEstimate,
    required this.campusEstimate,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String schoolName;
  final String ownerName;
  final String contactEmail;
  final String countryCode;
  final String city;
  final String planCode;
  final int studentEstimate;
  final int campusEstimate;
  final OnboardingStatus status;
  final DateTime createdAt;
}

/// Applicant-provided information. Authentication and approval are server concerns.
class SchoolOnboardingDraft {
  const SchoolOnboardingDraft({
    required this.schoolName,
    required this.ownerName,
    required this.contactEmail,
    required this.countryCode,
    required this.city,
    required this.planCode,
    required this.studentEstimate,
    required this.campusEstimate,
    this.legalName,
    this.registrationNumber,
    this.contactPhone,
    this.schoolType = 'private',
    this.educationBoard,
    this.curriculumSummary,
    this.preferredTimezone = 'UTC',
    this.preferredCurrency = 'USD',
  });

  final String schoolName;
  final String ownerName;
  final String contactEmail;
  final String countryCode;
  final String city;
  final String planCode;
  final int studentEstimate;
  final int campusEstimate;
  final String? legalName;
  final String? registrationNumber;
  final String? contactPhone;
  final String schoolType;
  final String? educationBoard;
  final String? curriculumSummary;
  final String preferredTimezone;
  final String preferredCurrency;
}
