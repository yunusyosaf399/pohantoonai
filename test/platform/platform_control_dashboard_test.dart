import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/platform/data/platform_monitoring_repository.dart';
import 'package:pohantoonai/features/platform/presentation/platform_control_dashboard_screen.dart';
import 'package:pohantoonai/features/provisioning/data/school_activation_repository.dart';

class _FakePlatformMonitoring implements PlatformMonitoringRepository {
  int overviewCalls=0;
  @override Future<PlatformSummary> overview() async {
    overviewCalls++;
    return const PlatformSummary(
      schools:0,activeSchools:0,suspendedSchools:0,
      pendingRequests:1,provisionedRequests:0,rejectedRequests:0,
      accounts:0,mfaAccounts:0,unverifiedEmailAccounts:0,
      suspendedMemberships:0,bannedAccounts:0,admittedStudents:0,
      requestsLast30Days:1,recentLoginAccounts:0,failedSecurityEmails:0,
    );
  }
  @override
  Future<List<PlatformTrend>> trends() async => const [];
  @override
  Future<List<PlatformSchool>> schools({required int offset,int limit=50})
    async => const [];
  @override
  Future<List<PlatformSchoolAccount>> accounts({
    required int offset,int limit=50,
  }) async => const [];
  @override
  Future<List<PlatformReviewEvent>> history() async => const [];
}

class _FakeActivation implements SchoolActivationRepository {
  String? requestedMoreFor;
  String? reason;
  final requests=<SchoolActivationReview>[
    SchoolActivationReview(
      id:'legacy-1',
      organizationId:'platform-1',
      schoolName:'Legacy Request School',
      applicantEmail:'school@example.invalid',
      planCode:'starter_test',
      isDemo:true,
      status:'submitted',
      activationReady:false,
      submittedAt:DateTime(2026,11,13),
    ),
  ];
  @override Future<String> operatorRole() async=>'authorized';
  @override Future<SchoolActivationStatus?> ownRequest() async=>null;
  @override Future<String> submitRequest() async=>'unused';
  @override Future<List<SchoolActivationReview>> operatorQueue({
    int offset=0,int limit=50,
  }) async=>requests.skip(offset).take(limit).toList();
  @override
  Future<String> approve({
    required String requestId,required String activationBasis,
    required String evidence,required bool identityVerified,
  }) async => throw StateError('Legacy request cannot be approved.');
  @override
  Future<void> reject({required String requestId,required String reason})
    async => throw StateError('Legacy request cannot be rejected.');
  @override
  Future<void> requestInformation({
    required String requestId,required String reason,
  }) async {
    requestedMoreFor=requestId;
    this.reason=reason;
    requests.clear();
  }
}

Future<void> _mount(
  WidgetTester tester,_FakePlatformMonitoring metrics,_FakeActivation activation,
  {double width=1100}
)async{
  tester.view.physicalSize=Size(width,950);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:PlatformControlDashboardScreen(
    monitoring:metrics,activation:activation,onSignOut:(){})));
  await tester.pumpAndSettle();
}

void main(){
  testWidgets('overview uses real repository results; no demo cards',
      (tester)async{
    final monitoring=_FakePlatformMonitoring();
    await _mount(tester,monitoring,_FakeActivation());
    expect(find.text('Platform overview'),findsOneWidget);
    expect(find.text('Waiting for review'),findsOneWidget);
    expect(find.text('Provisioned schools'),findsOneWidget);
    expect(find.text('DEMO DATA'),findsNothing);
    expect(monitoring.overviewCalls,greaterThan(0));
    expect(tester.takeException(),isNull);
  });

  testWidgets('legacy ownerless request can request info, never approve',
      (tester)async{
    final monitoring=_FakePlatformMonitoring();
    final activation=_FakeActivation();
    await _mount(tester,monitoring,activation);
    await tester.tap(find.byKey(const Key('platform-review-requests')));
    await tester.pumpAndSettle();
    expect(find.text('Legacy Request School'),findsOneWidget);
    expect(find.textContaining('Verification required:'),findsOneWidget);
    expect(find.byKey(const Key('approve-school-legacy-1')),findsNothing);
    await tester.tap(find.byKey(
      const Key('request-information-legacy-1')));
    await tester.pumpAndSettle();
    final confirm=find.byKey(const Key('operator-review-confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed,isNull);
    await tester.enterText(find.byKey(const Key('operator-review-evidence')),
      'Please verify the school owner identity and submit a current signed-in review.');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed,isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(activation.requestedMoreFor,'legacy-1');
    expect(activation.reason,contains('verify'));
    expect(tester.takeException(),isNull);
  });

  testWidgets('mobile shows directory empty states without overflow',
      (tester)async{
    final monitoring=_FakePlatformMonitoring();
    await _mount(tester,monitoring,_FakeActivation(),width:420);
    await tester.tap(find.text('Schools').last);
    await tester.pumpAndSettle();
    expect(find.text('No real schools have been provisioned yet.'),
      findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    expect(find.text('No provisioned school account memberships found.'),
      findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
