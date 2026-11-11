import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/settings/theme_controller.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';
import 'package:pohantoonai/features/onboarding/data/onboarding_plan_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_plan_offer.dart';
import 'package:pohantoonai/features/onboarding/domain/school_setup_draft.dart';
import 'package:pohantoonai/features/onboarding/data/school_setup_repository.dart';
import 'package:pohantoonai/features/onboarding/data/review_confirmation_repository.dart';
import 'package:pohantoonai/features/onboarding/data/onboarding_payment_preferences_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_payment_preferences.dart';
import 'package:pohantoonai/main.dart';

class TestAccount implements AccountAuthGateway {
  @override
  bool get signedIn => true;
  @override
  String? get signedInEmail => 'applicant@example.invalid';
  @override
  Stream<bool> get sessionChanges => const Stream<bool>.empty();
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> sendEmailLink(String email) async {}
  @override
  Future<void> signOut() async {}
}

class TestPlans implements OnboardingPlanRepository {
  String? saved;

  @override
  Future<List<OnboardingPlanOffer>> loadActivePlans() async => const [
    OnboardingPlanOffer(
      id: 'starter-plan', code: 'starter_demo', name: 'Starter Demo',
      summary: 'Essential tools for a single-campus school.',
      studentLimit: 250, campusLimit: 1, staffLimit: 30,
      trialDays: 14, isDemo: true),
    OnboardingPlanOffer(
      id: 'growth-plan', code: 'growth_demo', name: 'Growth Demo',
      summary: 'For growing schools and multiple campuses.',
      studentLimit: 1500, campusLimit: 5, staffLimit: 150,
      trialDays: 14, isDemo: true),
  ];

  @override
  Future<String?> loadSelectedPlanId() async => saved;
  @override
  Future<void> saveSelection(String planId) async => saved = planId;
}

class TestSchoolDrafts implements SchoolSetupRepository {
  SchoolSetupDraft? saved;

  @override
  Future<SchoolSetupDraft?> load() async => saved;

  @override
  Future<SchoolSetupDraft> save(SchoolSetupDraft draft) async {
    saved = draft;
    return draft;
  }
}

class TestReviewConfirmation implements ReviewConfirmationRepository {
  int saveCount = 0;
  @override
  Future<void> confirm({
    required SchoolSetupDraft draft,
    required OnboardingPlanOffer plan,
  }) async {
    saveCount++;
    if (!draft.readyForReview) {
      throw StateError('Draft not ready for review');
    }
  }
}

class TestPaymentPreferences implements OnboardingPaymentPreferencesRepository {
  OnboardingPaymentPreferences? settings;
  @override
  Future<OnboardingPaymentPreferences?> load() async => settings;
  @override
  Future<OnboardingPaymentPreferences> save(
      OnboardingPaymentPreferences preferences) async {
    settings = preferences;
    return preferences;
  }
}

void main() {
  testWidgets('signed-in applicant advances from plan to real Step 3 form',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plans = TestPlans();
    final drafts = TestSchoolDrafts();
    final reviews = TestReviewConfirmation();
    final payments = TestPaymentPreferences();

    await tester.pumpWidget(PohantoonAiApp(
      authGateway: TestAccount(),
      planRepository: plans,
      schoolSetupRepository: drafts,
      reviewConfirmationRepository: reviews,
      paymentPreferencesRepository: payments,
      themeController: ThemeController(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Choose the Right Plan for Your School'), findsOneWidget);
    expect(find.text('Organization overview'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('continue-to-school-setup')));
    await tester.tap(find.byKey(const Key('continue-to-school-setup')));
    await tester.pumpAndSettle();

    expect(plans.saved, 'growth-plan');
    expect(find.text('Tell us about your school'), findsOneWidget);
    expect(find.byKey(const Key('school-save-draft')), findsOneWidget);
    expect(find.byKey(const Key('school-account-email')), findsOneWidget);

    // Save an incomplete draft, then continue editing.
    await tester.ensureVisible(find.byKey(const Key('school-save-draft')));
    await tester.tap(find.byKey(const Key('school-save-draft')));
    await tester.pumpAndSettle();
    expect(drafts.saved, isNotNull);
    expect(drafts.saved!.readyForReview, false);

    // Required review fields.
    Future<void> type(String field,String value) async {
      final target = find.byKey(Key('school-field-' + field));
      await tester.ensureVisible(target);
      await tester.enterText(target,value);
      await tester.pumpAndSettle();
    }

    await type('schoolName','Sample Academy');
    await type('contactName','Sample Owner');
    await type('contactEmail','contact@example.invalid');
    await type('city','Sample City');
    await type('students','100');
    await type('campuses','1');

    await tester.ensureVisible(
      find.byKey(const Key('school-select-school-type')));
    await tester.tap(find.byKey(const Key('school-select-school-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private School').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('school-select-country')));
    await tester.tap(find.byKey(const Key('school-select-country')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saudi Arabia').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('school-continue-review')));
    await tester.tap(find.byKey(const Key('school-continue-review')));
    await tester.pumpAndSettle();

    expect(drafts.saved?.readyForReview,true);
    expect(drafts.saved?.schoolName,'Sample Academy');
    expect(find.byKey(const Key('school-review-preview-title')),findsOneWidget);
    expect(find.text('Review Your School Application'),findsOneWidget);

    // Must explicitly confirm the details before entering Step 5.
    await tester.ensureVisible(
      find.byKey(const Key('review-confirmation-checkbox')));
    await tester.tap(find.byKey(const Key('review-confirmation-checkbox')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review-go-to-payment')));
    await tester.tap(find.byKey(const Key('review-go-to-payment')));
    await tester.pumpAndSettle();
    expect(reviews.saveCount, 1);
    expect(find.byKey(const Key('payment-preview-title')),findsOneWidget);
    expect(find.byKey(const Key('payment-not-configured-notice')),
      findsOneWidget);
    // Skip records only unpaid test progress and opens an explicitly
    // non-provisioned Step 6 preview.
    await tester.ensureVisible(find.byKey(const Key('payment-skip-for-now')));
    await tester.tap(find.byKey(const Key('payment-skip-for-now')));
    await tester.pumpAndSettle();
    expect(payments.settings?.skippedForTesting, isTrue);
    expect(find.byKey(const Key('dashboard-test-preview-title')),
      findsOneWidget);
    expect(find.byKey(const Key('dashboard-not-provisioned-warning')),
      findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('dashboard-back-to-payment')));
    await tester.tap(find.byKey(const Key('dashboard-back-to-payment')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment-preview-title')),findsOneWidget);

    await tester.tap(find.byKey(const Key('payment-back-to-review')));
    await tester.pumpAndSettle();
    expect(find.text('Review Your School Application'),findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('review-edit-academics')));
    await tester.tap(find.byKey(const Key('review-edit-academics')));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about your school'),findsOneWidget);
    expect(find.byKey(const Key('school-field-students')),findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
