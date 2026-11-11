import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../../auth/presentation/school_campus_illustration.dart';
import '../../dashboard/data/demo_dashboard_preferences_repository.dart';
import '../../dashboard/domain/dashboard_demo_data.dart';
import '../../dashboard/presentation/rotating_dashboard_panels.dart';
import '../data/school_logo_repository.dart';
import '../domain/onboarding_plan_offer.dart';
import '../domain/school_setup_draft.dart';

/// Step 6 responsive demonstration workspace.
///
/// This is NOT a real school tenant. All example analytics, admissions,
/// approvals and finance statistics are fixed, clearly marked DEMO DATA.
/// No school member permission or payment entitlement is granted by a skip.
class SchoolDashboardSetupPreview extends StatefulWidget {
  const SchoolDashboardSetupPreview({
    super.key,
    required this.plan,
    required this.draft,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onBack,
    this.onEditDetails,
    this.preferencesRepository,
    this.logoRepository,
  });

  final OnboardingPlanOffer plan;
  final SchoolSetupDraft draft;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onBack;
  final ValueChanged<String>? onEditDetails;
  final DemoDashboardPreferencesRepository? preferencesRepository;
  final SchoolLogoRepository? logoRepository;

  @override
  State<SchoolDashboardSetupPreview> createState() =>
    _SchoolDashboardSetupPreviewState();
}

