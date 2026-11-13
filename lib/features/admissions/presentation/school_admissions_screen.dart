import 'package:flutter/material.dart';

import '../data/school_admissions_repository.dart';

/// Real school admissions. Availability comes only from ACTIVE owner/admin
/// membership, and the repository is additionally protected by database RLS.
class SchoolAdmissionsScreen extends StatefulWidget {
  const SchoolAdmissionsScreen({
    super.key,
    required this.repository,
    this.studentsOnly=false,
  });

  final SchoolAdmissionsRepository repository;
  /// The Students navigation opens the admitted-students roster.
  final bool studentsOnly;

  @override
  State<SchoolAdmissionsScreen> createState()=>_SchoolAdmissionsScreenState();
}

class _SchoolAdmissionsScreenState extends State<SchoolAdmissionsScreen> {
  List<AdmissionsSchool> schools=const [];
  List<SchoolAdmission> admissions=const [];
  AdmissionsSummary summary=AdmissionsSummary.empty;
  String? schoolId;
  String? error;
  String filter='all';
  String search='';
  bool loading=true;
  bool saving=false;
  int revision=0;

  @override
  void initState(){
    super.initState();
    filter=widget.studentsOnly?'admitted':'all';
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    final request=++revision;
    setState((){
      loading=true;error=null;
      admissions=const [];
      summary=AdmissionsSummary.empty;
    });
    try {
      final available=await widget.repository.availableSchools();
      if(!mounted||request!=revision)return;
      final preferred=available.any((s)=>s.id==schoolId)
        ? schoolId : (available.isEmpty?null:available.first.id);
      setState((){
        schools=available;
        schoolId=preferred;
        if(preferred==null) loading=false;
      });
      if(preferred!=null)await _loadAdmissions(preferred);
    } catch (_) {
      if(mounted&&request==revision)setState((){
        error='We could not verify your school access. Please retry.';
        loading=false;
      });
    }
  }

  Future<void> _loadAdmissions(String id) async {
    final request=++revision;
    setState((){
      loading=true;error=null;
      schoolId=id;
      admissions=const [];
      summary=AdmissionsSummary.empty;
    });
    try {
      final items=await widget.repository.load(id);
      final totals=await widget.repository.summary(id);
      if(mounted&&request==revision){
        setState((){
          admissions=items;summary=totals;loading=false;
        });
      }
    } catch (_) {
      if(mounted&&request==revision)setState((){
        loading=false;
        error='Admissions could not be loaded. Check your school permission and connection.';
      });
    }
  }

  void _chooseSchool(String id) {
    if(id==schoolId)return;
    _loadAdmissions(id);
  }

  List<SchoolAdmission> get visible {
    final q=search.trim().toLowerCase();
    return admissions.where((admission){
      final matchesStatus=filter=='all'||admission.status==filter;
      final matchesText=q.isEmpty ||
        admission.fullName.toLowerCase().contains(q) ||
        admission.grade.toLowerCase().contains(q) ||
        admission.guardianName.toLowerCase().contains(q);
      return matchesStatus&&matchesText;
    }).toList(growable:false);
  }

