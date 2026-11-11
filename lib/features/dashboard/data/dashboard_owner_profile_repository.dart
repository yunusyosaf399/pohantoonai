import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DashboardOwnerProfileRepository {
  Future<String?> loadDisplayName();
  Future<void> saveDisplayName(String displayName);
  Future<Map<String,String?>> loadProfile();
  Future<void> saveProfile({
    required String displayName,String? phone,String? position});
  String? get email;
}

class SupabaseDashboardOwnerProfileRepository
    implements DashboardOwnerProfileRepository {
  const SupabaseDashboardOwnerProfileRepository(this.client);
  final SupabaseClient client;

  String get userId {
    final id=client.auth.currentUser?.id;
    if(id==null)throw const AuthException('Please sign in.');
    return id;
  }

  @override
  String? get email=>client.auth.currentUser?.email;

  @override
  Future<Map<String,String?>> loadProfile() async {
    final row=await client.from('user_profiles')
      .select('display_name,phone,position')
      .eq('user_id',userId).maybeSingle();
    return {
      'display_name':row?['display_name'] as String?,
      'phone':row?['phone'] as String?,
      'position':row?['position'] as String?,
    };
  }

  @override
  Future<String?> loadDisplayName() async {
    final row=await client.from('user_profiles')
      .select('display_name').eq('user_id',userId).maybeSingle();
    return row?['display_name'] as String?;
  }

  @override
  Future<void> saveProfile({
    required String displayName,String? phone,String? position}) async {
    final text=displayName.trim();
    if(text.length<2||text.length>120) {
      throw const FormatException('Enter a name between 2 and 120 characters.');
    }
    if((phone?.length??0)>32||(position?.length??0)>120) {
      throw const FormatException('Owner phone or position is too long.');
    }
    await client.from('user_profiles').upsert({
      'user_id':userId,'display_name':text,
      'phone':phone?.trim().isEmpty==true?null:phone?.trim(),
      'position':position?.trim().isEmpty==true?null:position?.trim(),
    },onConflict:'user_id');
  }

  @override
  Future<void> saveDisplayName(String displayName) async {
    final text=displayName.trim();
    if(text.length<2||text.length>120) {
      throw const FormatException('Enter a name between 2 and 120 characters.');
    }
    await client.from('user_profiles').upsert({
      'user_id':userId,'display_name':text,
    },onConflict:'user_id');
  }
}
