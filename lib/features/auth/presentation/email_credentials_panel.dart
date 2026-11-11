import 'package:flutter/material.dart';

import '../data/account_auth_gateway.dart';

/// Built-in Supabase Auth code delivery, verification and password storage.
/// Never use an app-owned table or Edge Function to keep OTPs or passwords.
class EmailCredentialsPanel extends StatefulWidget {
  const EmailCredentialsPanel({super.key,required this.auth});
  final AccountEmailCredentials auth;

  @override
  State<EmailCredentialsPanel> createState() => _EmailCredentialsPanelState();
}

class _EmailCredentialsPanelState extends State<EmailCredentialsPanel> {
  final keyForm=GlobalKey<FormState>();
  final email=TextEditingController();
  final password=TextEditingController();
  final confirm=TextEditingController();
  final code=TextEditingController();
  String mode='register';
  bool busy=false,showPassword=false;
  String? feedback,error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    code.dispose();
    super.dispose();
  }

  void _setMode(String next) => setState(() {
    mode=next;
    error=null;feedback=null;code.clear();password.clear();confirm.clear();
  });

  Future<void> _submit() async {
    if(busy) return;
    if(mode!='verify' && mode!='verify_login' &&
       !keyForm.currentState!.validate()) return;
    if((mode=='verify'||mode=='verify_login') &&
      !RegExp(r'^\d{6,8}$').hasMatch(code.text.trim())) {
      setState(()=>error='Enter the 6–8 digit code from your email.');
      return;
    }
    setState(() { busy=true;error=null;feedback=null; });
    try {
      switch(mode) {
        case 'register':
          await widget.auth.signUpWithPassword(
            email.text.trim(),password.text);
          if(mounted) {
            _setMode('verify');
            setState(()=>feedback='Check your inbox for a verification code. '
              'Do not share it. If you received a confirmation link, '
              'open it instead. Code delivery requires the Supabase '
              'Confirm signup email template to include {{ .Token }}.');
          }
        case 'login':
          await widget.auth.signInWithPassword(
            email.text.trim(),password.text);
        case 'verify':
          await widget.auth.verifyEmailCode(
            email.text.trim(),code.text.trim(),isSignup:true);
        case 'verify_login':
          await widget.auth.verifyEmailCode(
            email.text.trim(),code.text.trim(),isSignup:false);
        case 'forgot':
          await widget.auth.sendPasswordReset(email.text.trim());
          if(mounted) setState(()=>feedback=
            'If the email exists, a password-reset message will arrive.');
      }
    } catch (_) {
      if(mounted) setState(() => error = switch(mode) {
        'login' => 'Sign-in failed. Check your credentials '
          'and verify your email first.',
        'register' => 'Could not register. Check the address or try sign in.',
        'verify' || 'verify_login' => 'Code invalid or expired. '
          'Request a new verification code.',
        _ => 'Could not send email. Retry after a short delay.',
      });
    } finally {
      if(mounted) setState(()=>busy=false);
    }
  }

  Future<void> _resend() async {
    if(busy)return;
    setState(() {busy=true;feedback=null;error=null;});
    try {
      await widget.auth.resendSignupCode(email.text.trim());
      if(mounted)setState(()=>feedback=
        'Verification email requested. Check your inbox and spam folder.');
    } catch (_) {
      if(mounted)setState(()=>error='Could not resend. '
        'Please wait before trying again.');
    } finally {
      if(mounted)setState(()=>busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors=Theme.of(context).colorScheme;
    final verifying=mode=='verify'||mode=='verify_login';
    return Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        if(!verifying) SegmentedButton<String>(
          key:const Key('email-auth-modes'),
          selected:{mode=='forgot'?'login':mode},
          onSelectionChanged:(s)=>_setMode(s.first),
          segments:const [
            ButtonSegment(value:'register',label:Text('Create account')),
            ButtonSegment(value:'login',label:Text('Sign in')),
          ]),
        const SizedBox(height:14),
        if(verifying)
          Text('Verify your email address',
            style:Theme.of(context).textTheme.titleMedium),
        Form(
          key:keyForm,
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              TextFormField(
                key:const Key('email-field'),
                controller:email,
                readOnly:verifying,
                keyboardType:TextInputType.emailAddress,
                autofillHints:const [AutofillHints.email],
                decoration:const InputDecoration(
                  labelText:'Email address',
                  prefixIcon:Icon(Icons.mail_outline)),
                validator:(value)=>RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                  .hasMatch(value?.trim()??'')
                  ? null:'Enter a valid email address',
              ),
              if(!verifying && mode!='forgot') ...[
                const SizedBox(height:11),
                TextFormField(
                  key:const Key('email-password-field'),
                  controller:password,
                  obscureText:!showPassword,
                  enableSuggestions:false,autocorrect:false,
                  autofillHints:[mode=='register'
                    ? AutofillHints.newPassword : AutofillHints.password],
                  decoration:InputDecoration(
                    labelText:mode=='register'
                      ? 'Create password':'Password',
                    prefixIcon:const Icon(Icons.lock_outline),
                    suffixIcon:IconButton(
                      tooltip:showPassword?'Hide password':'Show password',
                      onPressed:()=>setState(()=>
                        showPassword=!showPassword),
                      icon:Icon(showPassword?Icons.visibility_off:
                        Icons.visibility))),
                  validator:(v) => mode=='register' &&
                    (v==null||v.length<12)
                    ? 'Use at least 12 characters'
                    : (v==null||v.isEmpty) ? 'Enter your password':null,
                ),
                if(mode=='register') ...[
                  const SizedBox(height:11),
                  TextFormField(
                    key:const Key('email-confirm-password'),
                    controller:confirm,
                    obscureText:!showPassword,
                    enableSuggestions:false,autocorrect:false,
                    decoration:const InputDecoration(
                      labelText:'Confirm password',
                      prefixIcon:Icon(Icons.verified_user_outlined)),
                    validator:(v)=>v==password.text
                      ? null:'Passwords do not match',
                  ),
                ],
              ],
              if(verifying) ...[
                const SizedBox(height:12),
                TextFormField(
                  key:const Key('email-verification-code'),
                  controller:code,
                  keyboardType:TextInputType.number,
                  maxLength:8,
                  decoration:const InputDecoration(
                    labelText:'Email verification code',
                    prefixIcon:Icon(Icons.password_outlined),
                    counterText:'',
                    hintText:'Enter code'),
                ),
              ],
              const SizedBox(height:12),
              FilledButton.icon(
                key:Key(verifying?'verify-email-code':
                  mode=='register'?'email-register-password':
                  mode=='forgot'?'email-reset-password':
                  'email-login-password'),
                onPressed:busy?null:_submit,
                icon:Icon(verifying?Icons.verified_outlined:
                  mode=='register'?Icons.person_add_alt_1:
                  Icons.login),
                label:Text(verifying?'Verify email and continue':
                  mode=='register'?'Create account & send code':
                  mode=='forgot'?'Email password reset':
                  'Sign in with password'),
              ),
              if(verifying) ...[
                TextButton(
                  key:const Key('resend-email-code'),
                  onPressed:busy?null:_resend,
                  child:const Text('Resend verification code')),
                TextButton(
                  onPressed:()=>_setMode('register'),
                  child:const Text('Change email address')),
              ] else if(mode=='login')...[
                TextButton(
                  key:const Key('forgot-email-password'),
                  onPressed:()=>_setMode('forgot'),
                  child:const Text('Forgot password?')),
              ] else if(mode=='forgot')...[
                TextButton(
                  onPressed:()=>_setMode('login'),
                  child:const Text('Back to sign in')),
              ],
            ],
          ),
        ),
        if(busy)const Padding(
          padding:EdgeInsets.all(12),
          child:Center(child:CircularProgressIndicator())),
        if(error!=null)
          Text(error!,key:const Key('email-auth-error'),
            style:TextStyle(color:colors.error)),
        if(feedback!=null)
          Text(feedback!,key:const Key('email-auth-feedback'),
            style:TextStyle(fontSize:12,color:colors.primary)),
      ],
    );
  }
}
