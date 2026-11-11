import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../domain/onboarding_plan_offer.dart';

/// Navigation destination after the real Step 2 selection was saved.
/// Step 3 data collection is a separate module and is not simulated here.
class SchoolSetupPreview extends StatelessWidget {
  const SchoolSetupPreview({
    super.key,
    required this.selectedPlan,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
  });

  final OnboardingPlanOffer selectedPlan;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pohantoon AI · School Setup'),
        actions: [
          AppearanceSettingsButton(
            mode: themeMode, onChanged: onThemeChanged),
        ]),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('STEP 3 OF 6 · SCHOOL INFORMATION',
                        style: TextStyle(
                          fontSize: 12, letterSpacing: 1,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      const LinearProgressIndicator(value: 3 / 6),
                      const SizedBox(height: 28),
                      Icon(Icons.school_outlined,
                        color: colors.primary, size: 56),
                      const SizedBox(height: 18),
                      Text('Your plan is saved',
                        key: const Key('school-setup-preview-title'),
                        style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center),
                      const SizedBox(height: 15),
                      Text('Selected plan: ' + selectedPlan.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(selectedPlan.summaryLimits,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      const Text(
                        'The school-information form is the next module. '
                        'Your choice has been saved to your account, but '
                        'no school has been created, no subscription activated, '
                        'and no payment taken.',
                        textAlign: TextAlign.center),
                      const SizedBox(height: 26),
                      FilledButton.icon(
                        key: const Key('return-to-plan-selection'),
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to your plans'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
