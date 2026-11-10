import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/adaptive_layout.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../core/ui/app_theme.dart';
import '../data/organization_repository.dart';
import '../domain/organization_models.dart';

/// The same scrollable school-intake form is used on mobile, web and desktop.
class SchoolOnboardingScreen extends StatefulWidget {
  const SchoolOnboardingScreen({
    super.key,
    required this.plans,
    required this.onSubmit,
  });

  final List<SubscriptionPlan> plans;
  final Future<SchoolOnboardingRequest> Function(SchoolOnboardingDraft) onSubmit;

  @override
  State<SchoolOnboardingScreen> createState() => _SchoolOnboardingScreenState();
}

class _SchoolOnboardingScreenState extends State<SchoolOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _school = TextEditingController();
  final _legalName = TextEditingController();
  final _registration = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _country = TextEditingController(text: 'SA');
  final _city = TextEditingController();
  final _board = TextEditingController();
  final _curriculum = TextEditingController();
  final _students = TextEditingController(text: '100');
  final _campuses = TextEditingController(text: '1');
  final _timezone = TextEditingController(text: 'Asia/Riyadh');
  final _currency = TextEditingController(text: 'SAR');

  String _schoolType = 'private';
  String? _planCode;
  String? _error;
  bool _submitting = false;
  bool _showValidationSummary = false;

  @override
  void initState() {
    super.initState();
    _planCode = widget.plans.isEmpty ? null : widget.plans.first.code;
    _students.addListener(_refreshLimits);
    _campuses.addListener(_refreshLimits);
  }

  void _refreshLimits() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _school, _legalName, _registration, _owner, _email, _phone, _country,
      _city, _board, _curriculum, _students, _campuses, _timezone, _currency,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  SubscriptionPlan? get _selectedPlan {
    for (final plan in widget.plans) {
      if (plan.code == _planCode) return plan;
    }
    return null;
  }

  bool get _exceedsPlan {
    final plan = _selectedPlan;
    if (plan == null) return true;
    final students = int.tryParse(_students.text.trim()) ?? 0;
    final campuses = int.tryParse(_campuses.text.trim()) ?? 0;
    return (plan.studentLimit != null && students > plan.studentLimit!) ||
        (plan.campusLimit != null && campuses > plan.campusLimit!);
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'This field is required.' : null;

  String? _emailValidator(String? value) {
    final error = _required(value);
    if (error != null) return error;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(value!.trim());
    return valid ? null : 'Enter a valid email address.';
  }

  String? _countryValidator(String? value) {
    final error = _required(value);
    if (error != null) return error;
    return RegExp(r'^[a-zA-Z]{2}$').hasMatch(value!.trim())
        ? null
        : 'Use a two-letter country code, such as SA.';
  }

  String? _currencyValidator(String? value) {
    final error = _required(value);
    if (error != null) return error;
    return RegExp(r'^[a-zA-Z]{3}$').hasMatch(value!.trim())
        ? null
        : 'Use a three-letter currency code, such as SAR.';
  }

  String? _positiveNumber(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 1) return 'Enter a number greater than zero.';
    if (number > 10000000) return 'Enter a smaller, realistic estimate.';
    return null;
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _sectionHeading(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() {
        _showValidationSummary = true;
        _error = null;
      });
      return;
    }
    if (_selectedPlan == null || _exceedsPlan) {
      setState(() {
        _showValidationSummary = false;
        _error = 'Select a plan that covers your estimated students and campuses.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _showValidationSummary = false;
    });
    FocusScope.of(context).unfocus();
    final draft = SchoolOnboardingDraft(
      schoolName: _school.text.trim(),
      legalName: _legalName.text.trim(),
      registrationNumber: _registration.text.trim(),
      ownerName: _owner.text.trim(),
      contactEmail: _email.text.trim(),
      contactPhone: _phone.text.trim(),
      countryCode: _country.text.trim().toUpperCase(),
      city: _city.text.trim(),
      planCode: _planCode!,
      studentEstimate: int.parse(_students.text.trim()),
      campusEstimate: int.parse(_campuses.text.trim()),
      educationBoard: _board.text.trim(),
      curriculumSummary: _curriculum.text.trim(),
      schoolType: _schoolType,
      preferredTimezone: _timezone.text.trim(),
      preferredCurrency: _currency.text.trim().toUpperCase(),
    );
    try {
      await widget.onSubmit(draft);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on OrganizationFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      debugPrint('School onboarding save failed: $error');
      if (!mounted) return;
      setState(() {
        _error = 'We could not save this request. Your information is still here. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPlan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New school request'),
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 600 ? 16 : 28,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppPageTitle(
                        title: 'Tell us about your school',
                        subtitle: 'Start with essential details. An operator will review '
                            'the request before any school account is provisioned.',
                      ),
                      const SizedBox(height: 22),
                      const AppNotice(
                        title: 'Development preview',
                        message: 'This request stays in mock memory. No subscription '
                            'is purchased and no school is created.',
                      ),
                      if (_showValidationSummary) ...[
                        const SizedBox(height: 14),
                        const AppNotice(
                          key: Key('form-validation-summary'),
                          title: 'Please correct the highlighted fields',
                          message: 'Your information has been preserved. '
                              'Review the fields marked in red and submit again.',
                          kind: NoticeKind.error,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        AppNotice(
                          key: const Key('form-submit-error'),
                          title: 'Request not saved',
                          message: _error!,
                          kind: NoticeKind.error,
                        ),
                      ],
                      const SizedBox(height: 22),
                      AppSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionHeading(
                              'School identity',
                              'Legal and registered details, where available.',
                              Icons.domain_outlined,
                            ),
                            AdaptiveGrid(
                              columnsForWidth: AppBreakpoints.contentColumns,
                              children: [
                                _field('School name *', _school, validator: _required),
                                _field('Legal school name', _legalName),
                                _field('Registration / license number', _registration),
                                DropdownButtonFormField<String>(
                                  value: _schoolType,
                                  decoration: const InputDecoration(labelText: 'School type'),
                                  items: const [
                                    DropdownMenuItem(value: 'private', child: Text('Private')),
                                    DropdownMenuItem(value: 'public', child: Text('Public')),
                                    DropdownMenuItem(value: 'nonprofit', child: Text('Non-profit')),
                                    DropdownMenuItem(value: 'international', child: Text('International')),
                                    DropdownMenuItem(value: 'other', child: Text('Other')),
                                  ],
                                  onChanged: _submitting ? null : (value) {
                                    if (value != null) setState(() => _schoolType = value);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _sectionHeading('Primary contact', 'Who should receive onboarding updates?', Icons.person_outline_rounded),
                            AdaptiveGrid(
                              columnsForWidth: AppBreakpoints.contentColumns,
                              children: [
                                _field('Contact name *', _owner, validator: _required),
                                _field('Contact email *', _email,
                                    validator: _emailValidator,
                                    keyboardType: TextInputType.emailAddress),
                                _field('Contact phone', _phone,
                                    keyboardType: TextInputType.phone),
                                _field('Country code *', _country,
                                    validator: _countryValidator,
                                    hint: 'SA'),
                                _field('City *', _city, validator: _required),
                                _field('Time zone *', _timezone, validator: _required),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionHeading(
                              'Education and capacity',
                              'Estimates can be reviewed during school setup.',
                              Icons.school_outlined,
                            ),
                            AdaptiveGrid(
                              columnsForWidth: AppBreakpoints.contentColumns,
                              children: [
                                _field('Education board', _board),
                                _field('Curriculum', _curriculum),
                                _field(
                                  'Estimated students *', _students,
                                  validator: _positiveNumber,
                                  keyboardType: TextInputType.number,
                                  formatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                                _field(
                                  'Estimated campuses *', _campuses,
                                  validator: _positiveNumber,
                                  keyboardType: TextInputType.number,
                                  formatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                                _field('Currency code *', _currency,
                                    validator: _currencyValidator, hint: 'SAR'),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _sectionHeading(
                              'Subscription selection',
                              'Demo packages only — billing is not active.',
                              Icons.workspace_premium_outlined,
                            ),
                            if (widget.plans.isEmpty)
                              const AppNotice(
                                title: 'No plans available',
                                message: 'Unable to submit without a plan. Go back and retry loading the catalog.',
                                kind: NoticeKind.warning,
                              )
                            else
                              DropdownButtonFormField<String>(
                                key: const Key('school-plan-field'),
                                value: _planCode,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Plan *',
                                ),
                                items: [
                                  for (final plan in widget.plans)
                                    DropdownMenuItem(
                                      value: plan.code,
                                      child: Text(plan.name),
                                    ),
                                ],
                                onChanged: _submitting ? null : (value) {
                                  if (value != null) setState(() {
                                    _planCode = value;
                                    _error = null;
                                  });
                                },
                              ),
                            if (selected != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                selected.displayLimits + ' · ' +
                                    selected.trialDays.toString() + '-day demo trial',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                            if (_exceedsPlan && selected != null) ...[
                              const SizedBox(height: 14),
                              AppNotice(
                                key: const Key('plan-capacity-warning'),
                                kind: NoticeKind.warning,
                                title: 'Plan capacity exceeded',
                                message: 'The selected plan cannot cover the estimated '
                                    'students or campuses. Choose a larger plan or adjust the estimates.',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 480;
                          final actions = [
                            OutlinedButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton.icon(
                              key: const Key('submit-school-request'),
                              onPressed: (_submitting || widget.plans.isEmpty)
                                  ? null
                                  : _submit,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined),
                              label: Text(_submitting ? 'Saving request…' : 'Save demo request'),
                            ),
                          ];
                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                actions[1],
                                const SizedBox(height: 10),
                                actions[0],
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              actions[0],
                              const SizedBox(width: 12),
                              actions[1],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
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
