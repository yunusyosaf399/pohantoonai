enum OnboardingStatus { draft, submitted, inReview, approved }

extension OnboardingStatusLabel on OnboardingStatus {
  String get label => switch (this) {
    OnboardingStatus.draft => 'Draft',
    OnboardingStatus.submitted => 'Submitted',
    OnboardingStatus.inReview => 'In review',
    OnboardingStatus.approved => 'Approved',
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
      (studentLimit == null ? 'Unlimited' : studentLimit.toString()) + ' students · ' +
      (campusLimit == null ? 'Unlimited' : campusLimit.toString()) + ' campuses';
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
  });

  final String schoolName;
  final String ownerName;
  final String contactEmail;
  final String countryCode;
  final String city;
  final String planCode;
  final int studentEstimate;
  final int campusEstimate;
}
