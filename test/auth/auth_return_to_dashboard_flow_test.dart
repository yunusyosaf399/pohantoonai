import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/settings/theme_controller.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';
import 'package:pohantoonai/features/auth/data/account_mfa_repository.dart';
import 'package:pohantoonai/features/dashboard/data/dashboard_owner_profile_repository.dart';
import 'package:pohantoonai/features/onboarding/data/development_workspace_repository.dart';
import 'package:pohantoonai/features/onboarding/data/onboarding_payment_preferences_repository.dart';
import 'package:pohantoonai/features/onboarding/data/onboarding_plan_repository.dart';
import 'package:pohantoonai/features/onboarding/data/school_setup_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_payment_preferences.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_plan_offer.dart';
import 'package:pohantoonai/features/onboarding/domain/school_setup_draft.dart';
import 'package:pohantoonai/main.dart';

/// Test double models Supabase Auth user IDs, not email-as-tenant-ID.
class SimulatedAuth
    implements AccountAuthGateway, AccountEmailCredentials,
        AccountSessionIdentity {
  final changes=StreamController<String?>.broadcast();
  final recoveryEvents=StreamController<void>.broadcast();
  void startPasswordRecovery() => recoveryEvents.add(null);
  final emails=<String,String>{};
  final passwords=<String,String>{};
  String? uid;
  String? pendingEmail;
  String? pendingRecoveryEmail;
  bool failSignOut=false;

  SimulatedAuth({this.uid});
  @override
  String? get currentAuthUserId=>uid;
  @override
  Stream<String?> get sessionIdentityChanges=>changes.stream;
  @override
  bool get signedIn=>uid!=null;
  @override
  String? get signedInEmail {
    for(final e in emails.entries) {
      if(e.value==uid)return e.key;
    }
    return null;
  }
  @override
  Stream<bool> get sessionChanges=>changes.stream.map((v)=>v!=null);
  void enter(String? next){uid=next;changes.add(next);}
  @override
  Future<void> signInWithGoogle() async { enter('owner-id'); }
  @override
  Future<void> signOut() async {
    if(failSignOut)throw StateError('Unable to revoke recovery session');
    enter(null);
  }
  @override
  Future<void> sendEmailLink(String email)async{}
  @override
  Stream<void> get passwordRecoveryEvents=>recoveryEvents.stream;
  @override
  Future<void> signUpWithPassword(String email,String password)async{
    pendingEmail=email;
    passwords[email]=password;
  }
  @override
  Future<void> verifyEmailCode(String email,String code,
      {required bool isSignup})async{
    if(pendingEmail!=email||code!='123456'){
      throw StateError('Invalid simulated verification');
    }
    emails[email]='new-owner-id';
    enter('new-owner-id');
  }
  @override
  Future<void> resendSignupCode(String email)async{
    if(pendingEmail!=email)throw StateError('Unrecognized email');
  }
  @override
  Future<void> setAccountPassword(String password)async{
    final email=signedInEmail;
    if(email==null)throw StateError('Not signed in');
    passwords[email]=password;
    // Supabase also emits userUpdated after updateUser(password).
    changes.add(uid);
  }
  @override
  Future<void> signInWithPassword(String email,String password)async{
    if(passwords[email]!=password)throw StateError('Invalid credentials');
    final id=emails[email];
    if(id==null)throw StateError('Email not verified');
    enter(id);
  }
  @override
  Future<void> sendPasswordReset(String email)async{
    pendingRecoveryEmail=email;
  }
  @override
  Future<void> verifyRecoveryOtp(String email,String code)async{
    if(pendingRecoveryEmail!=email || code!='123456' ||
        !emails.containsKey(email))throw StateError('Bad recovery code');
    enter(emails[email]);
  }
  Future<void> dispose() async {
    await changes.close();
    await recoveryEvents.close();
  }
}

