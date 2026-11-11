import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../domain/onboarding_plan_offer.dart';

/// Step 5 handoff. This page intentionally contains no payment collection:
/// provider verification, pricing and backend payment intents are not ready.
class SchoolPaymentPreview extends StatelessWidget {
  const SchoolPaymentPreview({
    super.key,
    required this.plan,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
  });

  final OnboardingPlanOffer plan;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;

  String capacity(int? limit, String unit) => limit == null
      ? 'Unlimited ' + unit : 'Up to ' + limit.toString() + ' ' + unit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B222B)
          : const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text('Pohantoon AI · Payment'),
        actions: [
          AppearanceSettingsButton(
            mode: themeMode, onChanged: onThemeChanged),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Text('STEP 5 OF 6 — SUBSCRIPTION PAYMENT',
              key: Key('payment-progress-label'),
              style: TextStyle(fontSize: 12,
                letterSpacing: 1, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              value: 5 / 6, minHeight: 8),
            const SizedBox(height: 30),
            Text('Subscription Payment',
              key: const Key('payment-preview-title'),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('Your school information review is confirmed. '
              'The payment integration will be available in a '
              'separate module.',
              style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 22),
            Card(child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.layers_outlined, color: colors.primary),
                    const SizedBox(width: 9),
                    const Text('Selected subscription plan',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 14),
                  Text(plan.name, style: Theme.of(context)
                    .textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800)),
                  if (plan.isDemo)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text('Demo plan — development only')),
                  const SizedBox(height: 14),
                  Text(capacity(plan.studentLimit, 'students')),
                  Text(capacity(plan.campusLimit, 'campuses')),
                  Text(capacity(plan.staffLimit, 'staff')),
                  Text(plan.trialDays.toString()
                    + '-day trial configuration'),
                ],
              ),
            )),
            const SizedBox(height: 18),
            Container(
              key: const Key('payment-not-configured-notice'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(13)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline),
                  SizedBox(width: 12),
                  Expanded(child: Text(
                    'Payment processing is not configured yet. '
                    'No payment details are requested, no charge is made, '
                    'and no school or subscription is activated.',
                    style: TextStyle(height: 1.45))),
                ],
              ),
            ),
            const SizedBox(height: 26),
            OutlinedButton.icon(
              key: const Key('payment-back-to-review'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Application Review'),
            ),
          ],
        ),
      ))),
    );
  }
}
