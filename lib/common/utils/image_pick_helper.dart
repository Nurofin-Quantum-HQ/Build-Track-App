import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:buildtrack_mobile/design/bt_components.dart';
class PickedImage {
  final String path;
  final Future<Uint8List> Function() _readBytes;
  PickedImage._({
    required this.path,
    required Future<Uint8List> Function() readBytes,
  }) : _readBytes = readBytes;
  Future<Uint8List> readAsBytes() => _readBytes();
}
Future<PickedImage?> pickImageFromGallery(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 75,
    );
    if (picked == null) return null;
    return PickedImage._(
      path: picked.path,
      readBytes: () => picked.readAsBytes(),
    );
  } catch (e) {
    debugPrint('pickImageFromGallery error: $e');
    return null;
  }
}
class PickedAttachment {
  final String name;
  final Uint8List bytes;
  final String mimeType;
  const PickedAttachment({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });
  bool get isImage =>
      mimeType.startsWith('image/') ||
      name.toLowerCase().endsWith('.jpg') ||
      name.toLowerCase().endsWith('.jpeg') ||
      name.toLowerCase().endsWith('.png') ||
      name.toLowerCase().endsWith('.webp');
  ImageProvider? get imageProvider => isImage ? MemoryImage(bytes) : null;
  IconData get icon {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (ext == 'doc' || ext == 'docx') return Icons.description_outlined;
    if (ext == 'xls' || ext == 'xlsx') return Icons.table_chart_outlined;
    return Icons.insert_drive_file_outlined;
  }
  Color get iconColor {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return const Color(0xFFC01048);
    if (ext == 'doc' || ext == 'docx') return const Color(0xFF1565C0);
    if (ext == 'xls' || ext == 'xlsx') return const Color(0xFF067647);
    return const Color(0xFF667085);
  }
  Color get iconBg => iconColor.withValues(alpha: 0.10);
  String get dataUri => 'data:$mimeType;base64,${_base64Encode(bytes)}';
  static String _base64Encode(Uint8List bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final output = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final remaining = bytes.length - i;
      final b0 = bytes[i];
      final b1 = remaining > 1 ? bytes[i + 1] : 0;
      final b2 = remaining > 2 ? bytes[i + 2] : 0;
      output.write(chars[(b0 >> 2) & 0x3F]);
      output.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      output.write(remaining > 1 ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      output.write(remaining > 2 ? chars[b2 & 0x3F] : '=');
    }
    return output.toString();
  }
}
Future<PickedAttachment?> pickAttachmentDirect(BuildContext context) async {
  try {
    if (!kIsWeb) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        sheetAnimationStyle: btSheetStyleDefault(context),
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
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_outlined),
                title: const Text('Pick Document'),
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (choice == null) return null;
      if (choice == 'gallery' || choice == 'camera') {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
        if (picked == null) return null;
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        return PickedAttachment(
          name: picked.name,
          bytes: bytes,
          mimeType: mime,
        );
      }
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return null;
    final ext = (f.extension ?? 'bin').toLowerCase();
    final mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    return PickedAttachment(
      name: f.name,
      bytes: bytes,
      mimeType: mimeMap[ext] ?? 'application/octet-stream',
    );
  } catch (e) {
    debugPrint('pickAttachmentDirect error: $e');
    return null;
  }
}
ImageProvider? getProfileImageProvider(String? photoUrl) {
  if (photoUrl == null ||
      photoUrl.isEmpty ||
      photoUrl == 'null' ||
      photoUrl == 'delete' ||
      photoUrl == 'remove' ||
      photoUrl.trim().isEmpty) {
    return null;
  }
  if (photoUrl.startsWith('data:image/') && photoUrl.contains(';base64,')) {
    try {
      final base64String = photoUrl.split(';base64,').last;
      final bytes = base64.decode(base64String);
      return MemoryImage(bytes);
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return null;
    }
  }
  return NetworkImage(photoUrl);
}
