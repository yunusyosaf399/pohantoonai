import 'package:flutter/material.dart';

import '../data/account_auth_gateway.dart';

/// Supabase emits passwordRecovery after the reset link is opened.
/// Keep this dialog on top of the app until the verified account sets a
/// replacement password (or explicitly cancels).
class PasswordRecoveryDialog extends StatefulWidget {
  const PasswordRecoveryDialog({super.key,required this.auth});
  final AccountEmailCredentials auth;
  @override
  State<PasswordRecoveryDialog> createState()=>_PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<PasswordRecoveryDialog> {
  final pass=TextEditingController(),confirm=TextEditingController();
  bool busy=false;
  String? error;
  @override
  void dispose(){
    pass.dispose();confirm.dispose();
    super.dispose();
  }

  Future<void> _save()async{
    if(pass.text.length<12||pass.text!=confirm.text){
      setState(()=>error='Enter matching passwords of at least 12 characters.');
      return;
    }
    setState((){busy=true;error=null;});
    try{
      await widget.auth.setAccountPassword(pass.text);
      if(mounted)Navigator.of(context).pop(true);
    }catch(_){
      if(mounted)setState(()=>error='Password could not be changed. '
        'Your recovery link may have expired. Request another email.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:const Text('Set a new password'),
    content:SingleChildScrollView(
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('Use a strong new password for this verified email account.'),
        const SizedBox(height:12),
        TextField(
          key:const Key('recovery-new-password'),
          controller:pass,obscureText:true,enableSuggestions:false,
          autocorrect:false,
          decoration:const InputDecoration(labelText:'New password')),
        const SizedBox(height:12),
        TextField(
          key:const Key('recovery-confirm-password'),
          controller:confirm,obscureText:true,
          enableSuggestions:false,autocorrect:false,
          decoration:const InputDecoration(labelText:'Confirm password')),
        if(error!=null)Padding(
          padding:const EdgeInsets.only(top:12),
          child:Text(error!,style:TextStyle(
            color:Theme.of(context).colorScheme.error))),
      ]),
    ),
    actions:[
      TextButton(onPressed:busy?null:()=>Navigator.pop(context,false),
        child:const Text('Cancel')),
      FilledButton(
        key:const Key('recovery-save-password'),
        onPressed:busy?null:_save,
        child:const Text('Save password')),
    ],
  );
}
