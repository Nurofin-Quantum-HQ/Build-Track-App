import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/design/design.dart';
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
    final heroH = (media.size.height * 0.36).clamp(240.0, 340.0);
    return Scaffold(
      backgroundColor: Bt.card,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: media.size.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero
              Container(
                height: heroH + 28,
                decoration: const BoxDecoration(color: Bt.ink),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.9, -0.9),
                            radius: 1.1,
                            colors: [const Color(0xFFB7791F).withValues(alpha: 0.45), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(1.0, 0.6),
                            radius: 1.0,
                            colors: [bt.brand.withValues(alpha: 0.55), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 20),
                            Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'Every bag, worker\nand rupee — '),
                                TextSpan(text: 'on track.', style: TextStyle(color: Color.lerp(bt.brand, Colors.white, 0.45))),
                              ]),
                              style: BtText.title(context, size: 30).copyWith(color: Colors.white, height: 1.15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sheet
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Bt.card,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildForm(),
                        const SizedBox(height: 8),
                        _buildActions(),
                      ],
                    ),
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
              width: 34,
              height: 34,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Image.network(
                'assets/images/buildtrack-logo.png',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('BuildTrack', style: BtText.title(context, size: 24).copyWith(color: Colors.white)),
      ],
    );
  }
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntryLabeled(
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
        const SizedBox(height: 20),
        EntryLabeled(
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
                icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Bt.ink3),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildActions() {
    final bt = context.bt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
            style: TextButton.styleFrom(foregroundColor: bt.brand, minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
            child: Text('Forgot password?', style: BtText.subhead(context, weight: FontWeight.w600, color: bt.brand)),
          ),
        ),
        const SizedBox(height: 12),
        BtButton(
          label: _loading ? 'Signing in…' : 'Sign in',
          loading: _loading,
          onPressed: _loading ? null : _login,
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('New here? ', style: BtText.body(context, color: Bt.ink2)),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/create-workspace'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Create a workspace', style: BtText.body(context, weight: FontWeight.w600, color: bt.brand)),
              ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildPoweredByNurofin() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Powered by', style: BtText.caption(context)),
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
      if (data != null) {
        if (mounted) {
          context.read<SubscriptionProvider>().fetchStatus();
          context.read<ProjectProvider>().load();
          await PushNotificationService.init();
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        throw Exception('Invalid login response');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Widget _buildFooter() {
    return Column(
      children: [
        _buildPoweredByNurofin(),
        const SizedBox(height: 6),
        Text('Privacy Policy · Terms of Service', style: BtText.caption(context)),
      ],
    );
  }
}
