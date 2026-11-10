import 'package:flutter/material.dart';

import '../data/mock_organization_repository.dart';
import '../domain/organization_models.dart';

/// Module 01: Organization control panel. Current data source is MOCK ONLY.
class OrganizationControlPanel extends StatefulWidget {
  const OrganizationControlPanel({super.key});

  @override
  State<OrganizationControlPanel> createState() => _OrganizationControlPanelState();
}

class _OrganizationControlPanelState extends State<OrganizationControlPanel> {
  final MockOrganizationRepository _repository = MockOrganizationRepository();
  int _tab = 0;

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _newSchool() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _NewSchoolDialog(
        plans: _repository.plans,
        onSubmit: (draft) {
          _repository.submit(draft);
          Navigator.of(context).pop(true);
        },
      ),
    );
    if (!mounted || saved != true) return;
    setState(() => _tab = 2);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved in mock memory only — no school or subscription has been created.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repository,
      builder: (context, _) => LayoutBuilder(
        builder: (context, dimensions) {
          final wide = dimensions.maxWidth >= 860;
          return Scaffold(
            backgroundColor: const Color(0xFFF6F8FB),
            appBar: AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, color: Color(0xFF176A66)),
                  SizedBox(width: 12),
                  Flexible(child: Text('Pohantoon AI  /  Organization')),
                ],
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Chip(
                      avatar: const Icon(Icons.science_outlined, size: 18),
                      label: Text(wide ? 'DEVELOPMENT · MOCK DATA' : 'MOCK'),
                      backgroundColor: const Color(0xFFE7F7F4),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (index) => setState(() => _tab = index),
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
                      NavigationDestination(icon: Icon(Icons.layers_outlined), label: 'Plans'),
                      NavigationDestination(icon: Icon(Icons.apartment_outlined), label: 'Requests'),
                    ],
                  ),
            body: Row(
              children: [
                if (wide)
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: Color(0xFFE6EAF0))),
                    ),
                    child: NavigationRail(
                      extended: dimensions.maxWidth >= 1170,
                      selectedIndex: _tab,
                      onDestinationSelected: (index) => setState(() => _tab = index),
                      backgroundColor: Colors.white,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Overview'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.layers_outlined),
                          selectedIcon: Icon(Icons.layers),
                          label: Text('Subscription plans'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.apartment_outlined),
                          selectedIcon: Icon(Icons.apartment),
                          label: Text('School requests'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 28 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _activePage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _activePage() => switch (_tab) {
        1 => _plansPage(),
        2 => _requestsPage(),
        _ => _overviewPage(),
      };

  Widget _pageHeader(String title, String subtitle, {bool showAction = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: const Color(0xFF132D37))),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Color(0xFF63717F))),
            ],
          ),
          if (showAction)
            FilledButton.icon(
              onPressed: _newSchool,
              icon: const Icon(Icons.add),
              label: const Text('New school request'),
            ),
        ],
      ),
    );
  }

  Widget _overviewPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          'Organization overview',
          'Manage school interest, plans and onboarding. Preview data only.',
          showAction: true,
        ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _statCard('Demo plans', _repository.plans.length.toString(), Icons.layers_outlined),
            _statCard('School requests', _repository.requests.length.toString(), Icons.apartment_outlined),
            _statCard('Awaiting review', _repository.submittedCount.toString(), Icons.pending_actions_outlined),
            _statCard('Provisioned schools', '0', Icons.business_outlined),
          ],
        ),
        const SizedBox(height: 30),
        Text('Recent school applications', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ..._repository.requests.take(3).map(_requestCard),
        const SizedBox(height: 20),
        _notice(),
      ],
    );
  }

  Widget _statCard(String label, String number, IconData icon) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF176A66)),
              const SizedBox(height: 16),
              Text(number, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Color(0xFF63717F))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plansPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader('Subscription plans', 'These are fictional demo plans. No payments are collected.'),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _repository.plans.map((plan) {
            return SizedBox(
              width: 320,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_outlined, color: Color(0xFF176A66), size: 30),
                      const SizedBox(height: 18),
                      Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(plan.summary),
                      const SizedBox(height: 22),
                      Text(plan.displayLimits, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Demo trial: ' + plan.trialDays.toString() + ' days'),
                      const SizedBox(height: 24),
                      const Chip(label: Text('TEST PLAN · \$0 billed')),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        _notice(),
      ],
    );
  }

  Widget _requestsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          'School onboarding requests',
          'Collect school information, verify subscriptions and review before school creation.',
          showAction: true,
        ),
        if (_repository.requests.isEmpty)
          const Card(child: Padding(
            padding: EdgeInsets.all(24), child: Text('No requests in this demo yet.')))
        else
          ..._repository.requests.map(_requestCard),
        const SizedBox(height: 16),
        _notice(),
      ],
    );
  }

  Widget _requestCard(SchoolOnboardingRequest request) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.schoolName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Text(request.city + ', ' + request.countryCode + ' · ' + request.contactEmail,
                        style: const TextStyle(color: Color(0xFF63717F))),
                    const SizedBox(height: 5),
                    Text('Requested plan: ' + request.planCode),
                  ],
                ),
              ),
              Chip(label: Text(request.status.label)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice() => const Card(
        color: Color(0xFFEAF3FD),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFF30638B)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Development preview: all changes stay in memory until the '
                  'authenticated organization API and database integration are verified. '
                  'No payment, school creation or authorization happens here.',
                ),
              ),
            ],
          ),
        ),
      );
}

