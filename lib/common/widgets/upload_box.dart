import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:flutter/material.dart';
class UploadBox extends StatelessWidget {
  final PickedAttachment? attachment;
  final ValueChanged<PickedAttachment> onPicked;
  final VoidCallback onRemove;
  final String emptyLabel;
  final double height;
  const UploadBox({
    super.key,
    required this.attachment,
    required this.onPicked,
    required this.onRemove,
    this.emptyLabel = 'Tap to attach file',
    this.height = 130,
  });
  static const _blue = Color(0xFF0B63CE);
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: attachment == null
          ? _emptyState(context)
          : (attachment!.isImage ? _imagePreview() : _filePreview()),
    );
  }
  Widget _emptyState(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('empty'),
      onTap: () async {
        final result = await pickAttachmentDirect(context);
        if (result != null) onPicked(result);
      },
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD0D5DD), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: _blue,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1A1D3B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Images · PDF · DOC · XLSX',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8A90A8),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _imagePreview() {
    final provider = attachment!.imageProvider;
    if (provider == null) return _filePreview();
    return Stack(
      key: const ValueKey('image'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image(
            image: provider,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fileFallback(),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 12,
          right: 48,
          child: Text(
            attachment!.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Positioned(top: 8, right: 8, child: _removeButton()),
      ],
    );
  }
  Widget _filePreview() {
    return Container(
      key: const ValueKey('file'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: attachment!.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              attachment!.icon,
              color: attachment!.iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'File attached',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A1D3B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attachment!.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A90A8),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _removeButton(dark: false),
        ],
      ),
    );
  }
  Widget _fileFallback() {
    return Container(
      width: double.infinity,
      height: height,
      color: const Color(0xFFF0F0F0),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Color(0xFF667085), size: 32),
          SizedBox(height: 6),
          Text(
            'Preview unavailable',
            style: TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
        ],
      ),
    );
  }
  Widget _removeButton({bool dark = true}) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: dark
              ? Colors.black.withValues(alpha: 0.45)
              : Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color: dark ? Colors.white : const Color(0xFFC01048),
          size: 16,
        ),
      ),
    );
  }
}
