import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../../auth/presentation/school_campus_illustration.dart';
import '../data/onboarding_payment_preferences_repository.dart';
import '../domain/onboarding_payment_preferences.dart';
import '../domain/onboarding_plan_offer.dart';
import '../domain/school_setup_draft.dart';

/// Step 5 of 6: visually complete, but deliberately unpaid.
/// No card/PAN/CVV entry, checkout, pricing, subscription entitlement,
/// school provisioning or gateway token is implemented in this screen.
class SchoolPaymentPreview extends StatefulWidget {
  const SchoolPaymentPreview({
    super.key,
    required this.plan,
    required this.draft,
    required this.repository,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
    required this.onSkip,
    this.accountEmail,
  });

  final OnboardingPlanOffer plan;
  final SchoolSetupDraft draft;
  final OnboardingPaymentPreferencesRepository repository;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final String? accountEmail;

  @override
  State<SchoolPaymentPreview> createState() => _SchoolPaymentPreviewState();
}

class _SchoolPaymentPreviewState extends State<SchoolPaymentPreview> {
  late final Map<String, TextEditingController> fields;
  final ScrollController scroll = ScrollController();
  String cycle = 'monthly';
  String method = 'card';
  bool loading = true;
  bool saving = false;
  bool loaded = false;
  String? error;
  String? info;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    fields = {
      'billingEmail': TextEditingController(
        text: draft.contactEmail ?? widget.accountEmail ?? ''),
      'schoolName': TextEditingController(text: draft.schoolName ?? ''),
      'address': TextEditingController(text: draft.streetAddress ?? ''),
      'city': TextEditingController(text: draft.city ?? ''),
      'country': TextEditingController(text: draft.countryCode ?? ''),
      'postal': TextEditingController(text: draft.postalCode ?? ''),
      'tax': TextEditingController(),
    };
    _load();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { loading = true; loaded = false; error = null; });
    try {
      final previous = await widget.repository.load();
      if (!mounted) return;
      if (previous != null) {
        cycle = previous.billingCycle;
        method = previous.preferredMethod;
        fields['billingEmail']!.text = previous.billingEmail ?? '';
        fields['schoolName']!.text = previous.billingSchoolName ?? '';
        fields['address']!.text = previous.billingAddress ?? '';
        fields['city']!.text = previous.billingCity ?? '';
        fields['country']!.text = previous.billingCountryCode ?? '';
        fields['postal']!.text = previous.billingPostalCode ?? '';
        fields['tax']!.text = previous.taxIdentifier ?? '';
      }
      setState(() { loading = false; loaded = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Your saved billing details could not be loaded. '
          'Retry before continuing, so existing details are not overwritten.';
      });
    }
  }

  String? _value(String key) {
    final text = fields[key]!.text.trim();
    return text.isEmpty ? null : text;
  }

  OnboardingPaymentPreferences _formState({required bool skip}) =>
      OnboardingPaymentPreferences(
        billingCycle: cycle,
        preferredMethod: method,
        billingEmail: _value('billingEmail'),
        billingSchoolName: _value('schoolName'),
        billingAddress: _value('address'),
        billingCity: _value('city'),
        billingCountryCode: _value('country')?.toUpperCase(),
        billingPostalCode: _value('postal'),
        taxIdentifier: _value('tax'),
        skippedForTesting: skip,
      );

  Future<void> _persist({required bool skip}) async {
    if (saving || loading || !loaded) return;
    final preferences = _formState(skip: skip);
    final issues = preferences.validate();
    if (issues.isNotEmpty) {
      setState(() { error = issues.join('\n'); info = null; });
      _showTop();
      return;
    }
    setState(() { saving = true; error = null; info = null; });
    try {
      final result = await widget.repository.save(preferences);
      if (!mounted) return;
      if (skip) {
        if (!result.skippedForTesting) {
          throw StateError('Server did not confirm test-only skip.');
        }
        widget.onSkip();
      } else {
        setState(() => info = 'Billing preferences saved. '
          'No payment was made and your subscription is not active.');
        _showTop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Could not save the billing preferences. '
        'Your school information or selected plan may have changed, '
        'or the connection failed. Review your information and retry.');
      _showTop();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut);
      }
    });
  }

  String capacity(int? value, String unit) =>
    value == null ? 'Unlimited ' + unit
        : 'Up to ' + value.toString() + ' ' + unit;

  Color get primary => Theme.of(context).colorScheme.primary;

  Widget _card(String title, IconData icon, Widget content, {Key? key}) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF103039) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: dark ? null : [
          BoxShadow(color: Colors.black.withValues(alpha: .03),
            blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 23, color: colors.primary)),
            const SizedBox(width: 10),
            Expanded(child: Text(title,
              style: const TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 15),
          content,
        ],
      ),
    );
  }

  Widget _labelledText(String title, String key, {String? hint,
      int maxLength = 200, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          key: Key('payment-billing-' + key),
          enabled: !saving,
          controller: fields[key],
          maxLength: maxLength,
          keyboardType: keyboard,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true, counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12)),
        ),
      ],
    );
  }

  Widget _pair(Widget left, Widget right) {
    return LayoutBuilder(builder: (context, limits) {
      if (limits.maxWidth < 440) {
        return Column(children: [
          left, const SizedBox(height: 13), right,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left),
        const SizedBox(width: 13),
        Expanded(child: right),
      ]);
    });
  }

  Widget _paymentOption(String choice, IconData icon, String title) {
    final selected = method == choice;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: InkWell(
      key: Key('payment-method-' + choice),
      onTap: saving ? null : () => setState(() => method = choice),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: .14)
            : dark ? Colors.transparent : const Color(0xFFF9FBFD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: selected ? colors.primary : null),
            const SizedBox(width: 5),
            Flexible(child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11,
                fontWeight: selected ? FontWeight.w800
                  : FontWeight.w600))),
          ]),
      ),
    ));
  }

  Widget _paymentMethod() {
    final colors = Theme.of(context).colorScheme;
    return _card('Payment Method', Icons.credit_card_outlined,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _paymentOption('card', Icons.credit_card, 'Card'),
          const SizedBox(width: 7),
          _paymentOption('bank_transfer', Icons.account_balance_outlined,
            'Bank Transfer'),
          const SizedBox(width: 7),
          _paymentOption('wallet', Icons.account_balance_wallet_outlined,
            'Wallet'),
        ]),
        const SizedBox(height: 14),
        Container(
          key: const Key('payment-provider-placeholder'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: colors.primary),
              const SizedBox(width: 11),
              Expanded(child: Text(
                method == 'card'
                  ? 'Cardholder name, card number, expiry and CVV will be '
                    'collected by a secure payment provider when checkout '
                    'is activated. Do not enter card details here.'
                  : method == 'bank_transfer'
                  ? 'Verified bank transfer instructions will appear '
                    'after the payment provider is configured.'
                  : 'Supported secure wallets will appear '
                    'after the payment provider is configured.',
                style: const TextStyle(fontSize: 12.5, height: 1.5))),
            ]),
        ),
        const SizedBox(height: 11),
        Text('Save payment method for renewals',
          style: TextStyle(fontSize: 12,
            color: colors.onSurfaceVariant)),
        Text('Unavailable until provider tokenization and '
          'recurring billing consent are implemented.',
          style: TextStyle(fontSize: 11,
            color: colors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _billingDetails() => _card(
    'Billing Details', Icons.badge_outlined,
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _pair(
        _labelledText('Billing Email', 'billingEmail',
          maxLength: 254, keyboard: TextInputType.emailAddress),
        _labelledText('Company / School Name', 'schoolName',
          maxLength: 220),
      ),
      const SizedBox(height: 12),
      _labelledText('Billing Address', 'address', maxLength: 500),
      const SizedBox(height: 12),
      _pair(
        _labelledText('City', 'city', maxLength: 120),
        _labelledText('Country (two-letter ISO code)', 'country',
          hint: 'e.g., AF', maxLength: 2),
      ),
      const SizedBox(height: 12),
      _pair(
        _labelledText('Postal / ZIP Code', 'postal', maxLength: 32),
        _labelledText('Tax / VAT Number (optional)', 'tax', maxLength: 64),
      ),
    ]),
  );

  Widget _cycleOption(String value, String title) {
    final selected = cycle == value;
    final colors = Theme.of(context).colorScheme;
    return Expanded(child: InkWell(
      key: Key('payment-billing-cycle-' + value),
      onTap: saving ? null : () => setState(() => cycle = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1),
          color: selected ? colors.primary.withValues(alpha: .14)
              : Colors.transparent),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(selected ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
            color: selected ? colors.primary : colors.onSurfaceVariant,
            size: 20),
          const SizedBox(width: 9),
          Text(title, style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        ]),
      ),
    ));
  }

  Widget _priceRow(String label) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text('Not configured', style: TextStyle(
          color: colors.onSurfaceVariant, fontSize: 12)),
      ]),
    );
  }

  Widget _summary() {
    final colors = Theme.of(context).colorScheme;
    final plan = widget.plan;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _card('Selected Plan / Order Summary', Icons.layers_outlined,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: dark ? const Color(0xFF124A47)
              : const Color(0xFFE0F7EC)),
          child: Row(children: [
            Icon(Icons.account_balance_outlined,
              color: colors.primary, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, key: const Key('payment-selected-plan'),
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
                Text(plan.summary, style: const TextStyle(fontSize: 12)),
                if (plan.isDemo)
                  const Text('Development demo plan',
                    style: TextStyle(fontSize: 11)),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 15),
        const Text('Billing Cycle', style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 7),
        Row(children: [
          _cycleOption('monthly','Monthly'),
          const SizedBox(width: 11),
          _cycleOption('annual','Annual'),
        ]),
        const SizedBox(height: 14),
        for (final text in [
          capacity(plan.studentLimit, 'students'),
          capacity(plan.campusLimit, 'campuses'),
          capacity(plan.staffLimit, 'staff'),
          plan.trialDays.toString() + '-day demo trial configuration',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              Icon(Icons.check, color: colors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(text,
                style: const TextStyle(fontSize: 12.5))),
            ]),
          ),
        const Divider(height: 24),
        _priceRow('Plan Price (' + (cycle == 'monthly'
          ? 'Monthly' : 'Annual') + ')'),
        _priceRow('Setup Fee (One-time)'),
        _priceRow('Tax / VAT'),
        Container(
          key: const Key('payment-total-unavailable'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: colors.primaryContainer.withValues(alpha: .6)),
          child: const Row(children: [
            Expanded(child: Text('Total Due Today',
              style: TextStyle(fontWeight: FontWeight.w800))),
            Text('Not available',
              style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 13),
        TextField(
          key: const Key('payment-coupon-disabled'),
          enabled: false,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.local_offer_outlined),
            hintText: 'Coupon codes available with real checkout',
            isDense: true)),
        const SizedBox(height: 7),
        Text('Coupons cannot be applied until a trusted pricing '
          'and discount service is configured.',
          style: TextStyle(fontSize: 11,
            color: colors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _notice() {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const Key('payment-not-configured-notice'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF153E4E)
          : const Color(0xFFE4F2FF),
        borderRadius: BorderRadius.circular(13)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: colors.primary),
        const SizedBox(width: 12),
        const Expanded(child: Text(
          'Payment processing is not configured. You can save billing '
          'preferences or skip this step for testing. No charge will '
          'be made and no school subscription will be activated.',
          style: TextStyle(fontSize: 12.5, height: 1.45))),
      ]),
    );
  }

  Widget _feedback() {
    final colors = Theme.of(context).colorScheme;
    final isError = error != null;
    return Container(
      key: Key(isError ? 'payment-error' : 'payment-saved'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(12)),
      child: Text(isError ? error! : info!,
        style: TextStyle(color: isError ? colors.onErrorContainer
          : colors.onPrimaryContainer)),
    );
  }

  Widget _legalNotice() {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: dark ? const Color(0xFF123A38)
          : const Color(0xFFE3F7EE)),
      child: const Row(children: [
        Icon(Icons.shield_outlined),
        SizedBox(width: 11),
        Expanded(child: Text(
          'Recurring billing terms and payment authorization will '
          'be presented when real checkout becomes available. '
          'Skipping does not accept these terms.',
          style: TextStyle(fontSize: 12, height: 1.45))),
      ]),
    );
  }

  Widget _footer() {
    final save = OutlinedButton.icon(
      key: const Key('payment-save-preferences'),
      icon: const Icon(Icons.save_outlined),
      onPressed: loading || !loaded || saving
        ? null : () => _persist(skip: false),
      label: const Text('Save Details'));
    final back = OutlinedButton.icon(
      key: const Key('payment-back-to-review'),
      icon: const Icon(Icons.arrow_back),
      onPressed: saving ? null : widget.onBack,
      label: const Text('Back'));
    // Keep the requested call-to-action visible but provably inactive.
    // Only a verified payment provider may enable real checkout.
    final pay = FilledButton.icon(
      key: const Key('payment-pay-disabled'),
      icon: const Icon(Icons.lock_outline),
      onPressed: null,
      label: const Text('Pay Now & Activate'),
    );
    final skip = FilledButton.icon(
      key: const Key('payment-skip-for-now'),
      iconAlignment: IconAlignment.end,
      icon: saving
        ? const SizedBox(width: 16,height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.arrow_forward),
      onPressed: loading || !loaded || saving
        ? null : () => _persist(skip: true),
      label: const Text('Skip for Now'));
    return LayoutBuilder(builder: (context, limits) {
      if (limits.maxWidth < 540) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            skip,
            const SizedBox(height: 11),
            pay,
            const SizedBox(height: 11),
            Row(children: [
              Expanded(child: back),
              const SizedBox(width: 10),
              Expanded(child: save),
            ]),
          ],
        );
      }
      return Row(children: [
        back,
        const SizedBox(width: 10),
        save,
        const Spacer(),
        pay,
        const SizedBox(width: 10),
        skip,
      ]);
    });
  }

  Widget _paymentLayout() => LayoutBuilder(builder: (context, constraints) {
    if (constraints.maxWidth >= 1050) {
      // Wide Windows/Linux/Web: details on the left, order on the right.
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 6, child: Column(children: [
          _paymentMethod(),
          const SizedBox(height: 15),
          _billingDetails(),
        ])),
        const SizedBox(width: 18),
        Expanded(flex: 4, child: _summary()),
      ]);
    }
    if (constraints.maxWidth >= 760) {
      // Tablet layout follows references: payment, billing, then summary.
      return Column(children: [
        _paymentMethod(),
        const SizedBox(height: 15),
        _billingDetails(),
        const SizedBox(height: 15),
        _summary(),
      ]);
    }
    // Mobile portrait: order first so users understand their selected plan.
    return Column(children: [
      _summary(),
      const SizedBox(height: 15),
      _paymentMethod(),
      const SizedBox(height: 15),
      _billingDetails(),
    ]);
  });

  Widget _topBar(bool desktop) {
    final colors = Theme.of(context).colorScheme;
    return Row(children: [
      IconButton(
        key: const Key('payment-back-top'),
        onPressed: saving ? null : widget.onBack,
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back to Application Review'),
      if (!desktop) ...[
        const SizedBox(width: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset('assets/app_logo/app_icon.jpeg',
            width: 37, height: 37, fit: BoxFit.cover)),
        const SizedBox(width: 9),
        const Expanded(child: Text('Pohantoon AI',
          style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis)),
      ] else const Spacer(),
      AppearanceSettingsButton(
        mode: widget.themeMode,
        onChanged: widget.onThemeChanged),
      const SizedBox(width: 9),
      Tooltip(
        message: widget.accountEmail ?? 'Signed-in applicant',
        child: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(Icons.person_outline, color: colors.primary))),
    ]);
  }

  Widget _sidebar() {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF073D39)
          : const Color(0xFFE5F7F2),
        border: Border(right: BorderSide(color: colors.outlineVariant))),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 29, 22, 30),
        children: [
          Row(children: [
            Image.asset('assets/app_logo/app_icon.jpeg',
              width: 48, height: 48),
            const SizedBox(width: 9),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pohantoon AI', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Smarter School Management,\nPowered by AI',
                  style: TextStyle(fontSize: 10)),
              ])),
          ]),
          const SizedBox(height: 44),
          Text('School Registration',
            style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 17),
          for (final step in const [
            ('Account Connected',1),
            ('Choose Your Plan',2),
            ('School Information',3),
            ('Application Review',4),
            ('Subscription Payment',5),
            ('School Dashboard',6),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: step.$2 == 5
                  ? colors.primary.withValues(alpha: .18)
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: step.$2 < 5
                    ? colors.primary
                    : step.$2 == 5 ? colors.primaryContainer
                      : colors.surface,
                  child: step.$2 < 5
                    ? Icon(Icons.check,
                      size: 17, color: colors.onPrimary)
                    : Text(step.$2.toString(), style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(step.$1,
                  style: TextStyle(fontSize: 12.5,
                    fontWeight: step.$2 == 5
                      ? FontWeight.w800 : FontWeight.w500))),
              ]),
            ),
          const SizedBox(height: 35),
          const SchoolCampusIllustration(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0A2029)
        : const Color(0xFFF5F9FD),
      body: SafeArea(child: LayoutBuilder(
        builder: (context, outer) {
          final desktop = outer.maxWidth >= 1024;
          return Row(children: [
            if (desktop)
              SizedBox(width: outer.maxWidth >= 1400 ? 280 : 244,
                child: _sidebar()),
            Expanded(child: SingleChildScrollView(
              controller: scroll,
              key: Key(desktop ? 'payment-desktop-layout'
                : 'payment-mobile-layout'),
              padding: EdgeInsets.fromLTRB(
                desktop ? 26 : 18, 18,
                desktop ? 26 : 18, 40),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1340),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topBar(desktop),
                    const SizedBox(height: 13),
                    const Text('STEP 5 OF 6 — SUBSCRIPTION PAYMENT',
                      key: Key('payment-progress-label'),
                      style: TextStyle(
                        fontSize: 12, letterSpacing: .8,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(20),
                      child: const LinearProgressIndicator(
                        value: 5 / 6, minHeight: 8)),
                    const SizedBox(height: 22),
                    Text('Complete Your Subscription Payment',
                      key: const Key('payment-preview-title'),
                      style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(
                          fontSize: desktop ? 33 : 27,
                          height: 1.12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Review your selected subscription, '
                      'payment method and billing information.',
                      style: TextStyle(height: 1.4)),
                    const SizedBox(height: 17),
                    _notice(),
                    if (error != null || info != null) ...[
                      const SizedBox(height: 13), _feedback(),
                    ],
                    const SizedBox(height: 18),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(54),
                        child: Center(child: CircularProgressIndicator()))
                    else if (!loaded)
                      OutlinedButton.icon(
                        key: const Key('payment-retry-load'),
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry loading billing details'))
                    else ...[
                      _paymentLayout(),
                      const SizedBox(height: 16),
                      _legalNotice(),
                      const SizedBox(height: 19),
                      _footer(),
                    ],
                  ],
                ),
              )),
            )),
          ]);
        },
      )),
    );
  }
}