class SimulatedMfa implements AccountMfaRepository {
  bool enrolled=true,aal2=false;
  int verifies=0;
  @override
  Future<AccountMfaStatus> status() async => AccountMfaStatus(
    needsChallenge:enrolled&&!aal2,isAal2:aal2,
    factors:enrolled ?const [
      AccountTotpFactor(id:'factor-one',label:'Authenticator')] :const [],
  );
  @override
  Future<AccountTotpEnrollment> enroll()async=>
    const AccountTotpEnrollment(
      factorId:'new-id',secret:'SAMPLEKEY',
      otpauthUri:'otpauth://totp/test?secret=SAMPLEKEY');
  @override
  Future<void> verify(String factor,String code)async {
    verifies++;
    if(factor!='factor-one'||code!='654321')
      throw StateError('wrong code');
    aal2=true;
  }
  @override
  Future<void> unenroll(String id)async{enrolled=false;}
  @override
  Future<void> cancelEnrollment(String id)async{}
}

class UserPlans implements OnboardingPlanRepository{
  UserPlans(this.auth);
  final SimulatedAuth auth;
  final saved=<String,String>{};
  @override
  Future<String?> loadSelectedPlanId()async=>saved[auth.uid];
  @override
  Future<void> saveSelection(String planId)async{
    saved[auth.uid!]=planId;
  }
  @override
  Future<List<OnboardingPlanOffer>> loadActivePlans()async =>const [
    OnboardingPlanOffer(
      id:'growth-plan',code:'growth_demo',name:'Growth Demo',
      summary:'For growing schools and multiple campuses.',
      studentLimit:1500,campusLimit:5,staffLimit:150,
      trialDays:14,isDemo:true),
  ];
}

class UserDrafts implements SchoolSetupRepository {
  UserDrafts(this.auth);
  final SimulatedAuth auth;
  final saved=<String,SchoolSetupDraft>{};
  @override
  Future<SchoolSetupDraft?> load()async=>saved[auth.uid];
  @override
  Future<SchoolSetupDraft> save(SchoolSetupDraft d)async{
    saved[auth.uid!]=d;
    return d;
  }
}

class UserWorkspaces implements DevelopmentWorkspaceRepository {
  UserWorkspaces(this.auth,this.drafts,this.plans);
  final SimulatedAuth auth;
  final UserDrafts drafts;
  final UserPlans plans;
  final rows=<String,String>{};
  @override
  Future<bool> hasAccess(String planId)async=>
    rows[auth.uid]==planId;
  @override
  Future<void> enable(String planId)async{
    if(auth.uid==null||!drafts.saved[auth.uid]!.readyForReview||
        plans.saved[auth.uid]!=planId) {
      throw StateError('Incomplete simulated school setup');
    }
    rows[auth.uid!]=planId;
  }
}

class UserOwnerProfile implements DashboardOwnerProfileRepository{
  UserOwnerProfile(this.auth);
  final SimulatedAuth auth;
  final names=<String,String>{};
  @override
  String? get email=>auth.signedInEmail;
  @override
  Future<String?> loadDisplayName()async=>names[auth.uid];
  @override
  Future<Map<String,String?>> loadProfile()async=> {
    'display_name':names[auth.uid],'phone':null,'position':null,
  };
  @override
  Future<void> saveDisplayName(String text)async{
    names[auth.uid!]=text;
  }
  @override
  Future<void> saveProfile({
      required String displayName,String? phone,String? position})async{
    names[auth.uid!]=displayName;
  }
}

class UnpaidTestPreferences implements OnboardingPaymentPreferencesRepository{
  @override
  Future<OnboardingPaymentPreferences?> load()async=>null;
  @override
  Future<OnboardingPaymentPreferences> save(
      OnboardingPaymentPreferences value)async=>value;
}

