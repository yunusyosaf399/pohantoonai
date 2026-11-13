import 'package:flutter/material.dart';

import '../data/school_activation_repository.dart';

/// Displays only the applicant's own status. Rendering a test/demo workspace
/// never activates real schools or creates memberships.
class SchoolActivationRequestCard extends StatefulWidget {
  const SchoolActivationRequestCard({
    super.key,required this.repository,this.onRefreshSchoolAccess,
  });

  final SchoolActivationRepository repository;
  final VoidCallback? onRefreshSchoolAccess;

  @override
  State<SchoolActivationRequestCard> createState() =>
    _SchoolActivationRequestCardState();
}

class _SchoolActivationRequestCardState
    extends State<SchoolActivationRequestCard> {
  SchoolActivationStatus? request;
  bool loading=true;
  bool saving=false;
  String? error;

  @override
  void initState(){
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if(!mounted)return;
    setState((){
      loading=true;
      error=null;
    });
    try {
      final value=await widget.repository.ownRequest();
      if(mounted)setState((){
        request=value;
        loading=false;
      });
    } catch (_) {
      if(mounted)setState((){
        loading=false;
        error='School activation status is unavailable. Check your connection.';
      });
    }
  }

  Future<void> _submit() async {
    if(saving)return;
    final agree=await showDialog<bool>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:const Text('Submit your school for approval?'),
        content:const Text(
          'Your current school setup and confirmed review will be submitted '
          'to the platform review queue. Submitting does not activate a '
          'subscription, charge a payment method or grant access to students. '
          'A separate authorized reviewer must approve activation.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext,false),
            child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),
            child:const Text('Submit for review')),
        ],
      ),
    );
    if(agree!=true||!mounted)return;
    setState((){
      saving=true;
      error=null;
    });
    try {
      await widget.repository.submitRequest();
      if(!mounted)return;
      await _load();
      if(mounted)ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content:Text('School activation request submitted for review.')));
    } catch (_) {
      if(mounted)setState((){
        error='Could not submit the request. Finish and confirm your current '
          'school setup review, then retry. Contact support if it persists.';
      });
    } finally {
      if(mounted)setState(()=>saving=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme=Theme.of(context);
    final colors=theme.colorScheme;
    final status=request?.status;
    return Card(
      key:const Key('school-activation-request-card'),
      child:Padding(
        padding:const EdgeInsets.all(18),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            Row(children:[
              Icon(Icons.verified_user_outlined,color:colors.primary),
              const SizedBox(width:10),
              const Expanded(child:Text(
                'Real school activation',
                style:TextStyle(fontWeight:FontWeight.w800,fontSize:16))),
              if(status!=null)Chip(label:Text(status.toUpperCase())),
            ]),
            const SizedBox(height:9),
            Text(
              status=='provisioned'
                ? 'Your school has been approved and provisioned. '
                  'Refresh access to open your real Admissions dashboard.'
                : status=='submitted'||status=='in_review'
                ? 'Your school request is waiting for a separate platform '
                  'review. This workspace remains a development preview.'
                : status=='rejected'
                ? 'Your request was not approved. Contact platform support '
                  'for the review decision before resubmitting.'
                : status=='more_information'
                ? 'The platform reviewer needs additional information. '
                  'Contact support to continue the review.'
                : 'Request approval of the school you reviewed during setup. '
                  'Only an independently authorized platform reviewer can '
                  'activate a real school and owner membership.',
              style:TextStyle(fontSize:13,
                color:colors.onSurfaceVariant,height:1.5),
            ),
            const SizedBox(height:11),
            if(loading)const LinearProgressIndicator(
              key:Key('school-activation-loading')),
            if(error!=null)Padding(
              padding:const EdgeInsets.only(bottom:10),
              child:Text(error!,style:TextStyle(color:colors.error))),
            Wrap(spacing:9,runSpacing:7,children:[
              if(!loading&&!saving&&request==null)
                FilledButton.icon(
                  key:const Key('school-activation-submit'),
                  onPressed:_submit,
                  icon:const Icon(Icons.outbox_outlined),
                  label:const Text('Request approval')),
              if(!loading&&status=='provisioned')
                FilledButton.icon(
                  key:const Key('school-activation-open'),
                  onPressed:widget.onRefreshSchoolAccess,
                  icon:const Icon(Icons.school_outlined),
                  label:const Text('Open real school dashboard')),
              OutlinedButton.icon(
                onPressed:loading||saving?null:_load,
                icon:const Icon(Icons.refresh),
                label:const Text('Refresh status')),
            ]),
          ],
        ),
      ),
    );
  }
}
