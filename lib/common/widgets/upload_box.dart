import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';

/// Attach-a-file box (Design V2): an empty white list-row ("tap to upload"),
/// an image preview with the file name over a dark fade, or a file row.
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
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Bt.fast,
      switchInCurve: Bt.ease,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: attachment == null
          ? _emptyState(context)
          : (attachment!.isImage ? _imagePreview(context) : _filePreview(context)),
    );
  }
  Widget _emptyState(BuildContext context) {
    return Semantics(
      key: const ValueKey('empty'),
      button: true,
      label: emptyLabel,
      excludeSemantics: true,
      child: BtPressable(
        onTap: () async {
          final result = await pickAttachmentDirect(context);
          if (result != null) onPicked(result);
        },
        scale: .98,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Bt.card,
            borderRadius: BorderRadius.circular(Bt.rCard),
            boxShadow: Bt.shadow,
          ),
          child: Row(
            children: [
              const BtTile(icon: Icons.upload_file_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emptyLabel, style: BtText.body(context, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Images · PDF · DOC · XLSX', style: BtText.caption(context)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.add_rounded, color: Bt.ink3, size: 22),
            ],
          ),
        ),
      ),
    );
  }
  Widget _imagePreview(BuildContext context) {
    final provider = attachment!.imageProvider;
    if (provider == null) return _filePreview(context);
    return Container(
      key: const ValueKey('image'),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Bt.rCard), boxShadow: Bt.shadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Bt.rCard),
        child: Stack(
          children: [
            Image(
              image: provider,
              width: double.infinity,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fileFallback(context),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Bt.noir.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 14,
              right: 56,
              child: Text(
                attachment!.name,
                style: BtText.subhead(context, color: Bt.bone, weight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Positioned(top: 6, right: 6, child: _removeButton()),
          ],
        ),
      ),
    );
  }
  Widget _filePreview(BuildContext context) {
    return Container(
      key: const ValueKey('file'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: Bt.greenSoft,
        borderRadius: BorderRadius.circular(Bt.rCard),
      ),
      child: Row(
        children: [
          BtTile(icon: attachment!.icon, bg: Bt.card, fg: attachment!.iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Bt.green, size: 14),
                  const SizedBox(width: 4),
                  Text('File attached', style: BtText.body(context, weight: FontWeight.w600, color: Bt.green)),
                ]),
                const SizedBox(height: 2),
                Text(
                  attachment!.name,
                  style: BtText.caption(context, color: Bt.ink2),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _removeButton(dark: false),
        ],
      ),
    );
  }
  Widget _fileFallback(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      color: Bt.fill,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined, color: Bt.ink3, size: 32),
          const SizedBox(height: 6),
          Text('Preview unavailable', style: BtText.caption(context)),
        ],
      ),
    );
  }
  Widget _removeButton({bool dark = true}) {
    return BtIconButton(
      icon: Icons.close_rounded,
      size: 18,
      semantic: 'Remove attachment',
      color: dark ? Bt.bone : Bt.red,
      background: dark ? Bt.noir.withValues(alpha: 0.55) : null,
      onTap: onRemove,
    );
  }
}
