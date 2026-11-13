import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../../admissions/data/school_admissions_repository.dart';
import '../../admissions/presentation/school_admissions_screen.dart';

/// Authorized school dashboard. All numbers and records are loaded from
/// school_id-scoped Supabase queries under database RLS (never demo fixtures).
class LiveSchoolDashboardScreen extends StatefulWidget {
  const LiveSchoolDashboardScreen({
    super.key,
    required this.schools,
    required this.repository,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onSignOut,
  });

  final List<AdmissionsSchool> schools;
  final SchoolAdmissionsRepository repository;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;
  final VoidCallback onSignOut;

  @override
  State<LiveSchoolDashboardScreen> createState() =>
    _LiveSchoolDashboardScreenState();
}

class _LiveSchoolDashboardScreenState extends State<LiveSchoolDashboardScreen> {
  late String schoolId;
  AdmissionsSummary summary=AdmissionsSummary.empty;
  List<SchoolAdmission> recent=const [];
  bool busy=true;
  String? error;
  int requestId=0;

  @override
  void initState(){
    super.initState();
    schoolId=widget.schools.first.id;
    _reload();
  }

  Future<void> _reload() async {
    final seq=++requestId;
    setState((){
      busy=true;error=null;
      summary=AdmissionsSummary.empty;
      recent=const [];
    });
    try {
      final counts=await widget.repository.summary(schoolId);
      final rows=await widget.repository.load(schoolId);
      if(!mounted||seq!=requestId)return;
      setState((){
        busy=false;summary=counts;recent=rows.take(6).toList();
      });
    } catch (_) {
      if(!mounted||seq!=requestId)return;
      setState((){
        busy=false;
        error='Unable to load live school records. Check your school access and retry.';
      });
    }
  }

