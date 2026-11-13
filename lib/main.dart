import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_configuration.dart';
import 'core/settings/appearance_settings_button.dart';
import 'core/settings/theme_controller.dart';
import 'core/ui/app_theme.dart';
import 'features/auth/data/account_auth_gateway.dart';
import 'features/auth/data/secure_session_storage.dart';
import 'features/auth/data/account_mfa_repository.dart';
import 'features/auth/presentation/account_mfa_challenge_screen.dart';
import 'features/auth/presentation/account_welcome_screen.dart';
import 'features/auth/presentation/password_recovery_dialog.dart';
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
import 'features/dashboard/presentation/live_school_dashboard_screen.dart';
import 'features/admissions/data/school_admissions_repository.dart';
import 'features/onboarding/data/development_workspace_repository.dart';
import 'features/onboarding/presentation/school_setup_screen.dart';
import 'features/onboarding/presentation/school_review_preview.dart';
import 'features/onboarding/presentation/plan_selection_screen.dart';
import 'features/organization/presentation/organization_control_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Capture the callback intent BEFORE Supabase consumes/cleans the URL.
  // A recovery session must not be interpreted as ordinary app sign-in.
  final platformRoute=Uri.tryParse(
    WidgetsBinding.instance.platformDispatcher.defaultRouteName);
  final recoveryIntent=isPasswordRecoveryCallback(Uri.base) ||
    (platformRoute!=null && isPasswordRecoveryCallback(platformRoute));
  await Supabase.initialize(
    url: SupabaseConfiguration.url,
    publishableKey: SupabaseConfiguration.publishableKey,
    // Keep sessions refreshable across app restarts. Android stores the
    // session encrypted with a Keystore-backed key and migrates prior
    // SharedPreferences sessions once. Other platforms retain the existing
    // Supabase Flutter local-storage behavior.
    authOptions:FlutterAuthClientOptions(
      persistSession:true,
      autoRefreshToken:true,
      localStorage:!kIsWeb && defaultTargetPlatform==TargetPlatform.android
        ? AndroidSecureSessionStorage() : null,
    ),
  );
  runApp(PohantoonAiApp(initialRecoveryRequested:recoveryIntent));
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
    this.admissionsRepository,
    this.showOrganizationPreview = false,
    this.initialRecoveryRequested = false,
    this.authGateway,
    this.mfaRepository,
    this.themeController,
  });

  /// Explicit test/developer preview only; never granted by sign-in.
  final bool showOrganizationPreview;
  /// Safe cold-start callback intent (captured before Supabase.initialize).
  /// This is a UI gate only; never a substitute for Auth link verification.
  final bool initialRecoveryRequested;
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
  /// Optional secure admissions backend for tests; live uses RLS Supabase.
  final SchoolAdmissionsRepository? admissionsRepository;
  final AccountAuthGateway? authGateway;
  /// Testable MFA factor provider; real sessions use Supabase Auth.
  final AccountMfaRepository? mfaRepository;
  final ThemeController? themeController;

  @override
  State<PohantoonAiApp> createState() => _PohantoonAiAppState();
}

class _PohantoonAiAppState extends State<PohantoonAiApp> {
  late final ThemeController _theme;
  late final bool _ownsTheme;
  AccountAuthGateway? _auth;
  StreamSubscription<String?>? _authListener;
  String? _activeAuthUserId;
  StreamSubscription<void>? _recoveryListener;
  final GlobalKey<NavigatorState> _navigatorKey=GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _recoveryNavigatorKey=
    GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey=
    GlobalKey<ScaffoldMessengerState>();

