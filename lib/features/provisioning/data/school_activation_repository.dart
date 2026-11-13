import 'package:supabase_flutter/supabase_flutter.dart';

/// The platform operator role is derived from database-managed memberships,
/// not local session preferences, school IDs, or editable user metadata.
class SchoolActivationStatus {
  const SchoolActivationStatus({
    required this.requestId,required this.schoolName,required this.status,
    required this.submittedAt,this.schoolId,this.activationBasis,
  });

  final String requestId,schoolName,status;
  final DateTime submittedAt;
  final String? schoolId,activationBasis;

  factory SchoolActivationStatus.fromJson(Map<String,dynamic> value)=>
    SchoolActivationStatus(
      requestId:value['request_id'] as String,
      schoolName:value['school_display_name'] as String,
      status:value['status'] as String,
      submittedAt:DateTime.parse(value['submitted_at'] as String).toLocal(),
      schoolId:value['school_id'] as String?,
      activationBasis:value['activation_basis'] as String?,
    );
}

class SchoolActivationReview {
  const SchoolActivationReview({
    required this.id,required this.organizationId,required this.schoolName,
    required this.applicantEmail,required this.planCode,
    required this.isDemo,required this.status,
    required this.submittedAt,this.legalName,
    this.activationReady=true,
  });

  final String id,organizationId,schoolName,applicantEmail;
  final String planCode,status;
  final bool isDemo;
  /// Legacy/unlinked submissions are visible, but cannot be approved.
  final bool activationReady;
  final DateTime submittedAt;
  final String? legalName;

  factory SchoolActivationReview.fromJson(Map<String,dynamic> value)=>
    SchoolActivationReview(
      id:value['request_id'] as String,
      organizationId:value['organization_id'] as String,
      schoolName:value['school_display_name'] as String,
      applicantEmail:value['requester_email'] as String,
      planCode:value['plan_code'] as String,
      isDemo:value['plan_is_demo'] as bool,
      activationReady:value['activation_ready'] as bool? ?? false,
      status:value['status'] as String,
      submittedAt:DateTime.parse(value['submitted_at'] as String).toLocal(),
      legalName:value['school_legal_name'] as String?,
    );
}

/// Injectable for Flutter widget tests. Database RPCs are the authorization
/// boundary; clients never directly insert schools, memberships or operator grants.
abstract class SchoolActivationRepository {
  Future<String> operatorRole();
  Future<SchoolActivationStatus?> ownRequest();
  Future<String> submitRequest();
  Future<List<SchoolActivationReview>> operatorQueue();
  Future<String> approve({
    required String requestId,
    required String activationBasis,
    required String evidence,
    required bool identityVerified,
  });
  Future<void> reject({required String requestId,required String reason});
  Future<void> requestInformation({
    required String requestId,required String reason,
  });
}

class SupabaseSchoolActivationRepository implements SchoolActivationRepository {
  const SupabaseSchoolActivationRepository(this.client);
  final SupabaseClient client;

  @override
  Future<String> operatorRole() async {
    final result=await client.rpc('my_school_provisioning_role');
    return result as String;
  }

  @override
  Future<SchoolActivationStatus?> ownRequest() async {
    final response=await client.rpc('my_school_activation_status');
    final rows=(response as List).cast<Map<String,dynamic>>();
    return rows.isEmpty?null:SchoolActivationStatus.fromJson(rows.first);
  }

  @override
  Future<String> submitRequest() async {
    final response=await client.rpc('request_school_activation');
    return response as String;
  }

  @override
  Future<List<SchoolActivationReview>> operatorQueue() async {
    // Unlike the older queue, this includes legacy submissions without a
    // verified owner snapshot. Their activationReady flag stays false.
    final response=await client.rpc('platform_control_review_queue',params:{
      'p_limit':100,'p_offset':0,
    });
    return (response as List).map((value)=>
      SchoolActivationReview.fromJson(
        Map<String,dynamic>.from(value as Map))).toList(growable:false);
  }

  @override
  Future<String> approve({
    required String requestId,
    required String activationBasis,
    required String evidence,
    required bool identityVerified,
  }) async {
    final response=await client.rpc('approve_school_activation',params:{
      'p_request_id':requestId,
      'p_basis':activationBasis,
      'p_evidence':evidence,
      'p_identity_verified':identityVerified,
    });
    return response as String;
  }

  @override
  Future<void> reject({
    required String requestId,required String reason,
  }) async {
    await client.rpc('reject_school_activation',params:{
      'p_request_id':requestId,
      'p_reason':reason,
    });
  }
  @override
  Future<void> requestInformation({
    required String requestId,required String reason,
  }) async {
    await client.rpc('request_school_activation_information',params:{
      'p_request_id':requestId,
      'p_reason':reason,
    });
  }

}
