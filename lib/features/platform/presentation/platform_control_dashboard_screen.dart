import 'package:flutter/material.dart';

import '../data/platform_monitoring_repository.dart';
import '../../provisioning/data/school_activation_repository.dart';
import '../../provisioning/presentation/school_provisioning_operator_screen.dart';

/// Real PohantoonAI platform control center.
/// No mock data, no direct Auth table access, no admin service key in Flutter.
/// Every reporting RPC separately verifies a current platform role and AAL2.
class PlatformControlDashboardScreen extends StatefulWidget {
  const PlatformControlDashboardScreen({
    super.key,
    required this.monitoring,
    required this.activation,
    required this.onSignOut,
  });

  final PlatformMonitoringRepository monitoring;
  final SchoolActivationRepository activation;
  final VoidCallback onSignOut;

  @override
  State<PlatformControlDashboardScreen> createState() =>
    _PlatformControlDashboardScreenState();
}

class _PlatformControlDashboardScreenState
    extends State<PlatformControlDashboardScreen> {
  static const _pageSize=50;
  static const _sectionTitles=[
    'Overview','Requests','Schools','Accounts','Security',
  ];
  static const _sectionIcons=[
    Icons.dashboard_outlined,
    Icons.fact_check_outlined,
    Icons.account_balance_outlined,
    Icons.people_outline,
    Icons.shield_outlined,
  ];

  int tab=0;
  int schoolOffset=0;
  int accountOffset=0;
  int generation=0;
  PlatformSummary? summary;
  List<PlatformTrend> trends=const [];
  List<PlatformSchool> schools=const [];
  List<PlatformSchoolAccount> accounts=const [];
  List<PlatformReviewEvent> history=const [];
  String schoolQuery='';
  String accountQuery='';
  bool flaggedOnly=false;
  bool overviewLoading=true;
  bool schoolsLoading=false;
  bool accountsLoading=false;
  bool securityLoading=false;
  String? overviewError;
  String? schoolsError;
  String? accountsError;
  String? securityError;

  @override
  void initState(){
    super.initState();
    _refreshOverview();
  }

  @override
  void dispose(){
    ++generation;
    super.dispose();
  }

  Future<void> _refreshOverview() async {
    final request=++generation;
    setState((){
      overviewLoading=true;
      overviewError=null;
      summary=null;
      trends=const [];
    });
    try {
      final result=await widget.monitoring.overview();
      final monthly=await widget.monitoring.trends();
      if(!mounted||request!=generation)return;
      setState((){
        summary=result;
        trends=monthly;
        overviewLoading=false;
      });
    }catch(_){
      if(!mounted||request!=generation)return;
      setState((){
        overviewLoading=false;
        overviewError='Live platform information is unavailable. '
          'Check your platform role, MFA and network connection.';
      });
    }
  }

  Future<void> _refreshSchools() async {
    setState((){
      schoolsLoading=true;
      schoolsError=null;
      schools=const [];
    });
    try {
      final result=await widget.monitoring.schools(
        offset:schoolOffset,limit:_pageSize);
      if(!mounted||tab!=2)return;
      setState((){
        schools=result;
        schoolsLoading=false;
      });
    }catch(_){
      if(mounted&&tab==2)setState((){
        schoolsLoading=false;
        schoolsError='Unable to load the authorized school directory.';
      });
    }
  }

  Future<void> _refreshAccounts() async {
    setState((){
      accountsLoading=true;
      accountsError=null;
      accounts=const [];
    });
    try {
      final result=await widget.monitoring.accounts(
        offset:accountOffset,limit:_pageSize);
      if(!mounted||tab!=3)return;
      setState((){
        accounts=result;
        accountsLoading=false;
      });
    }catch(_){
      if(mounted&&tab==3)setState((){
        accountsLoading=false;
        accountsError='Unable to load school account security information.';
      });
    }
  }

  Future<void> _refreshSecurity() async {
    setState((){
      securityLoading=true;securityError=null;history=const [];
    });
    try {
      final result=await widget.monitoring.history();
      if(!mounted||tab!=4)return;
      setState((){
        history=result;securityLoading=false;
      });
    }catch(_){
      if(mounted&&tab==4)setState((){
        securityLoading=false;
        securityError='Unable to load the latest approval history.';
      });
    }
  }

  void _selectTab(int index) {
    if(tab==index)return;
    setState((){
      tab=index;
      // Immediately erase previous account-directory data on navigation.
      if(index!=3)accounts=const [];
      if(index!=2)schools=const [];
    });
    if(index==0) {
      _refreshOverview();
    }else if(index==2){
      _refreshSchools();
    }else if(index==3){
      _refreshAccounts();
    }else if(index==4){
      _refreshOverview();
      _refreshSecurity();
    }
  }

  void _refreshCurrent() {
    if(tab==0||tab==4)_refreshOverview();
    if(tab==2)_refreshSchools();
    if(tab==3)_refreshAccounts();
    if(tab==4)_refreshSecurity();
    // Requests has its own refresh button and reloads on tab entry.
  }

  Future<void> _pageSchools(int direction) async {
    setState(()=>schoolOffset=(schoolOffset+direction*_pageSize)
      .clamp(0,100000).toInt());
    await _refreshSchools();
  }

  Future<void> _pageAccounts(int direction) async {
    setState(()=>accountOffset=(accountOffset+direction*_pageSize)
      .clamp(0,100000).toInt());
    await _refreshAccounts();
  }

  @override
  Widget build(BuildContext context){
    return LayoutBuilder(builder:(context,layout){
      final wide=layout.maxWidth>=860;
      return Scaffold(
        appBar:AppBar(
          title:Row(mainAxisSize:MainAxisSize.min,children:[
            ClipRRect(
              borderRadius:BorderRadius.circular(7),
              child:Image.asset(
                'assets/app_logo/app_icon.jpeg',
                width:30,height:30,fit:BoxFit.cover),
            ),
            const SizedBox(width:10),
            const Flexible(child:Text('PohantoonAI • Platform Control',
              overflow:TextOverflow.ellipsis)),
          ]),
          actions:[
            IconButton(
              key:const Key('platform-refresh'),
              tooltip:'Refresh live information',
              onPressed:_refreshCurrent,
              icon:const Icon(Icons.refresh_outlined)),
            IconButton(
              tooltip:'Sign out',onPressed:widget.onSignOut,
              icon:const Icon(Icons.logout_outlined)),
          ],
        ),
        body:SafeArea(child:Row(children:[
          if(wide)NavigationRail(
            key:const Key('platform-navigation'),
            selectedIndex:tab,
            labelType:NavigationRailLabelType.all,
            destinations:[
              for(var i=0;i<_sectionTitles.length;i++)
                NavigationRailDestination(
                  icon:Icon(_sectionIcons[i]),
                  label:Text(_sectionTitles[i])),
            ],
            onDestinationSelected:_selectTab,
          ),
          Expanded(child:tab==1
            ? SchoolProvisioningOperatorScreen(
                key:const Key('platform-requests'),
                embedded:true,
                repository:widget.activation,
                onReviewCompleted:(){
                  _refreshOverview();
                },
                onSignOut:widget.onSignOut,
              )
            : Center(child:ConstrainedBox(
                constraints:const BoxConstraints(maxWidth:1270),
                child:_selectedContent(),
              )),
          ),
        ])),
        bottomNavigationBar:wide?null:NavigationBar(
          key:const Key('platform-mobile-navigation'),
          selectedIndex:tab,
          destinations:[
            for(var i=0;i<_sectionTitles.length;i++)
              NavigationDestination(
                icon:Icon(_sectionIcons[i]),
                label:_sectionTitles[i],
              ),
          ],
          onDestinationSelected:_selectTab,
        ),
      );
    });
  }

  Widget _selectedContent() {
    if(tab==2)return _schoolDirectory();
    if(tab==3)return _accountsDirectory();
    if(tab==4)return _security();
    return _overview();
  }

  Widget _header(String title,String subtitle,{Widget? trailing}) {
    final colors=Theme.of(context).colorScheme;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text(title,
          style:Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight:FontWeight.w800))),
        if(trailing!=null)trailing,
      ]),
      const SizedBox(height:6),
      Text(subtitle,style:TextStyle(color:colors.onSurfaceVariant)),
      const SizedBox(height:19),
    ]);
  }

  Widget _metric(String label,int number,IconData icon,{String? detail}) {
    final theme=Theme.of(context);
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(17),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          mainAxisAlignment:MainAxisAlignment.spaceBetween,
          children:[
            Icon(icon,size:26,color:theme.colorScheme.primary),
            Text('$number',style:theme.textTheme.headlineMedium?.copyWith(
              fontWeight:FontWeight.w900)),
            Text(label,maxLines:2,overflow:TextOverflow.ellipsis,
              style:theme.textTheme.bodyMedium?.copyWith(
                fontWeight:FontWeight.w600)),
            if(detail!=null)Text(detail,maxLines:2,
              style:theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _metricGrid(List<Widget> items) => LayoutBuilder(
    builder:(context,layout)=>GridView.count(
      crossAxisCount:layout.maxWidth<520?2:
        layout.maxWidth<980?3:4,
      crossAxisSpacing:11,
      mainAxisSpacing:11,
      childAspectRatio:layout.maxWidth<520?1.05:1.4,
      physics:const NeverScrollableScrollPhysics(),
      shrinkWrap:true,
      children:items,
    ),
  );

  Widget _failure(String message,VoidCallback retry) => Card(
    child:Padding(padding:const EdgeInsets.all(25),
      child:Column(children:[
        const Icon(Icons.lock_outline,size:36),
        const SizedBox(height:8),
        Text(message,textAlign:TextAlign.center),
        const SizedBox(height:10),
        FilledButton(onPressed:retry,child:const Text('Retry')),
      ]),
    ),
  );

  Widget _empty(String label,{IconData icon=Icons.inbox_outlined}) => Card(
    child:Padding(padding:const EdgeInsets.all(38),
      child:Column(children:[
        Icon(icon,size:35),
        const SizedBox(height:12),
        Text(label,textAlign:TextAlign.center),
      ]),
    ),
  );

  Widget _overview() => ListView(
    key:const Key('platform-overview'),
    padding:const EdgeInsets.fromLTRB(18,20,18,36),
    children:[
      _header('Platform overview',
        'Live school operations • Authorised organizations only'),
      if(overviewLoading)const Center(child:Padding(
        padding:EdgeInsets.all(35),child:CircularProgressIndicator()))
      else if(overviewError!=null)_failure(overviewError!,_refreshOverview)
      else if(summary!=null)...[
        _metricGrid([
          _metric('Provisioned schools',summary!.schools,
            Icons.account_balance_outlined),
          _metric('Active schools',summary!.activeSchools,
            Icons.verified_outlined),
          _metric('Waiting for review',summary!.pendingRequests,
            Icons.pending_actions_outlined),
          _metric('School accounts',summary!.accounts,
            Icons.people_outline),
          _metric('Admitted learners',summary!.admittedStudents,
            Icons.school_outlined),
          _metric('MFA-enrolled accounts',summary!.mfaAccounts,
            Icons.shield_outlined),
          _metric('Requests submitted in 30d',summary!.requestsLast30Days,
            Icons.assignment_outlined),
          _metric('Provisioned applications',summary!.provisionedRequests,
            Icons.fact_check_outlined),
        ]),
        const SizedBox(height:20),
        Card(child:Padding(padding:const EdgeInsets.all(18),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Quick actions',style:TextStyle(
              fontWeight:FontWeight.w800,fontSize:17)),
            const SizedBox(height:12),
            Wrap(spacing:10,runSpacing:10,children:[
              FilledButton.icon(
                key:const Key('platform-review-requests'),
                onPressed:()=>_selectTab(1),
                icon:const Icon(Icons.fact_check_outlined),
                label:const Text('Review school requests')),
              OutlinedButton.icon(
                onPressed:()=>_selectTab(2),
                icon:const Icon(Icons.account_balance_outlined),
                label:const Text('Manage school overview')),
              OutlinedButton.icon(
                onPressed:()=>_selectTab(4),
                icon:const Icon(Icons.shield_outlined),
                label:const Text('Security status')),
            ]),
          ]),
        )),
        const SizedBox(height:18),
        _trends(),
        const SizedBox(height:15),
        _notice('Metrics are calculated from provisioned schools, verified '
          'memberships, real admissions, and submitted requests. '
          'Billing revenue and attendance are intentionally not shown until '
          'those production modules are connected.'),
      ],
    ],
  );

  Widget _trends() {
    final maxValue=trends.fold<int>(1,(previous,row){
      final n=row.requests>row.provisioned?row.requests:row.provisioned;
      return n>previous?n:previous;
    });
    return Card(child:Padding(
      padding:const EdgeInsets.all(18),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('Six-month onboarding trends',
          style:TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
        const SizedBox(height:7),
        const Text('Submitted school requests and completed provisioning'),
        const SizedBox(height:15),
        if(trends.isEmpty)const Text('No historical trend data available.')
        else for(final t in trends)Padding(
          padding:const EdgeInsets.only(bottom:12),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${t.month.year}-${t.month.month.toString().padLeft(2,'0')}'
              ' • ${t.requests} requests · ${t.provisioned} provisioned'),
            const SizedBox(height:5),
            LinearProgressIndicator(value:t.requests/maxValue,minHeight:6),
            const SizedBox(height:3),
            LinearProgressIndicator(value:t.provisioned/maxValue,minHeight:4,
              color:Theme.of(context).colorScheme.secondary),
          ]),
        )),
      ]),
    ));
  }

  Widget _pageButtons(int offset,int count,VoidCallback previous,
      VoidCallback next) => Row(
    mainAxisAlignment:MainAxisAlignment.end,
    children:[
      Text('${offset+1}–${offset+count}'),
      const SizedBox(width:10),
      IconButton(
        tooltip:'Previous page',
        onPressed:offset==0?null:previous,
        icon:const Icon(Icons.chevron_left)),
      IconButton(
        tooltip:'Next page',
        onPressed:count<_pageSize?null:next,
        icon:const Icon(Icons.chevron_right)),
    ],
  );

  Widget _schoolDirectory() {
    final query=schoolQuery.trim().toLowerCase();
    final filtered=schools.where((s)=>
      query.isEmpty||s.name.toLowerCase().contains(query)||
      s.organization.toLowerCase().contains(query)).toList();
    return ListView(
      key:const Key('platform-school-directory'),
      padding:const EdgeInsets.fromLTRB(18,20,18,35),
      children:[
        _header('Schools',
          'Provisioned school directory • No simulated schools'),
        TextField(
          key:const Key('platform-schools-search'),
          onChanged:(v)=>setState(()=>schoolQuery=v),
          decoration:const InputDecoration(
            labelText:'Search schools on this page',
            prefixIcon:Icon(Icons.search),border:OutlineInputBorder()),
        ),
        const SizedBox(height:15),
        if(schoolsLoading)const Center(child:CircularProgressIndicator())
        else if(schoolsError!=null)_failure(schoolsError!,_refreshSchools)
        else if(schools.isEmpty)
          _empty(schoolOffset==0?'No real schools have been provisioned yet.'
            :'No more schools in this directory.',
            icon:Icons.account_balance_outlined)
        else for(final school in filtered)
          Card(child:Padding(padding:const EdgeInsets.all(16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Wrap(spacing:9,runSpacing:5,
                crossAxisAlignment:WrapCrossAlignment.center,
                children:[
                  Text(school.name,style:const TextStyle(
                    fontSize:17,fontWeight:FontWeight.w800)),
                  Chip(label:Text(school.status)),
                  Chip(label:Text(school.activationBasis
                    .replaceAll('_',' '))),
                ]),
              Text(school.organization),
              const SizedBox(height:7),
              Text('Owner: ${school.ownerEmail??'Not available'}'),
              Text('Members: ${school.members}   •   '
                'Admitted: ${school.admitted}   •   '
                'Pending admissions: ${school.pending}'),
              Text('Provisioned record: ${school.createdAt.toLocal()}',
                style:Theme.of(context).textTheme.bodySmall),
            ]),
          )),
        _pageButtons(schoolOffset,schools.length,
          ()=>_pageSchools(-1),()=>_pageSchools(1)),
        const SizedBox(height:8),
        _notice('Only schools tied to your active platform organization '
          'are visible. The search field filters this loaded page only.'),
      ],
    );
  }

  Widget _accountsDirectory() {
    final query=accountQuery.trim().toLowerCase();
    final filtered=accounts.where((a)=>
      (!flaggedOnly||a.needsReview) &&
      (query.isEmpty||a.schoolName.toLowerCase().contains(query)||
        (a.email??'').toLowerCase().contains(query))).toList();
    return ListView(
      key:const Key('platform-account-directory'),
      padding:const EdgeInsets.fromLTRB(18,20,18,35),
      children:[
        _header('School accounts',
          'Role membership and account security • Read-only monitoring'),
        TextField(
          key:const Key('platform-accounts-search'),
          onChanged:(v)=>setState(()=>accountQuery=v),
          decoration:const InputDecoration(
            prefixIcon:Icon(Icons.search),
            labelText:'Search accounts on this page',
            border:OutlineInputBorder()),
        ),
        CheckboxListTile(
          key:const Key('platform-risk-filter'),
          contentPadding:EdgeInsets.zero,
          title:const Text('Show accounts needing review'),
          value:flaggedOnly,
          onChanged:(v)=>setState(()=>flaggedOnly=v??false),
        ),
        const SizedBox(height:8),
        if(accountsLoading)const Center(child:CircularProgressIndicator())
        else if(accountsError!=null)_failure(accountsError!,_refreshAccounts)
        else if(accounts.isEmpty)
          _empty('No provisioned school account memberships found.',
            icon:Icons.people_outline)
        else if(filtered.isEmpty)
          _empty('No accounts match the current filters.')
        else for(final a in filtered)
          Card(child:Padding(padding:const EdgeInsets.all(16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(a.email??'Email unavailable',
                style:const TextStyle(
                  fontSize:16,fontWeight:FontWeight.w800)),
              const SizedBox(height:4),
              Text('${a.schoolName} • ${a.role.replaceAll('_',' ')}'),
              const SizedBox(height:9),
              Wrap(spacing:7,runSpacing:5,children:[
                _statusChip(a.membershipStatus,
                  a.membershipStatus=='active'),
                _statusChip(a.emailVerified?'Email verified':'Email unverified',
                  a.emailVerified),
                _statusChip(a.mfaEnrolled?'MFA enrolled':'MFA missing',
                  a.mfaEnrolled),
                if(a.banned)_statusChip('Account banned',false),
              ]),
              const SizedBox(height:7),
              Text('Last sign-in: ${a.lastSignIn?.toString().split('.').first??'Not recorded'}',
                style:Theme.of(context).textTheme.bodySmall),
            ]),
          )),
        _pageButtons(accountOffset,accounts.length,
          ()=>_pageAccounts(-1),()=>_pageAccounts(1)),
        const SizedBox(height:8),
        _notice('One row per school membership. MFA is based on verified '
          'enrolled factors, not the assurance level of a current session. '
          'No passwords, raw session records, IP addresses or student data '
          'are sent to this screen. Filters search this page only.'),
      ],
    );
  }

  Widget _statusChip(String label,bool healthy) => Chip(
    avatar:Icon(healthy?Icons.check_circle_outline:Icons.warning_amber_outlined,
      size:17,
      color:healthy?Theme.of(context).colorScheme.primary:
        Theme.of(context).colorScheme.error),
    label:Text(label),
  );

  Widget _security() {
    final s=summary;
    return ListView(
      key:const Key('platform-security'),
      padding:const EdgeInsets.fromLTRB(18,20,18,35),
      children:[
        _header('Security monitoring',
          'Account posture and audited approval history'),
        if(overviewLoading)const Center(child:CircularProgressIndicator())
        else if(overviewError!=null)_failure(overviewError!,_refreshOverview)
        else if(s!=null)...[
          _metricGrid([
            _metric('Accounts with verified MFA',s.mfaAccounts,
              Icons.verified_user_outlined),
            _metric('Unverified email accounts',s.unverifiedEmailAccounts,
              Icons.mark_email_unread_outlined),
            _metric('Suspended/revoked memberships',s.suspendedMemberships,
              Icons.block_outlined),
            _metric('Banned accounts',s.bannedAccounts,
              Icons.person_off_outlined),
            _metric('Security email failures (30d)',s.failedSecurityEmails,
              Icons.mark_email_read_outlined),
            _metric('Accounts signed in (30d)',s.recentLoginAccounts,
              Icons.login_outlined),
            _metric('Suspended schools',s.suspendedSchools,
              Icons.apartment_outlined),
            _metric('Rejected school requests',s.rejectedRequests,
              Icons.cancel_outlined),
          ]),
          const SizedBox(height:18),
          OutlinedButton.icon(
            onPressed:()=>_selectTab(3),
            icon:const Icon(Icons.people_outline),
            label:const Text('Inspect school account security')),
        ],
        const SizedBox(height:22),
        Text('Recent approval decisions',
          style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:9),
        if(securityLoading)const Center(child:CircularProgressIndicator())
        else if(securityError!=null)
          _failure(securityError!,_refreshSecurity)
        else if(history.isEmpty)
          _empty('No school approval decisions have been recorded.',
            icon:Icons.history_outlined)
        else for(final event in history)Card(
          child:ListTile(
            leading:Icon(event.decision=='approve'
              ? Icons.check_circle_outline:Icons.cancel_outlined),
            title:Text('${event.schoolName} • ${event.decision}'),
            subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text('Reviewer: ${event.reviewerEmail??'Unavailable'}'),
                Text('Recorded: ${event.at}'),
                if(event.reason?.isNotEmpty==true)
                  Text(event.reason!,maxLines:3,
                    overflow:TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
        const SizedBox(height:12),
        _notice('Security posture is based on Auth account state, enrolled '
          'MFA factors, school memberships and email-delivery records. '
          'This is not a real-time intrusion detection system or an '
          'exhaustive history of every sign-in attempt.'),
      ],
    );
  }

  Widget _notice(String value)=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:4),
    child:Text(value,
      style:Theme.of(context).textTheme.bodySmall?.copyWith(
        color:Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}
