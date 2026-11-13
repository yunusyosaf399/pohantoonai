import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/features/admissions/data/school_admissions_repository.dart';
import 'package:pohantoonai/features/admissions/presentation/school_admissions_screen.dart';

class FakeAdmissionsRepository implements SchoolAdmissionsRepository {
  List<AdmissionsSchool> allowed=const [];
  final data=<String,List<SchoolAdmission>>{};
  String? lastSchoolRead;
  String? lastSchoolWritten;
  NewSchoolAdmission? lastCreated;
  int decisions=0;

  @override
  Future<List<AdmissionsSchool>> availableSchools() async=>allowed;

  @override
  Future<List<SchoolAdmission>> load(String schoolId) async {
    lastSchoolRead=schoolId;
    return data[schoolId]??const [];
  }

  @override
  Future<void> create(String schoolId,NewSchoolAdmission admission) async {
    lastSchoolWritten=schoolId;
    lastCreated=admission;
  }

  @override
  Future<void> decide(String schoolId,String admissionId,String outcome) async {
    lastSchoolWritten=schoolId;
    decisions++;
    data[schoolId]=[
      for(final row in data[schoolId]??const <SchoolAdmission>[])
        if(row.id==admissionId)SchoolAdmission(
          id:row.id,schoolId:row.schoolId,firstName:row.firstName,
          lastName:row.lastName,grade:row.grade,
          guardianName:row.guardianName,guardianPhone:row.guardianPhone,
          status:outcome,createdAt:row.createdAt,
        )else row,
    ];
  }
}

const schoolOne=AdmissionsSchool(id:'school-one',name:'School One');
const schoolTwo=AdmissionsSchool(id:'school-two',name:'School Two');

SchoolAdmission applicant({
  required String schoolId,
  String status='pending',
})=>SchoolAdmission(
  id:'app-1',schoolId:schoolId,
  firstName:'Student',lastName:'One',
  grade:'Grade 3',guardianName:'Parent One',
  guardianPhone:'+1234567890',
  status:status,createdAt:DateTime(2026,11,13),
);

Future<void> mount(WidgetTester tester,FakeAdmissionsRepository repository,
    {bool studentsOnly=false}) async {
  tester.view.physicalSize=const Size(950,900);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home:SchoolAdmissionsScreen(
      repository:repository,studentsOnly:studentsOnly)));
  await tester.pumpAndSettle();
}

void main(){
  testWidgets('preview and unauthorised accounts cannot see entry action',
      (tester)async{
    final repo=FakeAdmissionsRepository();
    await mount(tester,repo);
    expect(find.byKey(const Key('admissions-access-required')),findsOneWidget);
    expect(find.byKey(const Key('admissions-new')),findsNothing);
    expect(repo.lastSchoolRead,isNull);
  });

  testWidgets('loads selected school only and supports admission decisions',
      (tester)async{
    final repo=FakeAdmissionsRepository()
      ..allowed=[schoolOne,schoolTwo]
      ..data['school-one']=[applicant(schoolId:'school-one')]
      ..data['school-two']=[applicant(schoolId:'school-two',status:'rejected')];
    await mount(tester,repo);
    expect(repo.lastSchoolRead,'school-one');
    expect(find.text('Student One'),findsOneWidget);
    await tester.tap(find.text('Admit'));
    await tester.pumpAndSettle();
    expect(find.text('Admit student?'),findsOneWidget);
    await tester.tap(find.text('Admit student'));
    await tester.pumpAndSettle();
    expect(repo.lastSchoolWritten,'school-one');
    expect(repo.decisions,1);
    expect(find.text('ADMITTED'),findsOneWidget);
    expect(find.text('Admit'),findsNothing);
  });

  testWidgets('students roster shows only admitted records', (tester)async {
    final repo=FakeAdmissionsRepository()
      ..allowed=[schoolOne]
      ..data['school-one']=[
        applicant(schoolId:'school-one'),
        applicant(schoolId:'school-one',status:'admitted'),
      ];
    await mount(tester,repo,studentsOnly:true);
    expect(find.text('No admitted students yet.'),findsNothing);
    expect(find.byKey(const Key('admissions-new')),findsNothing);
    expect(find.text('ADMITTED'),findsOneWidget);
    expect(find.text('PENDING'),findsNothing);
  });

  testWidgets('new admission saves with verified school scope', (tester)async {
    final repo=FakeAdmissionsRepository()..allowed=[schoolOne];
    await mount(tester,repo);
    await tester.tap(find.byKey(const Key('admissions-new')));
    await tester.pumpAndSettle();
    Future<void> type(String label,String value) async {
      final field=find.widgetWithText(TextFormField,label);
      await tester.ensureVisible(field);
      await tester.enterText(field,value);
    }
    await type('Student first name','Amina');
    await type('Student last name','Noor');
    await type('Grade applied for','Grade 5');
    await type('Guardian full name','Parent Noor');
    await type('Guardian phone','+1234567890');
    await tester.ensureVisible(find.byKey(const Key('admissions-save')));
    await tester.tap(find.byKey(const Key('admissions-save')));
    await tester.pumpAndSettle();
    expect(repo.lastSchoolWritten,'school-one');
    expect(repo.lastCreated?.firstName,'Amina');
    expect(repo.lastCreated?.grade,'Grade 5');
  });
}
