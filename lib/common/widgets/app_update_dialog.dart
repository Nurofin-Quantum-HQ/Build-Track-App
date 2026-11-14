import 'dart:io';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/services/app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  final String currentVersion;
  final int currentBuildNumber;

  const AppUpdateDialog({
    super.key,
    required this.info,
    required this.currentVersion,
    required this.currentBuildNumber,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

enum _UpdateState { idle, downloading, downloaded, error }

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  _UpdateState _state = _UpdateState.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _statusMessage = '';
  String? _errorMessage;
  File? _downloadedApk;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = _UpdateState.downloading;
      _errorMessage = null;
      _progress = 0.0;
      _statusMessage = 'Connecting...';
    });

    try {
      final file = await AppUpdateService.downloadApk(
        widget.info.downloadUrl,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
            _statusMessage = total > 0
                ? 'Downloading: ${(progress * 100).toInt()}%'
                : 'Downloading update...';
          });
        },
        onStatus: (msg) {
          if (!mounted) return;
          setState(() => _statusMessage = msg);
        },
      );

      if (file == null || !await file.exists()) {
        throw Exception('Downloaded file could not be saved.');
      }

      if (!mounted) return;
      setState(() {
        _downloadedApk = file;
        _state = _UpdateState.downloaded;
        _statusMessage = 'Ready to install';
      });

      // Automatically trigger the installer
      await _install(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _install(File file) async {
    final success = await AppUpdateService.installApk(file);
    if (!success && mounted) {
      // In case installer did not trigger or user needs to tap again
      setState(() {
        _statusMessage = 'Tap "Install Now" to proceed with installation';
      });
    }
  }

  void _onLater() {
    AppUpdateService.markDismissed(widget.info.buildNumber);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canDismiss = !widget.info.forceUpdate && _state != _UpdateState.downloading;

    return PopScope(
      canPop: canDismiss,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Bt.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Icon & Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Bt.noir,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Bt.bone,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Available',
                          style: BtText.d3(context).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A new build is ready to install',
                          style: BtText.subhead(context),
                        ),
                      ],
                    ),
                  ),
                  if (canDismiss)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Bt.ink3),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _onLater,
                    ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Version Comparison Badges
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Bt.fill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Bt.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CURRENT', style: BtText.mono(context).copyWith(fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          'v${widget.currentVersion} (#${widget.currentBuildNumber})',
                          style: BtText.num(BtText.body(context)).copyWith(
                            fontWeight: FontWeight.w600,
                            color: Bt.ink2,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: Bt.ink3),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('LATEST', style: BtText.mono(context).copyWith(fontSize: 10)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Bt.greenBright,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'v${widget.info.version} (#${widget.info.buildNumber})',
                              style: BtText.num(BtText.body(context)).copyWith(
                                fontWeight: FontWeight.w700,
                                color: Bt.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Release Notes
              Text('WHAT\'S NEW', style: BtText.mono(context).copyWith(fontSize: 11)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Bt.ground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.releaseNotes,
                    style: BtText.body(context).copyWith(fontSize: 13, height: 1.4),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Progress indicator / Error message / Status
              if (_state == _UpdateState.downloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: Bt.fill,
                    valueColor: const AlwaysStoppedAnimation<Color>(Bt.noir),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_statusMessage, style: BtText.subhead(context).copyWith(fontSize: 12)),
                    if (_totalBytes > 0)
                      Text(
                        '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                        style: BtText.mono(context).copyWith(fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else if (_state == _UpdateState.error) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Bt.redSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Bt.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage ?? 'Failed to download update.',
                          style: const TextStyle(color: Bt.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (_state == _UpdateState.downloaded) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Bt.greenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Bt.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(color: Bt.green, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Action Buttons
              if (_state == _UpdateState.idle)
                Row(
                  children: [
                    if (!widget.info.forceUpdate) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _onLater,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Bt.ink,
                            side: const BorderSide(color: Bt.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Later'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: widget.info.forceUpdate ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _startDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Bt.noir,
                          foregroundColor: Bt.bone,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              else if (_state == _UpdateState.downloaded)
                ElevatedButton(
                  onPressed: _downloadedApk != null ? () => _install(_downloadedApk!) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Bt.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Install Now', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              else if (_state == _UpdateState.error)
                ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Bt.noir,
                    foregroundColor: Bt.bone,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Retry Download'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
