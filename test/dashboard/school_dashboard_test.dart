import 'dart:typed_data';

import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/core/ui/app_theme.dart';
import 'package:pohantoonai/features/dashboard/data/demo_dashboard_preferences_repository.dart';
import 'package:pohantoonai/features/onboarding/data/school_logo_repository.dart';
import 'package:pohantoonai/features/onboarding/domain/onboarding_plan_offer.dart';
import 'package:pohantoonai/features/onboarding/domain/school_setup_draft.dart';
import 'package:pohantoonai/features/onboarding/presentation/school_dashboard_setup_preview.dart';

const plan = OnboardingPlanOffer(
  id: 'growth-demo',
  code: 'growth_demo',name: 'Growth Demo',
  summary:'School development demo',
  studentLimit:1500,campusLimit:5,staffLimit:150,
  trialDays:14,isDemo:true,
);
const draft = SchoolSetupDraft(
  schoolName:'My Test School',
  contactName:'Yunus Demo',
  city:'Kabul',countryCode:'AF',
  estimatedStudents:100,campusCount:1,
  readyForReview:true,
);

class FakeDashboardPreferences implements DemoDashboardPreferencesRepository {
  DemoDashboardPreferences? saved;
  @override
  Future<DemoDashboardPreferences?> load() async => saved;
  @override
  Future<void> save(DemoDashboardPreferences value) async {
    saved=value;
  }
}

class FakeSchoolLogo implements SchoolLogoRepository {
  @override
  Future<SchoolLogoUpload?> chooseAndUpload() async => null;
  @override
  Future<String> signedUrl(String path) async => '';
}

Future<void> mountDashboard(WidgetTester tester,Size size,{
  ThemeMode themeMode=ThemeMode.light,
  FakeDashboardPreferences? repo,
  ValueChanged<String>? onEditDetails,
}) async {
  tester.view.physicalSize=size;
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme:PohantoonTheme.light,
    darkTheme:PohantoonTheme.dark,
    themeMode:themeMode,
    home:SchoolDashboardSetupPreview(
      plan:plan,draft:draft,
      themeMode:themeMode,
      onThemeChanged:(_) async {},
      onBack:(){},
      preferencesRepository:repo??FakeDashboardPreferences(),
      logoRepository:FakeSchoolLogo(),
      onEditDetails:onEditDetails,
    ),
  ));
  await tester.pump();
}

void main() {
  test('logo format detection rejects non-images',() {
    expect(SupabaseSchoolLogoRepository.detectSupportedImage(
      Uint8List.fromList([0,1,2,3,4,5,6,7,8])),isNull);
    expect(SupabaseSchoolLogoRepository.detectSupportedImage(
      Uint8List.fromList([0xFF,0xD8,0xFF,0,0,0])), 'jpg');
    expect(SupabaseSchoolLogoRepository.detectSupportedImage(
      Uint8List.fromList([
        0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A
      ])), 'png');
  });

  testWidgets('desktop light: shows four KPIs and test-only indicator',
      (tester) async {
    await mountDashboard(tester,const Size(1500,1000));
    expect(find.text('Good morning, Yunus 👋'),findsOneWidget);
    expect(find.text('1,248'),findsOneWidget);
    expect(find.text('86'),findsOneWidget);
    expect(find.byKey(const Key('dashboard-demo-label')),findsOneWidget);
    expect(find.byKey(const Key('dashboard-not-provisioned-warning')),
      findsOneWidget);
    expect(find.byKey(const Key('dashboard-global-search')),
      findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('narrow dark layout: mobile nav and search',
      (tester) async {
    await mountDashboard(tester,const Size(390,844),
      themeMode:ThemeMode.dark);
    expect(find.text('Pohantoon AI'),findsWidgets);
    expect(find.text('Home'),findsOneWidget);
    expect(find.byKey(const Key('dashboard-global-search')),
      findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('trends rotate after 10 seconds and open full screen',
      (tester) async {
    await mountDashboard(tester,const Size(1500,1000));
    final before=find.text('Student enrollment');
    expect(before,findsOneWidget);
    await tester.pump(const Duration(seconds:11));
    expect(find.text('Attendance trend'),findsOneWidget);
    await tester.ensureVisible(find.byKey(
      const Key('dashboard-trend-fullscreen')));
    await tester.tap(find.byKey(
      const Key('dashboard-trend-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close-fullscreen-trend')),findsOneWidget);
    expect(find.textContaining('Illustrative chart only'),findsOneWidget);
    await tester.tap(find.byKey(const Key('close-fullscreen-trend')));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });

  testWidgets('analytics hover pauses 10-second automatic rotation',
      (tester) async {
    await mountDashboard(tester,const Size(1500,1000));
    final panel=find.byKey(const Key('dashboard-analytics-panel'));
    await tester.ensureVisible(panel);
    final mouse=await tester.createGesture(
      kind:PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location:tester.getCenter(panel));
    await tester.pump();
    await tester.pump(const Duration(seconds:11));
    expect(find.text('Student enrollment'),findsOneWidget);
    await mouse.moveTo(const Offset(3,3));
    await tester.pump();
    await tester.pump(const Duration(seconds:11));
    expect(find.text('Attendance trend'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('recent approvals and admissions rotate demo pages',
      (tester) async {
    await mountDashboard(tester,const Size(1500,1000));
    await tester.pump(const Duration(seconds:11));
    expect(find.text('Omar Ehsan'),findsOneWidget);
    expect(find.text('Aisha Rahimi'),findsWidgets);
    expect(tester.takeException(),isNull);
  });

  testWidgets('view all approvals shows more than the rotating three',
      (tester) async {
    await mountDashboard(tester,const Size(1500,1000));
    await tester.ensureVisible(
      find.byKey(const Key('dashboard-view-all-approvals')));
    await tester.tap(find.byKey(
      const Key('dashboard-view-all-approvals')));
    await tester.pumpAndSettle();
    expect(find.text('All Recent approvals'),findsOneWidget);
    expect(find.text('Omar Ehsan'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  testWidgets('profile menu leads back to editable school form',
      (tester) async {
    String? section;
    await mountDashboard(tester,const Size(390,844),
      onEditDetails:(value)=>section=value);
    await tester.tap(find.byKey(const Key('dashboard-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit school details'));
    await tester.pumpAndSettle();
    expect(section,'identity');
  });

  testWidgets('analytics and shortcuts selection persist only preferences',
      (tester) async {
    final repo=FakeDashboardPreferences();
    await mountDashboard(tester,const Size(1500,1000),repo:repo);
    await tester.tap(find.byKey(const Key('dashboard-trend-next')));
    await tester.pump();
    expect(repo.saved?.selectedChart,'attendance');
    expect(tester.takeException(),isNull);
  });
}
