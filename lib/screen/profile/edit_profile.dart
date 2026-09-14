import 'dart:convert';
import 'dart:typed_data';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_layout.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
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
  Uint8List? _selectedImageBytes;
  String? _selectedImagePath;
  String? _initialPhotoUrl;
  bool _deletePhoto = false;
  bool _isSaving = false;
  bool _isLoadingInitial = true;
  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFields());
  }
  void _initFields() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ProfileUserData) {
      _nameCtrl.text = args.name;
      _emailCtrl.text = args.email;
      // We don't have phone in args directly, it will be fetched or left empty
      _initialPhotoUrl = args.profilePhoto;
    } else {
      _nameCtrl.text = UserSession.userId.isNotEmpty ? UserSession.userId : '';
      _emailCtrl.text = '';
      _phoneCtrl.text = '';
      _initialPhotoUrl = UserSession.profilePhoto;
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
        _initialPhotoUrl = userJson['profilePhoto']?.toString();
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
  Future<void> _onSave() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
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
      final payload = <String, dynamic>{
        'name': name,
        if (email.isNotEmpty) 'email': email,
        if (phone.isNotEmpty) 'phone': phone,
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
