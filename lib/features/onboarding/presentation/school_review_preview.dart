import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../../auth/presentation/school_campus_illustration.dart';
import '../data/review_confirmation_repository.dart';
import '../data/school_logo_repository.dart';
import '../domain/onboarding_plan_offer.dart';
import '../domain/school_setup_draft.dart';

/// Step 4: applicant reviews the current draft before the payment stage.
/// Confirmation is NOT application submission, approval, or a payment.
class SchoolReviewPreview extends StatefulWidget {
  const SchoolReviewPreview({
    super.key,
    required this.draft,
    required this.plan,
    required this.repository,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
    required this.onEditSection,
    required this.onGoToPayment,
    this.accountEmail,
    this.logoRepository,
  });

  final SchoolSetupDraft draft;
  final OnboardingPlanOffer plan;
  final ReviewConfirmationRepository repository;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;
  final ValueChanged<String> onEditSection;
  final VoidCallback onGoToPayment;
  final String? accountEmail;
  final SchoolLogoRepository? logoRepository;

  @override
  State<SchoolReviewPreview> createState() => _SchoolReviewPreviewState();
}

class _SchoolReviewPreviewState extends State<SchoolReviewPreview> {
  bool confirmed = false;
  bool saving = false;
  String? error;
  final ScrollController scroll = ScrollController();

