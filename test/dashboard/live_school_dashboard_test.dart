import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/admissions/data/school_admissions_repository.dart';
import 'package:pohantoonai/features/dashboard/presentation/live_school_dashboard_screen.dart';

class _LiveAdmissionsFake implements SchoolAdmissionsRepository {
  final schoolIds=<String>[];
  String? lastRead;
  @override
  Future<List<AdmissionsSchool>> availableSchools() async=>const [
    AdmissionsSchool(id:'school-a',name:'School A'),
  ];
  @override
  Future<AdmissionsSummary> summary(String schoolId) async {
    schoolIds.add(schoolId);
    return schoolId=='school-a'
      ? const AdmissionsSummary(
          total:12,pending:4,admitted:7,rejected:1)
      : AdmissionsSummary.empty;
  }
  @override
  Future<List<SchoolAdmission>> load(String schoolId) async {
    lastRead=schoolId;
    return [
      SchoolAdmission(
        id:'admission-1',
        schoolId:schoolId,
        firstName:'Example',lastName:'Learner',
        grade:'Grade 5',guardianName:'Parent One',
        guardianPhone:'+1234567890',status:'pending',
        createdAt:DateTime(2026,11,13)),
    ];
  }
  @override
  Future<void> create(String schoolId,NewSchoolAdmission value) async {}
  @override
  Future<void> decide(String schoolId,String id,String outcome) async {}
}

void main(){
  testWidgets('real dashboard renders database-derived counts, not demo KPIs',
      (tester)async{
    tester.view.physicalSize=const Size(1200,970);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo=_LiveAdmissionsFake();
    await tester.pumpWidget(MaterialApp(home:LiveSchoolDashboardScreen(
      schools:const [AdmissionsSchool(id:'school-a',name:'School A')],
      repository:repo,
      themeMode:ThemeMode.light,
      onThemeChanged:(_)async{},
      onSignOut:(){},
    )));
    await tester.pumpAndSettle();
    expect(find.text('School dashboard'),findsOneWidget);
    expect(find.text('7'),findsOneWidget); // admitted via exact-count view
    expect(find.text('12'),findsOneWidget);
    expect(repo.lastRead,'school-a');
    expect(find.text('DEMO DATA'),findsNothing);
    expect(find.text('Example Learner'),findsOneWidget);
    await tester.tap(find.byKey(const Key('real-dashboard-new-admission')));
    await tester.pumpAndSettle();
    expect(find.text('Student admissions'),findsOneWidget);
    expect(find.text('School A'),findsWidgets);
  });
}
