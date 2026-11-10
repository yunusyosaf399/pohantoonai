import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/organization/data/organization_repository.dart';
import 'package:pohantoonai/features/organization/domain/organization_models.dart';
import 'package:pohantoonai/main.dart';

class ScenarioRepository implements OrganizationRepository {
  ScenarioRepository({
    required this.snapshot,
    this.failFirstLoad = false,
    this.failFirstSubmit = false,
  });

  final OrganizationSnapshot snapshot;
  final bool failFirstLoad;
  final bool failFirstSubmit;
  int loadCalls = 0;
  int submitCalls = 0;

  @override
  Future<OrganizationSnapshot> load() async {
    loadCalls++;
    if (failFirstLoad && loadCalls == 1) {
      throw const OrganizationFailure(
        OrganizationFailureCode.unavailable,
        'The demo service is temporarily unavailable.',
      );
    }
    return snapshot;
  }

  @override
  Future<SchoolOnboardingRequest> submit(SchoolOnboardingDraft draft) async {
    submitCalls++;
    if (failFirstSubmit && submitCalls == 1) {
      throw const OrganizationFailure(
        OrganizationFailureCode.unavailable,
        'The request could not be saved. Try again.',
      );
    }
    return SchoolOnboardingRequest(
      id: 'NEW001',
      schoolName: draft.schoolName,
      ownerName: draft.ownerName,
      contactEmail: draft.contactEmail,
      countryCode: draft.countryCode,
      city: draft.city,
      planCode: draft.planCode,
      studentEstimate: draft.studentEstimate,
      campusEstimate: draft.campusEstimate,
      status: OnboardingStatus.submitted,
      createdAt: DateTime(2026, 11, 10),
    );
  }
}

const demoPlan = SubscriptionPlan(
  code: 'starter_demo',
  name: 'Starter Demo',
  summary: 'A demo plan for schools.',
  studentLimit: 250,
  campusLimit: 1,
  trialDays: 14,
);

final sampleRequest = SchoolOnboardingRequest(
  id: 'SAMPLE01',
  schoolName: 'Sample Learning Academy',
  ownerName: 'Sample School Owner',
  contactEmail: 'school@example.invalid',
  countryCode: 'SA',
  city: 'Sample City',
  planCode: 'starter_demo',
  studentEstimate: 180,
  campusEstimate: 1,
  status: OnboardingStatus.submitted,
  createdAt: DateTime(2026, 11, 10),
);

Future<void> pumpAppAt(
  WidgetTester tester,
  Size size, {
  OrganizationRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(PohantoonAiApp(repository: repository));
  await tester.pumpAndSettle();
}

Future<void> openNewSchool(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('new-school-request')));
  await tester.pumpAndSettle();
  expect(find.text('Tell us about your school'), findsOneWidget);
}

Future<void> enterRequiredSchoolDetails(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('school-name-field')), 'Pilot School',
  );
  await tester.enterText(
    find.byKey(const Key('contact-name-field')), 'Pilot Owner',
  );
  await tester.enterText(
    find.byKey(const Key('contact-email-field')), 'owner@example.invalid',
  );
  await tester.enterText(find.byKey(const Key('city-field')), 'Dammam');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone uses bottom navigation, brand asset and overview',
      (tester) async {
    await pumpAppAt(tester, const Size(390, 844));
    expect(find.byKey(const Key('mobile-navigation')), findsOneWidget);
    expect(find.byKey(const Key('desktop-navigation')), findsNothing);
    expect(find.text('Organization overview'), findsOneWidget);
    expect(find.text('Sample Learning Academy'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/app_logo/app_icon.jpeg',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet selects compact navigation rail without overflow',
      (tester) async {
    await pumpAppAt(tester, const Size(820, 1024));
    expect(find.byKey(const Key('desktop-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mobile-navigation')), findsNothing);
    expect(find.text('Organization overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop shows responsive plans and safe billing warning',
      (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    expect(find.byKey(const Key('desktop-navigation')), findsOneWidget);
    await tester.tap(find.text('Subscription plans').first);
    await tester.pumpAndSettle();
    expect(find.text('Starter Demo'), findsOneWidget);
    expect(find.text('Growth Demo'), findsOneWidget);
    expect(find.text('Enterprise Demo'), findsOneWidget);
    expect(find.text('No billing in this preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed data loading provides a retry path',
      (tester) async {
    final repository = ScenarioRepository(
      snapshot: OrganizationSnapshot(
        plans: const [demoPlan],
        requests: [sampleRequest],
      ),
      failFirstLoad: true,
    );
    await pumpAppAt(tester, const Size(390, 844), repository: repository);
    expect(find.text('Unable to load your workspace'), findsOneWidget);
    expect(find.text('Retry loading'), findsOneWidget);
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();
    expect(find.text('Organization overview'), findsOneWidget);
    expect(repository.loadCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty request list shows an actionable empty state',
      (tester) async {
    final repository = ScenarioRepository(
      snapshot: const OrganizationSnapshot(
        plans: [demoPlan],
        requests: [],
      ),
    );
    await pumpAppAt(tester, const Size(390, 844), repository: repository);
    expect(find.text('No school applications yet'), findsOneWidget);
    expect(find.byKey(const Key('new-school-request')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search shows no matches and supports clearing filters',
      (tester) async {
    await pumpAppAt(tester, const Size(390, 844));
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('school-request-search')), 'not-an-existing-school',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching requests'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Sample Learning Academy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding form displays actionable field validation',
      (tester) async {
    await pumpAppAt(tester, const Size(390, 844));
    await openNewSchool(tester);
    await tester.ensureVisible(find.byKey(const Key('submit-school-request')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-school-request')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-validation-summary')), findsOneWidget);
    expect(find.text('Please correct the highlighted fields'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding warns about plan capacity',
      (tester) async {
    await pumpAppAt(tester, const Size(390, 844));
    await openNewSchool(tester);
    await tester.enterText(
      find.byKey(const Key('student-estimate-field')), '900',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-capacity-warning')), findsOneWidget);
    expect(find.text('Plan capacity exceeded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save error retains inputs for correction and retry',
      (tester) async {
    final repository = ScenarioRepository(
      snapshot: OrganizationSnapshot(
        plans: const [demoPlan],
        requests: [sampleRequest],
      ),
      failFirstSubmit: true,
    );
    await pumpAppAt(
      tester, const Size(900, 1000), repository: repository,
    );
    await openNewSchool(tester);
    await enterRequiredSchoolDetails(tester);
    await tester.ensureVisible(find.byKey(const Key('submit-school-request')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-school-request')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-submit-error')), findsOneWidget);
    expect(repository.submitCalls, 1);
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('school-name-field')),
    );
    expect(field.controller?.text, 'Pilot School');
    await tester.tap(find.byKey(const Key('submit-school-request')));
    await tester.pumpAndSettle();
    expect(repository.submitCalls, 2);
    expect(find.text('School onboarding requests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