  String display(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value.trim();
  String number(int? count) => count == null ? '—' : count.toString();
  String capacity(int? cap, String unit) =>
      cap == null ? 'Unlimited ' + unit
                  : 'Up to ' + cap.toString() + ' ' + unit;

  String get schoolType {
    const labels = {
      'public':'Public', 'private':'Private', 'international':'International',
      'nonprofit':'Nonprofit', 'other':'Other',
    };
    return labels[widget.draft.schoolType] ??
        display(widget.draft.schoolType);
  }

  String get country {
    const labels = {
      'AF':'Afghanistan','AT':'Austria','AU':'Australia','CA':'Canada',
      'DE':'Germany','FR':'France','GB':'United Kingdom','IN':'India',
      'PK':'Pakistan','SA':'Saudi Arabia','TH':'Thailand',
      'TR':'Türkiye','AE':'United Arab Emirates','US':'United States',
    };
    return labels[widget.draft.countryCode] ??
        display(widget.draft.countryCode);
  }

  String get currency {
    const labels = {
      'AFN':'AFN — Afghan Afghani','USD':'USD — US Dollar',
      'PKR':'PKR — Pakistani Rupee','SAR':'SAR — Saudi Riyal',
      'AED':'AED — UAE Dirham','EUR':'EUR — Euro',
      'GBP':'GBP — British Pound',
    };
    return labels[widget.draft.currencyCode] ??
        widget.draft.currencyCode;
  }

  Future<void> goToPayment() async {
    if (!confirmed || saving) return;
    setState(() { saving = true; error = null; });
    try {
      await widget.repository.confirm(draft: widget.draft, plan: widget.plan);
      if (mounted) widget.onGoToPayment();
    } catch (_) {
      if (!mounted) return;
      setState(() => error =
        'Your review could not be confirmed. The school information or '
        'selected plan may have changed. Return to School Information '
        'and review the saved details, then try again.');
      if (scroll.hasClients) {
        await scroll.animateTo(0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF091E26)
          : const Color(0xFFF5F9FE),
      body: SafeArea(child: LayoutBuilder(builder: (context, outer) {
        final desktop = outer.maxWidth >= 1024;
        return Row(children: [
          if (desktop)
            SizedBox(
              width: outer.maxWidth >= 1450 ? 276 : 246,
              child: sideRail()),
          Expanded(child: SingleChildScrollView(
            controller: scroll,
            key: Key(desktop ? 'review-desktop-layout'
                : 'review-mobile-layout'),
            padding: EdgeInsets.fromLTRB(
              desktop ? 28 : 18, 18, desktop ? 28 : 18, 40),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1350),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  topBar(desktop),
                  const SizedBox(height: 15),
                  const Text('STEP 4 OF 6 — APPLICATION REVIEW',
                    style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12,
                      letterSpacing: 1)),
                  const SizedBox(height: 11),
                  ClipRRect(borderRadius: BorderRadius.circular(18),
                    child: const LinearProgressIndicator(
                      key: Key('review-progress'), value: 4 / 6, minHeight: 8)),
                  const SizedBox(height: 25),
                  Text('Review Your School Application',
                    key: const Key('school-review-preview-title'),
                    style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(
                        fontSize: desktop ? 34 : 29,
                        height: 1.13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  Text('Please review all the information below before '
                    'going to the payment step.',
                    style: TextStyle(height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  notice(),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    errorBanner(),
                  ],
                  const SizedBox(height: 20),
                  reviewSections(),
                  const SizedBox(height: 20),
                  confirmation(),
                  const SizedBox(height: 23),
                  footer(),
                ],
              ),
            )),
          )),
        ]);
      })),
    );
  }

  Widget topBar(bool desktop) {
    final colors = Theme.of(context).colorScheme;
    return Row(children: [
      IconButton(
        key: const Key('review-back-top'),
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back to School Information',
        onPressed: saving ? null : widget.onBack),
      if (!desktop) ...[
        const SizedBox(width: 5),
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/app_logo/app_icon.jpeg',
            width: 34, height: 34, fit: BoxFit.cover)),
        const SizedBox(width: 9),
        const Expanded(child: Text('Pohantoon AI',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
      ] else const Spacer(),
      AppearanceSettingsButton(
        mode: widget.themeMode, onChanged: widget.onThemeChanged),
      const SizedBox(width: 8),
      Tooltip(
        message: widget.accountEmail ?? 'Signed-in applicant',
        child: CircleAvatar(backgroundColor: colors.primaryContainer,
          child: Icon(Icons.person_outline, color: colors.primary))),
    ]);
  }

  Widget sideRail() {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF073B38) : const Color(0xFFE6F7F3),
        border: Border(right: BorderSide(color: colors.outlineVariant))),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
        children: [
          Row(children: [
            Image.asset('assets/app_logo/app_icon.jpeg',
              width: 48, height: 48),
            const SizedBox(width: 10),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pohantoon AI', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18)),
                Text('Smarter School Management,\nPowered by AI',
                  style: TextStyle(fontSize: 10)),
              ],
            )),
          ]),
          const SizedBox(height: 44),
          Text('School Registration',
            style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          for (final step in const [
            ('Account Connected',1),('Choose Your Plan',2),
            ('School Information',3),('Application Review',4),
            ('Subscription Payment',5),('School Dashboard',6),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(
                horizontal: 9, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: step.$2 == 4
                    ? colors.primary.withValues(alpha: .16)
                    : Colors.transparent),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: step.$2 < 4
                    ? colors.primary
                    : step.$2 == 4 ? colors.primaryContainer
                        : colors.surface,
                  child: step.$2 < 4
                    ? Icon(Icons.check, size: 16, color: colors.onPrimary)
                    : Text(step.$2.toString(), style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(step.$1,
                  style: TextStyle(fontSize: 12.5,
                    fontWeight: step.$2 == 4
                      ? FontWeight.w800 : FontWeight.w500))),
              ]),
            ),
          const SizedBox(height: 36),
          const SchoolCampusIllustration(),
        ],
      ),
    );
  }

  Widget notice() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF134151)
                    : const Color(0xFFE4F2FF),
        borderRadius: BorderRadius.circular(13)),
      child: const Row(children: [
        Icon(Icons.info_outline, size: 23),
        SizedBox(width: 12),
        Expanded(child: Text(
          'Make sure all details are correct. You can go back '
          'to edit any section if needed.',
          style: TextStyle(height: 1.4, fontSize: 13))),
      ]),
    );
  }

  Widget errorBanner() => Container(
    key: const Key('review-confirmation-error'),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12)),
    child: Text(error!, style: TextStyle(
      color: Theme.of(context).colorScheme.onErrorContainer)),
  );

  Widget reviewSections() => LayoutBuilder(builder: (context, bounds) {
    final cards = sectionCards();
    if (bounds.maxWidth >= 1120) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 7, child: cardGrid(cards, true)),
        const SizedBox(width: 15),
        Expanded(flex: 3, child: planCard(false)),
      ]);
    }
    return Column(children: [
      cardGrid(cards, bounds.maxWidth >= 710),
      const SizedBox(height: 16),
      planCard(true),
    ]);
  });

  Widget cardGrid(List<Widget> cards, bool twoColumns) {
    if (!twoColumns) return Column(children: [
      for (final c in cards) ...[c, const SizedBox(height: 14)],
    ]);
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: cards[0]), const SizedBox(width: 14),
        Expanded(child: cards[1]),
      ]),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: cards[2]), const SizedBox(width: 14),
        Expanded(child: cards[3]),
      ]),
    ]);
  }

  List<Widget> sectionCards() {
    final d = widget.draft;
    final grade = display(d.lowestGrade) + ' – ' + display(d.highestGrade);
    return [
      detailCard('School Identity','identity',Icons.account_balance_outlined,[
        ('School Name',d.schoolName),
        ('Official Name',d.legalSchoolName),
        ('School Type',schoolType),
        ('Registration No.',d.registrationLicenseNumber),
        ('Established',d.establishedYear?.toString()),
        ('Website',d.websiteUrl),
      ]),
      detailCard('Owner & Contact Information','contact',
          Icons.person_outline,[
        ('Full Name',d.contactName),
        ('Position',d.contactPosition),
        ('Account Email',widget.accountEmail),
        ('School Email',d.contactEmail),
        ('Phone',d.contactPhone),
      ]),
      detailCard('School Location','location',Icons.location_on_outlined,[
        ('Country',country),
        ('Province / State',d.region),
        ('City',d.city),
        ('Address',d.streetAddress),
        ('Postal Code',d.postalCode),
        ('Time Zone',d.timezone),
        ('Currency',currency),
      ]),
      detailCard('Academic & Capacity','academics',Icons.school_outlined,[
        ('Estimated Students',number(d.estimatedStudents)),
        ('Campuses',number(d.campusCount)),
        ('Estimated Teachers',number(d.estimatedTeachers)),
        ('Estimated Staff',number(d.estimatedNonTeachingStaff)),
        ('Education Board',d.educationBoard),
        ('Curriculum',d.curriculum),
        ('Grade Range',grade),
        ('Teaching Languages',d.teachingLanguages.join(', ')),
      ]),
    ];
  }

  Widget detailCard(String title, String section, IconData icon,
      List<(String,String?)> fields) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF112D35) : Colors.white,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(17),
        boxShadow: dark ? null : [BoxShadow(
          color: Colors.black.withValues(alpha: .035),
          blurRadius: 12, offset: const Offset(0,4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start,children: [
            Container(
              width: 39, height: 39,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: colors.primary, size: 23)),
            const SizedBox(width: 9),
            Expanded(child: Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15))),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              key: Key('review-edit-' + section),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 7),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12)),
              onPressed: saving ? null
                : () => widget.onEditSection(section)),
          ]),
          const SizedBox(height: 15),
          if (section == 'identity' && widget.draft.logoStoragePath != null &&
              widget.logoRepository != null) ...[
            FutureBuilder<String>(
              future: widget.logoRepository!.signedUrl(
                widget.draft.logoStoragePath!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('School logo preview loading…',
                    style: TextStyle(fontSize: 11));
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(snapshot.data!,
                        width: 54, height: 54, fit: BoxFit.cover,
                        errorBuilder: (_,__,___) =>
                          const Icon(Icons.school_outlined)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('School logo uploaded privately',
                      style: TextStyle(fontSize: 12))),
                  ]),
                );
              },
            ),
          ],
          for (final field in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4,
                    child: Text(field.$1, style: TextStyle(
                      fontSize: 12, color: colors.onSurfaceVariant))),
                  const SizedBox(width: 8),
                  Expanded(flex: 6,
                    child: Text(display(field.$2),
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget planCard(bool compact) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final plan = widget.plan;
    return Container(
      key: const Key('review-selected-plan'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF123D37)
                    : const Color(0xFFE4F6EF),
        border: Border.all(color: colors.primary.withValues(alpha:.3)),
        borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.layers_outlined,color:colors.primary,size:28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Selected Subscription Plan',
              style: TextStyle(
                fontSize: 14,fontWeight:FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          Text(plan.name,style:const TextStyle(
            fontWeight:FontWeight.w800,fontSize:20)),
          if (plan.isDemo)
            Padding(padding:const EdgeInsets.only(top:3),
              child:Text('Demo plan',style:TextStyle(
                color:colors.primary,fontWeight:FontWeight.w700,
                fontSize:12))),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(plan.summary,style:TextStyle(
              fontSize:12,color:colors.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          for (final benefit in [
            capacity(plan.studentLimit,'students'),
            capacity(plan.campusLimit,'campuses'),
            capacity(plan.staffLimit,'staff'),
            plan.trialDays.toString() + '-day demo trial configuration',
          ])
            Padding(padding:const EdgeInsets.only(bottom:9),
              child:Row(children:[
                Icon(Icons.check,color:colors.primary,size:17),
                const SizedBox(width:8),
                Expanded(child:Text(benefit,
                  style:const TextStyle(fontSize:12.5))),
              ])),
          const SizedBox(height: 8),
          Text('No payment is charged during review.',
            style:TextStyle(
              color:colors.onSurfaceVariant,fontSize:11.5)),
        ],
      ),
    );
  }

  Widget confirmation() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const Key('review-confirmation-panel'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: dark ? const Color(0xFF103D38)
                    : const Color(0xFFE5F6EF)),
      child: CheckboxListTile(
        key: const Key('review-confirmation-checkbox'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
        title: const Text('I confirm that the information provided '
          'is accurate and complete to the best of my knowledge.',
          style: TextStyle(fontSize: 13, height: 1.4)),
        value: confirmed,
        onChanged: saving ? null : (value) => setState(() {
          confirmed = value ?? false;
          error = null;
        }),
      ),
    );
  }

  Widget footer() {
    final back = OutlinedButton.icon(
      key: const Key('school-review-edit'),
      icon: const Icon(Icons.arrow_back),
      label: const Text('Back'),
      onPressed: saving ? null : widget.onBack);
    final next = FilledButton.icon(
      key: const Key('review-go-to-payment'),
      iconAlignment: IconAlignment.end,
      icon: saving
        ? const SizedBox(width:16,height:16,
            child:CircularProgressIndicator(strokeWidth:2))
        : const Icon(Icons.arrow_forward),
      label: const Text('Go to Payment'),
      onPressed: confirmed && !saving ? goToPayment : null);
    return LayoutBuilder(builder:(context,bounds) {
      if (bounds.maxWidth < 360) return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [next,const SizedBox(height:11),back]);
      return Row(children:[
        Expanded(flex:2,child:back),
        const SizedBox(width:11),
        Expanded(flex:5,child:next),
      ]);
    });
  }
}
