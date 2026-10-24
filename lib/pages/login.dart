import 'dart:async';
import 'package:buildtrack_mobile/controller/theme_provider.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/services/auth_service.dart';
import 'package:buildtrack_mobile/services/push_notification_service.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCachedEmail();
  }

  Future<void> _loadCachedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedEmail = prefs.getString('cached_email');
    if (cachedEmail != null && cachedEmail.isNotEmpty) {
      if (mounted) {
        setState(() {
          _emailCtrl.text = cachedEmail;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final media = MediaQuery.of(context);
    final heroH = (media.size.height * 0.44).clamp(300.0, 400.0);
    return Scaffold(
      backgroundColor: Bt.ground,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: media.size.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Noir hero — mark + promise.
              BtHero(
                minHeight: heroH,
                padding: EdgeInsets.fromLTRB(24, media.padding.top + 28, 24, 30 + 26),
                child: SizedBox(
                  height: heroH - media.padding.top - 28 - 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BtReveal(child: _buildHeader()),
                      const Spacer(),
                      BtReveal(
                        index: 1,
                        child: Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Every bag, worker\nand rupee — '),
                            TextSpan(text: 'on track.', style: TextStyle(color: bt.accent)),
                          ]),
                          style: BtText.d1(context, color: Bt.bone),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bone sheet with the form.
              BtSheet(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildForm(),
                      const SizedBox(height: 4),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
              SizedBox(height: media.padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/images/buildtrack-logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Image.network(
                'assets/images/buildtrack-logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('BuildTrack', style: BtText.d3(context, color: Bt.bone)),
      ],
    );
  }
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtReveal(
          index: 2,
          child: BtField(
            label: 'Work email',
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              style: BtText.body(context),
              decoration: btInput(context, hint: 'you@company.com'),
            ),
          ),
        ),
        const SizedBox(height: 18),
        BtReveal(
          index: 3,
          child: BtField(
            label: 'Password',
            child: TextField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _login(),
              style: BtText.body(context),
              decoration: btInput(
                context,
                hint: 'Your password',
                suffix: IconButton(
                  tooltip: _obscurePass ? 'Show password' : 'Hide password',
                  icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Bt.ink2),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildActions() {
    final bt = context.bt;
    return BtReveal(
      index: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
              style: TextButton.styleFrom(foregroundColor: bt.accentInk, minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
              child: Text('Forgot password?', style: BtText.subhead(context, weight: FontWeight.w600, color: bt.accentInk)),
            ),
          ),
          const SizedBox(height: 8),
          BtButton(
            label: _loading ? 'Signing in…' : 'Sign in',
            loading: _loading,
            onPressed: _loading ? null : _login,
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('New here? ', style: BtText.body(context, color: Bt.ink2)),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/create-workspace'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Create a workspace',
                    style: BtText.body(context, weight: FontWeight.w600).copyWith(decoration: TextDecoration.underline, decorationColor: Bt.ink, decorationThickness: 1.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildPoweredByNurofin() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('POWERED BY', style: BtText.mono(context)),
        const SizedBox(width: 6),
        Image.asset(
          'assets/images/nurofin-logo.png',
          height: 16,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Image.network(
            'assets/images/nurofin-logo.png',
            height: 16,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter email and password')));
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await AuthService.login(email, password);
      if (data == null) throw Exception('Invalid login response');
      if (!mounted) return;
      // Fresh account data: plan, projects, theme (from the account's
      // themePreference). None of these may block sign-in.
      context.read<SubscriptionProvider>().fetchStatus();
      context.read<ProjectProvider>().load();
      context.read<ThemeProvider>().reload();
      // Push registration must never stop the user getting in (it threw on
      // iOS and left them on this screen although signed in).
      PushNotificationService.init().catchError((Object e) {
        debugPrint('Push init after login failed: $e');
      });
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loginErrorText(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _loginErrorText(Object e) {
    final msg = e.toString().replaceAll('Exception: ', '');
    if (msg == 'Unauthorized') return 'Invalid email or password';
    if (e is TimeoutException || e is http.ClientException || msg.contains('SocketException')) {
      return "Can't reach the server. Check your connection and try again.";
    }
    return msg;
  }
  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildPoweredByNurofin(),
        const SizedBox(height: 6),
        Text('PRIVACY POLICY · TERMS OF SERVICE', style: BtText.mono(context)),
      ],
    );
  }
}
