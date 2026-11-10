import 'package:flutter/material.dart';

import '../../../core/ui/adaptive_layout.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../core/ui/app_theme.dart';
import '../data/mock_organization_repository.dart';
import '../data/organization_repository.dart';
import '../domain/organization_models.dart';
import 'school_onboarding_screen.dart';

/// Module 01: one adaptive Organization console for mobile, web and desktop.
/// Data is in-memory until authenticated, scoped Supabase APIs are implemented.
class OrganizationControlPanel extends StatefulWidget {
  const OrganizationControlPanel({super.key, this.repository});

  /// Injection allows loading, error and empty-state widget testing.
  final OrganizationRepository? repository;

  @override
  State<OrganizationControlPanel> createState() =>
      _OrganizationControlPanelState();
}

class _OrganizationControlPanelState extends State<OrganizationControlPanel> {
  late final OrganizationRepository _repository;
  final TextEditingController _search = TextEditingController();

  OrganizationSnapshot? _snapshot;
  String? _loadError;
  int _selectedTab = 0;
  bool _loading = false;
  OnboardingStatus? _statusFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MockOrganizationRepository();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await _repository.load();
      if (!mounted) return;
      setState(() => _snapshot = result);
    } on OrganizationFailure catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    } catch (error) {
      debugPrint('Organization data load failed: $error');
      if (!mounted) return;
      setState(() {
        _loadError =
            'We could not load the organization data. Check your connection and retry.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSchool() async {
    final plans = _snapshot?.plans ?? const <SubscriptionPlan>[];
    if (plans.isEmpty) {
      showAppMessage(
        context,
        message: 'Subscription plans are unavailable. Refresh before continuing.',
        error: true,
      );
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SchoolOnboardingScreen(
          plans: plans,
          onSubmit: _repository.submit,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    setState(() => _selectedTab = 2);
    await _load();
    if (!mounted) return;
    showAppMessage(
      context,
      message:
          'Demo request saved locally. No school or paid subscription was created.',
    );
  }

  void _switchTab(int tab) {
    if (tab == _selectedTab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selectedTab = tab);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final rail = width >= AppBreakpoints.navigationRail;
          final extended = width >= AppBreakpoints.extendedRail;
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 72,
              titleSpacing: rail ? 24 : 16,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: 'Pohantoon AI logo',
                    image: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Transform.scale(
                          scale: 2,
                          child: Image.asset(
                            'assets/app_logo/app_icon.jpeg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.school_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      width < 390 ? 'Pohantoon' : 'Pohantoon AI',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (width >= 600)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Chip(
                        avatar: Icon(Icons.science_outlined, size: 17),
                        label: Text('DEMO · NO LIVE BILLING'),
                        backgroundColor: AppColors.primarySoft,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                IconButton(
                  key: const Key('refresh-organization'),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh organization data',
                ),
                const SizedBox(width: 10),
              ],
            ),
            bottomNavigationBar: rail
                ? null
                : NavigationBar(
                    key: const Key('mobile-navigation'),
                    selectedIndex: _selectedTab,
                    onDestinationSelected: _switchTab,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: 'Overview',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.layers_outlined),
                        selectedIcon: Icon(Icons.layers),
                        label: 'Plans',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.apartment_outlined),
                        selectedIcon: Icon(Icons.apartment),
                        label: 'Requests',
                      ),
                    ],
                  ),
            body: SafeArea(
              child: Row(
                children: [
                  if (rail)
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          right: BorderSide(color: AppColors.outline),
                        ),
                      ),
                      child: NavigationRail(
                        key: const Key('desktop-navigation'),
                        extended: extended,
                        minExtendedWidth: 230,
                        selectedIndex: _selectedTab,
                        onDestinationSelected: _switchTab,
                        backgroundColor: AppColors.surface,
                        labelType: extended
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Icon(
                            Icons.account_tree_outlined,
                            size: 26,
                            color: AppColors.primary,
                            semanticLabel: 'Organization modules',
                          ),
                        ),
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
                    child: Column(
                      children: [
                        if (_loading && _snapshot != null)
                          const LinearProgressIndicator(
                            minHeight: 3,
                            semanticsLabel: 'Refreshing organization data',
                          ),
                        Expanded(
                          child: _snapshot == null && _loading
                              ? const AppLoadingState()
                              : _snapshot == null
                                  ? _firstLoadFailure()
                                  : SingleChildScrollView(
                                      key: const Key('organization-scroll'),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior.onDrag,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: width < 650 ? 16 : 30,
                                        vertical: width < 650 ? 20 : 30,
                                      ),
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 1280,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              if (width < 600) ...[
                                                const AppNotice(
                                                  title: 'Development mode',
                                                  message:
                                                      'Your changes stay in this device session. '
                                                      'Live billing and provisioning are disabled.',
                                                ),
                                                const SizedBox(height: 16),
                                              ],
                                              if (_loadError != null) ...[
                                                AppNotice(
                                                  key: const Key('refresh-error'),
                                                  kind: NoticeKind.warning,
                                                  title: 'Showing previous data',
                                                  message: _loadError!,
                                                  actionLabel: 'Retry',
                                                  onAction: _load,
                                                ),
                                                const SizedBox(height: 18),
                                              ],
                                              _pageContent(_snapshot!),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _firstLoadFailure() => Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: AppEmptyState(
              key: const Key('organization-load-error'),
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load your workspace',
              message: _loadError ??
                  'Organization data is unavailable right now. Please try again.',
              action: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry loading'),
              ),
            ),
          ),
        ),
      );

  Widget _pageContent(OrganizationSnapshot snapshot) => switch (_selectedTab) {
        1 => _plansPage(snapshot),
        2 => _requestsPage(snapshot),
        _ => _overviewPage(snapshot),
      };

  Widget _actionButton() => FilledButton.icon(
        key: const Key('new-school-request'),
        onPressed: _createSchool,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New school request'),
      );

  Widget _overviewPage(OrganizationSnapshot snapshot) {
    final pending = snapshot.requests.where((request) =>
        request.status == OnboardingStatus.submitted ||
        request.status == OnboardingStatus.inReview ||
        request.status == OnboardingStatus.moreInformation).length;
    final provisioned = snapshot.requests
        .where((request) => request.status == OnboardingStatus.provisioned)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageTitle(
          title: 'Organization overview',
          subtitle: 'A clear view of your school onboarding pipeline.',
          action: _actionButton(),
        ),
        const SizedBox(height: 22),
        _welcomeHero(),
        const SizedBox(height: 22),
        AdaptiveGrid(
          columnsForWidth: AppBreakpoints.dashboardColumns,
          children: [
            _metricCard(
              'Demo plans', snapshot.plans.length.toString(),
              Icons.layers_outlined, 'Available packages',
            ),
            _metricCard(
              'School requests', snapshot.requests.length.toString(),
              Icons.apartment_outlined, 'Total applications',
            ),
            _metricCard(
              'Awaiting review', pending.toString(),
              Icons.pending_actions_outlined, 'Action may be required',
            ),
            _metricCard(
              'Provisioned schools', provisioned.toString(),
              Icons.domain_outlined, 'Demo records only',
            ),
          ],
        ),
        const SizedBox(height: 30),
        _sectionTitle('Recent school applications', 'View all',
            () => _switchTab(2)),
        const SizedBox(height: 14),
        if (snapshot.requests.isEmpty)
          AppEmptyState(
            key: const Key('overview-empty'),
            icon: Icons.mark_email_unread_outlined,
            title: 'No school applications yet',
            message: 'Create a demo school request to test the onboarding workflow.',
            action: _actionButton(),
          )
        else
          ...snapshot.requests.take(3).map(_requestTile),
        const SizedBox(height: 22),
        const AppNotice(
          title: 'Prototype and data safety',
          message:
              'The Supabase test database exists, but this interface still uses '
              'sample data. No real payment, school account or access rights are created.',
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _welcomeHero() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 27),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF153D47), Color(0xFF166860)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final introduction = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR ORGANIZATION WORKSPACE',
                  style: TextStyle(
                    fontSize: 12, letterSpacing: 1.6,
                    fontWeight: FontWeight.w700, color: Color(0xFFBCE7DC),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Start every school with a confident first step.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: Colors.white,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gather school information, match a plan and review '
                  'the request before activating a tenant.',
                  style: TextStyle(color: Color(0xFFE3F3EF), height: 1.5),
                ),
              ],
            );
            if (compact) return introduction;
            return Row(
              children: [
                Expanded(child: introduction),
                const SizedBox(width: 24),
                const Icon(
                  Icons.account_tree_outlined,
                  size: 96,
                  color: Color(0x66FFFFFF),
                ),
              ],
            );
          },
        ),
      );

  Widget _metricCard(String label, String value, IconData icon, String hint) {
    return AppSurface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 134),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String action, VoidCallback callback) =>
      LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            TextButton(
              onPressed: callback,
              child: Text(action),
            ),
          ],
        ),
      );

  Widget _plansPage(OrganizationSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppPageTitle(
          title: 'Subscription plans',
          subtitle: 'Compare the demonstration packages available to schools.',
        ),
        const SizedBox(height: 22),
        const AppNotice(
          title: 'No billing in this preview',
          message: 'Prices and limits are illustrative. Plan selection in the '
              'school request form does not charge a customer.',
        ),
        const SizedBox(height: 22),
        if (snapshot.plans.isEmpty)
          AppEmptyState(
            key: const Key('plans-empty'),
            title: 'No plans available',
            message: 'The plan catalog has no entries. Refresh to check again.',
            icon: Icons.layers_clear_outlined,
            action: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh plans'),
            ),
          )
        else
          AdaptiveGrid(
            columnsForWidth: (width) => width < 620 ? 1 : width < 1100 ? 2 : 3,
            children: snapshot.plans.map(_planCard).toList(),
          ),
      ],
    );
  }

  Widget _planCard(SubscriptionPlan plan) => AppSurface(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.workspace_premium_outlined,
                size: 31, color: AppColors.primary),
            const SizedBox(height: 18),
            Text(plan.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 8),
            Text(
              plan.summary,
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            Text(
              plan.displayLimits,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              plan.trialDays.toString() + '-day demo trial',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            const Chip(
              label: Text('TEST PLAN · \$0 billed'),
              backgroundColor: AppColors.primarySoft,
            ),
          ],
        ),
      );

  List<SchoolOnboardingRequest> _filteredRequests(OrganizationSnapshot snapshot) {
    final needle = _query.trim().toLowerCase();
    return snapshot.requests.where((request) {
      final matchesStatus = _statusFilter == null || request.status == _statusFilter;
      final matchesText = needle.isEmpty ||
          request.schoolName.toLowerCase().contains(needle) ||
          request.city.toLowerCase().contains(needle) ||
          request.contactEmail.toLowerCase().contains(needle) ||
          request.id.toLowerCase().contains(needle);
      return matchesStatus && matchesText;
    }).toList();
  }

  Widget _requestsPage(OrganizationSnapshot snapshot) {
    final results = _filteredRequests(snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageTitle(
          title: 'School onboarding requests',
          subtitle: 'Search, review and track prospective schools.',
          action: _actionButton(),
        ),
        const SizedBox(height: 22),
        AppSurface(
          child: AdaptiveGrid(
            columnsForWidth: AppBreakpoints.contentColumns,
            children: [
              TextField(
                key: const Key('school-request-search'),
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Search applications',
                  hintText: 'School, email, city or request ID',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              DropdownButtonFormField<OnboardingStatus?>(
                key: const Key('request-status-filter'),
                value: _statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filter by status',
                ),
                items: [
                  const DropdownMenuItem<OnboardingStatus?>(
                    value: null, child: Text('All statuses'),
                  ),
                  for (final status in OnboardingStatus.values)
                    DropdownMenuItem<OnboardingStatus?>(
                      value: status, child: Text(status.label),
                    ),
                ],
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (snapshot.requests.isEmpty)
          AppEmptyState(
            key: const Key('requests-empty'),
            title: 'No school requests yet',
            message: 'Use New school request to create a demo application.',
            icon: Icons.inbox_outlined,
            action: _actionButton(),
          )
        else if (results.isEmpty)
          AppEmptyState(
            key: const Key('requests-no-matches'),
            title: 'No matching requests',
            message: 'Try a different school name or clear the filters.',
            icon: Icons.search_off_rounded,
            action: OutlinedButton.icon(
              onPressed: () {
                _search.clear();
                setState(() {
                  _query = '';
                  _statusFilter = null;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear filters'),
            ),
          )
        else ...[
          Text(
            results.length.toString() +
                (results.length == 1 ? ' request' : ' requests'),
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          ...results.map(_requestTile),
        ],
        const SizedBox(height: 20),
        const AppNotice(
          title: 'Review workflow not connected',
          message: 'These requests are demo records. Approvals, payment '
              'verification and school provisioning need protected backend commands.',
          kind: NoticeKind.warning,
        ),
      ],
    );
  }

  Widget _requestTile(SchoolOnboardingRequest request) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 510;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.schoolName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  request.city + ', ' + request.countryCode +
                      ' · ' + request.contactEmail,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Plan: ' + request.planCode +
                      ' · ' + request.studentEstimate.toString() +
                      ' students',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            );
            final status = Chip(
              label: Text(request.status.label),
              backgroundColor: request.status == OnboardingStatus.approved ||
                      request.status == OnboardingStatus.provisioned
                  ? AppColors.primarySoft
                  : const Color(0xFFEDF2F8),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 10), status],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 14),
                status,
              ],
            );
          },
        ),
      ),
    );
  }
}
