import 'package:flutter/material.dart';

import 'core/ui/app_theme.dart';
import 'features/organization/data/organization_repository.dart';
import 'features/organization/presentation/organization_control_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PohantoonAiApp());
}

/// One Flutter app for Windows, Linux, macOS, iOS, Android and Web.
/// Platform-specific services can be injected without duplicating the UI.
class PohantoonAiApp extends StatelessWidget {
  const PohantoonAiApp({super.key, this.repository});

  final OrganizationRepository? repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pohantoon AI — Organization Console',
        theme: PohantoonTheme.light,
        home: OrganizationControlPanel(repository: repository),
      );
}
