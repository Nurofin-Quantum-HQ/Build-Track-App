import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_layout.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key});
  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}
class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  
  bool _isEmailVerified = false;
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  final _otpCtrl = TextEditingController();
  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AppScrollLayout(
      title: '',
      showAppBar: false,
      backgroundColor: const Color(0xFFF0EEFF),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        margin: EdgeInsets.zero,
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeader(),
            const SizedBox(height: AppTheme.spacingLg),
            _buildForm(),
            const SizedBox(height: AppTheme.spacingLg),
            _buildActions(),
          ],
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF4A3FDE), Color(0xFF7B52FF)],
          ).createShader(bounds),
          child: RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Build',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'Track',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF7BCFFF),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Create Account',
          style: AppTheme.heading2.copyWith(fontSize: 26, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          'Set up your workspace owner account to get started.',
          textAlign: TextAlign.center,
          style: AppTheme.body.copyWith(color: AppColors.textLight),
        ),
      ],
    );
  }
  Widget _buildForm() {
    return Column(
      children: [
        AppTextField(
          label: 'Full Name',
          controller: _nameCtrl,
          hint: 'e.g. Jane Doe',
          prefixIcon: Icons.person_outline,
        ),
        AppTextField(
          label: 'Phone Number',
          controller: _phoneCtrl,
          hint: 'e.g. +1 234 567 8900',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        AppTextField(
          label: 'Company Name',
          controller: _companyCtrl,
          hint: 'e.g. Apex Construction',
          prefixIcon: Icons.business_outlined,
        ),
        AppTextField(
          label: 'Email Address',
          controller: _emailCtrl,
          hint: 'name@company.com',
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          readOnly: _isEmailVerified,
        ),
        if (!_isEmailVerified && !_otpSent)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Align(
              alignment: Alignment.centerRight,
              child: _isSendingOtp
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _sendOtp,
                      child: const Text('Verify Email', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ),
          ),
        if (!_isEmailVerified && _otpSent) ...[
          AppTextField(
            label: 'Verification Code (OTP)',
            controller: _otpCtrl,
            hint: 'Enter 6-digit code',
            prefixIcon: Icons.security,
            keyboardType: TextInputType.number,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _sendOtp,
                  child: const Text('Resend Code'),
                ),
                _isVerifyingOtp
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _verifyOtp,
                        child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
        ],
        if (_isEmailVerified)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Email Verified', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        if (_isEmailVerified) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This account will be created as Workspace Admin.',
                    style: AppTheme.body.copyWith(color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          AppTextField(
            label: 'Password',
            controller: _passCtrl,
            hint: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePass,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textLight,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          AppTextField(
            label: 'Confirm Password',
            controller: _confirmCtrl,
            hint: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textLight,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ],
      ],
    );
  }
  Widget _buildActions() {
    return Column(
      children: [
        if (_isEmailVerified)
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AppButton(
                  label: 'Create Workspace',
                  icon: Icons.arrow_forward,
                  onPressed: _onCreatePressed,
                ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: AppTheme.body.copyWith(color: AppColors.textLight),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/login'),
              child: Text(
                'Sign in',
                style: AppTheme.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  void _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    setState(() => _isSendingOtp = true);
    try {
      final response = await ApiService.post('/auth/send-registration-otp', {'email': email});
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send verification code')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _verifyOtp() async {
    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (otp.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP')),
      );
      return;
    }
    setState(() => _isVerifyingOtp = true);
    try {
      final response = await ApiService.post('/auth/verify-registration-otp', {'email': email, 'otp': otp});
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isEmailVerified = true;
          _otpCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified successfully!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid verification code'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _onCreatePressed() async {
    if (!_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your email first')),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    if (name.isEmpty || email.isEmpty || pass.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields (including phone)')),
      );
      return;
    }
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() {
      _isLoading = true;
    });
    final payload = {
      'name': name,
      'companyName': company,
      'phone': phone,
      'email': email,
      'password': pass,
      'role': 'Admin',
    };
    try {
      final response = await ApiService.post('/auth/register', payload);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Cache the email so it's ready when they log in
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_email', email);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workspace created successfully! Please log in.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        String errorMsg = 'Failed to create account: ${response.statusCode}';
        try {
          final Map<String, dynamic> body = jsonDecode(response.body);
          if (body.containsKey('message')) {
            errorMsg = body['message'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
        );
      }
    } catch (e, st) {
      debugPrint('Registration exception details: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connection failed. Server might be offline. Error: $e',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
