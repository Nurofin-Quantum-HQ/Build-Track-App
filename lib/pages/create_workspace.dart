import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:buildtrack_mobile/common/widgets/app_layout.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _selectedFontStyle = 'Inter';
  Uint8List? _logoBytes;
  String? _logoDataUri;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  static const List<String> _fontOptions = [
    'Inter',
    'Outfit',
    'Poppins',
    'Montserrat',
    'Roboto',
    'Playfair Display',
    'Cinzel',
    'Caveat',
  ];

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
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/images/buildtrack-logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Image.network(
                  'assets/images/buildtrack-logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
          ],
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
          label: 'Company Name *',
          controller: _companyCtrl,
          hint: 'e.g. Apex Construction',
          prefixIcon: Icons.business_outlined,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company Name Font Style',
              style: AppTheme.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedFontStyle,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                  items: _fontOptions.map((font) {
                    return DropdownMenuItem<String>(
                      value: font,
                      child: Text(
                        font,
                        style: _getFontPreviewStyle(font),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFontStyle = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Company Logo',
                  style: AppTheme.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(Optional)',
                  style: AppTheme.body.copyWith(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _logoBytes != null
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _logoBytes!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Logo selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                ),
                              ),
                              GestureDetector(
                                onTap: _pickLogo,
                                child: const Text(
                                  'Change logo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          onPressed: () => setState(() {
                            _logoBytes = null;
                            _logoDataUri = null;
                          }),
                        ),
                      ],
                    ),
                  )
                : InkWell(
                    onTap: _pickLogo,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Upload Company Logo (Optional)',
                            style: AppTheme.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
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

  TextStyle _getFontPreviewStyle(String font) {
    const base = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark);
    switch (font.toLowerCase()) {
      case 'outfit': return GoogleFonts.outfit(textStyle: base);
      case 'poppins': return GoogleFonts.poppins(textStyle: base);
      case 'montserrat': return GoogleFonts.montserrat(textStyle: base);
      case 'roboto': return GoogleFonts.roboto(textStyle: base);
      case 'playfair display': return GoogleFonts.playfairDisplay(textStyle: base);
      case 'cinzel': return GoogleFonts.cinzel(textStyle: base);
      case 'caveat': return GoogleFonts.caveat(textStyle: base);
      case 'inter':
      default: return GoogleFonts.inter(textStyle: base);
    }
  }

  Future<void> _pickLogo() async {
    final picked = await pickImageFromGallery(context);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      _logoBytes = bytes;
      _logoDataUri = 'data:$mime;base64,${base64Encode(bytes)}';
    });
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
    if (name.isEmpty || company.isEmpty || email.isEmpty || pass.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields (including Company Name and phone)')),
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
      'companyFontStyle': _selectedFontStyle,
      'companyLogo': _logoDataUri,
      'phone': phone,
      'email': email,
      'password': pass,
      'role': 'Admin',
      'client': 'mobile',
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
