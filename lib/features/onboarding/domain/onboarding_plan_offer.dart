/// Public, read-only product offer; not an active subscription.
class OnboardingPlanOffer {
  const OnboardingPlanOffer({
    required this.id,
    required this.code,
    required this.name,
    required this.summary,
    required this.studentLimit,
    required this.campusLimit,
    required this.staffLimit,
    required this.trialDays,
    required this.isDemo,
  });

  final String id;
  final String code;
  final String name;
  final String summary;
  /// A null limit means unlimited. Zero means not included.
  final int? studentLimit;
  final int? campusLimit;
  final int? staffLimit;
  final int trialDays;
  final bool isDemo;

  factory OnboardingPlanOffer.fromJson(Map<String, dynamic> json) =>
      OnboardingPlanOffer(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        summary: (json['summary'] as String?) ?? '',
        studentLimit: (json['student_limit'] as num?)?.toInt(),
        campusLimit: (json['campus_limit'] as num?)?.toInt(),
        staffLimit: (json['staff_limit'] as num?)?.toInt(),
        trialDays: (json['trial_days'] as num).toInt(),
        isDemo: json['is_demo'] as bool,
      );

  String amount(int? value) => value == null ? 'Unlimited' : '$value';

  String get summaryLimits =>
      '${amount(studentLimit)} students · ${amount(campusLimit)} campuses · '
      '${amount(staffLimit)} staff';

  String get shortDescription => switch (code) {
        'starter_demo' => 'Essential tools for a single-campus school.',
        'growth_demo' => 'For growing schools and multiple campuses.',
        'enterprise_demo' => 'For larger institutions with extensive operational needs.',
        _ => summary,
      };
}
