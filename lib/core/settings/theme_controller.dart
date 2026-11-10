import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Appearance is available to guests and signed-in users.
/// Local setting works offline; the signed-in account's RLS-protected preference
/// is authoritative when a session is restored.
class ThemeController extends ChangeNotifier {
  ThemeController({SupabaseClient? client}) : _client = client;

  static const _localKey = 'pohantoon.theme_mode';
  final SupabaseClient? _client;
  final SharedPreferencesAsync _storage = SharedPreferencesAsync();
  ThemeMode _value = ThemeMode.system;

  ThemeMode get value => _value;

  String _toDb(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      };

  ThemeMode _fromDb(String? mode) => switch (mode) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };

  void _set(ThemeMode next) {
    if (_value == next) return;
    _value = next;
    notifyListeners();
  }

  Future<void> loadLocal() async {
    final previous = await _storage.getString(_localKey);
    _set(_fromDb(previous));
  }

  Future<void> change(ThemeMode mode) async {
    _set(mode);
    await _storage.setString(_localKey, _toDb(mode));

    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return;
    await client.from('user_preferences').upsert({
      'user_id': uid,
      'theme_mode': _toDb(mode),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> syncWithAccount() async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return;

    // Verifies the identity and initializes own missing profile/preferences.
    await client.functions.invoke('account-bootstrap');

    final data = await client
        .from('user_preferences')
        .select('theme_mode')
        .eq('user_id', uid)
        .maybeSingle();
    if (data == null) return;
    final mode = _fromDb(data['theme_mode'] as String?);
    _set(mode);
    await _storage.setString(_localKey, _toDb(mode));
  }
}
