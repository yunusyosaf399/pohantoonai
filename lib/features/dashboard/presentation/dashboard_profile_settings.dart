import 'package:flutter/material.dart';

import '../../auth/data/account_auth_gateway.dart';
import '../../onboarding/data/school_logo_repository.dart';
import '../../onboarding/data/school_setup_repository.dart';
import '../../onboarding/domain/school_setup_draft.dart';
import '../../onboarding/presentation/school_logo_picker.dart';
import '../data/dashboard_owner_profile_repository.dart';

/// All edits stay inside the dashboard, not the six-step signup wizard.
/// Legal name, registration number, school type and plan are locked.
class DashboardProfileSettings extends StatefulWidget {
  const DashboardProfileSettings({super.key,required this.draft,
    required this.schoolRepository,required this.ownerRepository,
    required this.onDraftSaved,this.onOwnerSaved,this.credentials,this.logoRepository,
    this.initialTab=0});
  final SchoolSetupDraft draft;
  final SchoolSetupRepository schoolRepository;
  final DashboardOwnerProfileRepository ownerRepository;
  final ValueChanged<SchoolSetupDraft> onDraftSaved;
  final ValueChanged<String>? onOwnerSaved;
  final AccountEmailCredentials? credentials;
  final SchoolLogoRepository? logoRepository;
  final int initialTab;
  @override
  State<DashboardProfileSettings> createState()=>
      _DashboardProfileSettingsState();
}

