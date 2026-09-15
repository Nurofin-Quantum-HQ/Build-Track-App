import 'dart:convert';
import 'dart:typed_data';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_layout.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
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
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove Profile Photo',
                  style: TextStyle(color: Colors.red),
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
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove Company Logo',
                  style: TextStyle(color: Colors.red),
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
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      } else {
        final body = json.decode(response.body);
        final msg = body['message']?.toString() ?? 'Update failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
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
  @override
  Widget build(BuildContext context) {
    return AppSubScreenLayout(
      title: 'Edit Profile',
      scrollable: true,
      child: _isLoadingInitial
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppTheme.spacingLg),
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showImageOptions,
                        child: Builder(
                          builder: (context) {
                            ImageProvider? imageProvider;
                            if (_selectedImageBytes != null) {
                              imageProvider = MemoryImage(_selectedImageBytes!);
                            } else if (_initialPhotoUrl != null &&
                                _initialPhotoUrl!.isNotEmpty) {
                              imageProvider = getProfileImageProvider(
                                _initialPhotoUrl,
                              );
                            }
                            return CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage: imageProvider,
                              child: imageProvider == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.white,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImageOptions,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: AppColors.primary,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXl),
                AppTextField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  hint: 'Enter your name',
                  prefixIcon: Icons.person_outline,
                ),
                AppTextField(
                  label: 'Email Address',
                  controller: _emailCtrl,
                  hint: 'name@company.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                AppTextField(
                  label: 'Phone Number',
                  controller: _phoneCtrl,
                  hint: 'Enter your phone number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                const Divider(),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Company Branding',
                  style: AppTheme.heading3.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Customize your company name and font style displayed across the app.',
                  style: AppTheme.body.copyWith(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                AppTextField(
                  label: 'Company Name *',
                  controller: _companyCtrl,
                  hint: 'Enter your company name',
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
                    Builder(
                      builder: (context) {
                        ImageProvider? logoProvider;
                        if (_selectedLogoBytes != null) {
                          logoProvider = MemoryImage(_selectedLogoBytes!);
                        } else if (!_deleteLogo && _initialLogoUrl != null && _initialLogoUrl!.isNotEmpty) {
                          logoProvider = getProfileImageProvider(_initialLogoUrl);
                        }

                        if (logoProvider != null) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: logoProvider,
                                      fit: BoxFit.contain,
                                    ),
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
                                        onTap: _showLogoOptions,
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
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => setState(() {
                                    _selectedLogoBytes = null;
                                    _selectedLogoPath = null;
                                    _initialLogoUrl = null;
                                    _deleteLogo = true;
                                  }),
                                ),
                              ],
                            ),
                          );
                        }

                        return InkWell(
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
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                  ],
                ),
                // Live preview card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE BRANDING PREVIEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF818CF8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              ImageProvider? previewLogo;
                              if (_selectedLogoBytes != null) {
                                previewLogo = MemoryImage(_selectedLogoBytes!);
                              } else if (!_deleteLogo && _initialLogoUrl != null && _initialLogoUrl!.isNotEmpty) {
                                previewLogo = getProfileImageProvider(_initialLogoUrl);
                              }

                              if (previewLogo != null) {
                                return Container(
                                  width: 36,
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: previewLogo,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          Expanded(
                            child: Text(
                              _companyCtrl.text.isNotEmpty ? _companyCtrl.text : 'Your Company',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _getFontPreviewStyle(_selectedFontStyle).copyWith(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXl),
                _isSaving
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : AppButton(
                        label: 'Save Changes',
                        icon: Icons.check_outlined,
                        onPressed: _onSave,
                      ),
                const SizedBox(height: AppTheme.spacingLg),
              ],
            ),
    );
  }
}
