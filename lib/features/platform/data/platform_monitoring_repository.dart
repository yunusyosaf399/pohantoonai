import 'package:supabase_flutter/supabase_flutter.dart';

/// Platform-level reporting is never an unauthenticated global directory.
/// Each RPC enforces active operator organization membership and JWT AAL2.
class PlatformSummary {
  const PlatformSummary({
    required this.schools,required this.activeSchools,
    required this.suspendedSchools,required this.pendingRequests,
    required this.provisionedRequests,required this.rejectedRequests,
    required this.accounts,required this.mfaAccounts,
    required this.unverifiedEmailAccounts,required this.suspendedMemberships,
    required this.bannedAccounts,required this.admittedStudents,
    required this.requestsLast30Days,required this.recentLoginAccounts,
    required this.failedSecurityEmails,
  });
  final int schools,activeSchools,suspendedSchools;
  final int pendingRequests,provisionedRequests,rejectedRequests;
  final int accounts,mfaAccounts,unverifiedEmailAccounts,suspendedMemberships;
  final int bannedAccounts,admittedStudents,requestsLast30Days;
  final int recentLoginAccounts,failedSecurityEmails;

  static const empty=PlatformSummary(
    schools:0,activeSchools:0,suspendedSchools:0,
    pendingRequests:0,provisionedRequests:0,rejectedRequests:0,
    accounts:0,mfaAccounts:0,unverifiedEmailAccounts:0,
    suspendedMemberships:0,bannedAccounts:0,admittedStudents:0,
    requestsLast30Days:0,recentLoginAccounts:0,failedSecurityEmails:0,
  );

  factory PlatformSummary.fromJson(Map<String,dynamic> m) {
    int n(String key) => (m[key] as num).toInt();
    return PlatformSummary(
      schools:n('total_schools'),
      activeSchools:n('active_schools'),
      suspendedSchools:n('suspended_schools'),
      pendingRequests:n('pending_requests'),
      provisionedRequests:n('provisioned_requests'),
      rejectedRequests:n('rejected_requests'),
      accounts:n('school_accounts'),
      mfaAccounts:n('mfa_protected_accounts'),
      unverifiedEmailAccounts:n('unverified_email_accounts'),
      suspendedMemberships:n('suspended_memberships'),
      bannedAccounts:n('banned_accounts'),
      admittedStudents:n('admitted_students'),
      requestsLast30Days:n('submitted_requests_30d'),
      recentLoginAccounts:n('recently_signed_in_accounts_30d'),
      failedSecurityEmails:n('failed_security_emails_30d'),
    );
  }
}

class PlatformSchool {
  const PlatformSchool({
    required this.id,required this.name,required this.organization,
    required this.status,required this.activationBasis,
    required this.createdAt,required this.members,required this.admitted,
    required this.pending,this.ownerEmail,
  });
  final String id,name,organization,status,activationBasis;
  final String? ownerEmail;
  final DateTime createdAt;
  final int members,admitted,pending;
  factory PlatformSchool.fromJson(Map<String,dynamic> m)=>PlatformSchool(
    id:m['school_id'] as String,
    name:m['school_name'] as String,
    organization:m['organization_name'] as String,
    status:m['lifecycle_status'] as String,
    activationBasis:m['activation_basis'] as String,
    createdAt:DateTime.parse(m['created_at'] as String).toLocal(),
    ownerEmail:m['owner_email'] as String?,
    members:(m['member_count'] as num).toInt(),
    admitted:(m['admitted_count'] as num).toInt(),
    pending:(m['pending_admissions'] as num).toInt(),
  );
}

class PlatformSchoolAccount {
  const PlatformSchoolAccount({
    required this.schoolId,required this.schoolName,
    required this.userId,required this.role,required this.membershipStatus,
    required this.emailVerified,required this.mfaEnrolled,
    required this.banned,this.email,this.lastSignIn,
  });
  final String schoolId,schoolName,userId,role,membershipStatus;
  final String? email;
  final bool emailVerified,mfaEnrolled,banned;
  final DateTime? lastSignIn;
  bool get needsReview =>
    !emailVerified||!mfaEnrolled||banned||
    membershipStatus=='suspended'||membershipStatus=='revoked';

