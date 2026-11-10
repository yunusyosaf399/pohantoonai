import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';
import 'package:pohantoonai/features/auth/presentation/account_welcome_screen.dart';

class FakeAuthGateway implements AccountAuthGateway {
  int googleCalls = 0;
  int emailCalls = 0;
  String? lastEmail;

  @override
  bool get signedIn => false;

  @override
  String? get signedInEmail => null;

  @override
  Stream<bool> get sessionChanges => const Stream<bool>.empty();

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
  }

  @override
  Future<void> sendEmailLink(String email) async {
    emailCalls++;
    lastEmail = email;
  }

  @override
  Future<void> signOut() async {}
}

Future<void> mountAt(WidgetTester tester, Size size,
    FakeAuthGateway auth,
    {ThemeMode themeMode = ThemeMode.system,
     Future<void> Function(ThemeMode)? onThemeChanged}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: AccountWelcomeScreen(
      auth: auth,
      themeMode: themeMode,
      onThemeChanged: onThemeChanged ?? (_) async {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile welcome includes sign in methods and progress', (tester) async {
    final auth = FakeAuthGateway();
    await mountAt(tester, const Size(390, 844), auth);
    expect(find.byKey(const Key('onboarding-mobile-layout')), findsOneWidget);
    expect(find.text('Pohantoon AI'), findsOneWidget);
    expect(find.text('Create Your School Account'), findsOneWidget);
    expect(find.byKey(const Key('continue-with-google')), findsOneWidget);
    expect(find.byKey(const Key('continue-with-email')), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('onboarding-progress')));
    expect(progress.value, 1 / 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop welcome uses split adaptive presentation', (tester) async {
    final auth = FakeAuthGateway();
    await mountAt(tester, const Size(1440, 900), auth);
    expect(find.byKey(const Key('onboarding-desktop-layout')), findsOneWidget);
    expect(find.text('Create Your School Account'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-mobile-layout')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('email entry validates then requests OTP magic link', (tester) async {
    final auth = FakeAuthGateway();
    await mountAt(tester, const Size(390, 844), auth);
    await tester.ensureVisible(find.byKey(const Key('continue-with-email')));
    await tester.tap(find.byKey(const Key('continue-with-email')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('send-email-link')));
    await tester.tap(find.byKey(const Key('send-email-link')));
    await tester.pumpAndSettle();
    expect(auth.emailCalls, 0);
    expect(find.text('Enter your email address'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('email-field')), 'school@example.com');
    await tester.ensureVisible(find.byKey(const Key('send-email-link')));
    await tester.tap(find.byKey(const Key('send-email-link')));
    await tester.pumpAndSettle();
    expect(auth.emailCalls, 1);
    expect(auth.lastEmail, 'school@example.com');
    expect(find.byKey(const Key('email-sent-confirmation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google button delegates to auth gateway', (tester) async {
    final auth = FakeAuthGateway();
    await mountAt(tester, const Size(1280, 900), auth);
    await tester.tap(find.byKey(const Key('continue-with-google')));
    await tester.pumpAndSettle();
    expect(auth.googleCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance settings exposes dark light and system', (tester) async {
    final auth = FakeAuthGateway();
    ThemeMode? selected;
    await mountAt(tester, const Size(390, 844), auth,
      onThemeChanged: (mode) async { selected = mode; });
    await tester.tap(find.byKey(const Key('appearance-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('theme-option-system')), findsOneWidget);
    expect(find.byKey(const Key('theme-option-light')), findsOneWidget);
    expect(find.byKey(const Key('theme-option-dark')), findsOneWidget);
    await tester.tap(find.byKey(const Key('theme-option-dark')));
    await tester.pumpAndSettle();
    expect(selected, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
}