  Future<void> _navigate({bool studentsOnly=false}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder:(_)=>SchoolAdmissionsScreen(
        repository:widget.repository,
        studentsOnly:studentsOnly,
      ),
    ));
    if(mounted)_reload();
  }

  void _selectSchool(String? id) {
    if(id==null||id==schoolId)return;
    setState(()=>schoolId=id);
    _reload();
  }

  AdmissionsSchool get school=>widget.schools.firstWhere(
    (s)=>s.id==schoolId,orElse:()=>widget.schools.first);

  @override
  Widget build(BuildContext context) {
    final colors=Theme.of(context).colorScheme;
    return LayoutBuilder(builder:(context,bounds){
      final wide=bounds.maxWidth>=900;
      return Scaffold(
        appBar:AppBar(
          title:Row(mainAxisSize:MainAxisSize.min,children:[
            ClipRRect(
              borderRadius:BorderRadius.circular(8),
              child:Image.asset('assets/app_logo/app_icon.jpeg',
                width:32,height:32,fit:BoxFit.cover)),
            const SizedBox(width:10),
            const Flexible(child:Text('PohantoonAI',
              overflow:TextOverflow.ellipsis,
              style:TextStyle(fontWeight:FontWeight.w800))),
          ]),
          actions:[
            IconButton(
              key:const Key('real-dashboard-refresh'),
              tooltip:'Refresh live dashboard',
              onPressed:busy?null:_reload,
              icon:const Icon(Icons.refresh)),
            AppearanceSettingsButton(
              mode:widget.themeMode,onChanged:widget.onThemeChanged),
            IconButton(
              tooltip:'Sign out',onPressed:widget.onSignOut,
              icon:const Icon(Icons.logout_outlined)),
          ],
        ),
        body:Row(children:[
          if(wide)NavigationRail(
            selectedIndex:0,
            labelType:NavigationRailLabelType.all,
            onDestinationSelected:(index){
              if(index==1)_navigate();
              if(index==2)_navigate(studentsOnly:true);
            },
            destinations:const [
              NavigationRailDestination(
                icon:Icon(Icons.space_dashboard_outlined),
                selectedIcon:Icon(Icons.space_dashboard),label:Text('Dashboard')),
              NavigationRailDestination(
                icon:Icon(Icons.note_add_outlined),label:Text('Admissions')),
              NavigationRailDestination(
                icon:Icon(Icons.people_outline),label:Text('Students')),
            ],
          ),
          Expanded(child:Container(
            color:colors.surface,
            child:Center(child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:1260),
              child:ListView(
                padding:const EdgeInsets.fromLTRB(20,24,20,40),
                children:[
                  Text('School dashboard',style:Theme.of(context)
                    .textTheme.headlineMedium?.copyWith(
                      fontWeight:FontWeight.w900)),
                  const SizedBox(height:5),
                  Text('Live school data • Authenticated school administration',
                    style:TextStyle(color:colors.onSurfaceVariant)),
                  const SizedBox(height:18),
                  Wrap(spacing:12,runSpacing:12,
                    crossAxisAlignment:WrapCrossAlignment.center,
                    children:[
                      if(widget.schools.length>1)SizedBox(width:340,
                        child:DropdownButtonFormField<String>(
                          key:const Key('real-dashboard-school-switcher'),
                          value:schoolId,
                          decoration:const InputDecoration(
                            labelText:'Active school',
                            border:OutlineInputBorder()),
                          items:widget.schools.map((s)=>DropdownMenuItem(
                            value:s.id,child:Text(s.name,
                              overflow:TextOverflow.ellipsis))).toList(),
                          onChanged:busy?null:_selectSchool,
                        ))
                      else Chip(
                        avatar:const Icon(Icons.account_balance_outlined,size:19),
                        label:Text(school.name),
                      ),
                      const Chip(
                        avatar:Icon(Icons.verified_user_outlined,
                          color:Colors.green,size:18),
                        label:Text('School-authorized')),
                    ],
                  ),
                  const SizedBox(height:22),
                  if(busy)const Center(child:Padding(
                    padding:EdgeInsets.all(32),
                    child:CircularProgressIndicator(
                      key:Key('real-dashboard-loading'))))
                  else if(error!=null)
                    Card(child:Padding(padding:const EdgeInsets.all(25),
                      child:Column(children:[
                        Icon(Icons.lock_outline,size:34,color:colors.error),
                        const SizedBox(height:10),
                        Text(error!,textAlign:TextAlign.center),
                        const SizedBox(height:10),
                        FilledButton(onPressed:_reload,child:const Text('Retry')),
                      ])))
                  else ...[
                    _metrics(),
                    const SizedBox(height:24),
                    _actions(),
                    const SizedBox(height:24),
                    _recent(),
                    const SizedBox(height:20),
                    Text('This dashboard displays actual Admissions data. '
                      'Attendance, fee collection, staffing and academic analytics '
                      'will appear only after their authorized modules are connected.',
                      style:TextStyle(color:colors.onSurfaceVariant,fontSize:12)),
                  ],
                ],
              ),
            )),
          )),
        ]),
        bottomNavigationBar:wide?null:NavigationBar(
          selectedIndex:0,
          destinations:const [
            NavigationDestination(icon:Icon(Icons.home_outlined),label:'Dashboard'),
            NavigationDestination(icon:Icon(Icons.note_add_outlined),label:'Admissions'),
            NavigationDestination(icon:Icon(Icons.people_outline),label:'Students'),
          ],
          onDestinationSelected:(index){
            if(index==1)_navigate();
            if(index==2)_navigate(studentsOnly:true);
          },
        ),
      );
    });
  }

  Widget _metrics()=>LayoutBuilder(builder:(context,bounds){
    final cards=[
      _metric('Applications',summary.total,Icons.list_alt_outlined),
      _metric('Pending',summary.pending,Icons.pending_actions_outlined),
      _metric('Admitted students',summary.admitted,Icons.school_outlined),
      _metric('Rejected',summary.rejected,Icons.cancel_outlined),
    ];
    return GridView.count(
      crossAxisCount:bounds.maxWidth<550?2:4,
      crossAxisSpacing:10,mainAxisSpacing:10,
      childAspectRatio:bounds.maxWidth<550?1.65:1.8,
      physics:const NeverScrollableScrollPhysics(),
      shrinkWrap:true,
      children:cards,
    );
  });

  Widget _metric(String title,int number,IconData icon) {
    final colors=Theme.of(context).colorScheme;
    return Card(
      child:Padding(padding:const EdgeInsets.all(13),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        mainAxisAlignment:MainAxisAlignment.spaceBetween,
        children:[
          Icon(icon,color:colors.primary,size:25),
          Text('$number',style:const TextStyle(
            fontSize:26,fontWeight:FontWeight.w800)),
          Text(title,maxLines:2,overflow:TextOverflow.ellipsis,
            style:TextStyle(fontSize:12,color:colors.onSurfaceVariant)),
        ],
      )),
    );
  }

  Widget _actions() => Card(
    child:Padding(padding:const EdgeInsets.all(19),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Quick actions',style:TextStyle(
          fontSize:17,fontWeight:FontWeight.w800)),
        const SizedBox(height:13),
        Wrap(spacing:11,runSpacing:11,children:[
          FilledButton.icon(
            key:const Key('real-dashboard-new-admission'),
            onPressed:()=>_navigate(),
            icon:const Icon(Icons.person_add_alt_outlined),
            label:const Text('New admission')),
          OutlinedButton.icon(
            onPressed:()=>_navigate(studentsOnly:true),
            icon:const Icon(Icons.people_outline),
            label:const Text('View students')),
          OutlinedButton.icon(
            onPressed:()=>_navigate(),
            icon:const Icon(Icons.fact_check_outlined),
            label:const Text('Review applications')),
        ]),
      ]),
    ),
  );

  Widget _recent() => Card(child:Padding(
    padding:const EdgeInsets.all(17),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        const Expanded(child:Text('Recent admissions',
          style:TextStyle(fontSize:17,fontWeight:FontWeight.w800))),
        TextButton(onPressed:()=>_navigate(),child:const Text('View all')),
      ]),
      const Divider(),
      if(recent.isEmpty)const Padding(
        padding:EdgeInsets.symmetric(vertical:24),
        child:Text('No admissions yet. Register your first applicant.'))
      else for(final item in recent)
        ListTile(
          contentPadding:EdgeInsets.zero,
          leading:const CircleAvatar(child:Icon(Icons.person_outline)),
          title:Text(item.fullName),
          subtitle:Text('Grade ${item.grade}'),
          trailing:Chip(label:Text(item.status)),
        ),
    ]),
  ));
}
