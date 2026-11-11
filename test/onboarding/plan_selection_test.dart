import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/ui/app_theme.dart';
import 'package:pohantoonai/features/onboarding/data/onboarding_plan_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_plan_offer.dart';
import 'package:pohantoonai/features/onboarding/presentation/plan_selection_screen.dart';

const plans = [
  OnboardingPlanOffer(
    id: 'starter-id', code: 'starter_demo', name: 'Starter Demo',
    summary: 'Core school management',
    studentLimit: 250, campusLimit: 1, staffLimit: 30,
    trialDays: 14, isDemo: true),
  OnboardingPlanOffer(
    id: 'growth-id', code: 'growth_demo', name: 'Growth Demo',
    summary: 'Multi-campus demo',
    studentLimit: 1500, campusLimit: 5, staffLimit: 150,
    trialDays: 14, isDemo: true),
  OnboardingPlanOffer(
    id: 'enterprise-id', code: 'enterprise_demo', name: 'Enterprise Demo',
    summary: 'Enterprise demo',
    studentLimit: null, campusLimit: null, staffLimit: null,
    trialDays: 30, isDemo: true),
];

class FakePlanRepository implements OnboardingPlanRepository {
  FakePlanRepository({this.saved, this.failLoad = false, this.failSave = false});
  String? saved;
  bool failLoad;
  bool failSave;
  int saveCalls = 0;

  @override
  Future<List<OnboardingPlanOffer>> loadActivePlans() async {
    if (failLoad) throw StateError('network unavailable');
    return plans;
  }

  @override
  Future<String?> loadSelectedPlanId() async => saved;

  @override
  Future<void> saveSelection(String planId) async {
    saveCalls++;
    if (failSave) throw StateError('permission denied');
    saved = planId;
  }
}

Future<void> mountPlan(
  WidgetTester tester, Size size, FakePlanRepository repo, {
  ThemeMode themeMode = ThemeMode.light,
  ValueChanged<OnboardingPlanOffer>? onContinue,
  Future<void> Function()? onBack,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: PohantoonTheme.light,
    darkTheme: PohantoonTheme.dark,
    themeMode: themeMode,
    home: PlanSelectionScreen(
      repository: repo,
      email: 'applicant@example.invalid',
      themeMode: themeMode,
      onThemeChanged: (_) async {},
      onBack: onBack ?? () async {},
      onContinue: onContinue ?? (_) {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('wide desktop shows sidebar and three demo plans',
    (tester) async {
    await mountPlan(tester, const Size(1536, 960), FakePlanRepository());
    expect(find.byKey(const Key('plan-desktop-layout')), findsOneWidget);
    expect(find.text('Starter Demo'), findsOneWidget);
    expect(find.text('Growth Demo'), findsWidgets);
    expect(find.text('Enterprise Demo'), findsOneWidget);
    expect(find.textContaining('No payment during registration'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('plan-onboarding-progress')));
    expect(indicator.value, 2 / 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile offers select and save the selected plan',
    (tester) async {
    final repo = FakePlanRepository();
    OnboardingPlanOffer? chosen;
    await mountPlan(tester, const Size(390, 844), repo,
      onContinue: (plan) => chosen = plan);
    expect(find.byKey(const Key('plan-mobile-layout')), findsOneWidget);
    expect(find.text('Selected Plan: Growth Demo'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('plan-card-starter_demo')));
    await tester.tap(find.byKey(const Key('plan-card-starter_demo')));
    await tester.pumpAndSettle();
    expect(find.text('Selected Plan: Starter Demo'), findsOneWidget);
    await tester.ensureVisible(find.byKey(
      const Key('continue-to-school-setup')));
    await tester.tap(find.byKey(const Key('continue-to-school-setup')));
    await tester.pumpAndSettle();
    expect(repo.saved, 'starter-id');
    expect(repo.saveCalls, 1);
    expect(chosen?.code, 'starter_demo');
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px phone and tablet do not throw layout exceptions',
    (tester) async {
    final repo = FakePlanRepository();
    await mountPlan(tester, const Size(320, 760), repo);
    await tester.ensureVisible(find.byKey(
      const Key('continue-to-school-setup')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode preserves a previously saved plan',
    (tester) async {
    await mountPlan(tester, const Size(1280, 850),
      FakePlanRepository(saved: 'enterprise-id'),
      themeMode: ThemeMode.dark);
    expect(find.text('Selected Plan: Enterprise Demo'), findsOneWidget);
    expect(find.textContaining('Unlimited students'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed plan load shows retry action', (tester) async {
    final repo = FakePlanRepository(failLoad: true);
    await mountPlan(tester, const Size(820, 900), repo);
    expect(find.byKey(const Key('retry-loading-plans')), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.byKey(const Key('retry-loading-plans')));
    await tester.pumpAndSettle();
    expect(find.text('Starter Demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a database write error does not continue to Step 3',
    (tester) async {
    final repo = FakePlanRepository(failSave: true);
    bool advanced = false;
    await mountPlan(tester, const Size(390, 844), repo,
      onContinue: (_) => advanced = true);
    await tester.ensureVisible(find.byKey(
      const Key('continue-to-school-setup')));
    await tester.tap(find.byKey(const Key('continue-to-school-setup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-save-error')), findsOneWidget);
    expect(advanced, false);
    expect(repo.saved, isNull);
    expect(tester.takeException(), isNull);
  });
}
