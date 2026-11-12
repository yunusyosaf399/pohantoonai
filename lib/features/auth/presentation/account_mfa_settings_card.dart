import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/account_mfa_repository.dart';

/// Optional two-factor security panel inside Dashboard → Owner & Security.
/// TOTP secrets live only in the transient enrollment widget and in Supabase
/// Auth. This screen must never write them into school/profile tables.
class AccountMfaSettingsCard extends StatefulWidget {
  const AccountMfaSettingsCard({
    super.key,required this.repository,this.onChanged,
  });
  final AccountMfaRepository repository;
  final VoidCallback? onChanged;

  @override
  State<AccountMfaSettingsCard> createState()=>_AccountMfaSettingsCardState();
}

class _AccountMfaSettingsCardState extends State<AccountMfaSettingsCard> {
  final code=TextEditingController();
  AccountMfaStatus? current;
  AccountTotpEnrollment? enrollment;
  bool loading=true,busy=false;
  String? error,notice;

  @override
  void initState(){super.initState();_load();}
  @override
  void dispose(){code.dispose();super.dispose();}

  Future<void> _load()async{
    try{
      final status=await widget.repository.status();
      if(mounted)setState((){
        current=status;loading=false;
        error=null;
      });
    }catch(_){
      if(mounted)setState((){
        loading=false;
        error='Two-factor status is unavailable. Retry when online.';
      });
    }
  }

