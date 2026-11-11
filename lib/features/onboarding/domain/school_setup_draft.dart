/// School details collected before creating any tenant.
class SchoolSetupDraft {
  const SchoolSetupDraft({
    this.schoolName,
    this.legalSchoolName,
    this.schoolType,
    this.registrationLicenseNumber,
    this.establishedYear,
    this.websiteUrl,
    this.contactName,
    this.contactPosition,
    this.contactEmail,
    this.contactPhone,
    this.countryCode,
    this.region,
    this.city,
    this.streetAddress,
    this.timezone = 'UTC',
    this.currencyCode = 'USD',
    this.estimatedStudents,
    this.campusCount,
    this.estimatedTeachers,
    this.estimatedNonTeachingStaff,
    this.educationBoard,
    this.curriculum,
    this.lowestGrade,
    this.highestGrade,
    this.teachingLanguages = const [],
    this.readyForReview = false,
  });

  final String? schoolName, legalSchoolName, schoolType;
  final String? registrationLicenseNumber, websiteUrl;
  final int? establishedYear;
  final String? contactName, contactPosition, contactEmail, contactPhone;
  final String? countryCode, region, city, streetAddress;
  final String timezone, currencyCode;
  final int? estimatedStudents, campusCount;
  final int? estimatedTeachers, estimatedNonTeachingStaff;
  final String? educationBoard, curriculum, lowestGrade, highestGrade;
  final List<String> teachingLanguages;
  final bool readyForReview;

  factory SchoolSetupDraft.fromJson(Map<String, dynamic> json) =>
      SchoolSetupDraft(
        schoolName: json['school_name'] as String?,
        legalSchoolName: json['legal_school_name'] as String?,
        schoolType: json['school_type'] as String?,
        registrationLicenseNumber: json['registration_license_number'] as String?,
        establishedYear: (json['established_year'] as num?)?.toInt(),
        websiteUrl: json['website_url'] as String?,
        contactName: json['contact_name'] as String?,
        contactPosition: json['contact_position'] as String?,
        contactEmail: json['contact_email'] as String?,
        contactPhone: json['contact_phone'] as String?,
        countryCode: json['country_code'] as String?,
        region: json['region'] as String?,
        city: json['city'] as String?,
        streetAddress: json['street_address'] as String?,
        timezone: (json['timezone'] as String?) ?? 'UTC',
        currencyCode: (json['currency_code'] as String?) ?? 'USD',
        estimatedStudents: (json['estimated_students'] as num?)?.toInt(),
        campusCount: (json['campus_count'] as num?)?.toInt(),
        estimatedTeachers: (json['estimated_teachers'] as num?)?.toInt(),
        estimatedNonTeachingStaff:
            (json['estimated_non_teaching_staff'] as num?)?.toInt(),
        educationBoard: json['education_board'] as String?,
        curriculum: json['curriculum'] as String?,
        lowestGrade: json['lowest_grade'] as String?,
        highestGrade: json['highest_grade'] as String?,
        teachingLanguages: (json['teaching_languages'] as List<dynamic>? ?? [])
            .map((value) => value.toString()).toList(growable: false),
        readyForReview: json['draft_status'] == 'ready_for_review',
      );

  Map<String, dynamic> toJson() => {
    'school_name': schoolName,
    'legal_school_name': legalSchoolName,
    'school_type': schoolType,
    'registration_license_number': registrationLicenseNumber,
    'established_year': establishedYear,
    'website_url': websiteUrl,
    'contact_name': contactName,
    'contact_position': contactPosition,
    'contact_email': contactEmail,
    'contact_phone': contactPhone,
    'country_code': countryCode,
    'region': region,
    'city': city,
    'street_address': streetAddress,
    'timezone': timezone,
    'currency_code': currencyCode,
    'estimated_students': estimatedStudents,
    'campus_count': campusCount,
    'estimated_teachers': estimatedTeachers,
    'estimated_non_teaching_staff': estimatedNonTeachingStaff,
    'education_board': educationBoard,
    'curriculum': curriculum,
    'lowest_grade': lowestGrade,
    'highest_grade': highestGrade,
    'teaching_languages': teachingLanguages,
    'draft_status': readyForReview ? 'ready_for_review' : 'draft',
  };

  /// Checks readiness before a user can proceed to Step 4. Matches server
  /// checks, including plan capacity; the server independently enforces both.
  List<String> reviewErrors({
    required int? studentLimit,
    required int? campusLimit,
    required int? staffLimit,
  }) {
    final issues = <String>[];
    bool missing(String? value) => value == null || value.trim().isEmpty;
    if (missing(schoolName)) issues.add('School name is required.');
    if (missing(schoolType)) issues.add('Choose a school type.');
    if (missing(contactName)) issues.add('Contact name is required.');
    if (missing(contactEmail)) issues.add('School contact email is required.');
    if (missing(countryCode)) issues.add('Select the country.');
    if (missing(city)) issues.add('City is required.');
    if (estimatedStudents == null || estimatedStudents! < 1) {
      issues.add('Estimated students must be greater than zero.');
    }
    if (campusCount == null || campusCount! < 1) {
      issues.add('Campus count must be at least one.');
    }
    if (studentLimit != null && estimatedStudents != null &&
        estimatedStudents! > studentLimit) {
      issues.add('Your student estimate exceeds the selected plan.');
    }
    if (campusLimit != null && campusCount != null &&
        campusCount! > campusLimit) {
      issues.add('Your campus estimate exceeds the selected plan.');
    }
    final staff = (estimatedTeachers ?? 0) +
        (estimatedNonTeachingStaff ?? 0);
    if (staffLimit != null && staff > staffLimit) {
      issues.add('Staff estimate exceeds the selected plan.');
    }
    if (contactEmail != null && !RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
        .hasMatch(contactEmail!)) {
      issues.add('Enter a valid school contact email.');
    }
    if (websiteUrl != null && !websiteUrl!.startsWith('https://')) {
      issues.add('School website must start with https://');
    }
    return issues;
  }
}
