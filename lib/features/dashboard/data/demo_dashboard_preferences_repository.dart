import 'package:supabase_flutter/supabase_flutter.dart';

class DemoDashboardPreferences {
  const DemoDashboardPreferences({
    this.selectedChart = 'enrollment',
    this.academicYearLabel = '2026–27',
    this.quickActions = const [
      'add_student','new_admission','mark_attendance',
      'record_payment','add_staff','send_notice',
    ],
  });
  final String selectedChart;
  final String academicYearLabel;
  final List<String> quickActions;

  factory DemoDashboardPreferences.fromJson(Map<String,dynamic> row) =>
    DemoDashboardPreferences(
      selectedChart: row['selected_chart'] as String? ?? 'enrollment',
      academicYearLabel: row['academic_year_label'] as String? ?? '2026–27',
      quickActions: (row['quick_actions'] as List<dynamic>? ?? const [])
        .map((e) => e.toString()).toList(),
    );
  Map<String,dynamic> toJson() => {
    'selected_chart':selectedChart,
    'academic_year_label':academicYearLabel,
    'quick_actions':quickActions,
  };
}

abstract class DemoDashboardPreferencesRepository {
  Future<DemoDashboardPreferences?> load();
  Future<void> save(DemoDashboardPreferences value);
}

class SupabaseDemoDashboardPreferencesRepository
    implements DemoDashboardPreferencesRepository {
  const SupabaseDemoDashboardPreferencesRepository(this.client);
  final SupabaseClient client;

  String get userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in to save dashboard settings.');
    return id;
  }

  @override
  Future<DemoDashboardPreferences?> load() async {
    final row = await client.from('onboarding_demo_dashboard_preferences')
      .select().eq('user_id',userId).maybeSingle();
    return row == null ? null : DemoDashboardPreferences.fromJson(row);
  }

  @override
  Future<void> save(DemoDashboardPreferences value) async {
    await client.from('onboarding_demo_dashboard_preferences')
      .upsert({'user_id':userId,...value.toJson()},onConflict:'user_id');
  }
}
