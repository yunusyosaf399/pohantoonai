import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_configuration.dart';
import 'core/settings/appearance_settings_button.dart';
import 'core/settings/theme_controller.dart';
import 'core/ui/app_theme.dart';
import 'features/auth/data/account_auth_gateway.dart';
import 'features/auth/presentation/account_welcome_screen.dart';
import 'features/organization/data/organization_repository.dart';
import 'features/organization/presentation/organization_control_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfiguration.url,
    publishableKey: SupabaseConfiguration.publishableKey,
  );
  runApp(const PohantoonAiApp());
}

/// One Flutter app across Android, iOS, Windows, macOS, Linux and Web.
/// New users ALWAYS start at Step 1 and cannot access the SaaS operator
/// control panel merely by authenticating.
class PohantoonAiApp extends StatefulWidget {
  const PohantoonAiApp({
    super.key,
    this.repository,
    this.showOrganizationPreview = false,
    this.authGateway,
    this.themeController,
  });

  /// Explicit test/developer preview only; never granted by sign-in.
  final bool showOrganizationPreview;
  final OrganizationRepository? repository;
  final AccountAuthGateway? authGateway;
  final ThemeController? themeController;

  @override
  State<PohantoonAiApp> createState() => _PohantoonAiAppState();
}

class _PohantoonAiAppState extends State<PohantoonAiApp> {
  late final ThemeController _theme;
  late final bool _ownsTheme;
  AccountAuthGateway? _auth;
  StreamSubscription<bool>? _authListener;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _ownsTheme = widget.themeController == null;

    if (widget.showOrganizationPreview) {
      _theme = widget.themeController ?? ThemeController();
    } else {
      final client = widget.authGateway == null
          ? Supabase.instance.client : null;
      _auth = widget.authGateway ??
          SupabaseAccountAuthGateway(client!);
      _theme = widget.themeController ?? ThemeController(client: client);
      _signedIn = _auth!.signedIn;
      _authListener = _auth!.sessionChanges.listen((signedIn) {
        if (!mounted) return;
        setState(() => _signedIn = signedIn);
        if (signedIn) _loadAccountPreferences();
      });
      // The storage plugin may not be available in isolated widget tests;
      // the app remains usable with system theme in that case.
      _theme.loadLocal().catchError((Object _) {});
      if (_signedIn) _loadAccountPreferences();
    }
    _theme.addListener(_refreshTheme);
  }

  void _refreshTheme() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAccountPreferences() async {
    try {
      await _theme.syncWithAccount();
    } catch (error) {
      // The user is still authenticated even if preferences are unavailable.
      debugPrint('Could not sync appearance settings after sign-in.');
    }
  }

  Future<void> _changeTheme(ThemeMode mode) => _theme.change(mode);

  Future<void> _signOut() async {
    await _auth!.signOut();
    if (mounted) setState(() => _signedIn = false);
  }

  @override
  void dispose() {
    _authListener?.cancel();
    _theme.removeListener(_refreshTheme);
    if (_ownsTheme) _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pohantoon AI',
        theme: PohantoonTheme.light,
        darkTheme: PohantoonTheme.dark,
        themeMode: _theme.value,
        home: widget.showOrganizationPreview
            ? OrganizationControlPanel(repository: widget.repository)
            : _signedIn
                ? _AuthenticatedAccountScreen(
                    email: _auth?.signedInEmail,
                    mode: _theme.value,
                    onThemeChanged: _changeTheme,
                    onSignOut: _signOut,
                  )
                : AccountWelcomeScreen(
                    auth: _auth!,
                    themeMode: _theme.value,
                    onThemeChanged: _changeTheme,
                  ),
      );
}

/// Step 1 success state only. School plan setup is a separate user workflow;
/// we deliberately DO NOT show the organization admin dashboard here.
class _AuthenticatedAccountScreen extends StatelessWidget {
  const _AuthenticatedAccountScreen({
    required this.email,
    required this.mode,
    required this.onThemeChanged,
    required this.onSignOut,
  });

  final String? email;
  final ThemeMode mode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pohantoon AI'),
        actions: [
          AppearanceSettingsButton(mode: mode, onChanged: onThemeChanged),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded,
                        size: 70, color: colors.primary),
                      const SizedBox(height: 22),
                      Text('Your account is connected',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(email ?? 'Signed-in Pohantoon AI user',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      const LinearProgressIndicator(value: 1 / 6),
                      const SizedBox(height: 13),
                      const Text('Step 1 of 6 complete.'),
                      const SizedBox(height: 10),
                      const Text(
                        'Subscription plan selection and school registration '
                        'will follow in Step 2. Signing in does not automatically '
                        'create a school or grant organization-admin access.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