  void _showWorkspaceMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notice=_workspaceError;
      if(!mounted||notice==null)return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content:Text(notice)));
    });
  }

  // Password-reset callbacks grant a temporary Auth session. They must never
  // initialize or reveal a school/student dashboard.
  bool _recoveringPassword = false;
  String? _recoveryEmail;
  bool _checkingMfa=false;
  bool _mfaRequired=false;
  int _mfaCheckGeneration=0;

  bool _signedIn = false;
  String? _authError;
  OnboardingPlanOffer? _schoolSetupPlan;
  SchoolSetupDraft? _reviewDraft;
  String? _editSection;
  bool _paymentStep = false;
  bool _dashboardTestPreview = false;
  List<AdmissionsSchool> _liveSchools=const [];
  bool _restoringWorkspace=false;
  String? _workspaceError;
  int _authGeneration=0;

  AccountMfaRepository? get _mfa =>
    widget.mfaRepository ??
      (widget.authGateway==null
        ? SupabaseAccountMfaRepository(Supabase.instance.client)
        : null);

  SchoolAdmissionsRepository? get _admissions =>
    widget.admissionsRepository ??
      (widget.authGateway==null
        ? SupabaseSchoolAdmissionsRepository(Supabase.instance.client)
        : null);

  // After passing the MFA gate, first check ACTIVE database membership.
  // Never use school_setup_drafts or development preview as authorization.
  Future<void> _resolveRealSchoolOrPreview() async {
    if(!mounted||!_signedIn||_recoveringPassword)return;
    final repo=_admissions;
    if(repo==null) {
      _loadAccountPreferences();
      _restoreWorkspace();
      return;
    }
    final serial=++_authGeneration;
    setState((){
      _restoringWorkspace=true;
      _workspaceError=null;
      _liveSchools=const [];
    });
    try {
      final available=await repo.availableSchools();
      if(!mounted||serial!=_authGeneration||!_signedIn||
          _recoveringPassword)return;
      if(available.isNotEmpty) {
        // Authenticated school administration takes priority over onboarding.
        setState((){
          _liveSchools=available;
          _restoringWorkspace=false;
          _schoolSetupPlan=null;
          _reviewDraft=null;
          _dashboardTestPreview=false;
          _paymentStep=false;
        });
        _loadAccountPreferences();
        return;
      }
      _loadAccountPreferences();
      if(_workspaces==null) {
        // Isolated widget tests may supply an admissions fake without
        // development-workspace storage. Do not leave an endless spinner.
        setState(()=>_restoringWorkspace=false);
        return;
      }
      _restoreWorkspace();
    }catch(_){
      if(!mounted||serial!=_authGeneration)return;
      // Fail closed when school access cannot be verified; never treat
      // network errors as an invitation to bypass provisioning.
      setState((){
        _liveSchools=const [];
        _restoringWorkspace=false;
        _workspaceError='Could not verify your authorized schools. '
          'Check the connection and retry.';
      });
      _showWorkspaceMessage();
    }
  }

  Future<void> _checkMfaAndRestore()async{
    if(!mounted||!_signedIn||_recoveringPassword)return;
    final repo=_mfa;
    if(repo==null) {
      await _resolveRealSchoolOrPreview();
      return;
    }
    final serial=++_mfaCheckGeneration;
    // Keep the gate visible until the actual MFA status request finishes.
    // Previously this block incremented _mfaCheckGeneration a second time
    // and cleared _checkingMfa, causing every result to be discarded.
    setState((){
      _checkingMfa=true;
      _mfaRequired=false;
      ++_authGeneration;
      _restoringWorkspace=false;
      _liveSchools=const [];
      _schoolSetupPlan=null;
      _reviewDraft=null;
      _dashboardTestPreview=false;
      _paymentStep=false;
    });
    try {
      final status=await repo.status();
      if(!mounted||serial!=_mfaCheckGeneration||
          !_signedIn||_recoveringPassword)return;
      if(status.needsChallenge) {
        setState((){
          _checkingMfa=false;
          _mfaRequired=true;
          _schoolSetupPlan=null;
          _reviewDraft=null;
          _dashboardTestPreview=false;
          _paymentStep=false;
        });
      }else{
        setState((){
          _checkingMfa=false;
          _mfaRequired=false;
        });
        await _resolveRealSchoolOrPreview();
      }
    }catch(_){
      if(mounted&&serial==_mfaCheckGeneration&&!_recoveringPassword){
        // Fail CLOSED. No network error may fall through to the dashboard.
        setState((){
          _checkingMfa=false;
          _mfaRequired=true;
          _schoolSetupPlan=null;
          _reviewDraft=null;
          _dashboardTestPreview=false;
        });
      }
    }
  }

  Future<void> _mfaVerified() async {
    // AAL2 must be confirmed from Supabase, never from a local boolean.
    await _checkMfaAndRestore();
  }

  void _startRecoveryWithEmail(String email) {
    _startPasswordRecovery();
    if(mounted)setState(()=>_recoveryEmail=email);
  }

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
    if(repository==null||!_signedIn||_recoveringPassword)return;
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
              _signedIn && !_recoveringPassword) {
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
        _showWorkspaceMessage();
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
      if(mounted){
        setState(()=>_workspaceError=
          'School details were saved, but demo access could not be enabled. '
          'Retry opening the dashboard.');
        _showWorkspaceMessage();
      }
    }finally{
      if(mounted)setState(()=>_restoringWorkspace=false);
    }
  }


  void _startPasswordRecovery() {
    if(!mounted || _recoveringPassword)return;
    setState((){
      _recoveringPassword=true;
      _recoveryEmail=null;
      ++_mfaCheckGeneration;
      _checkingMfa=false;
      _mfaRequired=false;
      // Invalidate a potentially in-flight workspace restore, and remove
      // the previous user's school from the entire widget tree immediately.
      ++_authGeneration;
      _restoringWorkspace=false;
      _workspaceError=null;
      _authError=null;
      _schoolSetupPlan=null;
      _reviewDraft=null;
      _editSection=null;
      _paymentStep=false;
      _dashboardTestPreview=false;
      _liveSchools=const [];
    });
  }

  Future<void> _exitPasswordRecovery() async {
    // A Supabase recovery link issues a temporary Auth session. Do not
    // let its success/cancel path turn that session into app access.
    // If sign-out fails, keep the exclusive recovery screen visible.
    await _signOut();
    if(mounted)setState((){
      _recoveringPassword=false;
      _recoveryEmail=null;
    });
  }

  @override
  void initState() {
    super.initState();
    _ownsTheme = widget.themeController == null;
    // Web cold-start callback safety: the Auth SDK might already have
    // exchanged the recovery link before the first widget subscribes.
    // The marker never authorizes a password update on its own.
    _recoveringPassword = widget.initialRecoveryRequested ||
      isPasswordRecoveryCallback(Uri.base);

    if (widget.showOrganizationPreview) {
      _theme = widget.themeController ?? ThemeController();
    } else {
      final client = widget.authGateway == null
          ? Supabase.instance.client : null;
      _auth = widget.authGateway ??
          SupabaseAccountAuthGateway(client!);
      _theme = widget.themeController ?? ThemeController(client: client);
      _signedIn = _auth!.signedIn;
      _activeAuthUserId = _signedIn
          ? (_auth is AccountSessionIdentity
              ? (_auth as AccountSessionIdentity).currentAuthUserId
              : 'legacy-auth-session')
          : null;
      if(_auth is AccountEmailCredentials){
        final credentials=_auth as AccountEmailCredentials;
        _recoveryListener=credentials.passwordRecoveryEvents.listen((_) {
          // Never open a dialog above a signed-in dashboard. Replace the
          // whole application home with the isolated reset screen instead.
          _startPasswordRecovery();
        },onError:(Object _,StackTrace __){});
      }
      // The production Auth gateway emits the actual stable auth.users.id.
      // An account switch invalidates A's rendered data even if there is
      // no intermediate signed-out event. Legacy widget fakes are supported.
      final Stream<String?> identityStream =
          _auth is AccountSessionIdentity
              ? (_auth as AccountSessionIdentity).sessionIdentityChanges
              : _auth!.sessionChanges.map((signedIn) =>
                  signedIn ? 'legacy-auth-session' : null);
      _authListener = identityStream.listen((userId) {
        if (!mounted) return;
        final wasSignedIn=_signedIn;
        final changedUser=_activeAuthUserId != userId;
        final signedIn=userId != null;
        setState(() {
          _activeAuthUserId=userId;
          _signedIn=signedIn;
          if(signedIn)_authError=null;
          if(!signedIn || (wasSignedIn && changedUser)){
            ++_authGeneration;
            ++_mfaCheckGeneration;
            _checkingMfa=false;
            _mfaRequired=false;
            _restoringWorkspace=false;
            _liveSchools=const [];
            _schoolSetupPlan=null;
            _reviewDraft=null;
            _editSection=null;
            _paymentStep=false;
            _dashboardTestPreview=false;
          }
          // Gate new or changed accounts immediately. For token refresh
          // of the same account, preserve the current screen and session.
          if(signedIn&&(!wasSignedIn||changedUser)&&
              !_recoveringPassword&&_mfa!=null){
            _checkingMfa=true;
          }
        });
        // Token refresh and userUpdated keep the SAME user. Never reset
        // their dashboard or race another MFA query on those events.
        if(signedIn && (!wasSignedIn||changedUser) &&
            !_recoveringPassword){
          _checkMfaAndRestore();
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
      if(_signedIn&&!_recoveringPassword){
        _checkingMfa=_mfa!=null;
        // Cold-started sessions are not authorized to display the
        // dashboard until factor assurance has been checked.
        WidgetsBinding.instance.addPostFrameCallback((_){
          if(mounted)_checkMfaAndRestore();
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
      _activeAuthUserId = null;
      _authError = null;
      _schoolSetupPlan = null;
      _reviewDraft = null;
      _editSection = null;
      _paymentStep = false;
      _dashboardTestPreview = false;
      _liveSchools=const [];
    });
  }

  @override
  void dispose() {
    _authListener?.cancel();
    _recoveryListener?.cancel();
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
        // A separate navigator discards any existing modal sheet, dialog,
        // or school route when recovery begins. No dashboard remains
        // underneath the recovery screen.
        navigatorKey:_recoveringPassword
          ? _recoveryNavigatorKey : _navigatorKey,
        scaffoldMessengerKey:_messengerKey,
        title: 'Pohantoon AI',
        theme: PohantoonTheme.light,
        darkTheme: PohantoonTheme.dark,
        themeMode: _theme.value,
        home: widget.showOrganizationPreview
            ? OrganizationControlPanel(repository: widget.repository)
            : _recoveringPassword && _auth is AccountEmailCredentials
                ? PasswordRecoveryScreen(
                    key: const Key('isolated-password-recovery'),
                    auth: _auth! as AccountEmailCredentials,
                    onComplete: _exitPasswordRecovery,
                    onCancel: _exitPasswordRecovery,
                    recoveryEmail:_recoveryEmail,
                  )
            : !_signedIn
                ? AccountWelcomeScreen(
                    auth: _auth!,
                    authError: _authError,
                    onAuthRetry: () => setState(() => _authError = null),
                    onRecoveryCodeRequested:_startRecoveryWithEmail,
                    themeMode: _theme.value,
                    onThemeChanged: _changeTheme,
                  )
                : _checkingMfa
                    ? const Scaffold(body:Center(
                        child:CircularProgressIndicator(
                          key:Key('checking-account-two-factor'))))
                : _mfaRequired && _mfa!=null
                    ? AccountMfaChallengeScreen(
                        key:const Key('exclusive-mfa-gate'),
                        repository:_mfa!,
                        onVerified:_mfaVerified,
                        onSignOut:_signOut,
                      )
                : _restoringWorkspace
                    ? const Scaffold(
                        body: Center(child: CircularProgressIndicator(
                          key: Key('restoring-school-workspace'))))
                : _workspaceError!=null
                    ? Scaffold(
                        body:Center(child:ConstrainedBox(
                          constraints:const BoxConstraints(maxWidth:400),
                          child:Padding(
                            padding:const EdgeInsets.all(24),
                            child:Column(
                              mainAxisSize:MainAxisSize.min,
                              children:[
                                const Icon(Icons.wifi_off_outlined,size:38),
                                const SizedBox(height:12),
                                Text(_workspaceError!,
                                  key:const Key('session-restore-error'),
                                  textAlign:TextAlign.center),
                                const SizedBox(height:12),
                                FilledButton.icon(
                                  key:const Key('session-restore-retry'),
                                  onPressed:_checkMfaAndRestore,
                                  icon:const Icon(Icons.refresh),
                                  label:const Text('Retry secure session')),
                                TextButton(
                                  onPressed:_signOut,
                                  child:const Text('Sign out')),
                              ],
                            ),
                          ),
                        )))
                : _liveSchools.isNotEmpty && _admissions!=null
                    ? LiveSchoolDashboardScreen(
                        key:ValueKey('live-school-${_activeAuthUserId??''}'),
                        schools:_liveSchools,
                        repository:_admissions!,
                        themeMode:_theme.value,
                        onThemeChanged:_changeTheme,
                        onSignOut:()=>_signOut(),
                      )
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
                            mfaRepository:_mfa,
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
