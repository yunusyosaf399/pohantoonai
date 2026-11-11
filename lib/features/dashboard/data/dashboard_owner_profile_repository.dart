import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DashboardOwnerProfileRepository {
  Future<String?> loadDisplayName();
  Future<void> saveDisplayName(String displayName);
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
  Future<String?> loadDisplayName() async {
    final row=await client.from('user_profiles')
      .select('display_name').eq('user_id',userId).maybeSingle();
    return row?['display_name'] as String?;
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
