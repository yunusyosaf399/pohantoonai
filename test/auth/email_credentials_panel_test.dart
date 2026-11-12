import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/auth/data/account_auth_gateway.dart';
import 'package:pohantoonai/features/auth/presentation/email_credentials_panel.dart';

class FakeEmailCredentials implements AccountEmailCredentials {
  String? email, password, lastCode;
  int signups=0,signins=0,verifications=0,resends=0;
  @override
  Stream<void> get passwordRecoveryEvents => const Stream<void>.empty();
  @override
  Future<void> signUpWithPassword(String email,String password) async {
    this.email=email;this.password=password;signups++;
  }
  @override
  Future<void> verifyEmailCode(String email,String code,
      {required bool isSignup}) async {
    this.email=email;lastCode=code;verifications++;
  }
  @override
  Future<void> signInWithPassword(String email,String password) async {
    this.email=email;this.password=password;signins++;
  }
  @override
  Future<void> resendSignupCode(String email)async{resends++;}
  @override
  Future<void> setAccountPassword(String password)async{}
  @override
  Future<void> sendPasswordReset(String email)async{
    this.email=email;
  }
  @override
  Future<void> verifyRecoveryOtp(String email,String code)async{
    this.email=email;
    lastCode=code;
  }
}

Future<void> mount(WidgetTester tester,FakeEmailCredentials gateway)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(
    body:SingleChildScrollView(child:EmailCredentialsPanel(auth:gateway)))));
  await tester.pumpAndSettle();
}

void main(){
  testWidgets('email registration uses Auth, requires password and email code',
      (tester)async{
    final auth=FakeEmailCredentials();
    await mount(tester,auth);
    await tester.enterText(find.byKey(const Key('email-field')),'owner@school.edu');
    await tester.enterText(
      find.byKey(const Key('email-password-field')),'Secure-long-password-2026');
    await tester.enterText(
      find.byKey(const Key('email-confirm-password')),'Secure-long-password-2026');
    await tester.tap(find.byKey(const Key('email-register-password')));
    await tester.pumpAndSettle();
    expect(auth.signups,1);
    expect(auth.email,'owner@school.edu');
    expect(find.byKey(const Key('email-verification-code')),findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('email-verification-code')),'123456');
    await tester.tap(find.byKey(const Key('verify-email-code')));
    await tester.pumpAndSettle();
    expect(auth.verifications,1);
    expect(auth.lastCode,'123456');
    expect(tester.takeException(),isNull);
  });

  testWidgets('email registration rejects weak or unmatched passwords',
      (tester)async{
    final auth=FakeEmailCredentials();
    await mount(tester,auth);
    await tester.enterText(find.byKey(const Key('email-field')),'test@school.edu');
    await tester.enterText(find.byKey(
      const Key('email-password-field')),'short');
    await tester.enterText(find.byKey(
      const Key('email-confirm-password')),'different');
    await tester.tap(find.byKey(const Key('email-register-password')));
    await tester.pumpAndSettle();
    expect(auth.signups,0);
    expect(find.text('Use at least 12 characters'),findsOneWidget);
  });

  testWidgets('existing account can use email password sign in',
      (tester)async{
    final auth=FakeEmailCredentials();
    await mount(tester,auth);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email-field')),'staff@school.edu');
    await tester.enterText(find.byKey(
      const Key('email-password-field')),'existing-password');
    await tester.tap(find.byKey(const Key('email-login-password')));
    await tester.pumpAndSettle();
    expect(auth.signins,1);
    expect(auth.email,'staff@school.edu');
    expect(tester.takeException(),isNull);
  });
}