Future<void> mountApp(WidgetTester tester,SimulatedAuth auth,
    UserPlans plans,UserDrafts drafts,UserWorkspaces workspaces,
    {bool initialRecovery=false,
     AccountMfaRepository? mfaRepository})async{
  tester.view.physicalSize=const Size(1100,980);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(PohantoonAiApp(
    initialRecoveryRequested:initialRecovery,
    authGateway:auth,mfaRepository:mfaRepository,planRepository:plans,
    schoolSetupRepository:drafts,
    developmentWorkspaceRepository:workspaces,
    ownerProfileRepository:UserOwnerProfile(auth),
    paymentPreferencesRepository:UnpaidTestPreferences(),
    themeController:ThemeController(),
  ));
  await tester.pumpAndSettle();
}

void main(){
  testWidgets('email recovery code blocks dashboard until password change '
      'and secure sign-out',(tester)async {
    final auth=SimulatedAuth()
      ..emails['owner@school.edu']='owner-id';
    addTearDown(auth.dispose);
    final plans=UserPlans(auth)..saved['owner-id']='growth-plan';
    final drafts=UserDrafts(auth)..saved['owner-id']=
      const SchoolSetupDraft(schoolName:'Secure Academy',
        schoolType:'private',contactName:'Owner',
        contactEmail:'owner@school.edu',countryCode:'AF',
        city:'Kabul',estimatedStudents:100,campusCount:1,
        readyForReview:true);
    final workspaces=UserWorkspaces(auth,drafts,plans)
      ..rows['owner-id']='growth-plan';
    await mountApp(tester,auth,plans,drafts,workspaces);
    await tester.tap(find.byKey(const Key('continue-with-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forgot-email-password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email-field')),
      'owner@school.edu');
    await tester.tap(find.byKey(const Key('email-reset-password')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('password-recovery-only-screen')),
      findsOneWidget);
    expect(find.byKey(const Key('recovery-email-otp')),findsOneWidget);
    expect(find.byKey(const Key('dashboard-main-scroll')),findsNothing);
    await tester.enterText(find.byKey(const Key('recovery-email-otp')),
      '999999');
    await tester.tap(find.byKey(const Key('recovery-verify-otp')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-error')),findsOneWidget);
    expect(find.byKey(const Key('recovery-new-password')),findsNothing);
    await tester.enterText(find.byKey(const Key('recovery-email-otp')),
      '123456');
    await tester.tap(find.byKey(const Key('recovery-verify-otp')));
    await tester.pumpAndSettle();
    expect(auth.uid,'owner-id');
    expect(find.byKey(const Key('dashboard-main-scroll')),findsNothing);
    expect(find.byKey(const Key('recovery-new-password')),findsOneWidget);
    await tester.enterText(find.byKey(const Key('recovery-new-password')),
      'A-secure-password-after-email-otp');
    await tester.enterText(find.byKey(const Key('recovery-confirm-password')),
      'A-secure-password-after-email-otp');
    await tester.tap(find.byKey(const Key('recovery-save-password')));
    await tester.pumpAndSettle();
    expect(auth.uid,isNull);
    expect(find.byKey(const Key('continue-with-email')),findsOneWidget);
    expect(find.byKey(const Key('dashboard-test-preview-title')),findsNothing);
    expect(tester.takeException(),isNull);
  });

  testWidgets('enrolled 2FA requires authenticator code before dashboard',
      (tester)async {
    final auth=SimulatedAuth(uid:'owner-id')
      ..emails['owner@school.edu']='owner-id';
    addTearDown(auth.dispose);
    final plans=UserPlans(auth)..saved['owner-id']='growth-plan';
    final drafts=UserDrafts(auth)..saved['owner-id']=
      const SchoolSetupDraft(schoolName:'Protected School',
        schoolType:'private',contactName:'Owner',
        contactEmail:'owner@school.edu',countryCode:'AF',
        city:'Kabul',estimatedStudents:120,campusCount:1,
        readyForReview:true);
    final workspaces=UserWorkspaces(auth,drafts,plans)
      ..rows['owner-id']='growth-plan';
    final mfa=SimulatedMfa();
    await mountApp(tester,auth,plans,drafts,workspaces,
      mfaRepository:mfa);
    expect(find.byKey(const Key('mfa-login-challenge-screen')),
      findsOneWidget);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);
    await tester.enterText(find.byKey(const Key('mfa-login-code')),
      '111111');
    await tester.tap(find.byKey(const Key('mfa-login-verify')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mfa-login-error')),findsOneWidget);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);
    await tester.enterText(find.byKey(const Key('mfa-login-code')),
      '654321');
    await tester.tap(find.byKey(const Key('mfa-login-verify')));
    await tester.pumpAndSettle();
    expect(mfa.aal2,isTrue);
    expect(find.byKey(const Key('mfa-login-challenge-screen')),findsNothing);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsOneWidget);
    expect(tester.takeException(),isNull);
  });


  testWidgets('password recovery never renders the signed-in dashboard '
      'under the reset screen and forces logout on success',(tester) async {
    final auth=SimulatedAuth(uid:'owner-id')
      ..emails['owner@school.edu']='owner-id';
    addTearDown(auth.dispose);
    final plans=UserPlans(auth)..saved['owner-id']='growth-plan';
    final drafts=UserDrafts(auth)..saved['owner-id']=
      const SchoolSetupDraft(
        schoolName:'Owner School',schoolType:'private',
        contactName:'Owner',contactEmail:'owner@school.edu',
        countryCode:'AF',city:'Kabul',
        estimatedStudents:120,campusCount:1,readyForReview:true);
    final workspaces=UserWorkspaces(auth,drafts,plans)
      ..rows['owner-id']='growth-plan';

    await mountApp(tester,auth,plans,drafts,workspaces);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsOneWidget);

    // An existing profile/menu route must also disappear when the
    // password-reset link arrives.
    await tester.tap(find.byKey(const Key('dashboard-profile-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Owner & security settings'),findsOneWidget);
    // Recovery grants an Auth session; this must NOT be ordinary dashboard
    // authorization even when that user had saved school membership data.
    auth.startPasswordRecovery();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('password-recovery-only-screen')),
      findsOneWidget);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);
    expect(find.byKey(const Key('dashboard-main-scroll')),findsNothing);
    expect(find.text('1,248'),findsNothing);
    expect(find.text('Owner & security settings'),findsNothing);

    await tester.enterText(find.byKey(
      const Key('recovery-new-password')),'A-long-secure-reset-password');
    await tester.enterText(find.byKey(
      const Key('recovery-confirm-password')),'A-long-secure-reset-password');
    await tester.tap(find.byKey(const Key('recovery-save-password')));
    await tester.pumpAndSettle();

    expect(auth.passwords['owner@school.edu'],
      'A-long-secure-reset-password');
    expect(auth.uid,isNull);
    expect(find.byKey(const Key('password-recovery-only-screen')),
      findsNothing);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);
    expect(find.byKey(const Key('continue-with-email')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('cold-start recovery intent blocks workspace restoration '
      'even when Auth already has an existing session',(tester) async {
    final auth=SimulatedAuth(uid:'owner-id')
      ..emails['owner@school.edu']='owner-id';
    addTearDown(auth.dispose);
    final plans=UserPlans(auth)..saved['owner-id']='growth-plan';
    final drafts=UserDrafts(auth)..saved['owner-id']=
      const SchoolSetupDraft(
        schoolName:'Private School',schoolType:'private',
        contactName:'Owner',contactEmail:'owner@school.edu',
        countryCode:'AF',city:'Kabul',
        estimatedStudents:120,campusCount:1,readyForReview:true);
    final workspaces=UserWorkspaces(auth,drafts,plans)
      ..rows['owner-id']='growth-plan';

    await mountApp(tester,auth,plans,drafts,workspaces,
      initialRecovery:true);
    expect(find.byKey(const Key('password-recovery-only-screen')),
      findsOneWidget);
    expect(find.byKey(const Key('restoring-school-workspace')),
      findsNothing);
    expect(find.byKey(const Key('dashboard-main-scroll')),findsNothing);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);
    await tester.tap(find.byKey(const Key('recovery-cancel-and-signout')));
    await tester.pumpAndSettle();
    expect(auth.uid,isNull);
    expect(find.byKey(const Key('continue-with-email')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('failed recovery sign-out keeps all dashboards inaccessible',
      (tester)async {
    final auth=SimulatedAuth(uid:'owner-id')
      ..emails['owner@school.edu']='owner-id'
      ..failSignOut=true;
    addTearDown(auth.dispose);
    final plans=UserPlans(auth)..saved['owner-id']='growth-plan';
    final drafts=UserDrafts(auth)..saved['owner-id']=
      const SchoolSetupDraft(
        schoolName:'Owner School',schoolType:'private',
        contactName:'Owner',contactEmail:'owner@school.edu',
        countryCode:'AF',city:'Kabul',estimatedStudents:100,
        campusCount:1,readyForReview:true);
    final workspaces=UserWorkspaces(auth,drafts,plans)
      ..rows['owner-id']='growth-plan';
    await mountApp(tester,auth,plans,drafts,workspaces,
      initialRecovery:true);
    await tester.enterText(find.byKey(const Key('recovery-new-password')),
      'A-strong-password-that-is-new');
    await tester.enterText(find.byKey(const Key('recovery-confirm-password')),
      'A-strong-password-that-is-new');
    await tester.tap(find.byKey(const Key('recovery-save-password')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('password-recovery-only-screen')),
      findsOneWidget);
    expect(find.byKey(const Key('recovery-error')),findsOneWidget);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);
    expect(auth.uid,'owner-id');
    // The completed password reset must not be submitted again on retry.
    auth.failSignOut=false;
    await tester.tap(find.byKey(const Key('recovery-save-password')));
    await tester.pumpAndSettle();
    expect(auth.uid,isNull);
    expect(find.byKey(const Key('continue-with-email')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('cancelling recovery signs out and never navigates to '
      'dashboard',(tester) async {
    final auth=SimulatedAuth(uid:'owner-id')
      ..emails['owner@school.edu']='owner-id';
    addTearDown(auth.dispose);
    final plans=UserPlans(auth)..saved['owner-id']='growth-plan';
    final drafts=UserDrafts(auth)..saved['owner-id']=
      const SchoolSetupDraft(
        schoolName:'Owner School',schoolType:'private',
        contactName:'Owner',contactEmail:'owner@school.edu',
        countryCode:'AF',city:'Kabul',
        estimatedStudents:120,campusCount:1,readyForReview:true);
    final workspaces=UserWorkspaces(auth,drafts,plans)
      ..rows['owner-id']='growth-plan';
    await mountApp(tester,auth,plans,drafts,workspaces);
    auth.startPasswordRecovery();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recovery-cancel-and-signout')));
    await tester.pumpAndSettle();
    expect(auth.uid,isNull);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);
    expect(find.byKey(const Key('continue-with-email')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });


  testWidgets(
      'Google owner adds password, signs out and returns to same dashboard; '
      'another user cannot reuse the visible workspace',
      (tester)async{
    final auth=SimulatedAuth(uid:'owner-id')
      ..emails['owner@school.edu']='owner-id';
    addTearDown(auth.dispose);
    final plans=UserPlans(auth)..saved['owner-id']='growth-plan';
    final drafts=UserDrafts(auth)..saved['owner-id']=const SchoolSetupDraft(
      schoolName:'Owner School',schoolType:'private',
      contactName:'School Owner',contactEmail:'owner@school.edu',
      countryCode:'AF',city:'Kabul',
      estimatedStudents:100,campusCount:1,
      readyForReview:true,
    );
    final workspace=UserWorkspaces(auth,drafts,plans)
      ..rows['owner-id']='growth-plan';
    await mountApp(tester,auth,plans,drafts,workspace);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owner & security settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owner & Security'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile-new-password')));
    await tester.enterText(find.byKey(const Key('profile-new-password')),
      'Secure-test-owner-password');
    await tester.enterText(find.byKey(const Key('profile-confirm-password')),
      'Secure-test-owner-password');
    await tester.ensureVisible(find.byKey(const Key('profile-add-password')));
    await tester.tap(find.byKey(const Key('profile-add-password')));
    await tester.pumpAndSettle();
    expect(auth.passwords['owner@school.edu'],'Secure-test-owner-password');

    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);

    await tester.tap(find.byKey(const Key('continue-with-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email-field')),
      'owner@school.edu');
    await tester.enterText(find.byKey(const Key('email-password-field')),
      'Secure-test-owner-password');
    await tester.tap(find.byKey(const Key('email-login-password')));
    await tester.pumpAndSettle();
    expect(auth.uid,'owner-id');
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsOneWidget);
    expect(find.text('Complete Your Subscription Payment'),findsNothing);

    // Account switch without a sign-out event must NOT retain owner data.
    auth.enter('another-user');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsNothing);
    expect(find.text('Choose the Right Plan for Your School'),
      findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('email signup verifies OTP then completes school setup '
      'directly into the same unpaid demo workspace',(tester)async{
    final auth=SimulatedAuth();
    addTearDown(auth.dispose);
    final plans=UserPlans(auth),drafts=UserDrafts(auth);
    final workspaces=UserWorkspaces(auth,drafts,plans);
    await mountApp(tester,auth,plans,drafts,workspaces);
    await tester.tap(find.byKey(const Key('continue-with-email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email-field')),
      'newowner@school.edu');
    await tester.enterText(find.byKey(const Key('email-password-field')),
      'Secure-new-owner-password');
    await tester.enterText(find.byKey(const Key('email-confirm-password')),
      'Secure-new-owner-password');
    await tester.tap(find.byKey(const Key('email-register-password')));
    await tester.pumpAndSettle();
    expect(auth.uid,isNull);
    await tester.enterText(find.byKey(const Key('email-verification-code')),
      '123456');
    await tester.tap(find.byKey(const Key('verify-email-code')));
    await tester.pumpAndSettle();
    expect(auth.uid,'new-owner-id');
    expect(find.text('Choose the Right Plan for Your School'),findsOneWidget);

    await tester.ensureVisible(find.byKey(
      const Key('continue-to-school-setup')));
    await tester.tap(find.byKey(const Key('continue-to-school-setup')));
    await tester.pumpAndSettle();
    Future<void> type(String field,String value)async{
      final item=find.byKey(Key('school-field-'+field));
      await tester.ensureVisible(item);
      await tester.enterText(item,value);
      await tester.pumpAndSettle();
    }
    await type('schoolName','New School');
    await type('contactName','New Owner');
    await type('contactEmail','contact@newschool.edu');
    await type('city','Kabul');
    await type('students','180');
    await type('campuses','1');
    await tester.ensureVisible(find.byKey(
      const Key('school-select-school-type')));
    await tester.tap(find.byKey(const Key('school-select-school-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private School').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('school-select-country')));
    await tester.tap(find.byKey(const Key('school-select-country')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saudi Arabia').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(
      const Key('school-continue-review')));
    await tester.tap(find.byKey(const Key('school-continue-review')));
    await tester.pumpAndSettle();
    expect(drafts.saved['new-owner-id']?.readyForReview,true);
    expect(workspaces.rows['new-owner-id'],'growth-plan');
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsOneWidget);
    expect(find.text('Complete Your Subscription Payment'),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