class _SchoolDashboardSetupPreviewState
    extends State<SchoolDashboardSetupPreview> {
  DemoDashboardPreferences settings = const DemoDashboardPreferences();
  String? schoolLogoUrl;
  bool settingsLoaded = false;
  static const actions = <(String,String,IconData)>[
    ('add_student','Add student',Icons.person_add_alt_outlined),
    ('new_admission','New admission',Icons.note_add_outlined),
    ('mark_attendance','Mark attendance',Icons.fact_check_outlined),
    ('record_payment','Record payment',Icons.credit_card_outlined),
    ('add_staff','Add staff',Icons.group_add_outlined),
    ('send_notice','Send notice',Icons.campaign_outlined),
    ('reports','Reports',Icons.bar_chart_outlined),
    ('settings','Settings',Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLogo();
  }

  DemoDashboardPreferencesRepository? get preferences {
    if (widget.preferencesRepository != null) {
      return widget.preferencesRepository;
    }
    // Test widgets using a fake plan/auth gateway can render without a
    // Supabase instance. Real sign-ins use the live repository in main.dart.
    return null;
  }

  Future<void> _loadSettings() async {
    try {
      final loaded = await preferences?.load();
      if (mounted) setState(() {
        if (loaded != null) settings = loaded;
        settingsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => settingsLoaded = true);
    }
  }

  Future<void> _loadLogo() async {
    final path = widget.draft.logoStoragePath;
    if (path == null || widget.logoRepository == null) return;
    try {
      final url = await widget.logoRepository!.signedUrl(path);
      if (mounted) setState(() => schoolLogoUrl = url);
    } catch (_) {
      // The logo is optional and no signed URL is logged or persisted.
    }
  }

  Future<void> _saveSettings(DemoDashboardPreferences value) async {
    setState(() => settings = value);
    try {
      await preferences?.save(value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Dashboard layout saved on screen. '
          'Account sync is unavailable; retry later.')));
    }
  }

  String get name {
    final full = widget.draft.contactName?.trim();
    if (full == null || full.isEmpty) return 'School owner';
    return full.split(RegExp(r'\s+')).first;
  }
  String get initials {
    final full = widget.draft.contactName?.trim();
    if (full == null || full.isEmpty) return 'SO';
    final parts = full.split(RegExp(r'\s+'));
    return (parts.first[0] +
      (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  void _unavailable(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(title + ' is not available in demo preview. '
        'It will open after school provisioning and permissions are implemented.')));
  }

  void _handleProfileAction(String value) {
    switch(value) {
      case 'school':
      case 'logo':
        widget.onEditDetails?.call('identity');
      case 'contact':
        widget.onEditDetails?.call('contact');
      case 'location':
        widget.onEditDetails?.call('location');
      case 'academic':
        widget.onEditDetails?.call('academics');
      case 'back':
        widget.onBack();
    }
  }

  Widget _profile() => PopupMenuButton<String>(
    key: const Key('dashboard-profile-menu'),
    tooltip: 'Account and school profile',
    onSelected: _handleProfileAction,
    itemBuilder: (_) => const [
      PopupMenuItem(value:'school',child:ListTile(
        leading:Icon(Icons.edit_outlined),
        title:Text('Edit school details'))),
      PopupMenuItem(value:'logo',child:ListTile(
        leading:Icon(Icons.image_outlined),
        title:Text('Change school logo'))),
      PopupMenuItem(value:'contact',child:ListTile(
        leading:Icon(Icons.contact_mail_outlined),
        title:Text('Edit school contact'))),
      PopupMenuItem(value:'location',child:ListTile(
        leading:Icon(Icons.location_on_outlined),
        title:Text('Edit location'))),
      PopupMenuItem(value:'academic',child:ListTile(
        leading:Icon(Icons.school_outlined),
        title:Text('Edit academics'))),
      PopupMenuDivider(),
      PopupMenuItem(value:'back',child:ListTile(
        leading:Icon(Icons.arrow_back),
        title:Text('Back to payment'))),
    ],
    child: CircleAvatar(
      radius:19,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(initials,style:TextStyle(fontSize:12,
        fontWeight:FontWeight.w800,
        color:Theme.of(context).colorScheme.primary)),
    ),
  );

  void _openSearch() {
    String query = '';
    final names = <String>[
      ...recentDemoAdmissions.map((e) => e.name),
      ...recentDemoApprovals.map((e) => e.name),
      ...actions.map((e) => e.$2),
      'School setup', 'Subscription plan', 'Approvals',
    ].toSet().toList()..sort();
    showDialog<void>(
      context:context,
      builder:(context)=>StatefulBuilder(builder:(context,setDialog) {
        final matches=names.where((s) =>
          s.toLowerCase().contains(query.toLowerCase())).take(10).toList();
        return AlertDialog(
          title: const Text('Global search · Demo data'),
          content: SizedBox(
            width: 480,
            height: 330,
            child: Column(children: [
              TextField(
                key: const Key('dashboard-search-input'),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText:'Search students, staff, classes or actions...',
                  prefixIcon:Icon(Icons.search)),
                onChanged:(s)=>setDialog(()=>query=s),
              ),
              const SizedBox(height:12),
              Expanded(child:ListView(
                children:[
                  for(final name in matches)
                    ListTile(title:Text(name),
                      subtitle:const Text('Illustrative search result'),
                      onTap:(){
                        Navigator.pop(context);
                        _unavailable(name);
                      }),
                  if (matches.isEmpty)
                    const Padding(padding:EdgeInsets.all(18),
                      child:Text('No demo result matches your search.')),
                ],
              )),
            ]),
          ),
          actions:[TextButton(
            onPressed:()=>Navigator.pop(context),
            child:const Text('Close'))],
        );
      }),
    );
  }

  Widget _searchBar({bool mobile=false}) {
    final colors=Theme.of(context).colorScheme;
    return InkWell(
      key: const Key('dashboard-global-search'),
      onTap:_openSearch,
      borderRadius:BorderRadius.circular(12),
      child:Container(
        constraints: BoxConstraints(minHeight:46,
          maxWidth:mobile ? double.infinity : 430),
        padding:const EdgeInsets.symmetric(horizontal:14),
        decoration:BoxDecoration(
          border:Border.all(color:colors.outlineVariant),
          color:colors.surface.withValues(alpha:.45),
          borderRadius:BorderRadius.circular(12)),
        child:Row(children:[
          const Icon(Icons.search,size:19),
          const SizedBox(width:11),
          Expanded(child:Text('Search students, staff, classes...',
            overflow:TextOverflow.ellipsis,
            style:TextStyle(fontSize:12,
              color:colors.onSurfaceVariant))),
          if (!mobile) Text('Ctrl K',style:TextStyle(fontSize:10,
              color:colors.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _appLogo({double size=38}) {
    if (schoolLogoUrl != null) {
      return ClipRRect(borderRadius:BorderRadius.circular(9),
        child:Image.network(schoolLogoUrl!,width:size,height:size,
          fit:BoxFit.cover,
          errorBuilder:(_,__,___) => Image.asset(
            'assets/app_logo/app_icon.jpeg',width:size,height:size)));
    }
    return ClipRRect(borderRadius:BorderRadius.circular(8),
      child:Image.asset('assets/app_logo/app_icon.jpeg',
        width:size,height:size,fit:BoxFit.cover));
  }

  Widget _topBar(bool mobile) {
    final colors=Theme.of(context).colorScheme;
    return Container(
      height:70,
      padding:const EdgeInsets.symmetric(horizontal:18),
      decoration:BoxDecoration(
        color:colors.surface.withValues(alpha:.6),
        border:Border(bottom:BorderSide(color:colors.outlineVariant))),
      child:Row(children:[
        if (mobile) ...[
          IconButton(
            key:const Key('dashboard-open-navigation'),
            onPressed:()=>_openNavSheet(),
            icon:const Icon(Icons.menu),
            tooltip:'Open navigation'),
          _appLogo(size:34),
          const SizedBox(width:8),
          const Expanded(child:Text('Pohantoon AI',
            overflow:TextOverflow.ellipsis,
            style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))),
        ] else ...[
          Expanded(child:Align(
            alignment:Alignment.centerLeft,
            child:_searchBar())),
        ],
        IconButton(
          key:const Key('dashboard-notifications'),
          tooltip:'Notifications (demo)',
          onPressed:()=>_unavailable('Notifications'),
          icon:const Icon(Icons.notifications_none_outlined)),
        AppearanceSettingsButton(
          mode:widget.themeMode,onChanged:widget.onThemeChanged),
        const SizedBox(width:6),
        _profile(),
      ]),
    );
  }

  void _openNavSheet() {
    showModalBottomSheet<void>(context:context,showDragHandle:true,
      builder:(ctx)=>SafeArea(child:ListView(
        shrinkWrap:true,
        children:[
          const ListTile(title:Text('School Workspace'),
            subtitle:Text('Demo navigation only')),
          for (final item in navigation)
            ListTile(
              leading:Icon(item.$2),
              title:Text(item.$1),
              onTap:(){
                Navigator.pop(ctx);
                if(item.$1!='Dashboard')_unavailable(item.$1);
              }),
        ],
      )));
  }

  static const navigation = <(String,IconData)>[
    ('Dashboard',Icons.dashboard_outlined),
    ('Students',Icons.people_outline),
    ('Admissions',Icons.note_add_outlined),
    ('Staff',Icons.group_add_outlined),
    ('Academics',Icons.school_outlined),
    ('Attendance',Icons.calendar_today_outlined),
    ('Fees & Finance',Icons.account_balance_wallet_outlined),
    ('Communication',Icons.chat_bubble_outline),
    ('Reports & Analytics',Icons.analytics_outlined),
    ('Settings',Icons.settings_outlined),
  ];

  Widget _sideBar({bool compact=false}) {
    final colors=Theme.of(context).colorScheme;
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Container(
      width:compact ? 74 : 245,
      decoration:BoxDecoration(
        color:dark ? const Color(0xFF0D2730) : Colors.white,
        border:Border(right:BorderSide(color:colors.outlineVariant))),
      child:Column(children:[
        Padding(padding:const EdgeInsets.symmetric(
          horizontal:13,vertical:22),
          child:Row(children:[
            _appLogo(size:41),
            if(!compact)...[
              const SizedBox(width:9),
              const Expanded(child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('Pohantoon AI',style:TextStyle(
                    fontSize:16,fontWeight:FontWeight.w800)),
                  Text('School Management',
                    style:TextStyle(fontSize:10)),
                ])),
            ],
          ])),
        if(!compact)
          ListTile(
            leading:const Icon(Icons.apartment_outlined),
            title:Text(widget.draft.schoolName ?? 'School workspace',
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(
                fontSize:12,fontWeight:FontWeight.w800)),
            subtitle:const Text('Test workspace',
              style:TextStyle(fontSize:10)),
          ),
        const SizedBox(height:12),
        Expanded(child:ListView(children:[
          for(final item in navigation)
            Padding(padding:const EdgeInsets.symmetric(
              horizontal:compact ? 8 : 13,vertical:3),
              child:Tooltip(message:item.$1,
                child:ListTile(
                  key:Key('dashboard-nav-' +
                    item.$1.toLowerCase().replaceAll(' ','-')),
                  shape:RoundedRectangleBorder(
                    borderRadius:BorderRadius.circular(11)),
                  selected:item.$1=='Dashboard',
                  selectedTileColor:colors.primary,
                  selectedColor:colors.onPrimary,
                  leading:Icon(item.$2,size:20),
                  title:compact ? null : Text(item.$1,style:const TextStyle(
                    fontSize:12,fontWeight:FontWeight.w700)),
                  dense:true,
                  contentPadding:EdgeInsets.symmetric(
                    horizontal:compact?16:11),
                  onTap:()=>item.$1=='Dashboard'
                    ? null : _unavailable(item.$1),
                )),
            ),
        ])),
        if(!compact)
          Padding(padding:const EdgeInsets.all(13),
            child:Container(
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(
                color:colors.primaryContainer.withValues(alpha:.5),
                borderRadius:BorderRadius.circular(11)),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(widget.plan.name,
                    style:const TextStyle(
                      fontWeight:FontWeight.w800,fontSize:12)),
                  const Text('Unpaid development preview',
                    style:TextStyle(fontSize:11)),
                ],
              )),
          ),
      ]),
    );
  }

  Widget _panel(Widget content,{double? height,Key? key}) {
    final colors=Theme.of(context).colorScheme;
    return Container(
      key:key,
      constraints:height == null ? null
        : BoxConstraints(minHeight:height),
      padding:const EdgeInsets.all(18),
      decoration:BoxDecoration(
        color:colors.surface,
        border:Border.all(color:colors.outlineVariant),
        borderRadius:BorderRadius.circular(17),
        boxShadow:Theme.of(context).brightness==Brightness.dark
          ? null : [BoxShadow(
              blurRadius:12,
              color:Colors.black.withValues(alpha:.025),
              offset:const Offset(0,4))]),
      child:content,
    );
  }

  Widget _metric(String title,String number,String note,
      IconData icon,{bool growth=false}) {
    final colors=Theme.of(context).colorScheme;
    return _panel(Column(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Container(padding:const EdgeInsets.all(9),
          decoration:BoxDecoration(
            color:colors.primaryContainer,
            borderRadius:BorderRadius.circular(11)),
          child:Icon(icon,color:colors.primary,size:21)),
        const SizedBox(height:10),
        Text(title,style:TextStyle(
          fontSize:12,fontWeight:FontWeight.w700,
          color:colors.onSurfaceVariant)),
        const SizedBox(height:4),
        Text(number,style:const TextStyle(
          fontWeight:FontWeight.w900,fontSize:27)),
        const SizedBox(height:4),
        Text(note,style:TextStyle(fontSize:11,
          color:growth?colors.primary:colors.onSurfaceVariant)),
      ],
    ),height:143);
  }

  Widget _metrics() => LayoutBuilder(builder:(context,bounds) {
    final columns=bounds.maxWidth >= 1220 ? 4
      : bounds.maxWidth >= 520 ? 2 : 2;
    final metrics=[
      _metric('Total students','1,248','↑ +2.6% vs last month',
        Icons.people_outline,growth:true),
      _metric('Total staff','86','↑ +1.2% vs last month',
        Icons.group_add_outlined,growth:true),
      _metric('Classes','24','6 grade levels',Icons.school_outlined),
      _metric('Campuses','3','5 available on selected plan',
        Icons.apartment_outlined),
    ];
    return GridView.builder(
      shrinkWrap:true,
      physics:const NeverScrollableScrollPhysics(),
      itemCount:metrics.length,
      gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:columns,
        crossAxisSpacing:13,mainAxisSpacing:13,
        mainAxisExtent:179),
      itemBuilder:(_,i)=>metrics[i],
    );
  });

  Widget _attendance() {
    final colors=Theme.of(context).colorScheme;
    return _panel(Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        const Text('Attendance overview',
          style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
        const SizedBox(height:5),
        Text('Today’s student presence · demo',
          style:TextStyle(fontSize:12,
            color:colors.onSurfaceVariant)),
        const SizedBox(height:18),
        Row(children:[
          SizedBox(width:144,height:144,
            child:Stack(alignment:Alignment.center,children:[
              CustomPaint(
                key:const Key('dashboard-attendance-donut'),
                size:const Size(140,140),
                painter:_AttendanceDonut(colors.primary)),
              Column(mainAxisSize:MainAxisSize.min,children:[
                const Text('94.6%',
                  style:TextStyle(
                    fontSize:24,fontWeight:FontWeight.w900)),
                Text('Present today',style:TextStyle(
                  fontSize:10,color:colors.onSurfaceVariant)),
              ]),
            ]),
          ),
          const SizedBox(width:15),
          Expanded(child:Column(children:[
            _legend('Present','1,181',colors.primary),
            _legend('Absent','49',const Color(0xFFE9A85B)),
            _legend('Excused','18',const Color(0xFF70A5F6)),
          ])),
        ]),
        const SizedBox(height:19),
        Container(
          padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(10),
            color:colors.primaryContainer.withValues(alpha:.48)),
          child:const Text('✓ Demo attendance is tracking above 90%',
            style:TextStyle(fontSize:11)),
        ),
      ],
    ));
  }

  Widget _legend(String label,String value,Color color) {
    final colors=Theme.of(context).colorScheme;
    return Padding(
      padding:const EdgeInsets.symmetric(vertical:9),
      child:Row(children:[
        CircleAvatar(radius:4,backgroundColor:color),
        const SizedBox(width:8),
        Expanded(child:Text(label,style:TextStyle(
          fontSize:11,color:colors.onSurfaceVariant))),
        Text(value,style:const TextStyle(
          fontSize:11,fontWeight:FontWeight.w800)),
      ]),
    );
  }

  Widget _fees() {
    final colors=Theme.of(context).colorScheme;
    return _panel(Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[
          const Expanded(child:Text('Fees this month',
            style:TextStyle(fontSize:17,
              fontWeight:FontWeight.w800))),
          Icon(Icons.account_balance_wallet_outlined,
            color:colors.primary),
        ]),
        const SizedBox(height:5),
        Text('Demo billing overview · AFN',
          style:TextStyle(fontSize:11,
            color:colors.onSurfaceVariant)),
        const SizedBox(height:24),
        Row(children:[
          Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Collected',style:TextStyle(fontSize:11)),
              const SizedBox(height:5),
              const Text('AFN 842K',style:TextStyle(
                fontSize:19,fontWeight:FontWeight.w800)),
          ])),
          Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
            const Text('Outstanding',style:TextStyle(fontSize:11)),
            const SizedBox(height:5),
            const Text('AFN 186K',style:TextStyle(
              fontSize:19,fontWeight:FontWeight.w800)),
          ]),
        ]),
        const SizedBox(height:18),
        ClipRRect(borderRadius:BorderRadius.circular(20),
          child:LinearProgressIndicator(
            value:.819,minHeight:10,
            color:colors.primary,
            backgroundColor:colors.surfaceContainerHighest)),
        const SizedBox(height:9),
        Row(children:[
          Text('81.9% collected · demo',
            style:TextStyle(
              fontSize:11,fontWeight:FontWeight.w700,
              color:colors.primary)),
          const Spacer(),
          TextButton(
            onPressed:()=>_unavailable('Fees & Finance'),
            child:const Text('View finance →')),
        ]),
      ],
    ),height:240);
  }

  Future<void> _customizeActions() async {
    final chosen=settings.quickActions.toSet();
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(sheetContext)=>StatefulBuilder(
        builder:(ctx,setSheet)=>SafeArea(child:Padding(
          padding:const EdgeInsets.fromLTRB(20,8,20,25),
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              Text('Customize quick actions',
                style:Theme.of(ctx).textTheme.titleLarge),
              const Text('Choose which demo shortcuts appear on the dashboard.'),
              const SizedBox(height:10),
              for(final action in actions)
                CheckboxListTile(
                  dense:true,
                  value:chosen.contains(action.$1),
                  title:Text(action.$2),
                  onChanged:(v)=>setSheet(() {
                    if(v==true && chosen.length<8) {
                      chosen.add(action.$1);
                    } else if(v==false) {
                      chosen.remove(action.$1);
                    }
                  }),
                ),
              const SizedBox(height:10),
              FilledButton(
                onPressed:(){
                  Navigator.pop(sheetContext);
                  _saveSettings(DemoDashboardPreferences(
                    academicYearLabel:settings.academicYearLabel,
                    selectedChart:settings.selectedChart,
                    quickActions:chosen.toList(),
                  ));
                },
                child:const Text('Save shortcuts')),
            ],
          ),
        )),
      ),
    );
  }

  Widget _quickActions() {
    final colors=Theme.of(context).colorScheme;
    final chosen=actions.where((a)=>settings.quickActions.contains(a.$1))
      .toList();
    return _panel(Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Row(children:[
          const Expanded(child:Text('Quick actions',
            style:TextStyle(fontSize:16,
              fontWeight:FontWeight.w800))),
          TextButton(
            key:const Key('dashboard-customize-actions'),
            onPressed:_customizeActions,
            child:const Text('Customize ›')),
        ]),
        Text('Frequently used school tasks',
          style:TextStyle(
            fontSize:11,color:colors.onSurfaceVariant)),
        const SizedBox(height:15),
        if(chosen.isEmpty)
          const Padding(padding:EdgeInsets.all(22),
            child:Text('No shortcuts selected. Choose Customize.'))
        else LayoutBuilder(builder:(context,limits){
          final cols=limits.maxWidth < 360 ? 2 : 3;
          return GridView.builder(
            shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
            itemCount:chosen.length,
            gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:cols,
              crossAxisSpacing:8,mainAxisSpacing:8,mainAxisExtent:95),
            itemBuilder:(context,i) {
              final action=chosen[i];
              return InkWell(
                key:Key('dashboard-quick-' + action.$1),
                borderRadius:BorderRadius.circular(11),
                onTap:()=>_unavailable(action.$2),
                child:Container(
                  decoration:BoxDecoration(
                    color:colors.surfaceContainerLowest,
                    border:Border.all(color:colors.outlineVariant),
                    borderRadius:BorderRadius.circular(11)),
                  child:Column(
                    mainAxisAlignment:MainAxisAlignment.center,
                    children:[
                      Icon(action.$3,size:23,color:colors.primary),
                      const SizedBox(height:9),
                      Text(action.$2,
                        textAlign:TextAlign.center,
                        style:const TextStyle(
                          fontSize:11,fontWeight:FontWeight.w800)),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ],
    ));
  }

  Widget _analyticsRow() => LayoutBuilder(builder:(context,bounds) {
    final trend=_panel(
      RotatingAnalyticsPanel(
        initialChart:settings.selectedChart,
        onChartSelected:(chart) => _saveSettings(
          DemoDashboardPreferences(
            selectedChart:chart,
            academicYearLabel:settings.academicYearLabel,
            quickActions:settings.quickActions,
          )),
      ),key:const Key('dashboard-analytics-panel'));
    final attendance=_attendance();
    if(bounds.maxWidth>=860) return Row(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Expanded(flex:6,child:trend),
        const SizedBox(width:15),
        Expanded(flex:4,child:attendance),
      ],
    );
    return Column(children:[
      trend,const SizedBox(height:15),attendance,
    ]);
  });

  Widget _activityRow() => LayoutBuilder(builder:(context,bounds) {
    final quick=_quickActions();
    Widget recent(String title,String key,List<DemoActivity> values) =>
      SizedBox(height:355,
        child:_panel(RotatingActivityPanel(
          title:title,panelKey:key,entries:values)));
    final admission=recent('Recent admissions','admissions',
      recentDemoAdmissions);
    final approval=recent('Recent approvals','approvals',
      recentDemoApprovals);
    if(bounds.maxWidth>=1130) return Row(
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Expanded(child:quick),const SizedBox(width:13),
        Expanded(child:admission),const SizedBox(width:13),
        Expanded(child:approval),
      ],
    );
    if(bounds.maxWidth>=690) return Column(children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:quick),const SizedBox(width:13),
        Expanded(child:admission),
      ]),
      const SizedBox(height:15),approval,
    ]);
    return Column(children:[
      quick,const SizedBox(height:14),
      admission,const SizedBox(height:14),
      approval,
    ]);
  });

  Widget _demoWarning() {
    final colors=Theme.of(context).colorScheme;
    return Container(
      key:const Key('dashboard-not-provisioned-warning'),
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(
        color:colors.primaryContainer.withValues(alpha:.37),
        borderRadius:BorderRadius.circular(11)),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(Icons.shield_outlined,size:20,color:colors.primary),
        const SizedBox(width:10),
        const Expanded(child:Text(
          'DEMO DATA ONLY. Payment skipped for testing. '
          'No subscription activated, school tenant created, '
          'or access to real school records granted.',
          style:TextStyle(fontSize:11,height:1.5))),
      ]),
    );
  }

  Widget _toolbar() {
    final colors=Theme.of(context).colorScheme;
    final now=DateTime.now();
    const months=['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final date=now.day.toString()+' '+months[now.month-1]+' '+
      now.year.toString();
    return Wrap(spacing:9,runSpacing:9,crossAxisAlignment:WrapCrossAlignment.center,
      children:[
        Chip(
          key:const Key('dashboard-demo-label'),
          label:const Text('DEMO DATA',style:TextStyle(
            fontSize:11,fontWeight:FontWeight.w800)),
          backgroundColor:colors.tertiaryContainer),
        Chip(
          avatar:const Icon(Icons.calendar_month_outlined,size:16),
          label:Text(date,style:const TextStyle(fontSize:11))),
        DropdownButton<String>(
          key:const Key('dashboard-academic-year'),
          value:['2026–27','2025–26','2027–28'].contains(
              settings.academicYearLabel)
            ? settings.academicYearLabel : '2026–27',
          items:const [
            DropdownMenuItem(value:'2025–26',
              child:Text('Academic Year: 2025–26')),
            DropdownMenuItem(value:'2026–27',
              child:Text('Academic Year: 2026–27')),
            DropdownMenuItem(value:'2027–28',
              child:Text('Academic Year: 2027–28')),
          ],
          onChanged:(value) {
            if(value==null)return;
            _saveSettings(DemoDashboardPreferences(
              academicYearLabel:value,
              selectedChart:settings.selectedChart,
              quickActions:settings.quickActions,
            ));
          },
        ),
      ],
    );
  }

  Widget _dashboardBody(bool mobile) {
    final colors=Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key:const Key('dashboard-main-scroll'),
      padding:EdgeInsets.fromLTRB(mobile?17:25,20,mobile?17:25,35),
      child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:1450),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            if(mobile) ...[_searchBar(mobile:true),
              const SizedBox(height:18)],
            if(!mobile) Text('Workspace   ›   Dashboard',
              style:TextStyle(fontSize:11,
                color:colors.onSurfaceVariant)),
            const SizedBox(height:8),
            Text('Good morning, '+name+' 👋',
              key:const Key('dashboard-test-preview-title'),
              style:Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight:FontWeight.w900,
                  fontSize:mobile?24:27)),
            const SizedBox(height:7),
            Text("Here's what's happening at your school today.",
              style:TextStyle(fontSize:13,
                color:colors.onSurfaceVariant)),
            const SizedBox(height:12),
            _toolbar(),
            const SizedBox(height:17),
            _demoWarning(),
            const SizedBox(height:17),
            _metrics(),
            const SizedBox(height:16),
            _analyticsRow(),
            const SizedBox(height:17),
            _activityRow(),
            const SizedBox(height:17),
            _fees(),
            const SizedBox(height:15),
            Row(children:[
              Expanded(child:Text(
                'Illustrative dashboards — not connected to live '
                'school data or permissions.',
                style:TextStyle(fontSize:11,
                  color:colors.onSurfaceVariant))),
              TextButton(
                key:const Key('dashboard-back-to-payment'),
                onPressed:widget.onBack,
                child:const Text('Back to payment')),
            ]),
          ],
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark=Theme.of(context).brightness==Brightness.dark;
    return LayoutBuilder(builder:(context,bounds){
      final mobile=bounds.maxWidth<720;
      final compact=bounds.maxWidth>=720 && bounds.maxWidth<1160;
      return Scaffold(
        backgroundColor:dark?const Color(0xFF071B23)
          :const Color(0xFFF3F7FB),
        body:SafeArea(child:Row(children:[
          if(!mobile)_sideBar(compact:compact),
          Expanded(child:Column(children:[
            _topBar(mobile),
            Expanded(child:_dashboardBody(mobile)),
          ])),
        ])),
        bottomNavigationBar:mobile?NavigationBar(
          selectedIndex:0,
          onDestinationSelected:(i) {
            if(i==3) {
              _openNavSheet();
            } else if(i!=0) {
              _unavailable(i==1 ? 'Students' : 'Admissions');
            }
          },
          destinations:const [
            NavigationDestination(
              icon:Icon(Icons.home_outlined),
              selectedIcon:Icon(Icons.home),label:'Home'),
            NavigationDestination(
              icon:Icon(Icons.people_outline),label:'Students'),
            NavigationDestination(
              icon:Icon(Icons.note_add_outlined),label:'Admissions'),
            NavigationDestination(
              icon:Icon(Icons.more_horiz),label:'More'),
          ],
        ):null,
      );
    });
  }
}

class _AttendanceDonut extends CustomPainter {
  const _AttendanceDonut(this.accent);
  final Color accent;
  @override
  void paint(Canvas canvas,Size size) {
    final rect=Rect.fromLTWH(8,8,size.width-16,size.height-16);
    final stroke=Paint()
      ..strokeWidth=15
      ..strokeCap=StrokeCap.butt
      ..style=PaintingStyle.stroke;
    double begin=-math.pi/2;
    for(final piece in [
      (0.946,accent),
      (0.039,const Color(0xFFE9A85B)),
      (0.015,const Color(0xFF70A5F6)),
    ]) {
      final sweep=2*math.pi*piece.$1;
      canvas.drawArc(rect,begin,sweep,false,stroke..color=piece.$2);
      begin+=sweep;
    }
  }
  @override
  bool shouldRepaint(covariant _AttendanceDonut old)=>
    old.accent!=accent;
}
