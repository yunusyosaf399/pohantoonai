import 'package:flutter/material.dart';

import '../data/account_mfa_repository.dart';

/// Exclusive login gate: AAL1 may not display any protected workspace while
/// a verified authenticator requires upgrading the session to AAL2.
class AccountMfaChallengeScreen extends StatefulWidget {
  const AccountMfaChallengeScreen({
    super.key,required this.repository,
    required this.onVerified,required this.onSignOut,
  });
  final AccountMfaRepository repository;
  final Future<void> Function() onVerified;
  final Future<void> Function() onSignOut;
  @override
  State<AccountMfaChallengeScreen> createState()=>_AccountMfaChallengeScreenState();
}

class _AccountMfaChallengeScreenState
    extends State<AccountMfaChallengeScreen> {
  final code=TextEditingController();
  bool busy=true;
  List<AccountTotpFactor> factors=const [];
  String? selectedFactor,error;

  @override
  void initState(){super.initState();_load();}

  Future<void> _load()async{
    try{
      final s=await widget.repository.status();
      if(!mounted)return;
      if(!s.needsChallenge&&s.isAal2){
        await widget.onVerified();
        return;
      }
      setState((){
        factors=s.factors;
        selectedFactor=factors.isEmpty?null:factors.first.id;
        busy=false;
        if(factors.isEmpty) error='No verified authenticator is available. '
          'Contact your administrator for account recovery.';
      });
    }catch(_){
      if(mounted)setState((){
        busy=false;
        error='Could not check your 2FA settings. Check the connection and retry.';
      });
    }
  }

  Future<void> _verify()async{
    if(busy)return;
    if(selectedFactor==null||!RegExp(r'^\d{6}$').hasMatch(code.text.trim())){
      setState(()=>error='Enter the six-digit code from your authenticator.');
      return;
    }
    setState((){busy=true;error=null;});
    try{
      await widget.repository.verify(selectedFactor!,code.text.trim());
      code.clear();
      if(mounted)await widget.onVerified();
    }catch(_){
      if(mounted)setState(()=>error='Invalid or expired code. '
        'Use the current code in your authenticator app.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _signOut()async{
    setState((){busy=true;error=null;});
    try{await widget.onSignOut();}
    catch(_){if(mounted)setState(()=>error='Could not sign out. Retry online.');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  @override
  void dispose(){code.dispose();super.dispose();}

  @override
  Widget build(BuildContext context){
    final colors=Theme.of(context).colorScheme;
    return Scaffold(
      key:const Key('mfa-login-challenge-screen'),
      backgroundColor:Theme.of(context).brightness==Brightness.dark
        ?const Color(0xFF071B23):const Color(0xFFF3F8F8),
      body:SafeArea(child:Center(child:SingleChildScrollView(
        padding:const EdgeInsets.all(18),
        child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:470),
          child:Card(child:Padding(
            padding:const EdgeInsets.all(24),
            child:Column(
              mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.stretch,
              children:[
                Row(children:[
                  Icon(Icons.verified_user_outlined,
                    size:36,color:colors.primary),
                  const SizedBox(width:12),
                  const Expanded(child:Text('Pohantoon AI',
                    style:TextStyle(fontSize:21,fontWeight:FontWeight.w800))),
                ]),
                const SizedBox(height:22),
                Text('Two-factor verification',
                  style:Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight:FontWeight.w800)),
                const SizedBox(height:10),
                const Text('Enter the current code from your authenticator '
                  'app to continue to your school dashboard.'),
                const SizedBox(height:18),
                if(factors.length>1)DropdownButtonFormField<String>(
                  key:const Key('mfa-login-factor-selector'),
                  value:selectedFactor,
                  decoration:const InputDecoration(labelText:'Authenticator'),
                  items:[
                    for(var i=0;i<factors.length;i++)
                      DropdownMenuItem(
                        value:factors[i].id,
                        child:Text('Authenticator '+(i+1).toString())),
                  ],
                  onChanged:busy?null:(v)=>setState(()=>selectedFactor=v),
                ),
                TextField(
                  key:const Key('mfa-login-code'),
                  controller:code,enabled:!busy&&factors.isNotEmpty,
                  maxLength:6,keyboardType:TextInputType.number,
                  autofillHints:const [AutofillHints.oneTimeCode],
                  decoration:const InputDecoration(
                    labelText:'Six-digit authenticator code',
                    hintText:'000000',prefixIcon:Icon(Icons.lock_outline),
                    counterText:''),
                  onSubmitted:(_)=>_verify(),
                ),
                if(error!=null)Padding(
                  padding:const EdgeInsets.only(top:8),
                  child:Text(error!,key:const Key('mfa-login-error'),
                    style:TextStyle(color:colors.error))),
                const SizedBox(height:16),
                FilledButton.icon(
                  key:const Key('mfa-login-verify'),
                  onPressed:busy||factors.isEmpty?null:_verify,
                  icon:busy
                    ?const SizedBox(width:18,height:18,
                        child:CircularProgressIndicator(strokeWidth:2))
                    :const Icon(Icons.lock_open_outlined),
                  label:const Text('Verify and continue'),
                ),
                const SizedBox(height:8),
                TextButton.icon(
                  key:const Key('mfa-login-sign-out'),
                  onPressed:busy?null:_signOut,
                  icon:const Icon(Icons.logout),
                  label:const Text('Sign out'),
                ),
                const SizedBox(height:10),
                Text('Your school data remains hidden until the second '
                  'factor has been verified.',
                  textAlign:TextAlign.center,
                  style:TextStyle(fontSize:11,
                    color:colors.onSurfaceVariant)),
              ],
            ),
          )),
        ),
      ))),
    );
  }
}
