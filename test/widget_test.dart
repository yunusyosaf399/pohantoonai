import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pohantoonai/main.dart';

void main() {
  testWidgets('organization console shows mock dashboard', (tester) async {
    await tester.pumpWidget(const PohantoonAiApp());

    expect(find.text('Organization overview'), findsOneWidget);
    expect(find.text('Sample Learning Academy'), findsOneWidget);
    expect(find.text('MOCK'), findsOneWidget);
    expect(find.text('Provisioned schools'), findsOneWidget);
  });

  testWidgets('school request demo validates required fields', (tester) async {
    await tester.pumpWidget(const PohantoonAiApp());
    await tester.tap(find.text('New school request'));
    await tester.pumpAndSettle();

    expect(find.text('New school request · Demo'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    await tester.tap(find.text('Save demo request'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    expect(find.text('New school request · Demo'), findsOneWidget);
  });
}
