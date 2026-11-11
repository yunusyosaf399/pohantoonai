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
import 'features/onboarding/data/onboarding_plan_repository.dart';
import 'features/onboarding/domain/onboarding_plan_offer.dart';
import 'features/onboarding/domain/school_setup_draft.dart';
import 'features/onboarding/data/school_setup_repository.dart';
import 'features/onboarding/presentation/school_setup_screen.dart';
import 'features/onboarding/presentation/school_review_preview.dart';
import 'features/onboarding/presentation/plan_selection_screen.dart';
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
    this.planRepository,
    this.schoolSetupRepository,
    this.showOrganizationPreview = false,
    this.authGateway,
    this.themeController,
  });

  /// Explicit test/developer preview only; never granted by sign-in.
  final bool showOrganizationPreview;
  final OrganizationRepository? repository;
  /// Injectable for widget tests; otherwise live RLS-backed Supabase.
  final OnboardingPlanRepository? planRepository;
  /// Optional mock repository for Step 3 widget tests.
  final SchoolSetupRepository? schoolSetupRepository;
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
  OnboardingPlanOffer? _schoolSetupPlan;
  SchoolSetupDraft? _reviewDraft;

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
        setState(() {
          _signedIn = signedIn;
          if (!signedIn) {
            _schoolSetupPlan = null;
            _reviewDraft = null;
          }
        });
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
    if (mounted) setState(() {
      _signedIn = false;
      _schoolSetupPlan = null;
      _reviewDraft = null;
    });
  }

  @override
  void dispose() {
    _authListener?.cancel();
    _theme.removeListener(_refreshTheme);
    if (_ownsTheme) _theme.dispose();
    super.dispose();
  }

  Future<void> _returnToSignIn() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Return to account sign-in?'),
        content: const Text(
          'Going back to Step 1 signs you out. Your saved plan remains '
          'attached to your account and will reappear when you sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay here')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _signOut();
    }
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
            : !_signedIn
                ? AccountWelcomeScreen(
                    auth: _auth!,
                    themeMode: _theme.value,
                    onThemeChanged: _changeTheme,
                  )
                : _schoolSetupPlan != null
                    ? _reviewDraft != null
                        ? SchoolReviewPreview(
                            draft: _reviewDraft!,
                            plan: _schoolSetupPlan!,
                            themeMode: _theme.value,
                            onThemeChanged: _changeTheme,
                            onBack: () => setState(() => _reviewDraft = null),
                          )
                        : SchoolSetupScreen(
                            plan: _schoolSetupPlan!,
                            repository: widget.schoolSetupRepository ??
                                SupabaseSchoolSetupRepository(
                                    Supabase.instance.client),
                            accountEmail: _auth?.signedInEmail,
                            themeMode: _theme.value,
                            onThemeChanged: _changeTheme,
                            onBack: () =>
                                setState(() => _schoolSetupPlan = null),
                            onContinue: (draft) =>
                                setState(() => _reviewDraft = draft),
                          )
                    : PlanSelectionScreen(
                        repository: widget.planRepository ??
                            SupabaseOnboardingPlanRepository(
                                Supabase.instance.client),
                        email: _auth?.signedInEmail,
                        themeMode: _theme.value,
                        onThemeChanged: _changeTheme,
                        onBack: _returnToSignIn,
                        onContinue: (plan) =>
                            setState(() => _schoolSetupPlan = plan),
                      ),
      );
}
