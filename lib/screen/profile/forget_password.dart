import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_layout.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
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
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - 160;
    return AppSubScreenLayout(
      title: 'Reset Password',
      scrollable: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: availableHeight),
        child: Center(
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
            margin: EdgeInsets.zero,
            borderRadius: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: AppTheme.spacingXl),
                _step2 ? _buildStep2Form() : _buildStep1Form(),
                const SizedBox(height: AppTheme.spacingLg),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_reset_outlined,
            color: AppColors.primary,
            size: 30,
          ),
        ),
        const SizedBox(height: AppTheme.spacingLg),
        Text(
          _step2 ? 'Enter Reset Token' : 'Reset Password',
          style: AppTheme.heading2.copyWith(fontSize: 26, letterSpacing: -0.5),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          _step2
              ? 'Copy the token from the reset link in your email and enter it below.'
              : 'Enter your email to receive a reset link.',
          textAlign: TextAlign.center,
          style: AppTheme.body.copyWith(
            color: AppColors.textLight,
            height: 1.4,
          ),
        ),
      ],
    );
  }
  Widget _buildStep1Form() {
    return AppTextField(
      label: 'Email Address',
      controller: _emailCtrl,
      hint: 'name@company.com',
      prefixIcon: Icons.mail_outline,
      keyboardType: TextInputType.emailAddress,
    );
  }
  Widget _buildStep2Form() {
    return Column(
      children: [
        AppTextField(
          label: 'Reset Token',
          controller: _tokenCtrl,
          hint: 'Paste token from email link',
          prefixIcon: Icons.key_outlined,
        ),
        AppTextField(
          label: 'New Password',
          controller: _newPassCtrl,
          hint: 'At least 6 characters',
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
        _isLoading
            ? Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : AppButton(
                label: _step2 ? 'Set New Password' : 'Send Reset Link',
                onPressed: _step2 ? _onSetPassword : _onSendLink,
              ),
        const SizedBox(height: AppTheme.spacingLg),
        GestureDetector(
          onTap: () {
            if (_step2) {
              setState(() => _step2 = false);
            } else {
              Navigator.pop(context);
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_back, color: AppColors.textDark, size: 16),
              const SizedBox(width: 6),
              Text(
                _step2 ? 'Back' : 'Back to login',
                style: AppTheme.body.copyWith(
                  color: AppColors.textDark.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
