import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/auth/data/account_mfa_repository.dart';
import 'package:pohantoonai/features/auth/presentation/account_mfa_challenge_screen.dart';
import 'package:pohantoonai/features/auth/presentation/account_mfa_settings_card.dart';

class FakeMfa implements AccountMfaRepository {
  bool aal2=false;
  bool enrolled=true;
  bool pending=false;
  bool failNext=false;
  int challenges=0;
  int enrollments=0;
  int cancellations=0;
  int removals=0;
  @override
  Future<AccountMfaStatus> status() async {
    if(failNext){failNext=false;throw StateError('network unavailable');}
    return AccountMfaStatus(
      needsChallenge:enrolled&&!aal2,
      isAal2:aal2,
      factors:enrolled
        ?const [AccountTotpFactor(id:'factor-one',label:'Authenticator app')]
        :const [],
    );
  }
  @override
  Future<AccountTotpEnrollment> enroll()async {
    enrollments++;
    pending=true;
    return const AccountTotpEnrollment(
      factorId:'new-factor',
      secret:'JBSWY3DPEHPK3PXP',
      otpauthUri:'otpauth://totp/Pohantoon%20AI:owner%40school.edu'
        '?secret=JBSWY3DPEHPK3PXP&issuer=Pohantoon%20AI',
    );
  }
  @override
  Future<void> verify(String factorId,String code)async {
    challenges++;
    if(code!='654321')throw StateError('invalid code');
    if(factorId=='new-factor'&&pending){
      pending=false;
      enrolled=true;
    }
    aal2=true;
  }
  @override
  Future<void> cancelEnrollment(String factorId)async {
    if(factorId!='new-factor')throw StateError('wrong factor');
    cancellations++;
    pending=false;
  }
  @override
  Future<void> unenroll(String factorId)async {
    if(!aal2)throw StateError('second factor required');
    if(factorId!='factor-one')throw StateError('unknown');
    enrolled=false;
    removals++;
  }
}

Future<void> mount(WidgetTester tester,Widget widget)async {
  tester.view.physicalSize=const Size(430,900);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:widget));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AAL1 with enrolled factor shows exclusive challenge',
      (tester)async {
    final mfa=FakeMfa();
    int accepted=0,signouts=0;
    await mount(tester,AccountMfaChallengeScreen(
      repository:mfa,
      onVerified:()async{accepted++;},
      onSignOut:()async{signouts++;},
    ));
    expect(find.byKey(const Key('mfa-login-challenge-screen')),
      findsOneWidget);
    expect(find.text('Two-factor verification'),findsOneWidget);
    await tester.enterText(find.byKey(const Key('mfa-login-code')),
      '111111');
    await tester.tap(find.byKey(const Key('mfa-login-verify')));
    await tester.pumpAndSettle();
    expect(accepted,0);
    expect(find.byKey(const Key('mfa-login-error')),findsOneWidget);
    await tester.enterText(find.byKey(const Key('mfa-login-code')),
      '654321');
    await tester.tap(find.byKey(const Key('mfa-login-verify')));
    await tester.pumpAndSettle();
    expect(accepted,1);
    expect(mfa.aal2,isTrue);
    expect(signouts,0);
    expect(tester.takeException(),isNull);
  });

  testWidgets('enrollment shows QR/manual key, confirms OTP and erases secret',
      (tester)async {
    final mfa=FakeMfa()..enrolled=false;
    int changed=0;
    await mount(tester,Scaffold(body:SingleChildScrollView(
      child:AccountMfaSettingsCard(repository:mfa,
        onChanged:()=>changed++))));
    expect(find.text('Status: Not enabled'),findsOneWidget);
    await tester.tap(find.byKey(const Key('mfa-enrollment-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mfa-enrollment-qr')),findsOneWidget);
    expect(find.text('JBSWY3DPEHPK3PXP'),findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('mfa-enrollment-code')));
    await tester.enterText(find.byKey(const Key('mfa-enrollment-code')),
      '654321');
    await tester.ensureVisible(
      find.byKey(const Key('mfa-enable-confirm')));
    await tester.tap(find.byKey(const Key('mfa-enable-confirm')));
    await tester.pumpAndSettle();
    expect(changed,1);
    expect(mfa.aal2,isTrue);
    expect(mfa.enrolled,isTrue);
    expect(find.text('JBSWY3DPEHPK3PXP'),findsNothing);
    expect(find.textContaining('Status: Enabled'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('cancelled pending enrollment is cleaned up',
      (tester)async {
    final mfa=FakeMfa()..enrolled=false;
    await mount(tester,Scaffold(body:SingleChildScrollView(
      child:AccountMfaSettingsCard(repository:mfa))));
    await tester.tap(find.byKey(const Key('mfa-enrollment-start')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('mfa-enrollment-cancel')));
    await tester.tap(find.byKey(const Key('mfa-enrollment-cancel')));
    await tester.pumpAndSettle();
    expect(mfa.cancellations,1);
    expect(mfa.pending,isFalse);
    expect(find.text('JBSWY3DPEHPK3PXP'),findsNothing);
  });

  testWidgets('removing verified factor requires explicit confirmation',
      (tester)async {
    final mfa=FakeMfa()..aal2=true;
    await mount(tester,Scaffold(body:SingleChildScrollView(
      child:AccountMfaSettingsCard(repository:mfa))));
    await tester.ensureVisible(find.byKey(
      const Key('mfa-remove-factor-factor-one')));
    await tester.tap(find.byKey(
      const Key('mfa-remove-factor-factor-one')));
    await tester.pumpAndSettle();
    expect(mfa.removals,0);
    expect(find.text('Remove authenticator?'),findsOneWidget);
    await tester.tap(find.text('Remove factor'));
    await tester.pumpAndSettle();
    expect(mfa.removals,1);
    expect(mfa.enrolled,isFalse);
  });
}
