import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/settings/theme_controller.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';
import 'package:pohantoonai/features/auth/data/account_mfa_repository.dart';
import 'package:pohantoonai/features/provisioning/data/school_activation_repository.dart';
import 'package:pohantoonai/features/platform/data/platform_monitoring_repository.dart';
import 'package:pohantoonai/main.dart';

class _SignedInOperator implements AccountAuthGateway,AccountSessionIdentity {
  @override bool get signedIn=>true;
  @override String? get signedInEmail=>'operator@example.invalid';
  @override String? get currentAuthUserId=>'operator-user-id';
  @override Stream<bool> get sessionChanges=>const Stream<bool>.empty();
  @override Stream<String?> get sessionIdentityChanges=>
    const Stream<String?>.empty();
  @override Future<void> signInWithGoogle() async {}
  @override Future<void> sendEmailLink(String email) async {}
  @override Future<void> signOut() async {}
}

class _PassedMfa implements AccountMfaRepository {
  @override
  Future<AccountMfaStatus> status() async=>
    const AccountMfaStatus(
      needsChallenge:false,isAal2:true,factors:[]);
  @override
  Future<AccountTotpEnrollment> enroll() async=>
    const AccountTotpEnrollment(
      factorId:'test',secret:'TESTKEY',
      otpauthUri:'otpauth://totp/test?secret=TESTKEY');
  @override Future<void> verify(String factor,String code) async {}
  @override Future<void> unenroll(String id) async {}
  @override Future<void> cancelEnrollment(String id) async {}
}

class _OperatorRepository implements SchoolActivationRepository {
  @override
  Future<String> operatorRole() async=>'authorized';
  @override
  Future<SchoolActivationStatus?> ownRequest() async=>null;
  @override
  Future<String> submitRequest() async=>'none';
  @override
  Future<List<SchoolActivationReview>> operatorQueue({
    int offset=0,int limit=50,
  }) async=>const [];
  @override
  Future<String> approve({
    required String requestId,required String activationBasis,
    required String evidence,required bool identityVerified,
  }) async=>throw StateError('Not a live test');
  @override
  Future<void> reject({
    required String requestId,required String reason,
  }) async=>throw StateError('Not a live test');
  @override
  Future<void> requestInformation({
    required String requestId,required String reason,
  }) async {}

}

class _EmptyPlatformMonitoring implements PlatformMonitoringRepository {
  @override Future<PlatformSummary> overview() async=>PlatformSummary.empty;
  @override Future<List<PlatformTrend>> trends() async=>const [];
  @override Future<List<PlatformSchool>> schools({
    required int offset,int limit=50,
  }) async=>const [];
  @override Future<List<PlatformSchoolAccount>> accounts({
    required int offset,int limit=50,
  }) async=>const [];
  @override Future<List<PlatformReviewEvent>> history() async=>const [];
}

void main(){
  testWidgets('MFA-passed audited platform operator routes to real review console',
    (tester)async{
    tester.view.physicalSize=const Size(1000,850);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PohantoonAiApp(
      authGateway:_SignedInOperator(),
      mfaRepository:_PassedMfa(),
      activationRepository:_OperatorRepository(),
      platformMonitoringRepository:_EmptyPlatformMonitoring(),
      themeController:ThemeController(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Platform overview'),findsOneWidget);
    expect(find.text('Provisioned schools'),findsOneWidget);
    expect(find.text('DEMO DATA'),findsNothing);
    expect(tester.takeException(),isNull);
    await tester.tap(find.byKey(const Key('platform-review-requests')));
    await tester.pumpAndSettle();
    expect(find.text('Provisioning review'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
