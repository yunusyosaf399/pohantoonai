import 'package:flutter/material.dart';

import '../data/account_auth_gateway.dart';

/// The recovery callback must NEVER display a normal signed-in workspace.
/// This is an exclusive MaterialApp.home screen, not a dialog layered over
/// an authenticated school/student dashboard.
///
/// The caller signs out the temporary recovery session on BOTH success and
/// cancellation, then returns to regular account sign-in.
class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    required this.auth,
    required this.onComplete,
    required this.onCancel,
    this.recoveryEmail,
  });

  final AccountEmailCredentials auth;
  final Future<void> Function() onComplete;
  final Future<void> Function() onCancel;
  /// Non-null only for the in-app email-code recovery path.
  /// Null means Supabase already verified a signed recovery deep link.
  final String? recoveryEmail;

  @override
  State<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final password=TextEditingController();
  final confirm=TextEditingController();
  final code=TextEditingController();
  bool otpVerified=false;
  bool busy=false;
  bool updated=false;
  String? error;

  @override
  void initState() {
    super.initState();
    otpVerified=widget.recoveryEmail==null;
  }

  @override
  void dispose(){
    password.dispose();
    confirm.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _verifyRecoveryCode() async {
    if(busy||widget.recoveryEmail==null)return;
    if(!RegExp(r'^\d{6,8}$').hasMatch(code.text.trim())) {
      setState(()=>error='Enter the verification code sent to your email.');
      return;
    }
    setState((){busy=true;error=null;});
    try {
      await widget.auth.verifyRecoveryOtp(
        widget.recoveryEmail!,code.text.trim());
      if(!mounted)return;
      code.clear();
      setState(()=>otpVerified=true);
    }catch(_){
      if(mounted)setState(()=>error='Invalid or expired recovery code. '
        'Request a new code and try again.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _resendCode() async {
    if(busy||widget.recoveryEmail==null)return;
    setState((){busy=true;error=null;});
    try {
      await widget.auth.sendPasswordReset(widget.recoveryEmail!);
      if(mounted)setState(()=>error='If the address is registered, '
        'a new recovery code was requested.');
    }catch(_){
      if(mounted)setState(()=>error='Could not request a new code. '
        'Wait before trying again.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _save() async {
    if(busy||!otpVerified)return;
    if(!updated && (password.text.length<12 ||
       password.text!=confirm.text)) {
      setState(()=>error='Enter matching passwords of at least 12 characters.');
      return;
    }
    setState((){busy=true;error=null;});
    try {
      if(!updated) {
        await widget.auth.setAccountPassword(password.text);
        if(!mounted)return;
        // Temporary password-recovery sessions are never school logins.
        updated=true;
        password.clear();
        confirm.clear();
      }
      await widget.onComplete();
    }catch(_){
      if(!mounted)return;
      setState(()=>error=updated
        ? 'Password updated, but secure sign-out could not finish. '
          'Retry closing the recovery session.'
        : 'Could not update the password. Try a fresh recovery code.');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _cancel() async {
    if(busy)return;
    setState((){busy=true;error=null;});
    try {
      await widget.onCancel();
    } catch (_) {
      if(mounted)setState(()=>error=
        'Secure sign-out failed. Try again before leaving recovery.');
    } finally {
      if(mounted)setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme=Theme.of(context).colorScheme;
    final dark=Theme.of(context).brightness==Brightness.dark;
    return Scaffold(
      key:const Key('password-recovery-only-screen'),
      backgroundColor:dark?const Color(0xFF081C26)
          :const Color(0xFFF3F8F8),
      body:SafeArea(child:Center(child:SingleChildScrollView(
        padding:const EdgeInsets.symmetric(horizontal:20,vertical:30),
        child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:470),
          child:Card(
            elevation:0,
            child:Padding(
              padding:const EdgeInsets.all(25),
              child:Column(
                mainAxisSize:MainAxisSize.min,
                crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  Row(children:[
                    Icon(Icons.lock_outline,
                      size:35,color:scheme.primary),
                    const SizedBox(width:12),
                    const Expanded(child:Text('Pohantoon AI',
                      style:TextStyle(fontSize:21,
                        fontWeight:FontWeight.w800))),
                  ]),
                  const SizedBox(height:24),
                  Text(!otpVerified?'Verify recovery code'
                      :updated?'Password updated'
                      :'Reset your password',
                    style:Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight:FontWeight.w800)),
                  const SizedBox(height:9),
                  Text(!otpVerified
                    ? 'Enter the one-time code from the Pohantoon AI '
                      'password reset email. No link or browser is required.'
                    :updated
                    ? 'Your password was changed. Close this recovery '
                      'session to return to normal sign-in.'
                    : 'Set a new password to secure your account. '
                      'Your school dashboard is unavailable while '
                      'this recovery session is active.',
                    style:TextStyle(color:scheme.onSurfaceVariant)),
                  if(!otpVerified)...[
                    const SizedBox(height:19),
                    TextField(
                      key:const Key('recovery-email-otp'),
                      controller:code,
                      enabled:!busy,
                      maxLength:8,
                      keyboardType:TextInputType.number,
                      autofillHints:const [AutofillHints.oneTimeCode],
                      decoration:const InputDecoration(
                        labelText:'Email recovery code',
                        hintText:'Enter the code',
                        prefixIcon:Icon(Icons.mail_outline),
                        counterText:'',
                      ),
                    ),
                    const SizedBox(height:8),
                    FilledButton.icon(
                      key:const Key('recovery-verify-otp'),
                      onPressed:busy?null:_verifyRecoveryCode,
                      icon:const Icon(Icons.verified_user_outlined),
                      label:const Text('Verify recovery code')),
                    TextButton(
                      key:const Key('recovery-resend-otp'),
                      onPressed:busy?null:_resendCode,
                      child:const Text('Resend recovery code')),
                  ],
                  if(otpVerified&&!updated)...[
                    const SizedBox(height:19),
                    TextField(
                      key:const Key('recovery-new-password'),
                      controller:password,
                      obscureText:true,
                      autocorrect:false,
                      enableSuggestions:false,
                      autofillHints:const [AutofillHints.newPassword],
                      decoration:const InputDecoration(
                        labelText:'New password',
                        prefixIcon:Icon(Icons.lock_outline),
                        helperText:'At least 12 characters'),
                    ),
                    const SizedBox(height:12),
                    TextField(
                      key:const Key('recovery-confirm-password'),
                      controller:confirm,
                      obscureText:true,
                      autocorrect:false,
                      enableSuggestions:false,
                      decoration:const InputDecoration(
                        labelText:'Confirm password',
                        prefixIcon:Icon(Icons.verified_user_outlined)),
                    ),
                  ],
                  if(error!=null)...[
                    const SizedBox(height:15),
                    Text(error!,key:const Key('recovery-error'),
                      style:TextStyle(color:scheme.error)),
                  ],
                  const SizedBox(height:19),
                  if(otpVerified)FilledButton.icon(
                    key:const Key('recovery-save-password'),
                    onPressed:busy?null:_save,
                    icon:busy
                      ? const SizedBox(width:18,height:18,
                          child:CircularProgressIndicator(strokeWidth:2))
                      : Icon(updated?Icons.logout:Icons.password_outlined),
                    label:Text(updated
                      ? 'Finish secure sign-out':'Save new password'),
                  ),
                  const SizedBox(height:8),
                  OutlinedButton(
                    key:const Key('recovery-cancel-and-signout'),
                    onPressed:busy?null:_cancel,
                    child:const Text('Cancel and sign out')),
                  const SizedBox(height:15),
                  Text('For your security, password recovery '
                    'never opens the school or student dashboard.',
                    textAlign:TextAlign.center,
                    style:TextStyle(fontSize:11,
                      color:scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ))),
    );
  }
}