  Future<void> _enroll()async{
    if(busy)return;
    setState((){busy=true;error=null;notice=null;});
    try{
      final result=await widget.repository.enroll();
      if(mounted)setState(()=>enrollment=result);
    }catch(_){
      if(mounted)setState(()=>error=
        'Could not start authenticator setup. Check your session.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _confirm()async{
    final factor=enrollment;
    if(busy||factor==null)return;
    if(!RegExp(r'^\d{6}$').hasMatch(code.text.trim())){
      setState(()=>error='Enter the six-digit authenticator code.');
      return;
    }
    setState((){busy=true;error=null;});
    try{
      await widget.repository.verify(factor.factorId,code.text.trim());
      if(!mounted)return;
      code.clear();
      setState((){
        // Erase in-memory QR and shared secret immediately after enrollment.
        enrollment=null;
        notice='Two-factor authentication is enabled for this account. '
          'You will be asked for a code when signing in again.';
      });
      await _load();
      widget.onChanged?.call();
    }catch(_){
      if(mounted)setState(()=>error=
        'Code incorrect or expired. Use the current code in your '
        'authenticator app.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _cancel()async{
    final factor=enrollment;
    if(busy||factor==null)return;
    setState((){busy=true;error=null;});
    try {
      await widget.repository.cancelEnrollment(factor.factorId);
      if(mounted)setState((){
        enrollment=null;
        code.clear();
        notice='Unverified authenticator setup was cancelled.';
      });
    }catch(_){
      if(mounted)setState(()=>error='Could not cancel enrollment securely. '
        'Try again while connected.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _remove(AccountTotpFactor factor)async{
    if(busy||current?.isAal2!=true)return;
    final confirmed=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Remove authenticator?'),
        content:const Text('Removing this factor reduces sign-in security. '
          'If it is your only authenticator, two-factor verification will '
          'no longer be required.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Keep authenticator')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Remove factor')),
        ],
      ),
    );
    if(confirmed!=true||!mounted)return;
    setState((){busy=true;error=null;});
    try{
      await widget.repository.unenroll(factor.id);
      if(!mounted)return;
      setState(()=>notice='Authenticator removed from your account.');
      await _load();
      widget.onChanged?.call();
    }catch(_){
      if(mounted)setState(()=>error='Cannot remove this authenticator. '
        'Sign in with a verified code (AAL2) and retry.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Widget _setup(BuildContext context){
    final item=enrollment!;
    final colors=Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        const Text('Set up your authenticator app',
          style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
        const SizedBox(height:8),
        const Text('1. Open Google Authenticator, Microsoft Authenticator, '
          '1Password or another TOTP app. Scan this QR code from another '
          'device, or enter the setup key manually.'),
        const SizedBox(height:12),
        Center(child:Container(
          key:const Key('mfa-enrollment-qr'),
          padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:Colors.white,
            borderRadius:BorderRadius.circular(13)),
          child:QrImageView(
            data:item.otpauthUri,size:180,
            backgroundColor:Colors.white,
            errorCorrectionLevel:QrErrorCorrectLevel.M),
        )),
        const SizedBox(height:10),
        Text('Manual setup key (keep private)',
          style:TextStyle(fontSize:11,color:colors.onSurfaceVariant)),
        SelectableText(item.secret,
          key:const Key('mfa-enrollment-secret'),
          textAlign:TextAlign.center,
          style:const TextStyle(
            fontSize:16,letterSpacing:1.2,fontWeight:FontWeight.w800)),
        TextButton.icon(
          key:const Key('mfa-copy-secret'),
          onPressed:()=>Clipboard.setData(
            ClipboardData(text:item.secret)),
          icon:const Icon(Icons.copy_outlined),
          label:const Text('Copy setup key'),
        ),
        const SizedBox(height:12),
        const Text('2. Enter the current six-digit code from the '
          'authenticator app to finish enrollment.'),
        const SizedBox(height:10),
        TextField(
          key:const Key('mfa-enrollment-code'),
          controller:code,enabled:!busy,
          keyboardType:TextInputType.number,maxLength:6,
          decoration:const InputDecoration(
            labelText:'Authenticator code',hintText:'000000',
            counterText:'',prefixIcon:Icon(Icons.lock_outline)),
        ),
        const SizedBox(height:8),
        FilledButton.icon(
          key:const Key('mfa-enable-confirm'),
          onPressed:busy?null:_confirm,
          icon:const Icon(Icons.check_circle_outline),
          label:const Text('Verify code and enable 2FA')),
        TextButton(
          key:const Key('mfa-enrollment-cancel'),
          onPressed:busy?null:_cancel,
          child:const Text('Cancel setup')),
        Text('Do not screenshot, email, or share the QR code or setup key.',
          textAlign:TextAlign.center,
          style:TextStyle(
            color:colors.onSurfaceVariant,fontSize:11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context){
    final colors=Theme.of(context).colorScheme;
    final state=current;
    return Container(
      key:const Key('mfa-settings-card'),
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        border:Border.all(color:colors.outlineVariant),
        borderRadius:BorderRadius.circular(14),
        color:colors.surfaceContainerLow),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Row(children:[
            Icon(Icons.verified_user_outlined,color:colors.primary),
            const SizedBox(width:9),
            const Expanded(child:Text('Two-factor authentication',
              style:TextStyle(fontSize:17,fontWeight:FontWeight.w800))),
          ]),
          const SizedBox(height:9),
          const Text('Add a second layer of account security using '
            'time-based codes from an authenticator app.'),
          if(error!=null)Padding(
            padding:const EdgeInsets.symmetric(vertical:9),
            child:Text(error!,key:const Key('mfa-settings-error'),
              style:TextStyle(color:colors.error))),
          if(notice!=null)Padding(
            padding:const EdgeInsets.symmetric(vertical:9),
            child:Text(notice!,key:const Key('mfa-settings-notice'),
              style:TextStyle(color:colors.primary))),
          if(loading)
            const Padding(padding:EdgeInsets.all(12),
              child:Center(child:CircularProgressIndicator()))
          else if(enrollment!=null)
            _setup(context)
          else if(state!=null)...[
            Padding(padding:const EdgeInsets.symmetric(vertical:12),
              child:Text(state.factors.isEmpty
                ? 'Status: Not enabled'
                : 'Status: Enabled (' +
                  state.factors.length.toString()+' authenticator(s))',
                style:TextStyle(fontWeight:FontWeight.w800,
                  color:colors.primary))),
            for(var i=0;i<state.factors.length;i++)
              ListTile(
                dense:true,
                leading:const Icon(Icons.phone_android_outlined),
                title:Text('Authenticator '+(i+1).toString()),
                subtitle:const Text('Verified TOTP device'),
                trailing:TextButton(
                  key:Key('mfa-remove-factor-'+
                    state.factors[i].id),
                  onPressed:busy||!state.isAal2?null
                    :()=>_remove(state.factors[i]),
                  child:const Text('Remove')),
              ),
            const SizedBox(height:10),
            OutlinedButton.icon(
              key:const Key('mfa-enrollment-start'),
              onPressed:busy?null:_enroll,
              icon:const Icon(Icons.add_circle_outline),
              label:Text(state.factors.isEmpty
                ? 'Enable 2FA':'Add backup authenticator')),
            const SizedBox(height:6),
            const Text('Recommendation: add a second authenticator '
              'before changing devices. Supabase does not issue '
              'downloadable TOTP backup codes in this workflow.',
              style:TextStyle(fontSize:11)),
          ]else
            TextButton.icon(
              key:const Key('mfa-status-retry'),
              onPressed:_load,icon:const Icon(Icons.refresh),
              label:const Text('Retry checking security settings')),
        ],
      ),
    );
  }
}