class _DashboardProfileSettingsState extends State<DashboardProfileSettings>
    with SingleTickerProviderStateMixin {
  late TabController tabs;
  final fields=<String,TextEditingController>{};
  final owner=TextEditingController();
  final password=TextEditingController();
  final confirm=TextEditingController();
  String? logoPath,error,success;
  bool busy=false;
  static const editable=<String,String>{
    'school_name':'School name','website_url':'Website',
    'contact_name':'Contact name','contact_position':'Contact position',
    'contact_email':'School contact email','contact_phone':'Phone',
    'region':'State / Province','city':'City',
    'street_address':'Street address','postal_code':'Postal code',
    'education_board':'Education board','curriculum':'Curriculum',
    'lowest_grade':'Lowest grade','highest_grade':'Highest grade',
  };
  @override
  void initState(){
    super.initState();
    tabs=TabController(length:2,vsync:this,initialIndex:widget.initialTab);
    final values=widget.draft.toJson();
    for(final key in editable.keys) {
      fields[key]=TextEditingController(text:values[key]?.toString()??'');
    }
    logoPath=widget.draft.logoStoragePath;
    _loadOwner();
  }

  Future<void> _loadOwner() async {
    try {
      final result=await widget.ownerRepository.loadDisplayName();
      if(mounted)owner.text=result??widget.draft.contactName??'';
    } catch (_) {
      if(mounted)owner.text=widget.draft.contactName??'';
    }
  }

  @override
  void dispose(){
    tabs.dispose();
    for(final c in fields.values)c.dispose();
    owner.dispose();password.dispose();confirm.dispose();
    super.dispose();
  }

  Future<void> _saveSchool()async{
    if(busy)return;
    final json=<String,dynamic>{...widget.draft.toJson()};
    for(final e in fields.entries){
      final value=e.value.text.trim();
      json[e.key]=value.isEmpty?null:value;
    }
    json['logo_storage_path']=logoPath;
    final next=SchoolSetupDraft.fromJson(json);
    if(next.schoolName==null||next.schoolName!.length<2||
       next.contactName==null||next.city==null||
       !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
         .hasMatch(next.contactEmail??'')){
      setState(()=>error='School name, contact, email and city are required.');
      return;
    }
    setState((){busy=true;error=null;success=null;});
    try{
      final saved=await widget.schoolRepository.save(next);
      if(!mounted)return;
      widget.onDraftSaved(saved);
      setState(()=>success='School profile saved without reopening onboarding.');
    }catch(_){
      if(mounted)setState(()=>error='Could not save this school profile. '
        'Check your account and selected plan.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _saveOwner()async{
    if(busy)return;
    setState((){busy=true;error=null;success=null;});
    try{
      await widget.ownerRepository.saveDisplayName(owner.text);
      if(mounted){
        widget.onOwnerSaved?.call(owner.text.trim());
        setState(()=>success='Owner name updated.');
      }
    }catch(_){
      if(mounted)setState(()=>error='Owner name could not be updated.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _setPassword()async{
    if(busy)return;
    if(password.text.length<12||password.text!=confirm.text){
      setState(()=>error='Passwords must match and be at least 12 characters.');
      return;
    }
    if(widget.credentials==null) {
      setState(()=>error='Password settings unavailable in this session.');
      return;
    }
    setState((){busy=true;error=null;success=null;});
    try{
      await widget.credentials!.setAccountPassword(password.text);
      if(!mounted)return;
      password.clear();confirm.clear();
      setState(()=>success='Password saved in Supabase Auth. '
        'Email/password sign-in is now available.');
    }catch(_){
      if(mounted)setState(()=>error='Could not set password. Verify your '
        'email or reauthenticate, then retry.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Widget _school() => ListView(
    padding:const EdgeInsets.all(18),
    children:[
      const Text('School profile',style:TextStyle(
        fontSize:19,fontWeight:FontWeight.w800)),
      const SizedBox(height:7),
      const Text('Legal name, registration number, school type and '
        'subscription plan are locked.'),
      const SizedBox(height:12),
      SchoolLogoPicker(
        path:logoPath,repository:widget.logoRepository,
        onChanged:(v)=>setState(()=>logoPath=v)),
      const SizedBox(height:14),
      for(final e in editable.entries)...[
        TextField(
          key:Key('profile-school-'+e.key),
          controller:fields[e.key],
          enabled:!busy,
          decoration:InputDecoration(labelText:e.value,isDense:true)),
        const SizedBox(height:12),
      ],
      FilledButton.icon(
        key:const Key('profile-save-school'),
        onPressed:busy?null:_saveSchool,
        icon:const Icon(Icons.save_outlined),
        label:const Text('Save school details')),
    ],
  );

  Widget _ownerTab() => ListView(
    padding:const EdgeInsets.all(18),
    children:[
      const Text('Owner & Security',style:TextStyle(
        fontSize:19,fontWeight:FontWeight.w800)),
      const SizedBox(height:12),
      TextFormField(
        key:const Key('profile-owner-email'),
        initialValue:widget.ownerRepository.email??'Signed-in account',
        readOnly:true,
        decoration:const InputDecoration(
          labelText:'Sign-in email (locked)',
          prefixIcon:Icon(Icons.lock_outline))),
      const SizedBox(height:12),
      TextField(
        key:const Key('profile-owner-name'),
        controller:owner,maxLength:120,
        decoration:const InputDecoration(labelText:'Owner display name')),
      FilledButton(
        key:const Key('profile-save-owner'),
        onPressed:busy?null:_saveOwner,
        child:const Text('Save owner profile')),
      const Divider(height:34),
      const Text('Add or change account password',
        style:TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      const Text('Google users can create an email password for the '
        'same verified account. Passwords are held by Supabase Auth only.'),
      const SizedBox(height:14),
      TextField(
        key:const Key('profile-new-password'),
        controller:password,obscureText:true,
        autocorrect:false,enableSuggestions:false,
        decoration:const InputDecoration(
          labelText:'New password (12+ characters)')),
      const SizedBox(height:12),
      TextField(
        key:const Key('profile-confirm-password'),
        controller:confirm,obscureText:true,
        autocorrect:false,enableSuggestions:false,
        decoration:const InputDecoration(
          labelText:'Confirm password')),
      const SizedBox(height:12),
      FilledButton(
        key:const Key('profile-add-password'),
        onPressed:busy?null:_setPassword,
        child:const Text('Save password')),
    ],
  );

  @override
  Widget build(BuildContext context){
    final colors=Theme.of(context).colorScheme;
    return Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:820),
      child:Column(children:[
        Row(children:[
          const Expanded(child:Padding(
            padding:EdgeInsets.all(14),
            child:Text('Dashboard settings',
              key:Key('profile-settings-title'),
              style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)))),
          IconButton(tooltip:'Close settings',
            onPressed:()=>Navigator.pop(context),
            icon:const Icon(Icons.close)),
        ]),
        TabBar(controller:tabs,tabs:const [
          Tab(icon:Icon(Icons.apartment_outlined),text:'School profile'),
          Tab(icon:Icon(Icons.person_outline),text:'Owner & Security'),
        ]),
        if(error!=null)Padding(
          padding:const EdgeInsets.all(9),
          child:Text(error!,style:TextStyle(color:colors.error))),
        if(success!=null)Padding(
          padding:const EdgeInsets.all(9),
          child:Text(success!,style:TextStyle(color:colors.primary))),
        Expanded(child:TabBarView(
          controller:tabs,children:[_school(),_ownerTab()])),
      ]),
    ));
  }
}
