import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/services/auth_service.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  static const _bgColor = Color(0xFFF0EEFF);
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;
  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: _bgColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 24 + bottomInset),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
                    margin: EdgeInsets.zero,
                    borderRadius: 28,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: AppTheme.spacingXl),
                        _buildForm(),
                        const SizedBox(height: AppTheme.spacingLg),
                        _buildActions(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/buildtrack-logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Image.network(
                  'assets/images/buildtrack-logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('BuildTrack', style: AppTheme.heading1.copyWith(fontSize: 30)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Manage your construction smarter',
          style: AppTheme.body.copyWith(color: AppColors.textLight),
        ),
      ],
    );
  }
  Widget _buildForm() {
    return Column(
      children: [
        AppTextField(
          label: 'Email Address',
          controller: _emailCtrl,
          hint: 'name@company.com',
          prefixIcon: Icons.mail_outline,
        ),
        AppTextField(
          label: 'Password',
          controller: _passCtrl,
          hint: 'Enter your password',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscurePass,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
      ],
    );
  }
  Widget _buildActions() {
    return Column(
      children: [
        AppButton(
          label: _loading ? 'Signing in...' : 'Sign In',
          onPressed: _loading ? null : _login,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/forgot-password'),
            child: Text(
              'Forgot password?',
              style: AppTheme.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: AppTheme.body.copyWith(color: AppColors.textLight),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/create-workspace'),
              child: Text(
                'Create account',
                style: AppTheme.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _buildPoweredByNurofin(),
      ],
    );
  }
  Widget _buildPoweredByNurofin() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Powered by',
            style: AppTheme.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/nurofin-logo.png',
            height: 18,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Image.network(
              'assets/images/nurofin-logo.png',
              height: 18,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
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
    return Text('Privacy Policy • Terms of Service', style: AppTheme.caption);
  }
}
