import 'package:supabase_flutter/supabase_flutter.dart';

/// Admissions belong to a provisioned school, NEVER to the demo workspace.
/// The client always supplies school_id, but PostgreSQL RLS is authoritative.
class AdmissionsSchool {
  const AdmissionsSchool({required this.id, required this.name});
  final String id;
  final String name;
}

class SchoolAdmission {
  const SchoolAdmission({
    required this.id, required this.schoolId,
    required this.firstName, required this.lastName,
    required this.grade, required this.guardianName,
    required this.guardianPhone, required this.status,
    required this.createdAt,
  });

  final String id, schoolId, firstName, lastName, grade;
  final String guardianName, guardianPhone, status;
  final DateTime createdAt;
  String get fullName => '$firstName $lastName';

  factory SchoolAdmission.fromJson(Map<String, dynamic> row) =>
    SchoolAdmission(
      id:row['id'] as String,
      schoolId:row['school_id'] as String,
      firstName:row['student_first_name'] as String,
      lastName:row['student_last_name'] as String,
      grade:row['grade_applied'] as String,
      guardianName:row['guardian_full_name'] as String,
      guardianPhone:row['guardian_phone'] as String,
      status:row['status'] as String,
      createdAt:DateTime.parse(row['created_at'] as String).toLocal(),
    );
}

class AdmissionsSummary {
  const AdmissionsSummary({
    required this.total,required this.pending,
    required this.admitted,required this.rejected,
  });
  final int total,pending,admitted,rejected;
  static const empty=AdmissionsSummary(
    total:0,pending:0,admitted:0,rejected:0);

  factory AdmissionsSummary.fromJson(Map<String,dynamic> row) =>
    AdmissionsSummary(
      total:(row['total_applications'] as num).toInt(),
      pending:(row['pending_applications'] as num).toInt(),
      admitted:(row['admitted_students'] as num).toInt(),
      rejected:(row['rejected_applications'] as num).toInt(),
    );
}

class NewSchoolAdmission {
  const NewSchoolAdmission({
    required this.firstName, required this.lastName,
    required this.grade, required this.guardianName,
    required this.guardianPhone, this.guardianEmail,
    this.notes, this.dateOfBirth,
  });

  final String firstName, lastName, grade;
  final String guardianName, guardianPhone;
  final String? guardianEmail, notes;
  final DateTime? dateOfBirth;
}

abstract class SchoolAdmissionsRepository {
  Future<List<AdmissionsSchool>> availableSchools();
  Future<List<SchoolAdmission>> load(String schoolId);
  Future<AdmissionsSummary> summary(String schoolId);
  Future<void> create(String schoolId, NewSchoolAdmission admission);
  Future<void> decide(String schoolId, String admissionId, String outcome);
}

class SupabaseSchoolAdmissionsRepository implements SchoolAdmissionsRepository {
  const SupabaseSchoolAdmissionsRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<AdmissionsSchool>> availableSchools() async {
    final userId=client.auth.currentUser?.id;
    if(userId==null) throw const AuthException('Sign in first.');
    // Client-side filtering is defense in depth, NOT an authorization grant.
    // DB policy permits only self-read of memberships and active school reads.
    final memberships=await client.from('school_memberships')
      .select('school_id')
      .eq('user_id',userId)
      .eq('membership_status','active')
      .inFilter('role',['school_owner','school_admin']);
    final ids=memberships.map((row)=>row['school_id'] as String)
      .toSet().toList(growable:false);
    if(ids.isEmpty)return const [];
    final rows=await client.from('schools')
      .select('id,name')
      .inFilter('id',ids)
      .eq('lifecycle_status','active')
      .order('name');
    return rows.map((row)=>AdmissionsSchool(
      id:row['id'] as String,name:row['name'] as String))
      .toList(growable:false);
  }

  @override
  Future<List<SchoolAdmission>> load(String schoolId) async {
    final rows=await client.from('school_admissions')
      .select('id,school_id,student_first_name,student_last_name,'
        'grade_applied,guardian_full_name,guardian_phone,status,created_at')
      .eq('school_id',schoolId)
      .order('created_at',ascending:false)
      .limit(200);
    return rows.map((row)=>SchoolAdmission.fromJson(row))
      .toList(growable:false);
  }

  @override
  Future<AdmissionsSummary> summary(String schoolId) async {
    // security_invoker=true on the view means underlying RLS still checks
    // membership, school lifecycle, and enrolled AAL2 for every count.
    final row=await client.from('school_admission_counts')
      .select('total_applications,pending_applications,'
        'admitted_students,rejected_applications')
      .eq('school_id',schoolId)
      .maybeSingle();
    return row==null?AdmissionsSummary.empty:
      AdmissionsSummary.fromJson(row);
  }

  @override
  Future<void> create(String schoolId,NewSchoolAdmission value) async {
    await client.from('school_admissions').insert({
      'school_id':schoolId,
      'student_first_name':value.firstName.trim(),
      'student_last_name':value.lastName.trim(),
      'grade_applied':value.grade.trim(),
      'guardian_full_name':value.guardianName.trim(),
      'guardian_phone':value.guardianPhone.trim(),
      if(value.guardianEmail?.trim().isNotEmpty==true)
        'guardian_email':value.guardianEmail!.trim(),
      if(value.notes?.trim().isNotEmpty==true)
        'notes':value.notes!.trim(),
      if(value.dateOfBirth!=null)
        'date_of_birth':[
          value.dateOfBirth!.year.toString().padLeft(4,'0'),
          value.dateOfBirth!.month.toString().padLeft(2,'0'),
          value.dateOfBirth!.day.toString().padLeft(2,'0'),
        ].join('-'),
      // Never submit created_by, membership role, or initial status.
      // PostgreSQL derives the author and enforces a pending application.
    });
  }

  @override
  Future<void> decide(String schoolId,String admissionId,String outcome) async {
    if(outcome!='admitted' && outcome!='rejected') {
      throw ArgumentError.value(outcome,'outcome','Unsupported admission decision');
    }
    final result=await client.from('school_admissions')
      .update({'status':outcome})
      .eq('school_id',schoolId)
      .eq('id',admissionId)
      .eq('status','pending')
      .select('id');
    if(result.isEmpty){
      throw StateError('This application is no longer pending.');
    }
  }
}