  Future<void> _addAdmission() async {
    final school=schoolId;
    if(school==null||saving)return;
    final value=await showModalBottomSheet<NewSchoolAdmission>(
      context:context,
      isScrollControlled:true,
      useSafeArea:true,
      showDragHandle:true,
      builder:(context)=>const _NewAdmissionForm(),
    );
    if(value==null||!mounted)return;
    setState(()=>saving=true);
    try {
      await widget.repository.create(school,value);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Admission saved securely.')));
      await _loadAdmissions(school);
    } catch (_) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text(
          'Could not save the admission. Verify your school authorization and entered details.')));
    } finally {
      if(mounted)setState(()=>saving=false);
    }
  }

  Future<void> _decide(SchoolAdmission admission,String outcome) async {
    final school=schoolId;
    if(school==null||saving||admission.status!='pending')return;
    final action=outcome=='admitted'?'Admit student':'Reject application';
    final confirm=await showDialog<bool>(
      context:context,
      builder:(context)=>AlertDialog(
        title:Text(action+'?'),
        content:Text('Apply this decision to ${admission.fullName}? '
          'A final decision cannot be edited in this first release.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),
            child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),
            child:Text(action)),
        ],
      ),
    );
    if(confirm!=true||!mounted)return;
    setState(()=>saving=true);
    try {
      await widget.repository.decide(school,admission.id,outcome);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Application ${outcome=='admitted'?'admitted':'rejected'} successfully.')));
      await _loadAdmissions(school);
    } catch (_) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text(
          'The admission was not changed. Reload and check your permission.')));
    } finally {
      if(mounted)setState(()=>saving=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors=Theme.of(context).colorScheme;
    return Scaffold(
      appBar:AppBar(
        title:Text(widget.studentsOnly?'Students':'Admissions'),
        actions:[
          IconButton(
            key:const Key('admissions-refresh'),
            tooltip:'Reload school admissions',
            icon:const Icon(Icons.refresh),
            onPressed:saving?null:_loadSchools),
        ],
      ),
      floatingActionButton:(!loading&&error==null&&schoolId!=null&&!widget.studentsOnly)
        ? FloatingActionButton.extended(
            key:const Key('admissions-new'),
            onPressed:saving?null:_addAdmission,
            icon:const Icon(Icons.person_add_alt_outlined),
            label:const Text('New admission'))
        :null,
      body:SafeArea(
        child:Center(child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:1200),
          child:Padding(
            padding:const EdgeInsets.fromLTRB(17,16,17,90),
            child:_body(colors),
          ),
        )),
      ),
    );
  }

  Widget _body(ColorScheme colors) {
    if(loading)return const Center(
      child:CircularProgressIndicator(key:Key('admissions-loading')));
    if(error!=null)return Center(child:Column(
      mainAxisSize:MainAxisSize.min,
      children:[
        Icon(Icons.shield_outlined,size:42,color:colors.error),
        const SizedBox(height:12),
        Text(error!,textAlign:TextAlign.center),
        const SizedBox(height:12),
        FilledButton(onPressed:_loadSchools,child:const Text('Retry')),
      ],
    ));
    if(schools.isEmpty)return Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:530),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(Icons.lock_outline,size:49,color:colors.primary),
        const SizedBox(height:15),
        const Text('School access required',
          key:Key('admissions-access-required'),
          style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
        const SizedBox(height:12),
        const Text(
          'Real admissions become available after your school is provisioned '
          'and your account has an active school_owner or school_admin membership. '
          'A development preview does not grant access to student records.',
          textAlign:TextAlign.center),
        const SizedBox(height:17),
        OutlinedButton.icon(onPressed:_loadSchools,
          icon:const Icon(Icons.refresh),label:const Text('Check access again')),
      ]),
    ));
    final selected=schools.firstWhere((s)=>s.id==schoolId,
      orElse:()=>schools.first);
    final pending=summary.pending;
    final admitted=summary.admitted;
    final rejected=summary.rejected;
    return ListView(children:[
      Text(widget.studentsOnly?'Admitted students':'Student admissions',
        style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      Text('Live records • ${selected.name} • School-authorized access',
        style:TextStyle(color:colors.onSurfaceVariant)),
      const SizedBox(height:16),
      if(schools.length>1) Card(child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:14,vertical:5),
        child:DropdownButtonHideUnderline(child:DropdownButton<String>(
          key:const Key('admissions-school-switcher'),
          isExpanded:true,value:schoolId,
          items:schools.map((s)=>DropdownMenuItem(
            value:s.id,child:Text(s.name))).toList(),
          onChanged:saving?null:(id){if(id!=null)_chooseSchool(id);},
        )),
      )),
      LayoutBuilder(builder:(context,limits){
        final narrow=limits.maxWidth<590;
        final stats=[
          _stat('Pending',pending,Icons.schedule_outlined),
          _stat('Admitted',admitted,Icons.how_to_reg_outlined),
          _stat('Rejected',rejected,Icons.cancel_outlined),
        ];
        return narrow?Column(children:[
          for(final stat in stats)...[stat,const SizedBox(height:7)]
        ]):Row(children:[
          for(var i=0;i<stats.length;i++)...[
            if(i!=0)const SizedBox(width:9),
            Expanded(child:stats[i]),
          ],
        ]);
      }),
      const SizedBox(height:17),
      Wrap(spacing:10,runSpacing:10,crossAxisAlignment:WrapCrossAlignment.center,
        children:[
          SizedBox(width:320,child:TextField(
            key:const Key('admissions-search'),
            onChanged:(value)=>setState(()=>search=value),
            decoration:const InputDecoration(
              isDense:true,prefixIcon:Icon(Icons.search),
              labelText:'Search student, grade or guardian',
              border:OutlineInputBorder(),
            ),
          )),
          if(!widget.studentsOnly)SizedBox(width:160,child:
            DropdownButtonFormField<String>(
              key:const Key('admissions-filter'),
              value:filter,
              decoration:const InputDecoration(
                isDense:true,labelText:'Status',border:OutlineInputBorder()),
              items:const [
                DropdownMenuItem(value:'all',child:Text('All')),
                DropdownMenuItem(value:'pending',child:Text('Pending')),
                DropdownMenuItem(value:'admitted',child:Text('Admitted')),
                DropdownMenuItem(value:'rejected',child:Text('Rejected')),
              ],
              onChanged:(v)=>setState(()=>filter=v??'all'),
            )),
        ],
      ),
      const SizedBox(height:15),
      if(visible.isEmpty)
        Card(child:Padding(
          padding:const EdgeInsets.all(30),
          child:Center(child:Text(widget.studentsOnly
            ? 'No admitted students yet.'
            : 'No applications match this filter.')),
        ))
      else
        for(final item in visible)
          Card(
            key:Key('admission-row-${item.id}'),
            margin:const EdgeInsets.only(bottom:9),
            child:Padding(padding:const EdgeInsets.all(15),
              child:LayoutBuilder(builder:(context,limits){
                final narrow=limits.maxWidth<620;
                final info=Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(item.fullName,style:const TextStyle(
                      fontWeight:FontWeight.w800,fontSize:16)),
                    const SizedBox(height:7),
                    Text('Grade: ${item.grade}  •  Guardian: ${item.guardianName}'),
                    const SizedBox(height:4),
                    Text('Phone: ${item.guardianPhone}  •  ${item.createdAt.toLocal().toString().split('.').first}',
                      style:TextStyle(color:colors.onSurfaceVariant,fontSize:12)),
                  ],
                );
                final tools=Wrap(spacing:8,runSpacing:8,
                  crossAxisAlignment:WrapCrossAlignment.center,
                  children:[
                    Chip(label:Text(item.status.toUpperCase())),
                    if(item.status=='pending'&&!widget.studentsOnly)...[
                      OutlinedButton(
                        onPressed:saving?null:()=>_decide(item,'rejected'),
                        child:const Text('Reject')),
                      FilledButton(
                        onPressed:saving?null:()=>_decide(item,'admitted'),
                        child:const Text('Admit')),
                    ],
                  ],
                );
                return narrow?Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[info,const SizedBox(height:10),tools],
                ):Row(children:[
                  Expanded(child:info),const SizedBox(width:12),tools,
                ]);
              }),
            ),
          ),
      const SizedBox(height:12),
      Text('Showing the 200 most recent admission records at most. '
        'Each database request is filtered by the selected school ID '
        'and independently checked by PostgreSQL RLS.',
        style:TextStyle(color:colors.onSurfaceVariant,fontSize:11)),
    ]);
  }

  Widget _stat(String title,int value,IconData icon) => Card(
    child:Padding(padding:const EdgeInsets.all(14),
      child:Row(children:[
        Icon(icon,size:25),
        const SizedBox(width:14),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:const TextStyle(fontSize:12)),
          Text('$value',style:const TextStyle(
            fontSize:23,fontWeight:FontWeight.bold)),
        ]),
      ]),
    ),
  );
}

