import 'dart:convert';
import 'dart:io';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:buildtrack_mobile/config/api_config.dart';
class ReceiptViewerScreen extends StatefulWidget {
  const ReceiptViewerScreen({super.key});
  @override
  State<ReceiptViewerScreen> createState() => _ReceiptViewerScreenState();
}
class _ReceiptViewerScreenState extends State<ReceiptViewerScreen> {
  bool _isDownloading = false;
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  static primaryBlue = AppColors.primary;
  static const bgColor = AppColors.gradientStart;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic')) {
      return true;
    }
    if ((lower.startsWith('http://') || lower.startsWith('https://')) &&
        !lower.endsWith('.pdf')) {
      return true;
    }
    if (lower.startsWith('data:image/')) {
      return true;
    }
    return false;
  }
  String _normalizeUrl(String url) {
    if (url.startsWith('/')) {
      final base = ApiConfig.baseUrl.replaceAll('/api', '');
      return '$base$url';
    }
    return url;
  }
  String _getFileName(String path) {
    if (path.startsWith('data:image/')) {
      return 'Base64 Image';
    }
    try {
      final uri = Uri.parse(path);
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    } catch (_) {}
    return path.split('/').last;
  }
  Future<void> _downloadAndOpenFile(
    String url, {
    bool open = true,
    bool share = false,
  }) async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
    });
    try {
      final String actionText = share
          ? 'Sharing'
          : (open ? 'Opening' : 'Downloading');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionText receipt...'),
          duration: const Duration(seconds: 2),
        ),
      );
      File file;
      final normalizedUrl = _normalizeUrl(url);
      if (normalizedUrl.startsWith('http://') ||
          normalizedUrl.startsWith('https://')) {
        final response = await http.get(Uri.parse(normalizedUrl));
        if (response.statusCode != 200) {
          throw HttpException(
            'Failed to download file (Status: ${response.statusCode})',
          );
        }
        final tempDir = await getTemporaryDirectory();
        String fileName = url.split('/').last;
        if (fileName.contains('?')) {
          fileName = fileName.split('?').first;
        }
        if (!fileName.contains('.')) {
          fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
        file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
      } else {
        file = File(normalizedUrl);
        if (!await file.exists()) {
          throw const FileSystemException('Local file does not exist');
        }
      }
      if (!mounted) return;
      if (share) {
        final xFile = XFile(file.path);
        await SharePlus.instance.share(
          ShareParams(files: [xFile], text: 'Receipt Proof'),
        );
      } else if (open) {
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to temporary folder: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (message.contains('MissingPluginException')) {
          message =
              'Plugin not loaded. Please stop the app and rebuild/run it again from scratch.';
        } else {
          message = 'Error: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }
  Widget _buildImageWidget(String receipt) {
    final normalizedReceipt = _normalizeUrl(receipt);
    if (normalizedReceipt.startsWith('http://') ||
        normalizedReceipt.startsWith('https://')) {
      return Image.network(
        normalizedReceipt,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.red, size: 48),
                SizedBox(height: 12),
                Text(
                  'Failed to load image from network',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (normalizedReceipt.startsWith('data:image/')) {
      try {
        final base64String = normalizedReceipt.split(',').last;
        return Image.memory(base64Decode(base64String), fit: BoxFit.contain);
      } catch (e) {
        return const Center(child: Icon(Icons.broken_image, color: Colors.red));
      }
    } else {
      final file = File(normalizedReceipt);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      } else {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.red, size: 48),
              SizedBox(height: 12),
              Text(
                'Local file not found',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    final String receipt = args['receipt'] as String? ?? 'receipt.pdf';
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, receipt),
            Expanded(child: _buildReceiptView(context, receipt)),
          ],
        ),
      ),
    );
  }
  Widget _buildTopBar(BuildContext context, String receipt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: textDark, size: 22),
          ),
          const Text(
            'Receipt',
            style: TextStyle(
              color: textDark,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 22),
        ],
      ),
    );
  }
  Widget _buildReceiptView(BuildContext context, String receipt) {
    final normalizedReceipt = _normalizeUrl(receipt);
    final isPdf = normalizedReceipt.toLowerCase().endsWith('.pdf');
    final isImage = _isImageFile(normalizedReceipt);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E5FF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPdf
                        ? Colors.red.withValues(alpha: 0.1)
                        : primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    color: isPdf ? Colors.red : primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFileName(receipt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPdf ? 'PDF Document' : 'Image File',
                        style: const TextStyle(color: textGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Verified',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Center(
                            child: GestureDetector(
                              onDoubleTapDown: (details) =>
                                  _doubleTapDetails = details,
                              onDoubleTap: () {
                                if (_transformationController.value !=
                                    Matrix4.identity()) {
                                  _transformationController.value =
                                      Matrix4.identity();
                                } else {
                                  final position =
                                      _doubleTapDetails!.localPosition;
                                  _transformationController.value =
                                      Matrix4.translationValues(
                                        -position.dx,
                                        -position.dy,
                                        0.0,
                                      ) *
                                      Matrix4.diagonal3Values(2.0, 2.0, 1.0);
                                }
                              },
                              child: InteractiveViewer(
                                transformationController:
                                    _transformationController,
                                boundaryMargin: const EdgeInsets.all(20),
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: _buildImageWidget(receipt),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.zoom_out,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _transformationController.value =
                                          Matrix4.identity();
                                    },
                                  ),
                                  const Text(
                                    'Reset',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _transformationController.value =
                                          Matrix4.diagonal3Values(
                                            2.0,
                                            2.0,
                                            1.0,
                                          );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.pinch_sharp,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Pinch to zoom / Drag to pan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: Colors.red,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _getFileName(receipt),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'PDF documents cannot be previewed inline.\nTap below to open in your system reader.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textGray,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: () => _downloadAndOpenFile(receipt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppGradients.primaryButton,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _isDownloading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.open_in_new,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                const SizedBox(width: 8),
                                Text(
                                  _isDownloading
                                      ? 'Opening...'
                                      : 'Open Full View',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
