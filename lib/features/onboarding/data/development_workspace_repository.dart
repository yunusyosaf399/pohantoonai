import 'package:supabase_flutter/supabase_flutter.dart';

/// Only the signed-in applicant can enable their own development dashboard.
/// This status is not billing approval, a school tenant or any membership.
abstract class DevelopmentWorkspaceRepository {
  Future<bool> hasAccess(String selectedPlanId);
  Future<void> enable(String selectedPlanId);
}

class SupabaseDevelopmentWorkspaceRepository
    implements DevelopmentWorkspaceRepository {
  const SupabaseDevelopmentWorkspaceRepository(this.client);
  final SupabaseClient client;

  String get userId {
    final id=client.auth.currentUser?.id;
    if(id==null)throw const AuthException('Please sign in.');
    return id;
  }

  @override
  Future<bool> hasAccess(String selectedPlanId) async {
    final row=await client.from('onboarding_dev_workspaces')
      .select('selected_plan_id,access_kind')
      .eq('user_id',userId).maybeSingle();
    return row != null &&
      row['selected_plan_id']==selectedPlanId &&
      row['access_kind']=='development_preview';
  }

  @override
  Future<void> enable(String selectedPlanId) async {
    // The server revalidates the active demo offer, its selection, and
    // a ready-for-review draft. Never use a service-role key.
    await client.from('onboarding_dev_workspaces').upsert(
      {'user_id':userId,'selected_plan_id':selectedPlanId},
      onConflict:'user_id',ignoreDuplicates:true);
    if(!await hasAccess(selectedPlanId)) {
      throw StateError('This account has not completed demo school setup.');
    }
  }
}
