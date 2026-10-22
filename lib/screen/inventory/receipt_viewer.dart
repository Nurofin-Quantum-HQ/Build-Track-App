import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'dart:io';
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
      btToast(context, '$actionText receipt...');
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
          btToast(context, 'Could not open file: ${result.message}', error: true);
        }
      } else {
        btToast(context, 'Saved to temporary folder: ${file.path}');
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
        btToast(context, message, error: true);
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
          return const Center(child: BtBrickLoader(label: 'Loading receipt…'));
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: BtEmpty(icon: Icons.broken_image_outlined, title: 'Failed to load image from network'),
          );
        },
      );
    } else if (normalizedReceipt.startsWith('data:image/')) {
      try {
        final base64String = normalizedReceipt.split(',').last;
        return Image.memory(base64Decode(base64String), fit: BoxFit.contain);
      } catch (e) {
        return const Center(child: Icon(Icons.broken_image_outlined, color: Bt.red, size: 40));
      }
    } else {
      final file = File(normalizedReceipt);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      } else {
        return const Center(
          child: BtEmpty(icon: Icons.broken_image_outlined, title: 'Local file not found'),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    final String receipt = args['receipt'] as String? ?? 'receipt.pdf';
    final normalizedReceipt = _normalizeUrl(receipt);
    final isPdf = normalizedReceipt.toLowerCase().endsWith('.pdf');
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Bt.noir,
      body: BtHero(
        overlap: 0,
        padding: EdgeInsets.fromLTRB(Bt.gutter, top + 8, Bt.gutter, 0),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height - top - 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BtIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Bt.bone,
                    background: Colors.white.withValues(alpha: .09),
                    semantic: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
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
                          style: BtText.headline(context).copyWith(color: Bt.bone),
                        ),
                        Text(
                          isPdf ? 'PDF Document' : 'Image File',
                          style: BtText.caption(context, color: Bt.onNoir2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const BtBadge(label: 'Verified', tone: BtTone.green),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: BtReveal(distance: 28, child: _buildReceiptView(context, receipt))),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: BtButton(
                          label: 'Share',
                          icon: Icons.ios_share_rounded,
                          variant: BtButtonVariant.onDark,
                          onPressed: _isDownloading ? null : () => _downloadAndOpenFile(receipt, open: false, share: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LightButton(
                          label: _isDownloading ? 'Opening...' : 'Open Full View',
                          icon: Icons.open_in_new_rounded,
                          loading: _isDownloading,
                          onTap: _isDownloading ? null : () => _downloadAndOpenFile(receipt),
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
    );
  }

  Widget _buildReceiptView(BuildContext context, String receipt) {
    final normalizedReceipt = _normalizeUrl(receipt);
    final isImage = _isImageFile(normalizedReceipt);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rCard),
        boxShadow: Bt.shadowLg,
      ),
      child: isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(Bt.rCard),
              child: Stack(
                children: [
                  Center(
                    child: GestureDetector(
                      onDoubleTapDown: (details) => _doubleTapDetails = details,
                      onDoubleTap: () {
                        if (_transformationController.value != Matrix4.identity()) {
                          _transformationController.value = Matrix4.identity();
                        } else {
                          final position = _doubleTapDetails!.localPosition;
                          _transformationController.value =
                              Matrix4.translationValues(-position.dx, -position.dy, 0.0) *
                                  Matrix4.diagonal3Values(2.0, 2.0, 1.0);
                        }
                      },
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        boundaryMargin: const EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: _buildImageWidget(receipt),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Bt.noir.withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(Bt.rChip + 4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BtIconButton(
                            icon: Icons.zoom_out_rounded,
                            size: 20,
                            color: Bt.bone,
                            semantic: 'Reset zoom',
                            onTap: () => _transformationController.value = Matrix4.identity(),
                          ),
                          Text('Reset', style: BtText.caption(context, color: Bt.bone, weight: FontWeight.w600)),
                          BtIconButton(
                            icon: Icons.zoom_in_rounded,
                            size: 20,
                            color: Bt.bone,
                            semantic: 'Zoom in',
                            onTap: () => _transformationController.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Bt.noir.withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(Bt.rChip),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pinch_rounded, color: Bt.bone, size: 14),
                            const SizedBox(width: 6),
                            Text('Pinch to zoom / Drag to pan', style: BtText.caption(context, color: Bt.bone, weight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BtTile(icon: Icons.picture_as_pdf_outlined, size: 84, bg: Bt.redSoft, fg: Bt.red),
                  const SizedBox(height: 20),
                  Text(
                    _getFileName(receipt),
                    textAlign: TextAlign.center,
                    style: BtText.title(context, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDF documents cannot be previewed inline.\nTap below to open in your system reader.',
                    textAlign: TextAlign.center,
                    style: BtText.subhead(context),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Bone (light) button for use on noir, as on the Receipt-Viewer board.
class _LightButton extends StatelessWidget {
  const _LightButton({required this.label, required this.icon, required this.onTap, this.loading = false});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    return BtPressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: Bt.buttonH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Bt.bone, borderRadius: BorderRadius.circular(Bt.rButton)),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Bt.ink))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 19, color: Bt.ink),
                const SizedBox(width: 8),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.button(context, color: Bt.ink))),
              ]),
      ),
    );
  }
}
