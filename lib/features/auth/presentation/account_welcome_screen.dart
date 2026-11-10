import 'package:flutter/material.dart';

import '../../../core/settings/appearance_settings_button.dart';
import '../data/account_auth_gateway.dart';
import 'school_campus_illustration.dart';

/// Step 1 / 6: an adaptive *app* screen, not a website template.
/// No school/organization privileges follow from simply signing in.
class AccountWelcomeScreen extends StatefulWidget {
  const AccountWelcomeScreen({
    super.key,
    required this.auth,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final AccountAuthGateway auth;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;

  @override
  State<AccountWelcomeScreen> createState() => _AccountWelcomeScreenState();
}

class _AccountWelcomeScreenState extends State<AccountWelcomeScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailExpanded = false;
  bool _emailSent = false;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _resetErrors() => setState(() {
        _error = null;
        _message = null;
      });

  Future<void> _google() async {
    if (_busy) return;
    _resetErrors();
    setState(() => _busy = true);
    try {
      await widget.auth.signInWithGoogle();
      if (!mounted) return;
      setState(() => _message =
          'Finish signing in with Google in your browser to continue.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Google sign-in could not start. Check your connection and '
          'the Google provider configuration, then try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _email() async {
    if (_busy || !_emailKey.currentState!.validate()) return;
    _resetErrors();
    setState(() => _busy = true);
    try {
      await widget.auth.sendEmailLink(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _emailSent = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'We could not send your sign-in email. Check the address, '
          'email delivery setup, and try again shortly.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF091B23) : const Color(0xFFF0F7F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            if (desktop) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Container(
                      key: const Key('onboarding-desktop-layout'),
                      height: 800,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(color: colors.outlineVariant),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: dark ? .28 : .09),
                          blurRadius: 56,
                          offset: const Offset(0, 18),
                        )],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF11343B)
                                    : const Color(0xFFEAF8F3),
                              ),
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _BrandHeader(),
                                  const SizedBox(height: 50),
                                  _welcomeCopy(desktop: true),
                                  const SizedBox(height: 30),
                                  const SchoolCampusIllustration(),
                                  const SizedBox(height: 36),
                                  const _StepProgress(),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 11,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(34),
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: AppearanceSettingsButton(
                                      mode: widget.themeMode,
                                      onChanged: widget.onThemeChanged,
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28, vertical: 44),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(
                                          color: colors.outlineVariant),
                                      boxShadow: [BoxShadow(
                                        color: Colors.black.withValues(alpha: .055),
                                        blurRadius: 35,
                                        offset: const Offset(0, 15),
                                      )],
                                    ),
                                    child: _authPanel(),
                                  ),
                                  const SizedBox(height: 28),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              key: const Key('onboarding-mobile-layout'),
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 380 ? 16 : 22,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(child: _BrandHeader(compact: true)),
                          AppearanceSettingsButton(
                            mode: widget.themeMode,
                            onChanged: widget.onThemeChanged,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const _StepProgress(compact: true),
                      const SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 380 ? 22 : 30,
                          vertical: 34,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: colors.outlineVariant),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: dark ? .2 : .065),
                            blurRadius: 36,
                            offset: const Offset(0, 14),
                          )],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _welcomeCopy(desktop: false),
                            const SizedBox(height: 18),
                            const SchoolCampusIllustration(),
                            const SizedBox(height: 26),
                            _authPanel(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _welcomeCopy({required bool desktop}) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to\nPohantoon AI',
          key: const Key('welcome-heading'),
          style: (desktop ? text.displayMedium : text.headlineLarge)
              ?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.09,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          desktop
              ? 'Set up your school, manage your institution, and bring your '
                  'entire school community together with a modern, '
                  'AI-powered platform.'
              : 'Build efficient, data-driven, and modern school '
                  'operations in minutes.',
          style: (desktop ? text.titleMedium : text.bodyLarge)?.copyWith(
            color: muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _authPanel() {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Create Your School Account',
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Sign in securely with Google or email to begin registering your school.',
          style: text.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant, height: 1.55,
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          key: const Key('continue-with-google'),
          onPressed: _busy ? null : _google,
          style: OutlinedButton.styleFrom(
            backgroundColor: colors.surface,
            foregroundColor: colors.onSurface,
            side: BorderSide(color: colors.outlineVariant),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _GoogleMark(),
              const SizedBox(width: 14),
              Flexible(child: Text('Continue with Google',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              )),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Divider(color: colors.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('OR', style: text.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              )),
            ),
            Expanded(child: Divider(color: colors.outlineVariant)),
          ],
        ),
        const SizedBox(height: 18),
        if (!_emailExpanded)
          OutlinedButton.icon(
            key: const Key('continue-with-email'),
            onPressed: _busy ? null : () => setState(() => _emailExpanded = true),
            icon: const Icon(Icons.mail_outline),
            label: const Text('Continue with email'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              minimumSize: const Size.fromHeight(54),
            ),
          )
        else if (_emailSent)
          Container(
            key: const Key('email-sent-confirmation'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mark_email_read_outlined, color: colors.primary),
                const SizedBox(height: 10),
                const Text('Check your email',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('If your address is eligible, you will receive a '
                    'sign-in link. Open it to continue.'),
                TextButton(
                  onPressed: () => setState(() => _emailSent = false),
                  child: const Text('Use a different email'),
                ),
              ],
            ),
          )
        else
          Form(
            key: _emailKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('email-field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Your email address',
                    prefixIcon: Icon(Icons.mail_outline),
                    hintText: 'you@school.edu',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Enter your email address';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) return 'Enter a valid email address';
                    return null;
                  },
                  onFieldSubmitted: (_) => _email(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('send-email-link'),
                  onPressed: _busy ? null : _email,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send sign-in link'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                ),
              ],
            ),
          ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator(
            key: Key('auth-loading-indicator'))),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, key: const Key('auth-error-message'),
            style: TextStyle(color: colors.error)),
        ],
        if (_message != null) ...[
          const SizedBox(height: 16),
          Text(_message!, key: const Key('auth-information-message'),
            style: TextStyle(color: colors.primary)),
        ],
        const SizedBox(height: 28),
        Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.verified_user_outlined, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Your school information is kept secure.',
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/app_logo/app_icon.jpeg',
            width: compact ? 52 : 72,
            height: compact ? 52 : 72,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.school_rounded, size: compact ? 45 : 62),
          ),
        ),
        const SizedBox(width: 13),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pohantoon AI',
                style: (compact ? text.titleLarge : text.headlineMedium)
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.65,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text('Smarter School Management, Powered by AI',
                style: text.bodySmall?.copyWith(color: muted),
                maxLines: 2),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(compact ? 'STEP 1 OF 6 · CREATE ACCOUNT'
            : 'Step 1 of 6 · Create Account',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: LinearProgressIndicator(
            key: const Key('onboarding-progress'),
            value: 1 / 6,
            minHeight: compact ? 10 : 12,
            backgroundColor: colors.primary.withValues(alpha: .13),
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
      ],
    );
  }
}

/// Multicolor G mark approximated with styled text, without an external asset.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => const LinearGradient(
      colors: [
        Color(0xFF4285F4), Color(0xFFEA4335),
        Color(0xFFFBBC05), Color(0xFF34A853),
      ],
    ).createShader(bounds),
    child: const Text('G', style: TextStyle(
      fontSize: 27, fontWeight: FontWeight.w900, height: 1)),
  );
}