class _NewSchoolDialog extends StatefulWidget {
  const _NewSchoolDialog({required this.plans, required this.onSubmit});

  final List<SubscriptionPlan> plans;
  final ValueChanged<SchoolOnboardingDraft> onSubmit;

  @override
  State<_NewSchoolDialog> createState() => _NewSchoolDialogState();
}

class _NewSchoolDialogState extends State<_NewSchoolDialog> {
  final _form = GlobalKey<FormState>();
  final _school = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _country = TextEditingController(text: 'SA');
  final _city = TextEditingController();
  final _students = TextEditingController(text: '100');
  final _campuses = TextEditingController(text: '1');
  late String _planCode;

  @override
  void initState() {
    super.initState();
    _planCode = widget.plans.first.code;
  }

  @override
  void dispose() {
    for (final controller in [_school, _owner, _email, _country, _city, _students, _campuses]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _positiveNumber(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 1) return 'Enter a positive number';
    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    widget.onSubmit(
      SchoolOnboardingDraft(
        schoolName: _school.text.trim(),
        ownerName: _owner.text.trim(),
        contactEmail: _email.text.trim(),
        countryCode: _country.text.trim().toUpperCase(),
        city: _city.text.trim(),
        planCode: _planCode,
        studentEstimate: int.parse(_students.text),
        campusEstimate: int.parse(_campuses.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New school request · Demo'),
      content: SizedBox(
        width: 520,
        height: 475,
        child: Form(
          key: _form,
          child: ListView(
            children: [
              const Text('Collect introductory school details before review and provisioning.'),
              const SizedBox(height: 16),
              TextFormField(controller: _school, decoration: const InputDecoration(
                  labelText: 'School name'), validator: _required),
              const SizedBox(height: 12),
              TextFormField(controller: _owner, decoration: const InputDecoration(
                  labelText: 'Owner / contact name'), validator: _required),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'School contact email'),
                keyboardType: TextInputType.emailAddress,
                validator: (s) => _required(s) ?? ((s?.contains('@') ?? false) ? null : 'Enter a valid email'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _country,
                decoration: const InputDecoration(labelText: 'Country code (2 letters)'),
                validator: (s) => _required(s) ??
                    ((s?.trim().length == 2) ? null : 'Use a two-letter country code'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _students,
                decoration: const InputDecoration(labelText: 'Estimated students'),
                keyboardType: TextInputType.number,
                validator: _positiveNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _campuses,
                decoration: const InputDecoration(labelText: 'Estimated campuses'),
                keyboardType: TextInputType.number,
                validator: _positiveNumber,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _planCode,
                decoration: const InputDecoration(labelText: 'Demo subscription plan'),
                items: widget.plans.map((plan) => DropdownMenuItem(
                  value: plan.code, child: Text(plan.name),
                )).toList(),
                onChanged: (value) { if (value != null) setState(() => _planCode = value); },
              ),
              const SizedBox(height: 12),
              const Text('Additional legal, academic and campus information will be collected '
                  'in the complete onboarding module. This form does not initiate payment.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save demo request')),
      ],
    );
  }
}