class _NewAdmissionForm extends StatefulWidget {
  const _NewAdmissionForm();
  @override
  State<_NewAdmissionForm> createState()=>_NewAdmissionFormState();
}

class _NewAdmissionFormState extends State<_NewAdmissionForm> {
  final form=GlobalKey<FormState>();
  final firstName=TextEditingController();
  final lastName=TextEditingController();
  final grade=TextEditingController();
  final guardian=TextEditingController();
  final phone=TextEditingController();
  final email=TextEditingController();
  final notes=TextEditingController();
  DateTime? birth;

  @override
  void dispose(){
    for(final controller in [firstName,lastName,grade,guardian,phone,email,notes]){
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value,{int min=2}) {
    if((value??'').trim().length<min)return 'This field is required.';
    return null;
  }

  void _submit(){
    if(!form.currentState!.validate())return;
    Navigator.pop(context,NewSchoolAdmission(
      firstName:firstName.text,lastName:lastName.text,
      grade:grade.text,guardianName:guardian.text,
      guardianPhone:phone.text,guardianEmail:email.text,
      notes:notes.text,dateOfBirth:birth));
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor:.94,
    child:Padding(
      padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),
      child:SingleChildScrollView(
        padding:const EdgeInsets.fromLTRB(22,10,22,28),
        child:Form(key:form,child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            const Text('New student admission',style:TextStyle(
              fontSize:22,fontWeight:FontWeight.w800)),
            const SizedBox(height:9),
            const Text('Only an authorized school owner or admin can save '
              'this record. New applications start as pending.'),
            const SizedBox(height:20),
            _field(firstName,'Student first name',maxLength:100),
            _field(lastName,'Student last name',maxLength:100,min:1),
            _field(grade,'Grade applied for',maxLength:40,min:1),
            OutlinedButton.icon(
              onPressed:() async {
                final value=await showDatePicker(
                  context:context,
                  firstDate:DateTime(1900),
                  lastDate:DateTime.now(),
                  initialDate:birth??DateTime(DateTime.now().year-8),
                );
                if(value!=null&&mounted)setState(()=>birth=value);
              },
              icon:const Icon(Icons.cake_outlined),
              label:Text(birth==null?'Date of birth (optional)'
                :'Date of birth: ${birth!.year}-${birth!.month.toString().padLeft(2,'0')}-${birth!.day.toString().padLeft(2,'0')}'),
            ),
            const SizedBox(height:15),
            const Divider(),
            const Text('Guardian contact',style:TextStyle(
              fontSize:16,fontWeight:FontWeight.w700)),
            const SizedBox(height:10),
            _field(guardian,'Guardian full name',maxLength:150),
            Padding(padding:const EdgeInsets.only(bottom:13),
              child:TextFormField(
                key:const Key('admissions-guardian-phone'),
                controller:phone,maxLength:30,
                keyboardType:TextInputType.phone,
                decoration:const InputDecoration(
                  labelText:'Guardian phone',
                  border:OutlineInputBorder(),counterText:''),
                validator:(value){
                  if(value==null||!RegExp(r'^[+0-9 ()-]{7,30}$')
                    .hasMatch(value.trim())){
                    return 'Enter a valid contact number (7–30 characters).';
                  }
                  return null;
                },
              )),
            Padding(padding:const EdgeInsets.only(bottom:13),
              child:TextFormField(
                controller:email,maxLength:254,
                keyboardType:TextInputType.emailAddress,
                decoration:const InputDecoration(
                  labelText:'Guardian email (optional)',
                  border:OutlineInputBorder(),counterText:''),
                validator:(value){
                  final text=(value??'').trim();
                  if(text.isEmpty)return null;
                  if (!RegExp(r'^[^ @]+@[^ @]+[.][^ @]+$')
                      .hasMatch(text)) {
                    return 'Enter a valid email.';
                  }
                  return null;
                },
              )),
            TextFormField(
              controller:notes,maxLength:1000,maxLines:3,
              decoration:const InputDecoration(
                labelText:'Notes (optional)',
                border:OutlineInputBorder()),
            ),
            const SizedBox(height:17),
            FilledButton.icon(
              key:const Key('admissions-save'),
              icon:const Icon(Icons.save_outlined),
              onPressed:_submit,
              label:const Text('Save pending admission'),
            ),
          ],
        )),
      ),
    ),
  );

  Widget _field(TextEditingController controller,String label,
      {required int maxLength,int min=2}) =>
    Padding(
      padding:const EdgeInsets.only(bottom:13),
      child:TextFormField(
        controller:controller,
        maxLength:maxLength,
        decoration:InputDecoration(labelText:label,
          border:const OutlineInputBorder(),counterText:''),
        validator:(value)=>_required(value,min:min),
      ),
    );
}
