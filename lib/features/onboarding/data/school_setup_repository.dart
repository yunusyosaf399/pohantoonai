import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/school_setup_draft.dart';

abstract class SchoolSetupRepository {
  Future<SchoolSetupDraft?> load();
  Future<SchoolSetupDraft> save(SchoolSetupDraft draft);
}

/// Client has only its own draft-row privileges via Supabase RLS.
/// A school tenant is not created during these calls.
class SupabaseSchoolSetupRepository implements SchoolSetupRepository {
  SupabaseSchoolSetupRepository(this._client);
  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in to set up your school.');
    return id;
  }

  @override
  Future<SchoolSetupDraft?> load() async {
    final userId = _userId;
    final row = await _client.from('school_setup_drafts')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : SchoolSetupDraft.fromJson(row);
  }

  @override
  Future<SchoolSetupDraft> save(SchoolSetupDraft draft) async {
    final userId = _userId;
    final payload = <String, dynamic>{
      'user_id': userId,
      ...draft.toJson(),
    };
    final row = await _client.from('school_setup_drafts')
        .upsert(payload, onConflict: 'user_id')
        .select().single();
    return SchoolSetupDraft.fromJson(row);
  }
}
