import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../../auth/presentation/school_campus_illustration.dart';
import '../data/onboarding_plan_repository.dart';
import '../domain/onboarding_plan_offer.dart';

/// Step 2: authenticated applicants choose an unbilled plan. The backend
/// permits only their own draft selection, never plan editing or payment.
class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({
    super.key,
    required this.repository,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
    required this.onContinue,
    this.email,
  });
  final OnboardingPlanRepository repository;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final Future<void> Function() onBack;
  final ValueChanged<OnboardingPlanOffer> onContinue;
  final String? email;

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  List<OnboardingPlanOffer> _plans = const [];
  String? _chosen;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final plans = await widget.repository.loadActivePlans();
      final saved = await widget.repository.loadSelectedPlanId();
      if (!mounted) return;
      String? selection = plans.any((plan) => plan.id == saved)
          ? saved : null;
      if (selection == null) {
        for (final plan in plans) {
          if (plan.code == 'growth_demo') { selection = plan.id; break; }
        }
      }
      setState(() {
        _plans = plans;
        _chosen = selection ?? plans.firstOrNull?.id;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load available plans. Check your internet '
            'connection and sign-in, then try again.';
      });
    }
  }

  OnboardingPlanOffer? get _selected {
    for (final plan in _plans) {
      if (plan.id == _chosen) return plan;
    }
    return null;
  }

  void _select(OnboardingPlanOffer plan) {
    if (_saving) return;
    setState(() {
      _chosen = plan.id;
      _saveError = null;
    });
  }

  Future<void> _continue() async {
    final plan = _selected;
    if (plan == null || _saving) return;
    setState(() { _saving = true; _saveError = null; });
    try {
      await widget.repository.saveSelection(plan.id);
      if (mounted) widget.onContinue(plan);
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Could not save your selected plan. '
            'Nothing was charged. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF10242C) : Colors.white,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, outer) {
          final desktop = outer.maxWidth >= 960;
          return Row(children: [
            if (desktop)
              SizedBox(
                width: outer.maxWidth >= 1200 ? 312 : 254,
                child: _sidebar(),
              ),
            Expanded(
              child: SingleChildScrollView(
                key: Key(desktop ? 'plan-desktop-layout' : 'plan-mobile-layout'),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 32 : 18, desktop ? 30 : 16,
                    desktop ? 32 : 18, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(desktop),
                          SizedBox(height: desktop ? 24 : 30),
                          Text('STEP 2 OF 6 · CHOOSE YOUR PLAN',
                            key: const Key('plan-progress-label'),
                            textAlign: desktop ? TextAlign.center : TextAlign.left,
                            style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                          const SizedBox(height: 13),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: const LinearProgressIndicator(
                              key: Key('plan-onboarding-progress'),
                              value: 2 / 6, minHeight: 8)),
                          SizedBox(height: desktop ? 38 : 32),
                          Text('Choose the Right Plan for Your School',
                            textAlign: desktop ? TextAlign.center : TextAlign.left,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: desktop ? 34 : 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.75, height: 1.12)),
                          const SizedBox(height: 12),
                          Text(
                            'Start with the plan that fits your school today. '
                            'You can review your selection before '
                            'submitting your application.',
                            textAlign: desktop ? TextAlign.center : TextAlign.left,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 23),
                          _informationBanner(),
                          const SizedBox(height: 24),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(54),
                              child: Center(child: CircularProgressIndicator(
                                key: Key('plans-loading'))))
                          else if (_error != null)
                            _failureCard()
                          else if (_plans.isEmpty)
                            const Card(child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No plans are available at this time.',
                                textAlign: TextAlign.center)))
                          else ...[
                            _grid(),
                            const SizedBox(height: 22),
                            _summary(),
                            SizedBox(height: desktop ? 58 : 30),
                            if (_saveError != null) ...[
                              Text(_saveError!,
                                key: const Key('plan-save-error'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                              const SizedBox(height: 16),
                            ],
                            _footer(desktop),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _brand({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/app_logo/app_icon.jpeg',
          width: compact ? 40 : 52, height: compact ? 40 : 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.school_rounded,
            size: compact ? 40 : 52)),
      ),
      const SizedBox(width: 9),
      Flexible(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pohantoon AI', maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 17 : 20,
              fontWeight: FontWeight.w800)),
          if (!compact)
            Text('Smarter School Management,\nPowered by AI',
              style: TextStyle(fontSize: 10,
                color: colors.onSurfaceVariant, height: 1.3)),
        ],
      )),
    ]);
  }

  Widget _sidebar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF112C32) : const Color(0xFFEAF7F2),
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 36),
        children: [
          _brand(compact: false),
          const SizedBox(height: 56),
          Text('SCREEN 02 / 06',
            style: TextStyle(fontSize: 12, letterSpacing: 1,
              color: colors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 11),
          Text('Choose Your\nSubscription Plan',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.12)),
          const SizedBox(height: 12),
          Text('One school workspace, tailored to the size '
            'of your institution.',
            style: TextStyle(height: 1.48,
              color: colors.onSurfaceVariant)),
          const SizedBox(height: 38),
          const SchoolCampusIllustration(),
          const SizedBox(height: 64),
          for (final step in const [
            ('Google Account', 1),
            ('Choose Your Plan', 2),
            ('School Information', 3),
            ('Application Review', 4),
            ('Subscription Payment', 5),
            ('School Dashboard', 6),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: step.$2 == 1
                      ? colors.primary
                      : step.$2 == 2 ? colors.primaryContainer : colors.surface,
                  child: step.$2 == 1
                      ? Icon(Icons.check, size: 15, color: colors.onPrimary)
                      : Text(step.$2.toString(), style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: step.$2 == 2
                            ? colors.primary : colors.onSurfaceVariant)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step.$1,
                  style: TextStyle(fontSize: 13,
                    fontWeight: step.$2 == 2
                        ? FontWeight.w800 : FontWeight.w500,
                    color: step.$2 == 2
                        ? colors.onSurface : colors.onSurfaceVariant))),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _header(bool desktop) {
    final colors = Theme.of(context).colorScheme;
    return Row(children: [
      if (desktop)
        OutlinedButton.icon(
          key: const Key('plan-back-top'),
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'))
      else ...[
        IconButton(
          key: const Key('plan-back-top'),
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
          tooltip: 'Back to account sign-in'),
        const SizedBox(width: 5),
        Expanded(child: _brand(compact: true)),
      ],
      if (desktop) const Spacer(),
      AppearanceSettingsButton(
        mode: widget.themeMode, onChanged: widget.onThemeChanged),
      const SizedBox(width: 7),
      if (desktop)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(28)),
          child: Row(children: [
            Icon(Icons.verified_user_outlined,
              size: 21, color: colors.primary),
            const SizedBox(width: 7),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('School applicant', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12)),
              Text(widget.email?.isNotEmpty == true
                  ? widget.email! : 'Account connected',
                style: TextStyle(fontSize: 10,
                  color: colors.onSurfaceVariant)),
            ]),
          ]),
        )
      else
        CircleAvatar(radius: 17,
          backgroundColor: colors.primaryContainer,
          child: Icon(Icons.person_outline,
            size: 20, color: colors.primary)),
    ]);
  }

  Widget _informationBanner() {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF17443E) : const Color(0xFFE4F5EF),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.info_rounded, color: colors.primary),
        const SizedBox(width: 12),
        const Expanded(child: Text(
          'No payment during registration. Subscription payment '
          'follows application approval.',
          style: TextStyle(fontSize: 13, height: 1.4))),
      ]),
    );
  }

  Widget _grid() => LayoutBuilder(builder: (context, bounds) {
    final width = bounds.maxWidth;
    final columns = width >= 990 ? 3 : width >= 690 ? 2 : 1;
    const gap = 16.0;
    final cardWidth = (width - (columns - 1) * gap) / columns;
    return Wrap(spacing: gap, runSpacing: 16, children: [
      for (final plan in _plans)
        SizedBox(width: cardWidth,
          child: _planCard(plan, fixedHeight: columns > 1)),
    ]);
  });

  Widget _planCard(OnboardingPlanOffer plan, {required bool fixedHeight}) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = plan.id == _chosen;
    final border = selected ? colors.primary : colors.outlineVariant;
    final background = selected
        ? (dark ? const Color(0xFF153F39) : const Color(0xFFF2FAF6))
        : colors.surface;

    return Semantics(
      button: true,
      selected: selected,
      label: plan.name + ', ' + plan.summaryLimits,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('plan-card-' + plan.code),
          onTap: _saving ? null : () => _select(plan),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: fixedHeight ? 360 : null,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border, width: selected ? 2 : 1)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF1B4742)
                          : const Color(0xFFE6F4EE),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.account_balance_outlined,
                      color: colors.primary, size: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name,
                        style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                      if (plan.isDemo)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('Demo plan',
                            style: TextStyle(color: colors.primary,
                              fontSize: 11, fontWeight: FontWeight.w700))),
                      const SizedBox(height: 7),
                      Text(plan.shortDescription,
                        style: TextStyle(color: colors.onSurfaceVariant,
                          fontSize: 12, height: 1.35)),
                    ],
                  )),
                  const SizedBox(width: 4),
                  Icon(selected ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                    color: selected ? colors.primary : colors.outline),
                ]),
                const SizedBox(height: 21),
                _benefit(Icons.groups_outlined,
                  plan.capacity(plan.studentLimit, 'students')),
                _benefit(Icons.apartment_outlined,
                  plan.capacity(plan.campusLimit, 'campuses')),
                _benefit(Icons.badge_outlined,
                  plan.capacity(plan.staffLimit, 'staff')),
                _benefit(Icons.calendar_month_outlined,
                  plan.trialDays.toString() + '-day demo trial configuration'),
                if (fixedHeight) const Spacer()
                else const SizedBox(height: 16),
                Text(selected ? 'Selected plan ✓' : 'Select plan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.primary,
                    fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12.5, height: 1.35))),
      ]),
    );
  }

  Widget _summary() {
    final plan = _selected;
    if (plan == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const Key('selected-plan-summary'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF17443E) : const Color(0xFFE4F5EF),
        borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        Icon(Icons.layers_outlined, size: 30, color: colors.primary),
        const SizedBox(width: 15),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selected Plan: ' + plan.name,
              style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(plan.summaryLimits,
              style: TextStyle(fontSize: 12.5,
                color: colors.onSurfaceVariant)),
          ],
        )),
      ]),
    );
  }

  Widget _footer(bool desktop) {
    final colors = Theme.of(context).colorScheme;
    final back = OutlinedButton(
      key: const Key('plan-back-bottom'),
      onPressed: widget.onBack,
      child: const Text('Back'));
    final next = FilledButton.icon(
      key: const Key('continue-to-school-setup'),
      iconAlignment: IconAlignment.end,
      onPressed: _saving ? null : _continue,
      icon: _saving
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.arrow_forward),
      label: const Text('Continue to School Setup'));
    if (desktop) {
      return Row(children: [
        Expanded(child: Text('You can review your plan before submitting '
          'your school application.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12))),
        const SizedBox(width: 14),
        back, const SizedBox(width: 10), next,
      ]);
    }
    return LayoutBuilder(builder: (context, size) => Column(children: [
      if (size.maxWidth < 360) ...[
        SizedBox(width: double.infinity, child: next),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: back),
      ] else
        Row(children: [
          Expanded(flex: 2, child: back),
          const SizedBox(width: 10),
          Expanded(flex: 5, child: next),
        ]),
      const SizedBox(height: 16),
      Text('You can review your plan before submitting your application.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    ]));
  }

  Widget _failureCard() => Card(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(children: [
      Icon(Icons.wifi_off_outlined,
        color: Theme.of(context).colorScheme.error),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        key: const Key('retry-loading-plans'),
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Try again')),
    ]),
  ));
}
