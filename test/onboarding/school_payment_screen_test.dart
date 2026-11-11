import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/ui/app_theme.dart';
import 'package:pohantoonai/features/onboarding/data/onboarding_payment_preferences_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_payment_preferences.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_plan_offer.dart';
import 'package:pohantoonai/features/onboarding/domain/school_setup_draft.dart';
import 'package:pohantoonai/features/onboarding/presentation/school_payment_preview.dart';

const plan = OnboardingPlanOffer(
  id: 'growth-test',
  code: 'growth_demo', name: 'Growth Demo',
  summary: 'For growing schools and multiple campuses.',
  studentLimit: 1500, campusLimit: 5, staffLimit: 150,
  trialDays: 14, isDemo: true,
);
const draft = SchoolSetupDraft(
  schoolName: 'Test International School',
  contactEmail: 'school@example.invalid',
  streetAddress: 'Sample Street',
  city: 'Kabul', countryCode: 'AF',
  postalCode: '1001',
  estimatedStudents: 200, campusCount: 2,
  readyForReview: true,
);

class FakeBilling implements OnboardingPaymentPreferencesRepository {
  FakeBilling({this.loaded, this.failSave = false, this.failLoad = false});
  OnboardingPaymentPreferences? loaded;
  bool failSave;
  bool failLoad;
  int saveCount = 0;

  @override
  Future<OnboardingPaymentPreferences?> load() async {
    if (failLoad) {
      throw StateError('offline');
    }
    return loaded;
  }

  @override
  Future<OnboardingPaymentPreferences> save(
      OnboardingPaymentPreferences preferences) async {
    saveCount++;
    if (failSave) throw StateError('server rejected');
    loaded = preferences;
    return preferences;
  }
}

Future<void> mount(WidgetTester tester, Size size, FakeBilling repo, {
  ThemeMode themeMode = ThemeMode.light,
  VoidCallback? skip,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: PohantoonTheme.light,
    darkTheme: PohantoonTheme.dark,
    themeMode: themeMode,
    home: SchoolPaymentPreview(
      plan: plan,
      draft: draft,
      repository: repo,
      themeMode: themeMode,
      onThemeChanged: (_) async {},
      onBack: () {},
      onSkip: skip ?? () {},
      accountEmail: 'test@example.invalid',
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('No billing preference model ever serializes card secrets', () {
    const settings = OnboardingPaymentPreferences(
      billingEmail: 'accounts@example.invalid',
      skippedForTesting: true,
    );
    final row = settings.toJson();
    expect(row['test_flow_state'], 'skipped_for_testing');
    for (final banned in [
      'card_number','cvv','card_expiry','payment_status',
      'paid_at','gateway_secret','subscription_activated_at',
    ]) {
      expect(row.containsKey(banned), isFalse);
    }
  });

  testWidgets('light mobile screen shows plan, payment methods and skip',
      (tester) async {
    await mount(tester, const Size(390, 844), FakeBilling());
    expect(find.byKey(const Key('payment-mobile-layout')), findsOneWidget);
    expect(find.text('Complete Your Subscription Payment'), findsOneWidget);
    expect(find.text('Growth Demo'), findsOneWidget);
    expect(find.byKey(const Key('payment-total-unavailable')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('payment-pay-disabled')));
    final pay = tester.widget<FilledButton>(
      find.byKey(const Key('payment-pay-disabled')));
    expect(pay.onPressed, isNull);
    expect(find.byKey(const Key('payment-skip-for-now')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip saves only a test flag then advances',
      (tester) async {
    final repo = FakeBilling();
    int nextCalls = 0;
    await mount(tester, const Size(390, 844), repo,
      skip: () => nextCalls++);
    await tester.ensureVisible(
      find.byKey(const Key('payment-skip-for-now')));
    await tester.tap(find.byKey(const Key('payment-skip-for-now')));
    await tester.pumpAndSettle();
    expect(repo.saveCount, 1);
    expect(repo.loaded?.skippedForTesting, isTrue);
    expect(repo.loaded?.billingSchoolName,
      'Test International School');
    expect(repo.loaded?.billingPostalCode, '1001');
    expect(nextCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save billing details does not skip or activate anything',
      (tester) async {
    final repo = FakeBilling();
    int nextCalls = 0;
    await mount(tester, const Size(900, 1024), repo,
      skip: () => nextCalls++);
    await tester.ensureVisible(
      find.byKey(const Key('payment-billing-cycle-annual')));
    await tester.tap(find.byKey(const Key('payment-billing-cycle-annual')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('payment-method-wallet')));
    await tester.tap(find.byKey(const Key('payment-method-wallet')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('payment-save-preferences')));
    await tester.tap(find.byKey(const Key('payment-save-preferences')));
    await tester.pumpAndSettle();
    expect(repo.loaded?.billingCycle, 'annual');
    expect(repo.loaded?.preferredMethod, 'wallet');
    expect(repo.loaded?.skippedForTesting, isFalse);
    expect(nextCalls, 0);
    expect(find.byKey(const Key('payment-saved')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip works even when optional billing email is invalid',
      (tester) async {
    final repo = FakeBilling();
    int nextCalls = 0;
    await mount(tester, const Size(390, 844), repo,
      skip: () => nextCalls++);
    await tester.ensureVisible(
      find.byKey(const Key('payment-billing-billingEmail')));
    await tester.enterText(
      find.byKey(const Key('payment-billing-billingEmail')),
      'invalid email');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('payment-skip-for-now')));
    await tester.tap(find.byKey(const Key('payment-skip-for-now')));
    await tester.pumpAndSettle();
    expect(nextCalls, 1);
    expect(repo.loaded?.skippedForTesting, isTrue);
    expect(repo.loaded?.billingEmail, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed database write blocks test skip',
      (tester) async {
    final repo = FakeBilling(failSave: true);
    int nextCalls = 0;
    await mount(tester, const Size(390, 844), repo,
      skip: () => nextCalls++);
    await tester.ensureVisible(
      find.byKey(const Key('payment-skip-for-now')));
    await tester.tap(find.byKey(const Key('payment-skip-for-now')));
    await tester.pumpAndSettle();
    expect(nextCalls, 0);
    expect(repo.loaded, isNull);
    expect(find.byKey(const Key('payment-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft loading failure blocks overwrite and shows retry',
      (tester) async {
    await mount(tester, const Size(390, 844),
      FakeBilling(failLoad: true));
    expect(find.byKey(const Key('payment-retry-load')), findsOneWidget);
    expect(find.byKey(const Key('payment-skip-for-now')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop dark and narrow phone layouts avoid exceptions',
      (tester) async {
    await mount(tester, const Size(1512, 1000), FakeBilling(),
      themeMode: ThemeMode.dark);
    expect(find.byKey(const Key('payment-desktop-layout')), findsOneWidget);
    expect(find.text('School Registration'), findsOneWidget);
    expect(find.byKey(const Key('payment-selected-plan')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
