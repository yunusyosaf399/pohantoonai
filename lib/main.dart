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
import 'features/onboarding/data/review_confirmation_repository.dart';
import 'features/onboarding/presentation/school_payment_preview.dart';
import 'features/onboarding/presentation/school_dashboard_setup_preview.dart';
import 'features/onboarding/data/onboarding_payment_preferences_repository.dart';
import 'features/onboarding/data/school_logo_repository.dart';
import 'features/dashboard/data/demo_dashboard_preferences_repository.dart';
import 'features/dashboard/data/dashboard_owner_profile_repository.dart';
import 'features/onboarding/data/development_workspace_repository.dart';
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
    this.reviewConfirmationRepository,
    this.paymentPreferencesRepository,
    this.logoRepository,
    this.demoDashboardPreferencesRepository,
    this.developmentWorkspaceRepository,
    this.ownerProfileRepository,
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
  /// Injectable review persistence for widget tests; live app uses RLS.
  final ReviewConfirmationRepository? reviewConfirmationRepository;
  /// Mockable Step 5; real implementation uses applicant-owned RLS.
  final OnboardingPaymentPreferencesRepository? paymentPreferencesRepository;
  final SchoolLogoRepository? logoRepository;
  final DemoDashboardPreferencesRepository? demoDashboardPreferencesRepository;
  final DevelopmentWorkspaceRepository? developmentWorkspaceRepository;
  final DashboardOwnerProfileRepository? ownerProfileRepository;
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
  String? _authError;
  OnboardingPlanOffer? _schoolSetupPlan;
  SchoolSetupDraft? _reviewDraft;
  String? _editSection;
  bool _paymentStep = false;
  bool _dashboardTestPreview = false;
  bool _restoringWorkspace=false;
  String? _workspaceError;
  int _authGeneration=0;

  DevelopmentWorkspaceRepository? get _workspaces =>
    widget.developmentWorkspaceRepository ??
      (widget.authGateway == null
        ? SupabaseDevelopmentWorkspaceRepository(Supabase.instance.client)
        : null);

  OnboardingPlanRepository get _plans =>
    widget.planRepository ??
      SupabaseOnboardingPlanRepository(Supabase.instance.client);

  SchoolSetupRepository get _schoolDrafts =>
    widget.schoolSetupRepository ??
      SupabaseSchoolSetupRepository(Supabase.instance.client);

  Future<void> _restoreWorkspace() async {
    final repository=_workspaces;
    if(repository==null||!_signedIn)return;
    final generation=++_authGeneration;
    setState((){
      _restoringWorkspace=true;
      _workspaceError=null;
    });
    try {
      final planId=await _plans.loadSelectedPlanId();
      if(planId!=null) {
        final offers=await _plans.loadActivePlans();
        final matching=offers.where((p)=>p.id==planId).firstOrNull;
        final draft=await _schoolDrafts.load();
        if(matching!=null&&matching.isDemo&&draft!=null&&
            draft.readyForReview) {
          var active=await repository.hasAccess(planId);
          if(!active) {
            // Legacy users who previously skipped payment migrate through
            // their own authenticated session, not a privileged backfill.
            final previous=await (widget.paymentPreferencesRepository ??
              SupabaseOnboardingPaymentPreferencesRepository(
                Supabase.instance.client)).load();
            if(previous?.skippedForTesting==true){
              await repository.enable(planId);
              active=await repository.hasAccess(planId);
            }
          }
          if(active && mounted && generation==_authGeneration &&
              _signedIn) {
            setState((){
              _schoolSetupPlan=matching;
              _reviewDraft=draft;
              _paymentStep=false;
              _dashboardTestPreview=true;
            });
          }
        }
      }
    }catch(_){
      if(mounted&&generation==_authGeneration){
        setState(()=>_workspaceError=
          'Could not check your saved school dashboard. '
          'Check the connection and retry.');
      }
    }finally{
      if(mounted&&generation==_authGeneration) {
        setState(()=>_restoringWorkspace=false);
      }
    }
  }

  Future<void> _finishSchoolSetup(SchoolSetupDraft draft) async {
    final repo=_workspaces;
    if(repo==null) {
      // Injected legacy widget tests can still exercise Steps 4/5.
      setState(()=>_reviewDraft=draft);
      return;
    }
    final plan=_schoolSetupPlan;
    if(plan==null)return;
    setState((){
      _restoringWorkspace=true;
      _workspaceError=null;
    });
    try {
      await repo.enable(plan.id);
      if(!mounted)return;
      setState((){
        _reviewDraft=draft;
        _dashboardTestPreview=true;
        _paymentStep=false;
      });
    }catch(_){
      if(mounted)setState(()=>_workspaceError=
        'School details were saved, but demo access could not be enabled. '
        'Retry opening the dashboard.');
    }finally{
      if(mounted)setState(()=>_restoringWorkspace=false);
    }
  }


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
        final wasSignedIn=_signedIn;
        setState(() {
          _signedIn = signedIn;
          if (signedIn) _authError = null;
          if (!signedIn) {
            ++_authGeneration;
            _restoringWorkspace = false;
            _schoolSetupPlan = null;
            _reviewDraft = null;
            _editSection = null;
            _paymentStep = false;
            _dashboardTestPreview = false;
          }
        });
        if (signedIn && !wasSignedIn) {
          _loadAccountPreferences();
          _restoreWorkspace();
        }
      }, onError: (Object error, StackTrace stack) {
        // Supabase emits OAuth code-exchange failures and network failures
        // on the auth stream. Without onError they become uncaught errors.
        // Never log full callback URIs, codes, JWTs or auth provider tokens.
        if (!mounted) return;
        debugPrint('Supabase Auth callback could not complete.');
        setState(() {
          _authError = 'Sign-in could not finish. Check that the browser '
              'returned to Pohantoon AI, then try again. If it repeats, '
              'verify your Supabase Auth redirect URL settings.';
        });
      });
      // The storage plugin may not be available in isolated widget tests;
      // the app remains usable with system theme in that case.
      _theme.loadLocal().catchError((Object _) {});
      if (_signedIn) {
        _loadAccountPreferences();
        // Delay until initState returns to avoid setState-during-build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted)_restoreWorkspace();
        });
      }
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
      ++_authGeneration;
      _restoringWorkspace=false;
      _signedIn = false;
      _authError = null;
      _schoolSetupPlan = null;
      _reviewDraft = null;
      _editSection = null;
      _paymentStep = false;
      _dashboardTestPreview = false;
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
                    authError: _authError,
                    onAuthRetry: () => setState(() => _authError = null),
                    themeMode: _theme.value,
                    onThemeChanged: _changeTheme,
                  )
                : _restoringWorkspace
                    ? const Scaffold(
                        body: Center(child: CircularProgressIndicator(
                          key: Key('restoring-school-workspace'))))
                : _schoolSetupPlan != null
                    ? _dashboardTestPreview
                        ? SchoolDashboardSetupPreview(
                            plan: _schoolSetupPlan!,
                            draft: _reviewDraft!,
                            themeMode: _theme.value,
                            onThemeChanged: _changeTheme,
                            preferencesRepository: widget.demoDashboardPreferencesRepository ??
                                (widget.authGateway == null
                                  ? SupabaseDemoDashboardPreferencesRepository(
                                      Supabase.instance.client)
                                  : null),
                            logoRepository: widget.logoRepository ??
                                (widget.authGateway == null
                                  ? SupabaseSchoolLogoRepository(
                                      Supabase.instance.client)
                                  : null),
                            schoolRepository: widget.schoolSetupRepository ??
                                (widget.authGateway == null
                                  ? SupabaseSchoolSetupRepository(
                                      Supabase.instance.client)
                                  : null),
                            ownerRepository: widget.ownerProfileRepository ??
                                (widget.authGateway == null
                                  ? SupabaseDashboardOwnerProfileRepository(
                                      Supabase.instance.client)
                                  : null),
                            credentials: _auth is AccountEmailCredentials
                                ? _auth as AccountEmailCredentials : null,
                            onDraftSaved: (saved) => setState(() {
                              _reviewDraft=saved;
                            }),
                            onSignOut: () => _signOut(),
                            onEditDetails: (section) => setState(() {
                              _dashboardTestPreview = false;
                              _paymentStep = false;
                              _reviewDraft = null;
                              _editSection = section;
                            }),
                            onBack: () =>
                                setState(() => _dashboardTestPreview = false),
                          )
                        : _paymentStep
                            ? SchoolPaymentPreview(
                                plan: _schoolSetupPlan!,
                                draft: _reviewDraft!,
                                repository: widget.paymentPreferencesRepository ??
                                    SupabaseOnboardingPaymentPreferencesRepository(
                                      Supabase.instance.client),
                                accountEmail: _auth?.signedInEmail,
                                themeMode: _theme.value,
                                onThemeChanged: _changeTheme,
                                onBack: () =>
                                    setState(() => _paymentStep = false),
                                onSkip: () =>
                                    setState(() => _dashboardTestPreview = true),
                              )
                            : _reviewDraft != null
                            ? SchoolReviewPreview(
                                draft: _reviewDraft!,
                                plan: _schoolSetupPlan!,
                                repository: widget.reviewConfirmationRepository ??
                                    SupabaseReviewConfirmationRepository(
                                      Supabase.instance.client),
                                accountEmail: _auth?.signedInEmail,
                                logoRepository: widget.logoRepository ??
                                    (widget.authGateway == null
                                      ? SupabaseSchoolLogoRepository(
                                          Supabase.instance.client)
                                      : null),
                                themeMode: _theme.value,
                                onThemeChanged: _changeTheme,
                                onBack: () => setState(() {
                                  _reviewDraft = null;
                                  _editSection = null;
                                }),
                                onEditSection: (section) => setState(() {
                                  _reviewDraft = null;
                                  _editSection = section;
                                }),
                                onGoToPayment: () => _workspaces == null
                                  ? setState(() => _paymentStep = true)
                                  : _finishSchoolSetup(_reviewDraft!),
                              )
                            : SchoolSetupScreen(
                                plan: _schoolSetupPlan!,
                                repository: widget.schoolSetupRepository ??
                                    SupabaseSchoolSetupRepository(
                                        Supabase.instance.client),
                                initialSection: _editSection,
                                logoRepository: widget.logoRepository,
                                directDashboard: _workspaces != null,
                                accountEmail: _auth?.signedInEmail,
                                themeMode: _theme.value,
                                onThemeChanged: _changeTheme,
                                onBack: () => setState(() {
                                  _schoolSetupPlan = null;
                                  _editSection = null;
                                }),
                                onContinue: (draft) {
                                  _editSection = null;
                                  _finishSchoolSetup(draft);
                                },
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
