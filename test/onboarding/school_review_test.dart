import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/ui/app_theme.dart';
import 'package:pohantoonai/features/onboarding/data/review_confirmation_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_plan_offer.dart';
import 'package:pohantoonai/features/onboarding/domain/school_setup_draft.dart';
import 'package:pohantoonai/features/onboarding/presentation/school_review_preview.dart';

const plan = OnboardingPlanOffer(
  id: 'growth-id', code: 'growth_demo', name: 'Growth Demo',
  summary: 'For growing schools and multiple campuses.',
  studentLimit: 1500, campusLimit: 5, staffLimit: 150,
  trialDays: 14, isDemo: true,
);
const draft = SchoolSetupDraft(
  schoolName: 'Example School',
  legalSchoolName: 'Example School Limited',
  schoolType: 'private',
  establishedYear: 2018,
  contactName: 'Applicant',
  contactEmail: 'office@example.invalid',
  countryCode: 'AF',
  city: 'Kabul',
  timezone: 'Asia/Kabul',
  currencyCode: 'AFN',
  estimatedStudents: 1200,
  campusCount: 2,
  estimatedTeachers: 80,
  estimatedNonTeachingStaff: 40,
  teachingLanguages: ['Dari', 'Pashto', 'English'],
  readyForReview: true,
);

class FakeReviewRepo implements ReviewConfirmationRepository {
  FakeReviewRepo({this.fail = false});
  bool fail;
  int confirmations = 0;
  @override
  Future<void> confirm({
    required SchoolSetupDraft draft,
    required OnboardingPlanOffer plan,
  }) async {
    confirmations++;
    if (fail) throw StateError('stale data');
  }
}

Future<void> mountReview(WidgetTester tester, Size size,
    FakeReviewRepo repository, {
    ThemeMode theme = ThemeMode.light,
    VoidCallback? onPayment,
    ValueChanged<String>? onEdit,
  }) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: PohantoonTheme.light,
    darkTheme: PohantoonTheme.dark,
    themeMode: theme,
    home: SchoolReviewPreview(
      draft: draft,
      plan: plan,
      repository: repository,
      themeMode: theme,
      accountEmail: 'applicant@example.invalid',
      onThemeChanged: (_) async {},
      onBack: () {},
      onEditSection: onEdit ?? (_) {},
      onGoToPayment: onPayment ?? () {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile displays real review details and disables payment',
      (tester) async {
    final repo = FakeReviewRepo();
    await mountReview(tester, const Size(390, 844), repo);
    expect(find.byKey(const Key('review-mobile-layout')), findsOneWidget);
    expect(find.text('Review Your School Application'), findsOneWidget);
    expect(find.text('Example School'), findsOneWidget);
    expect(find.text('Growth Demo'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('review-go-to-payment')));
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('review-go-to-payment')));
    expect(button.onPressed, isNull);
    expect(repo.confirmations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirming accuracy is required before going to payment',
      (tester) async {
    final repo = FakeReviewRepo();
    bool nextStep = false;
    await mountReview(tester, const Size(390, 844), repo,
      onPayment: () => nextStep = true);
    await tester.ensureVisible(
      find.byKey(const Key('review-confirmation-checkbox')));
    await tester.tap(
      find.byKey(const Key('review-confirmation-checkbox')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('review-go-to-payment')));
    await tester.tap(find.byKey(const Key('review-go-to-payment')));
    await tester.pumpAndSettle();
    expect(repo.confirmations, 1);
    expect(nextStep, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server rejects stale review and navigation stays on Step 4',
      (tester) async {
    final repo = FakeReviewRepo(fail: true);
    bool nextStep = false;
    await mountReview(tester, const Size(390, 844), repo,
      onPayment: () => nextStep = true);
    await tester.ensureVisible(
      find.byKey(const Key('review-confirmation-checkbox')));
    await tester.tap(
      find.byKey(const Key('review-confirmation-checkbox')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('review-go-to-payment')));
    await tester.tap(find.byKey(const Key('review-go-to-payment')));
    await tester.pumpAndSettle();
    expect(nextStep, false);
    expect(find.byKey(const Key('review-confirmation-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit academic section routes back to the relevant form',
      (tester) async {
    String? section;
    await mountReview(tester, const Size(390, 844), FakeReviewRepo(),
      onEdit: (value) => section = value);
    await tester.ensureVisible(
      find.byKey(const Key('review-edit-academics')));
    await tester.tap(find.byKey(const Key('review-edit-academics')));
    await tester.pumpAndSettle();
    expect(section, 'academics');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop dark theme shows sidebar and plan summary',
      (tester) async {
    await mountReview(tester, const Size(1536, 960), FakeReviewRepo(),
      theme: ThemeMode.dark);
    expect(find.byKey(const Key('review-desktop-layout')), findsOneWidget);
    expect(find.text('School Registration'), findsOneWidget);
    expect(find.byKey(const Key('review-selected-plan')), findsOneWidget);
    expect(find.text('Review Your School Application'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact 320px screen remains scrollable',
      (tester) async {
    await mountReview(tester, const Size(320, 740), FakeReviewRepo());
    await tester.ensureVisible(
      find.byKey(const Key('review-go-to-payment')));
    expect(tester.takeException(), isNull);
  });
}
