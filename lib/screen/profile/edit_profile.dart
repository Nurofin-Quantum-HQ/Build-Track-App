import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'profile.dart';
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}
class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _companyCtrl;
  String _selectedFontStyle = 'Inter';
  Uint8List? _selectedImageBytes;
  String? _selectedImagePath;
  String? _initialPhotoUrl;
  bool _deletePhoto = false;

  Uint8List? _selectedLogoBytes;
  String? _selectedLogoPath;
  String? _initialLogoUrl;
  bool _deleteLogo = false;

  bool _isSaving = false;
  bool _isLoadingInitial = true;

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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _companyCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFields());
  }
  void _initFields() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ProfileUserData) {
      _nameCtrl.text = args.name;
      _emailCtrl.text = args.email;
      _companyCtrl.text = args.companyName;
      _selectedFontStyle = args.companyFontStyle.isNotEmpty ? args.companyFontStyle : 'Inter';
      _phoneCtrl.text = '';
      _initialPhotoUrl = args.profilePhoto;
      _initialLogoUrl = args.companyLogo;
    } else {
      _nameCtrl.text = UserSession.userId.isNotEmpty ? UserSession.userId : '';
      _emailCtrl.text = '';
      _companyCtrl.text = UserSession.companyName;
      _selectedFontStyle = UserSession.companyFontStyle.isNotEmpty ? UserSession.companyFontStyle : 'Inter';
      _phoneCtrl.text = '';
      _initialPhotoUrl = UserSession.profilePhoto;
      _initialLogoUrl = UserSession.companyLogo;
      _fetchProfile();
      return;
    }
    _fetchProfile();
    setState(() => _isLoadingInitial = false);
  }
  Future<void> _fetchProfile() async {
    try {
      final response = await ApiService.get('/users/profile');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final userJson = decoded['user'] ?? decoded;
        _nameCtrl.text = userJson['name']?.toString() ?? '';
        _emailCtrl.text = userJson['email']?.toString() ?? '';
        _phoneCtrl.text = userJson['phone']?.toString() ?? '';
        _companyCtrl.text = userJson['companyName']?.toString() ?? '';
        _selectedFontStyle = userJson['companyFontStyle']?.toString() ?? 'Inter';
        _initialPhotoUrl = userJson['profilePhoto']?.toString();
        _initialLogoUrl = userJson['companyLogo']?.toString();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }
  Future<void> _showImageOptions() async {
    final hasPhoto =
        _selectedImageBytes != null ||
        (_initialPhotoUrl != null && _initialPhotoUrl!.isNotEmpty);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFC01048)),
                title: const Text(
                  'Remove Profile Photo',
                  style: TextStyle(color: Color(0xFFC01048)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedImageBytes = null;
                    _selectedImagePath = null;
                    _initialPhotoUrl = null;
                    _deletePhoto = true;
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  Future<void> _pickImage() async {
    final picked = await pickImageFromGallery(context);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImagePath = picked.path;
      _deletePhoto = false;
    });
  }
  Future<void> _pickLogo() async {
    final picked = await pickImageFromGallery(context);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedLogoBytes = bytes;
      _selectedLogoPath = picked.path;
      _deleteLogo = false;
    });
  }

  void _showLogoOptions() {
    final hasLogo =
        _selectedLogoBytes != null ||
        (_initialLogoUrl != null && _initialLogoUrl!.isNotEmpty);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickLogo();
              },
            ),
            if (hasLogo)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFC01048)),
                title: const Text(
                  'Remove Company Logo',
                  style: TextStyle(color: Color(0xFFC01048)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedLogoBytes = null;
                    _selectedLogoPath = null;
                    _initialLogoUrl = null;
                    _deleteLogo = true;
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
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

  Future<void> _onSave() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    if (company.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Company Name cannot be empty')));
      return;
    }
    if (email.isNotEmpty && !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      if (_deletePhoto) {
        final photoResponse = await ApiService.put('/users/profile/photo', {
          'profilePhoto': 'delete',
        });
        if (photoResponse.statusCode != 200) {
          throw Exception('Failed to delete profile photo');
        }
      } else if (_selectedImageBytes != null) {
        final base64Image = base64Encode(_selectedImageBytes!);
        final ext = _selectedImagePath != null
            ? _selectedImagePath!.split('.').last.toLowerCase()
            : 'jpg';
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        final photoResponse = await ApiService.put('/users/profile/photo', {
          'profilePhoto': 'data:$mimeType;base64,$base64Image',
        });
        if (photoResponse.statusCode != 200) {
          throw Exception('Failed to upload profile photo');
        }
      }

      String? companyLogoValue;
      if (_deleteLogo) {
        companyLogoValue = '';
      } else if (_selectedLogoBytes != null) {
        final ext = _selectedLogoPath != null
            ? _selectedLogoPath!.split('.').last.toLowerCase()
            : 'png';
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        companyLogoValue = 'data:$mimeType;base64,${base64Encode(_selectedLogoBytes!)}';
      }

      final payload = <String, dynamic>{
        'name': name,
        'companyName': company,
        'companyFontStyle': _selectedFontStyle,
        if (email.isNotEmpty) 'email': email,
        if (phone.isNotEmpty) 'phone': phone,
        'companyLogo': ?companyLogoValue,
      };
      final response = await ApiService.put('/users/profile', payload);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final userJson = decoded['user'] ?? decoded;
        await UserSession.fromLoginResponse(
          Map<String, dynamic>.from(userJson),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF067647),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      } else {
        final body = json.decode(response.body);
        final msg = body['message']?.toString() ?? 'Update failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFFC01048)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: const Color(0xFFC01048),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }
  Widget _inlineField(String label, TextEditingController c, String hint, {TextInputType? type, Iterable<String>? autofill}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          SizedBox(width: 96, child: Text(label, style: BtText.subhead(context))),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: type,
              autofillHints: autofill,
              onChanged: (_) => setState(() {}),
              style: BtText.body(context),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: BtText.body(context, color: Bt.placeholder),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    ImageProvider? photo;
    if (_selectedImageBytes != null) {
      photo = MemoryImage(_selectedImageBytes!);
    } else if (_initialPhotoUrl != null && _initialPhotoUrl!.isNotEmpty) {
      photo = getProfileImageProvider(_initialPhotoUrl);
    }
    ImageProvider? logo;
    if (_selectedLogoBytes != null) {
      logo = MemoryImage(_selectedLogoBytes!);
    } else if (!_deleteLogo && _initialLogoUrl != null && _initialLogoUrl!.isNotEmpty) {
      logo = getProfileImageProvider(_initialLogoUrl);
    }
    final company = _companyCtrl.text.isNotEmpty ? _companyCtrl.text : 'Your Company';
    final initials = company.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Edit profile',
        trailing: _isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                onPressed: _isLoadingInitial ? null : _onSave,
                style: TextButton.styleFrom(foregroundColor: bt.brand, minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
                child: Text('Save', style: BtText.headline(context).copyWith(color: bt.brand)),
              ),
      ),
      body: _isLoadingInitial
          ? const Padding(padding: EdgeInsets.all(16), child: BtSkeletonList(count: 4))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Change profile photo',
                    child: GestureDetector(
                      onTap: _showImageOptions,
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Bt.ink,
                        backgroundImage: photo,
                        child: photo == null
                            ? Text(
                                _nameCtrl.text.trim().isEmpty
                                    ? '?'
                                    : _nameCtrl.text.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join(),
                                style: BtText.title(context, size: 28).copyWith(color: Colors.white),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _showImageOptions,
                    style: TextButton.styleFrom(foregroundColor: bt.brand, minimumSize: const Size(44, 44)),
                    child: Text('Change photo', style: BtText.body(context, weight: FontWeight.w500, color: bt.brand)),
                  ),
                ),
                const SizedBox(height: 12),
                BtGroup(children: [
                  _inlineField('Name', _nameCtrl, 'Enter your name', autofill: const [AutofillHints.name]),
                  _inlineField('Phone', _phoneCtrl, 'Enter your phone number', type: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber]),
                  _inlineField('Email', _emailCtrl, 'name@company.com', type: TextInputType.emailAddress, autofill: const [AutofillHints.email]),
                ]),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text('Company · shown at the top of everyone\'s app', style: BtText.caption(context)),
                ),
                BtGroup(children: [
                  _inlineField('Name', _companyCtrl, 'Enter your company name'),
                  BtRow(
                    leading: SizedBox(width: 80, child: Text('Logo', style: BtText.subhead(context))),
                    title: logo == null ? 'Upload' : 'Change logo',
                    titleColor: logo == null ? Bt.ink : bt.brand,
                    onTap: logo == null ? _pickLogo : _showLogoOptions,
                    trailing: logo == null
                        ? const Icon(Icons.chevron_right_rounded, color: Bt.placeholder)
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Bt.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Bt.line),
                                image: DecorationImage(image: logo, fit: BoxFit.contain),
                              ),
                            ),
                            BtIconButton(
                              icon: Icons.delete_outline_rounded,
                              semantic: 'Remove logo',
                              color: Bt.red,
                              onTap: () => setState(() {
                                _selectedLogoBytes = null;
                                _selectedLogoPath = null;
                                _initialLogoUrl = null;
                                _deleteLogo = true;
                              }),
                            ),
                          ]),
                  ),
                  BtRow(
                    leading: SizedBox(width: 80, child: Text('Name style', style: BtText.subhead(context))),
                    title: _selectedFontStyle,
                    showChevron: true,
                    onTap: () async {
                      final picked = await showBtSheet<String>(
                        context,
                        title: 'Name style',
                        builder: (sheetCtx) => BtGroup(children: [
                          for (final font in _fontOptions)
                            InkWell(
                              onTap: () => Navigator.pop(sheetCtx, font),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 56),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(children: [
                                    Expanded(child: Text(company, maxLines: 1, overflow: TextOverflow.ellipsis, style: _getFontPreviewStyle(font).copyWith(fontSize: 18))),
                                    Text(font, style: BtText.caption(sheetCtx)),
                                    if (font == _selectedFontStyle) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.check_rounded, color: bt.brand, size: 20),
                                    ],
                                  ]),
                                ),
                              ),
                            ),
                        ]),
                      );
                      if (picked != null) setState(() => _selectedFontStyle = picked);
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                BtCard(
                  child: Row(children: [
                    if (logo != null)
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Bt.card,
                          borderRadius: BorderRadius.circular(Bt.rTile),
                          border: Border.all(color: Bt.line),
                          image: DecorationImage(image: logo, fit: BoxFit.contain),
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(Bt.rTile)),
                        child: Text(initials, style: BtText.headline(context)),
                      ),
                    Expanded(
                      child: Text(
                        company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _getFontPreviewStyle(_selectedFontStyle).copyWith(fontSize: 18, color: Bt.ink),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text('Preview', style: BtText.caption(context)),
                ),
              ],
            ),
    );
  }
}
