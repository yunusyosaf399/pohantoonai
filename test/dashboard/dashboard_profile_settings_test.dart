import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';
import 'package:pohantoonai/features/dashboard/data/dashboard_owner_profile_repository.dart';
import 'package:pohantoonai/features/dashboard/presentation/dashboard_profile_settings.dart';
import 'package:pohantoonai/features/onboarding/data/school_setup_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/school_setup_draft.dart';

class FakeOwnerProfile implements DashboardOwnerProfileRepository {
  final values=<String,String?>{
    'display_name':'Original Owner',
    'phone':null,'position':null,
  };
  @override
  String? get email=>'owner@school.edu';
  @override
  Future<Map<String,String?>> loadProfile() async => Map.of(values);
  @override
  Future<String?> loadDisplayName() async => values['display_name'];
  @override
  Future<void> saveDisplayName(String name) async {
    values['display_name']=name;
  }
  @override
  Future<void> saveProfile({
    required String displayName,String? phone,String? position})async {
    values['display_name']=displayName;
    values['phone']=phone;
    values['position']=position;
  }
}

class FakeSchoolRepository implements SchoolSetupRepository {
  SchoolSetupDraft? latest;
  @override
  Future<SchoolSetupDraft?> load()async=>latest;
  @override
  Future<SchoolSetupDraft> save(SchoolSetupDraft draft)async{
    latest=draft;return draft;
  }
}

class FakeCredentials implements AccountEmailCredentials {
  String? updatedPassword;
  @override
  Stream<void> get passwordRecoveryEvents=>const Stream<void>.empty();
  @override
  Future<void> setAccountPassword(String password)async{
    updatedPassword=password;
  }
  @override
  Future<void> signUpWithPassword(String e,String p)async{}
  @override
  Future<void> verifyEmailCode(String e,String c,
    {required bool isSignup})async{}
  @override
  Future<void> signInWithPassword(String e,String p)async{}
  @override
  Future<void> resendSignupCode(String e)async{}
  @override
  Future<void> sendPasswordReset(String e)async{}
}

const testDraft=SchoolSetupDraft(
  schoolName:'School One',contactName:'School Contact',
  contactEmail:'contact@school.edu',city:'Kabul',
  countryCode:'AF',estimatedStudents:100,campusCount:1,
  readyForReview:true,
);

Future<void> mount(WidgetTester tester,FakeOwnerProfile owner,
    FakeSchoolRepository school,FakeCredentials credentials)async{
  tester.view.physicalSize=const Size(900,950);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
    DashboardProfileSettings(
      draft:testDraft,schoolRepository:school,
      ownerRepository:owner,credentials:credentials,
      onDraftSaved:(_){},
    ))));
  await tester.pumpAndSettle();
}

void main(){
  testWidgets('owner can edit own name phone and position without onboarding',
    (tester)async{
    final owner=FakeOwnerProfile(),school=FakeSchoolRepository();
    final auth=FakeCredentials();
    await mount(tester,owner,school,auth);
    await tester.tap(find.text('Owner & Security'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-owner-name')),
      'Updated Owner');
    await tester.enterText(find.byKey(const Key('profile-owner-phone')),
      '+93 700 123456');
    await tester.enterText(find.byKey(const Key('profile-owner-position')),
      'Director');
    await tester.ensureVisible(find.byKey(const Key('profile-save-owner')));
    await tester.tap(find.byKey(const Key('profile-save-owner')));
    await tester.pumpAndSettle();
    expect(owner.values['display_name'],'Updated Owner');
    expect(owner.values['phone'],'+93 700 123456');
    expect(owner.values['position'],'Director');
    expect(find.text('Continue to Review'),findsNothing);
  });

  testWidgets('Google owner can create password inside dashboard',
    (tester)async{
    final owner=FakeOwnerProfile(),school=FakeSchoolRepository();
    final auth=FakeCredentials();
    await mount(tester,owner,school,auth);
    await tester.tap(find.text('Owner & Security'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile-new-password')));
    await tester.enterText(find.byKey(const Key('profile-new-password')),
      'Very-strong-password-2026');
    await tester.enterText(find.byKey(const Key('profile-confirm-password')),
      'Very-strong-password-2026');
    await tester.ensureVisible(find.byKey(const Key('profile-add-password')));
    await tester.tap(find.byKey(const Key('profile-add-password')));
    await tester.pumpAndSettle();
    expect(auth.updatedPassword,'Very-strong-password-2026');
    expect(tester.takeException(),isNull);
  });
}
