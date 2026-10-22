import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
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
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: const BtNavBar(title: 'Create workspace'),
      bottomNavigationBar: _isEmailVerified
          ? BtCtaBar(children: [
              Expanded(
                child: BtButton(
                  label: 'Create Workspace',
                  icon: Icons.arrow_forward_rounded,
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _onCreatePressed,
                ),
              ),
            ])
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _buildSteps(),
          const SizedBox(height: 24),
          BtReveal(child: _buildHeader()),
          const SizedBox(height: 20),
          BtReveal(index: 1, child: _buildPreview()),
          const SizedBox(height: 28),
          _buildForm(),
          const SizedBox(height: 4),
          _buildActions(),
        ],
      ),
    );
  }

  /// 01 You · 02 Company · 03 Sign-in — fills in as the form is completed.
  Widget _buildSteps() {
    final bt = context.bt;
    return ListenableBuilder(
      listenable: Listenable.merge([_nameCtrl, _phoneCtrl, _companyCtrl]),
      builder: (context, _) {
        final done = [
          _nameCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim().isNotEmpty,
          _companyCtrl.text.trim().isNotEmpty,
          _isEmailVerified,
        ];
        const labels = ['01 YOU', '02 COMPANY', '03 SIGN-IN'];
        return Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 6,
                    color: Bt.ink.withValues(alpha: .08),
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: Bt.medium,
                      curve: Bt.ease,
                      widthFactor: done[i] ? 1 : 0,
                      heightFactor: 1,
                      child: DecoratedBox(decoration: BoxDecoration(color: i == 0 ? Bt.ink : bt.accent, borderRadius: BorderRadius.circular(6))),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: BtText.mono(context, color: done[i] ? Bt.ink : Bt.ink3)),
              ]),
            ),
          ],
        ]);
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create account', style: BtText.d2(context)),
        const SizedBox(height: 6),
        Text(
          'Set up your workspace owner account to get started.',
          style: BtText.body(context, color: Bt.ink2),
        ),
      ],
    );
  }

  /// Noir card previewing the company name in the chosen font (+ logo).
  Widget _buildPreview() {
    return BtCard(
      variant: BtCardVariant.ink,
      padding: const EdgeInsets.all(20),
      child: ListenableBuilder(
        listenable: _companyCtrl,
        builder: (context, _) {
          final name = _companyCtrl.text.trim();
          final shown = name.isEmpty ? 'Your company' : name;
          final initials = shown.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LIVE PREVIEW', style: BtText.mono(context, color: Bt.onNoir2)),
            const SizedBox(height: 14),
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  width: 52,
                  height: 52,
                  color: Bt.bone,
                  alignment: Alignment.center,
                  child: _logoBytes != null
                      ? Image.memory(_logoBytes!, width: 52, height: 52, fit: BoxFit.contain)
                      : Text(initials, style: BtText.title(context, size: 18).copyWith(color: Bt.noir)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Bt.fast,
                  child: Text(
                    shown,
                    key: ValueKey(_selectedFontStyle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _getFontPreviewStyle(_selectedFontStyle).copyWith(fontSize: 26, height: 1.1, color: name.isEmpty ? Bt.onNoir3 : Bt.bone),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text('This name sits at the top of everyone\'s app.', style: BtText.caption(context, color: Bt.onNoir2)),
          ]);
        },
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 12),
        child: Text(text, style: BtText.mono(context)),
      );

  Widget _field(String label, TextEditingController c, String hint, {TextInputType? type, bool readOnly = false, bool obscure = false, Widget? suffix, bool required = false, Iterable<String>? autofill}) {
    return EntryLabeled(
      label: label,
      required: required,
      child: TextField(
        controller: c,
        keyboardType: type,
        readOnly: readOnly,
        obscureText: obscure,
        autofillHints: autofill,
        style: BtText.body(context, color: readOnly ? Bt.ink2 : Bt.ink),
        decoration: btInput(context, hint: hint, suffix: suffix),
      ),
    );
  }

  Widget _buildForm() {
    final bt = context.bt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('01 · YOU'),
        EntryFormSection(
          children: [
            _field('Full name', _nameCtrl, 'e.g. Jane Doe', autofill: const [AutofillHints.name]),
            _field('Phone number', _phoneCtrl, 'e.g. +91 98765 43210', type: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber]),
          ],
        ),
        _sectionLabel('02 · COMPANY'),
        EntryFormSection(
          children: [
            _field('Company name', _companyCtrl, 'e.g. Apex Construction', required: true),
            EntryLabeled(
              label: 'Company name font style',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(children: [
                  for (final font in _fontOptions) ...[
                    if (font != _fontOptions.first) const SizedBox(width: 8),
                    _fontChip(font),
                  ],
                ]),
              ),
            ),
            EntryLabeled(
              label: 'Company logo · optional',
              child: _logoBytes != null
                  ? BtGroup(children: [
                      BtRow(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(Bt.rTile),
                          child: Image.memory(_logoBytes!, width: 40, height: 40, fit: BoxFit.contain),
                        ),
                        title: 'Logo selected',
                        subtitle: 'Tap to change',
                        onTap: _pickLogo,
                        trailing: BtIconButton(
                          icon: Icons.close_rounded,
                          semantic: 'Remove logo',
                          color: Bt.red,
                          onTap: () => setState(() {
                            _logoBytes = null;
                            _logoDataUri = null;
                          }),
                        ),
                      ),
                    ])
                  : BtPressable(
                      onTap: _pickLogo,
                      semanticLabel: 'Upload company logo',
                      child: CustomPaint(
                        painter: _DashedBorderPainter(color: Bt.ink.withValues(alpha: .18), radius: 18),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(children: [
                            BtTile(icon: Icons.add_photo_alternate_outlined, bg: bt.accentSoft, fg: bt.accentInk),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Upload company logo', style: BtText.body(context, weight: FontWeight.w600)),
                                Text('Optional · PNG or JPG', style: BtText.caption(context, color: Bt.ink2)),
                              ]),
                            ),
                            const Icon(Icons.add_rounded, color: Bt.ink3, size: 20),
                          ]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        _sectionLabel('03 · SIGN-IN'),
        EntryFormSection(
          children: [
            _field(
              'Email address',
              _emailCtrl,
              'name@company.com',
              type: TextInputType.emailAddress,
              readOnly: _isEmailVerified,
              autofill: const [AutofillHints.email],
              suffix: _isEmailVerified ? const Icon(Icons.check_circle_rounded, color: Bt.green) : null,
            ),
            AnimatedSize(
              duration: Bt.medium,
              curve: Bt.ease,
              alignment: Alignment.topCenter,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!_isEmailVerified && !_otpSent)
                  BtButton(
                    label: 'Verify Email',
                    icon: Icons.mark_email_read_outlined,
                    variant: BtButtonVariant.secondary,
                    loading: _isSendingOtp,
                    onPressed: _isSendingOtp ? null : _sendOtp,
                  ),
                if (!_isEmailVerified && _otpSent) ...[
                  _field('Verification code (OTP)', _otpCtrl, 'Enter 6-digit code', type: TextInputType.number, autofill: const [AutofillHints.oneTimeCode]),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: BtButton(label: 'Resend Code', variant: BtButtonVariant.secondary, onPressed: _sendOtp),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BtButton(
                          label: 'Confirm',
                          loading: _isVerifyingOtp,
                          onPressed: _isVerifyingOtp ? null : _verifyOtp,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_isEmailVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Bt.greenSoft, borderRadius: BorderRadius.circular(Bt.rTile)),
                    child: Row(children: [
                      const Icon(Icons.admin_panel_settings_outlined, color: Bt.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Email verified. This account will be created as Workspace Admin.', style: BtText.subhead(context, color: Bt.ink)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'Password',
                    _passCtrl,
                    '••••••••',
                    obscure: _obscurePass,
                    autofill: const [AutofillHints.newPassword],
                    suffix: IconButton(
                      tooltip: _obscurePass ? 'Show password' : 'Hide password',
                      icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Bt.ink2),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'Confirm password',
                    _confirmCtrl,
                    '••••••••',
                    obscure: _obscureConfirm,
                    suffix: IconButton(
                      tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                      icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Bt.ink2),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fontChip(String font) {
    final on = font == _selectedFontStyle;
    return BtPressable(
      onTap: () => setState(() => _selectedFontStyle = font),
      scale: .95,
      semanticLabel: 'Font $font',
      child: AnimatedContainer(
        duration: Bt.fast,
        curve: Bt.ease,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Bt.ink : Bt.card,
          borderRadius: BorderRadius.circular(14),
          border: on ? null : Border.all(color: Bt.inputBorder),
        ),
        child: Text(font, style: _getFontPreviewStyle(font).copyWith(fontSize: 15, color: on ? Bt.bone : Bt.ink)),
      ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Already have an account? ', style: BtText.body(context, color: Bt.ink2)),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/login'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Sign in',
                  style: BtText.body(context, weight: FontWeight.w600).copyWith(decoration: TextDecoration.underline, decorationColor: Bt.ink, decorationThickness: 1.4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(child: _buildPoweredByNurofin()),
      ],
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
          const SnackBar(content: Text('Email verified successfully!'), backgroundColor: Color(0xFF067647)),
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

/// Dashed rounded outline for the logo drop zone.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color || old.radius != radius;
}
