import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _step2 = false;
  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: _step2 ? 'Set new password' : 'Reset password',
        trailing: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(_step2 ? 'STEP 2 OF 2' : 'STEP 1 OF 2', style: BtText.mono(context)),
        ),
        onBack: () {
          if (_step2) {
            setState(() => _step2 = false);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      bottomNavigationBar: BtCtaBar(vertical: true, children: [_buildActions()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          BtReveal(child: _buildArt()),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: Bt.medium,
            switchInCurve: Bt.ease,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(anim), child: child),
            ),
            child: Column(
              key: ValueKey(_step2),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _step2 ? _buildStep2Form() : _buildStep1Form(),
                const SizedBox(height: 20),
                _buildStepList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Noir card with the accent lock tile that pops in.
  Widget _buildArt() {
    final bt = context.bt;
    return BtCard(
      variant: BtCardVariant.ink,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 168,
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_step2),
            tween: Tween(begin: Bt.reduceMotion(context) ? 1 : .6, end: 1),
            duration: Bt.slow,
            curve: Bt.spring,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: bt.accent, borderRadius: BorderRadius.circular(24)),
              child: Icon(_step2 ? Icons.key_outlined : Icons.lock_reset_outlined, size: 32, color: bt.onAccent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _step2 ? 'Enter reset token' : 'Forgot your password?',
          style: BtText.d2(context),
        ),
        const SizedBox(height: 8),
        Text(
          _step2
              ? 'Copy the token from the reset link in your email and enter it below.'
              : 'Enter your email to receive a reset link.',
          style: BtText.body(context, color: Bt.ink2),
        ),
      ],
    );
  }

  /// 01 Get the link · 02 Paste token, set new password.
  Widget _buildStepList() {
    final bt = context.bt;
    Widget row(String n, String title, String sub, {required bool active, required bool done}) {
      return Opacity(
        opacity: active || done ? 1 : .55,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            SizedBox(width: 26, child: Text(n, style: BtText.mono(context, color: active ? bt.accentInk : Bt.ink3))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: BtText.body(context, weight: FontWeight.w500)),
                Text(sub, style: BtText.caption(context, color: Bt.ink2)),
              ]),
            ),
            if (done)
              const Icon(Icons.check_circle_rounded, color: Bt.green, size: 20)
            else if (active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: bt.accentSoft, borderRadius: BorderRadius.circular(99)),
                child: Text('Now', style: BtText.caption(context, color: bt.accentInk, weight: FontWeight.w600)),
              ),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Bt.rCard), border: Border.all(color: Bt.line)),
      child: Column(children: [
        row('01', 'Get the link', 'Sent to your inbox in a few seconds', active: !_step2, done: _step2),
        const Divider(height: 1, color: Bt.line, indent: 16, endIndent: 16),
        row('02', 'Paste token, set new password', 'At least 6 characters', active: _step2, done: false),
      ]),
    );
  }

  Widget _buildStep1Form() {
    return EntryLabeled(
      label: 'Email address',
      child: TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        style: BtText.body(context),
        decoration: btInput(context, hint: 'name@company.com'),
      ),
    );
  }
  Widget _buildStep2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntryLabeled(
          label: 'Reset token',
          child: TextField(
            controller: _tokenCtrl,
            style: BtText.body(context),
            decoration: btInput(context, hint: 'Paste token from email link'),
          ),
        ),
        const SizedBox(height: 20),
        EntryLabeled(
          label: 'New password',
          child: TextField(
            controller: _newPassCtrl,
            obscureText: _obscurePass,
            style: BtText.body(context),
            decoration: btInput(
              context,
              hint: 'At least 6 characters',
              suffix: IconButton(
                tooltip: _obscurePass ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Bt.ink2),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtButton(
          label: _step2 ? 'Set New Password' : 'Send Reset Link',
          loading: _isLoading,
          onPressed: _isLoading ? null : (_step2 ? _onSetPassword : _onSendLink),
        ),
        const SizedBox(height: 4),
        BtButton(
          label: _step2 ? 'Back' : 'Back to login',
          variant: BtButtonVariant.quiet,
          onPressed: () {
            if (_step2) {
              setState(() => _step2 = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
  Future<void> _onSendLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Please enter a valid email address', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      try {
        await ApiService.get('/health');
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
      final token = await ApiService.resetPassword(email);
      if (!mounted) return;
      _showSnack('Reset link sent! Check your email.');
      setState(() {
        _step2 = true;
        if (token != null) _tokenCtrl.text = token;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> _onSetPassword() async {
    final token = _tokenCtrl.text.trim();
    final password = _newPassCtrl.text.trim();
    if (token.isEmpty) {
      _showSnack('Please paste the token from your email', isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService.confirmResetPassword(token: token, password: password);
      if (!mounted) return;
      _showSnack('Password reset successfully! Please log in.');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFC01048) : const Color(0xFF067647),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
