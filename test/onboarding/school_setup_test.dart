import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/ui/app_theme.dart';
import 'package:pohantoonai/features/onboarding/data/school_setup_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_plan_offer.dart';
import 'package:pohantoonai/features/onboarding/domain/school_setup_draft.dart';
import 'package:pohantoonai/features/onboarding/presentation/school_setup_screen.dart';

const testPlan = OnboardingPlanOffer(
  id:'growth-id',code:'growth_demo',name:'Growth Demo',
  summary:'For growing schools and multiple campuses.',
  studentLimit:1500,campusLimit:5,staffLimit:150,
  trialDays:14,isDemo:true);

class FakeDrafts implements SchoolSetupRepository {
  FakeDrafts({this.initial,this.failFirstLoad=false,this.failSave=false});
  SchoolSetupDraft? initial;
  bool failFirstLoad;
  bool failSave;
  int saves=0;

  @override
  Future<SchoolSetupDraft?> load() async {
    if(failFirstLoad) {
      failFirstLoad=false;
      throw StateError('offline');
    }
    return initial;
  }

  @override
  Future<SchoolSetupDraft> save(SchoolSetupDraft draft) async {
    saves++;
    if(failSave) throw StateError('write refused');
    initial=draft;
    return draft;
  }
}

Future<void> pumpForm(
  WidgetTester tester,Size size,FakeDrafts repository,{
  ThemeMode mode=ThemeMode.light,
  ValueChanged<SchoolSetupDraft>? onReview,
}) async {
  tester.view.physicalSize=size;
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme:PohantoonTheme.light,
    darkTheme:PohantoonTheme.dark,
    themeMode:mode,
    home:SchoolSetupScreen(
      plan:testPlan,
      repository:repository,
      accountEmail:'applicant@example.invalid',
      themeMode:mode,
      onThemeChanged:(_) async {},
      onBack:(){},
      onContinue:onReview??(_){},
    )));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop displays two-column identity and contact sections',
      (tester) async {
    await pumpForm(tester,const Size(1550,1000),FakeDrafts());
    expect(find.byKey(const Key('school-setup-desktop-layout')),findsOneWidget);
    expect(find.text('School Identity'),findsOneWidget);
    expect(find.text('Primary Contact'),findsOneWidget);
    expect(find.text('Location & Preferences'),findsOneWidget);
    expect(find.text('Academics & Capacity'),findsOneWidget);
    expect(find.text('Selected plan: Growth Demo'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('mobile saves an incomplete draft and does not advance',
      (tester) async {
    final repo=FakeDrafts();
    bool reviewed=false;
    await pumpForm(tester,const Size(390,844),repo,
      onReview:(_)=>reviewed=true);
    expect(find.byKey(const Key('school-setup-mobile-layout')),findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('school-save-draft')));
    await tester.tap(find.byKey(const Key('school-save-draft')));
    await tester.pumpAndSettle();
    expect(repo.saves,1);
    expect(repo.initial?.readyForReview,false);
    expect(reviewed,false);
    expect(tester.takeException(),isNull);
  });

  testWidgets('required fields prevent continuing to review',
      (tester) async {
    final repo=FakeDrafts();
    bool reviewed=false;
    await pumpForm(tester,const Size(390,844),repo,
      onReview:(_)=>reviewed=true);
    await tester.ensureVisible(find.byKey(const Key('school-continue-review')));
    await tester.tap(find.byKey(const Key('school-continue-review')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('school-setup-error')),findsOneWidget);
    expect(repo.saves,0);
    expect(reviewed,false);
    expect(tester.takeException(),isNull);
  });

  testWidgets('draft reload prepopulates school name and contact',
      (tester) async {
    final repo=FakeDrafts(initial:const SchoolSetupDraft(
      schoolName:'Previously Saved School',
      contactName:'Saved Contact',
      contactEmail:'saved@example.invalid',
      countryCode:'SA',city:'Riyadh',
      estimatedStudents:30,campusCount:1,
      schoolType:'private',
    ));
    await pumpForm(tester,const Size(850,950),repo);
    expect(find.text('Previously Saved School'),findsOneWidget);
    expect(find.text('Saved Contact'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('failed load offers retry, not blank overwritten draft',
      (tester) async {
    final repo=FakeDrafts(failFirstLoad:true);
    await pumpForm(tester,const Size(390,850),repo);
    expect(find.text('Retry loading draft'),findsOneWidget);
    await tester.tap(find.text('Retry loading draft'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about your school'),findsOneWidget);
    expect(find.byKey(const Key('school-save-draft')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('dark appearance and tablet layout do not overflow',
      (tester) async {
    await pumpForm(tester,const Size(850,1050),FakeDrafts(),
      mode:ThemeMode.dark);
    expect(find.byKey(const Key('school-setup-mobile-layout')),findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('school-continue-review')));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });

  testWidgets('save failure does not falsely claim draft persisted',
      (tester) async {
    final repo=FakeDrafts(failSave:true);
    await pumpForm(tester,const Size(390,850),repo);
    await tester.ensureVisible(find.byKey(const Key('school-save-draft')));
    await tester.tap(find.byKey(const Key('school-save-draft')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('school-setup-error')),findsOneWidget);
    expect(repo.initial,isNull);
    expect(tester.takeException(),isNull);
  });
}