  factory PlatformSchoolAccount.fromJson(Map<String,dynamic> m)=>
    PlatformSchoolAccount(
      schoolId:m['school_id'] as String,
      schoolName:m['school_name'] as String,
      userId:m['user_id'] as String,
      email:m['account_email'] as String?,
      role:m['school_role'] as String,
      membershipStatus:m['membership_status'] as String,
      emailVerified:m['email_verified'] as bool,
      mfaEnrolled:m['mfa_enrolled'] as bool,
      banned:m['account_banned'] as bool? ?? false,
      lastSignIn:m['last_sign_in_at'] == null?null:
        DateTime.parse(m['last_sign_in_at'] as String).toLocal(),
    );
}

class PlatformTrend {
  const PlatformTrend(this.month,this.requests,this.provisioned);
  final DateTime month;
  final int requests,provisioned;
  factory PlatformTrend.fromJson(Map<String,dynamic> m)=>PlatformTrend(
    DateTime.parse(m['month_start'] as String),
    (m['submitted_requests'] as num).toInt(),
    (m['schools_provisioned'] as num).toInt(),
  );
}

class PlatformReviewEvent {
  const PlatformReviewEvent({
    required this.id,required this.schoolName,required this.decision,
    required this.at,this.reviewerEmail,this.reason,
  });
  final String id,schoolName,decision;
  final String? reviewerEmail,reason;
  final DateTime at;
  factory PlatformReviewEvent.fromJson(Map<String,dynamic> m)=>
    PlatformReviewEvent(
      id:m['review_id'] as String,schoolName:m['school_name'] as String,
      decision:m['decision'] as String,reviewerEmail:m['reviewer_email'] as String?,
      reason:m['reason'] as String?,
      at:DateTime.parse(m['reviewed_at'] as String).toLocal(),
    );
}

abstract class PlatformMonitoringRepository {
  Future<PlatformSummary> overview();
  Future<List<PlatformSchool>> schools({required int offset,int limit=50});
  Future<List<PlatformSchoolAccount>> accounts({required int offset,int limit=50});
  Future<List<PlatformTrend>> trends();
  Future<List<PlatformReviewEvent>> history();
}

class SupabasePlatformMonitoringRepository implements PlatformMonitoringRepository {
  const SupabasePlatformMonitoringRepository(this.client);
  final SupabaseClient client;

  List<Map<String,dynamic>> _rows(dynamic response)=>
    (response as List).map((x)=>Map<String,dynamic>.from(x as Map))
      .toList(growable:false);

  @override
  Future<PlatformSummary> overview() async {
    final rows=_rows(await client.rpc('platform_control_overview'));
    if(rows.length!=1)throw StateError('Invalid platform summary response.');
    return PlatformSummary.fromJson(rows.first);
  }

  @override
  Future<List<PlatformSchool>> schools({required int offset,int limit=50}) async =>
    _rows(await client.rpc('platform_control_school_directory',params:{
      'p_offset':offset,'p_limit':limit,
    })).map(PlatformSchool.fromJson).toList(growable:false);

  @override
  Future<List<PlatformSchoolAccount>> accounts({required int offset,int limit=50}) async =>
    _rows(await client.rpc('platform_control_school_accounts',params:{
      'p_offset':offset,'p_limit':limit,
    })).map(PlatformSchoolAccount.fromJson).toList(growable:false);

  @override
  Future<List<PlatformTrend>> trends() async =>
    _rows(await client.rpc('platform_control_monthly_trends'))
      .map(PlatformTrend.fromJson).toList(growable:false);

  @override
  Future<List<PlatformReviewEvent>> history() async =>
    _rows(await client.rpc('platform_control_review_history'))
      .map(PlatformReviewEvent.fromJson).toList(growable:false);
}
