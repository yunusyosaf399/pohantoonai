import 'package:flutter/material.dart';

import 'features/organization/presentation/organization_control_panel.dart';

void main() => runApp(const PohantoonAiApp());

class PohantoonAiApp extends StatelessWidget {
  const PohantoonAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pohantoon AI — Organization Console (Development)',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176A66)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const OrganizationControlPanel(),
    );
  }
}
