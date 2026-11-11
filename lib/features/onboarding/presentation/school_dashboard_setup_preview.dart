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

