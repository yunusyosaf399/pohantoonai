import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/settings/theme_controller.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';
import 'package:pohantoonai/features/onboarding/data/onboarding_plan_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_plan_offer.dart';
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

void main() {
  testWidgets('signed-in user sees Step 2; saving advances to Step 3',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plans = TestPlans();

    await tester.pumpWidget(PohantoonAiApp(
      authGateway: TestAccount(),
      planRepository: plans,
      themeController: ThemeController(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Choose the Right Plan for Your School'), findsOneWidget);
    expect(find.text('Organization overview'), findsNothing);

    await tester.ensureVisible(find.byKey(
      const Key('continue-to-school-setup')));
    await tester.tap(find.byKey(const Key('continue-to-school-setup')));
    await tester.pumpAndSettle();

    expect(plans.saved, 'growth-plan');
    expect(find.byKey(const Key('school-setup-preview-title')), findsOneWidget);
    expect(find.textContaining('no school has been created'), findsOneWidget);
    await tester.tap(find.byKey(const Key('return-to-plan-selection')));
    await tester.pumpAndSettle();
    expect(find.text('Selected Plan: Growth Demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
