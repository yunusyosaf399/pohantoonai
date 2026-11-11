import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../domain/onboarding_plan_offer.dart';
import '../domain/school_setup_draft.dart';

/// Step 6 navigation preview ONLY. A test skip is never an entitlement.
class SchoolDashboardSetupPreview extends StatelessWidget {
  const SchoolDashboardSetupPreview({
    super.key,
    required this.plan,
    required this.draft,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
  });
  final OnboardingPlanOffer plan;
  final SchoolSetupDraft draft;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B2129)
        : const Color(0xFFF4F9FB),
      appBar: AppBar(
        title: const Text('Pohantoon AI · School Dashboard'),
        actions: [
          AppearanceSettingsButton(
            mode: themeMode, onChanged: onThemeChanged),
        ]),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('STEP 6 OF 6 — SCHOOL DASHBOARD',
              style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 12),
            const LinearProgressIndicator(value: 1, minHeight: 8),
            const SizedBox(height: 28),
            Text('School Dashboard — Test Preview',
              key: const Key('dashboard-test-preview-title'),
              style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('You skipped payment to test the onboarding flow. '
              'This is a preview of the next stage, not an activated school.'),
            const SizedBox(height: 24),
            Card(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft.schoolName ?? 'Unnamed school',
                    style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Text('Selected plan: ' + plan.name),
                  const SizedBox(height: 15),
                  Row(children: [
                    Icon(Icons.info_outline, color: colors.primary),
                    const SizedBox(width: 9),
                    const Expanded(child: Text(
                      'Payment status: Not paid · Test flow skipped')),
                  ]),
                ],
              ),
            )),
            const SizedBox(height: 18),
            Container(
              key: const Key('dashboard-not-provisioned-warning'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: colors.primaryContainer.withValues(alpha: .45)),
              child: const Text(
                'No payment was charged, no subscription activated, '
                'no school tenant created, and no school administrator '
                'access granted. The actual dashboard will only unlock '
                'after secure approval, verified billing, and provisioning.',
                style: TextStyle(height: 1.5)),
            ),
            const SizedBox(height: 26),
            OutlinedButton.icon(
              key: const Key('dashboard-back-to-payment'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Subscription Payment')),
          ],
        ),
      ))),
    );
  }
}
