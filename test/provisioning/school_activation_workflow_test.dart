import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/provisioning/data/school_activation_repository.dart';
import 'package:pohantoonai/features/provisioning/presentation/school_activation_request_card.dart';
import 'package:pohantoonai/features/provisioning/presentation/school_provisioning_operator_screen.dart';

class FakeActivation implements SchoolActivationRepository {
  String role='authorized';
  SchoolActivationStatus? own;
  bool submitted=false;
  String? approvedId,basis,rejectedId;
  bool? identityChecked;
  String? evidence;
  List<SchoolActivationReview> reviews=[
    SchoolActivationReview(
      id:'request-1',organizationId:'org-1',schoolName:'Pilot School',
      applicantEmail:'school@example.invalid',planCode:'starter_demo',
      isDemo:true,status:'submitted',submittedAt:DateTime(2026,11,13)),
  ];

  @override
  Future<String> operatorRole() async=>role;
  @override
  Future<SchoolActivationStatus?> ownRequest() async=>own;
  @override
  Future<String> submitRequest() async {
    submitted=true;
    own=SchoolActivationStatus(
      requestId:'request-1',schoolName:'Pilot School',status:'submitted',
      submittedAt:DateTime(2026,11,13));
    return own!.requestId;
  }
  @override
  Future<List<SchoolActivationReview>> operatorQueue({
    int offset=0,int limit=50,
  }) async=>reviews;
  @override
  Future<String> approve({
    required String requestId,
    required String activationBasis,
    required String evidence,
    required bool identityVerified,
  }) async {
    approvedId=requestId;
    basis=activationBasis;
    this.evidence=evidence;
    identityChecked=identityVerified;
    reviews=[];
    return 'school-id-created-by-backend';
  }
  @override
  Future<void> requestInformation({
    required String requestId,required String reason,
  }) async {}

  @override
  Future<void> reject({required String requestId,required String reason})
    async {
    rejectedId=requestId;
    evidence=reason;
    reviews=[];
  }
}

void main(){
  testWidgets('applicant request needs an explicit confirmation',
    (tester)async{
    final fake=FakeActivation();
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:SchoolActivationRequestCard(
        repository:fake)))));
    await tester.pumpAndSettle();
    expect(fake.submitted,false);
    await tester.tap(find.byKey(const Key('school-activation-submit')));
    await tester.pumpAndSettle();
    expect(fake.submitted,false);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(fake.submitted,true);
    expect(find.text('SUBMITTED'),findsOneWidget);
    expect(find.byKey(const Key('school-activation-submit')),findsNothing);
  });

  testWidgets('platform reviewer must attest identity and record evidence',
    (tester)async{
    final fake=FakeActivation();
    tester.view.physicalSize=const Size(1060,900);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:
      SchoolProvisioningOperatorScreen(
        repository:fake,onSignOut:(){})));
    await tester.pumpAndSettle();
    expect(find.text('Pilot School'),findsOneWidget);
    await tester.tap(find.byKey(const Key('approve-school-request-1')));
    await tester.pumpAndSettle();
    final confirm=find.byKey(const Key('operator-review-confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed,isNull);
    await tester.enterText(find.byKey(const Key('operator-review-evidence')),
      'An independent reviewer verified school legal identity and owner.');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed,isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed,isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(fake.approvedId,'request-1');
    expect(fake.basis,'approved_pilot');
    expect(fake.identityChecked,true);
  });
}
