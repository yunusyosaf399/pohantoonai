import 'package:flutter/material.dart';

import '../data/school_activation_repository.dart';

/// Production operator console; unlike the mock OrganizationControlPanel,
/// every row and action is backed by server-side operator membership + AAL2.
class SchoolProvisioningOperatorScreen extends StatefulWidget {
  const SchoolProvisioningOperatorScreen({
    super.key,required this.repository,required this.onSignOut,
  });

  final SchoolActivationRepository repository;
  final VoidCallback onSignOut;

  @override
  State<SchoolProvisioningOperatorScreen> createState() =>
    _SchoolProvisioningOperatorScreenState();
}

class _SchoolProvisioningOperatorScreenState
    extends State<SchoolProvisioningOperatorScreen> {
  bool loading=true;
  bool saving=false;
  String? error;
  String filter='pending';
  List<SchoolActivationReview> requests=const [];

  @override
  void initState(){
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if(!mounted)return;
    setState((){
      loading=true;error=null;requests=const [];
    });
    try {
      final rows=await widget.repository.operatorQueue();
      if(mounted)setState((){
        requests=rows;
        loading=false;
      });
    }catch(_){
      if(mounted)setState((){
        loading=false;
        error='Could not verify operator access or load school requests. '
          'Use an active platform owner/admin account with completed 2FA.';
      });
    }
  }

  List<SchoolActivationReview> get visible => requests.where((r) =>
    filter=='all' || (filter=='pending'
      ? r.status=='submitted'||r.status=='in_review'
      : r.status==filter)).toList(growable:false);

  Future<void> _review(SchoolActivationReview record,
      {required bool approve}) async {
    if(saving||record.status!='submitted'&&record.status!='in_review')return;
    final decision=await showDialog<_OperatorDecision>(
      context:context,
      builder:(ctx)=>_ReviewDialog(record:record,approve:approve),
    );
    if(decision==null||!mounted)return;
    setState(()=>saving=true);
    try {
      if(approve){
        await widget.repository.approve(
          requestId:record.id,
          activationBasis:record.isDemo
            ? 'approved_pilot':'verified_subscription',
          evidence:decision.reason,
          identityVerified:decision.verifiedIdentity,
        );
      }else{
        await widget.repository.reject(
          requestId:record.id,reason:decision.reason);
      }
      if(!mounted)return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content:Text(approve
          ? 'School provisioned and owner membership granted.'
          : 'School request rejected with an audit record.')));
      await _load();
    }catch(_){
      if(mounted)ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content:Text(
          'Review could not finish. Verify your operator role, two-factor '
          'authentication, school identity and subscription eligibility.')));
    }finally{
      if(mounted)setState(()=>saving=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors=Theme.of(context).colorScheme;
    final pending=requests.where((r)=>r.status=='submitted'||
      r.status=='in_review').length;
    return Scaffold(
      appBar:AppBar(
        title:const Text('PohantoonAI • School approvals'),
        actions:[
          IconButton(
            key:const Key('operator-review-refresh'),
            tooltip:'Refresh school review queue',
            onPressed:saving?null:_load,
            icon:const Icon(Icons.refresh)),
          IconButton(
            tooltip:'Sign out',
            onPressed:widget.onSignOut,
            icon:const Icon(Icons.logout_outlined)),
        ],
      ),
      body:SafeArea(child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:1160),
        child:ListView(
          padding:const EdgeInsets.fromLTRB(18,23,18,48),
          children:[
            Text('Provisioning review',style:Theme.of(context)
              .textTheme.headlineMedium?.copyWith(
                fontWeight:FontWeight.w900)),
            const SizedBox(height:7),
            Text('Verified platform operators only • 2FA required • '
              'Separate from school-owner permissions',
              style:TextStyle(color:colors.onSurfaceVariant)),
            const SizedBox(height:17),
            Card(child:Padding(
              padding:const EdgeInsets.all(17),
              child:Row(children:[
                Icon(Icons.fact_check_outlined,
                  color:colors.primary,size:27),
                const SizedBox(width:14),
                Expanded(child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text('$pending awaiting review',
                      style:const TextStyle(
                        fontWeight:FontWeight.w800,fontSize:18)),
                    const Text('Every approval is audited; no demo '
                      'payment skip can grant live access.'),
                  ],
                )),
              ]),
            )),
            const SizedBox(height:15),
            Wrap(
              spacing:9,runSpacing:9,
              crossAxisAlignment:WrapCrossAlignment.center,
              children:[
                ChoiceChip(
                  label:const Text('Pending'),
                  selected:filter=='pending',
                  onSelected:(_)=>setState(()=>filter='pending')),
                ChoiceChip(
                  label:const Text('Provisioned'),
                  selected:filter=='provisioned',
                  onSelected:(_)=>setState(()=>filter='provisioned')),
                ChoiceChip(
                  label:const Text('Rejected'),
                  selected:filter=='rejected',
                  onSelected:(_)=>setState(()=>filter='rejected')),
                ChoiceChip(
                  label:const Text('All'),
                  selected:filter=='all',
                  onSelected:(_)=>setState(()=>filter='all')),
              ],
            ),
            const SizedBox(height:16),
            if(loading)const Padding(
              padding:EdgeInsets.all(27),
              child:Center(child:CircularProgressIndicator(
                key:Key('operator-review-loading'))))
            else if(error!=null)
              Card(child:Padding(padding:const EdgeInsets.all(24),
                child:Column(children:[
                  Icon(Icons.shield_outlined,
                    color:colors.error,size:37),
                  const SizedBox(height:8),
                  Text(error!,textAlign:TextAlign.center),
                  const SizedBox(height:8),
                  FilledButton(onPressed:_load,
                    child:const Text('Retry')),
                ])))
            else if(visible.isEmpty)
              const Card(child:Padding(
                padding:EdgeInsets.all(35),
                child:Center(child:Text(
                  'No school requests match the selected status.'))))
            else
              for(final record in visible)Card(
                key:Key('school-review-${record.id}'),
                margin:const EdgeInsets.only(bottom:11),
                child:Padding(padding:const EdgeInsets.all(18),
                  child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Wrap(
                        spacing:12,runSpacing:7,
                        crossAxisAlignment:WrapCrossAlignment.center,
                        children:[
                          Text(record.schoolName,
                            style:const TextStyle(
                              fontWeight:FontWeight.w800,fontSize:18)),
                          Chip(label:Text(record.status.toUpperCase())),
                          Chip(label:Text(record.isDemo
                            ? 'Test-only plan':'Non-demo plan')),
                        ],
                      ),
                      const SizedBox(height:9),
                      Text('Applicant: ${record.applicantEmail}'),
                      Text('Plan: ${record.planCode}'),
                      if(record.legalName?.isNotEmpty==true)
                        Text('Legal name: ${record.legalName}'),
                      Text('Submitted: ${record.submittedAt.toLocal()}',
                        style:TextStyle(fontSize:12,
                          color:colors.onSurfaceVariant)),
                      if(record.status=='submitted'||
                        record.status=='in_review')...[
                        const SizedBox(height:13),
                        Wrap(spacing:9,runSpacing:8,children:[
                          FilledButton.icon(
                            key:Key('approve-school-${record.id}'),
                            onPressed:saving?null:()=>_review(record,approve:true),
                            icon:const Icon(Icons.verified_user_outlined),
                            label:Text(record.isDemo
                              ? 'Approve pilot':'Approve verified school')),
                          OutlinedButton.icon(
                            onPressed:saving?null:()=>_review(record,approve:false),
                            icon:const Icon(Icons.block_outlined),
                            label:const Text('Reject')),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ))),
    );
  }
}

class _OperatorDecision {
  const _OperatorDecision(this.reason,{this.verifiedIdentity=false});
  final String reason;
  final bool verifiedIdentity;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.record,required this.approve});
  final SchoolActivationReview record;
  final bool approve;

  @override
  State<_ReviewDialog> createState()=>_ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final reason=TextEditingController();
  bool identityVerified=false;
  @override
  void dispose(){
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minimum=widget.approve?20:15;
    final title=widget.approve?'Approve school activation':'Reject school request';
    final isValid=reason.text.trim().length>=minimum &&
      (!widget.approve||identityVerified);
    return AlertDialog(
      title:Text(title),
      content:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:470),
        child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text(widget.record.schoolName,
              style:const TextStyle(fontWeight:FontWeight.bold)),
            const SizedBox(height:9),
            Text(widget.approve
              ? widget.record.isDemo
                ? 'Development pilot approval. This grants access to REAL '
                  'school records under an explicitly approved test-only plan; '
                  'it does not establish a paid subscription.'
                : 'Requires a separate verified subscription on the server. '
                  'A pending or skipped checkout is not sufficient.'
              : 'A rejection is recorded permanently for audit.'),
            const SizedBox(height:12),
            if(widget.approve)CheckboxListTile(
              contentPadding:EdgeInsets.zero,
              controlAffinity:ListTileControlAffinity.leading,
              value:identityVerified,
              onChanged:(v)=>setState(()=>identityVerified=v??false),
              title:const Text('I independently verified the school identity '
                'and owner authorization.'),
            ),
            const SizedBox(height:9),
            TextField(
              key:const Key('operator-review-evidence'),
              controller:reason,
              onChanged:(_)=>setState((){}),
              maxLines:4,maxLength:2000,
              decoration:InputDecoration(
                labelText:widget.approve
                  ? 'Approval evidence and justification'
                  : 'Rejection reason',
                border:const OutlineInputBorder(),
                helperText:'At least $minimum characters',
              ),
            ),
          ],
        )),
      ),
      actions:[
        TextButton(
          onPressed:()=>Navigator.pop(context),
          child:const Text('Cancel')),
        FilledButton(
          key:const Key('operator-review-confirm'),
          onPressed:isValid?()=>Navigator.pop(context,
            _OperatorDecision(reason.text.trim(),
              verifiedIdentity:identityVerified)):null,
          child:Text(widget.approve?'Approve and provision':'Reject request')),
      ],
    );
  }
}
