import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buildtrack_mobile/common/widgets/app_update_dialog.dart';

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final DateTime? publishedAt;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
    this.publishedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 1,
      downloadUrl: json['downloadUrl'] as String? ??
          'https://github.com/Nurofin-Quantum-HQ/Build-Track-App/releases/latest/download/app-release.apk',
      releaseNotes: json['releaseNotes'] as String? ??
          'Latest performance improvements and bug fixes.',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
    );
  }
}

class AppUpdateCheckResult {
  final bool isAvailable;
  final AppUpdateInfo? info;
  final String currentVersion;
  final int currentBuildNumber;

  const AppUpdateCheckResult({
    required this.isAvailable,
    this.info,
    required this.currentVersion,
    required this.currentBuildNumber,
  });
}

class AppUpdateService {
  static const String _primaryUrl =
      'https://github.com/Nurofin-Quantum-HQ/Build-Track-App/releases/latest/download/version.json';
  static const String _fallbackUrl =
      'https://raw.githubusercontent.com/Nurofin-Quantum-HQ/Build-Track-App/main/version.json';

  static const String _prefLastPromptTime = 'bt_app_update_last_prompt_time';
  static const String _prefDismissedBuild = 'bt_app_update_dismissed_build';

  /// Fetch remote metadata and compare with current app version.
  static Future<AppUpdateCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      AppUpdateInfo? remoteInfo;

      // Try primary release asset URL first
      try {
        final res = await http.get(Uri.parse(_primaryUrl)).timeout(
              const Duration(seconds: 5),
            );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          remoteInfo = AppUpdateInfo.fromJson(data);
        }
      } catch (e) {
        debugPrint('[AppUpdateService] Primary check failed: $e');
      }

      // Try raw github fallback if primary asset failed
      if (remoteInfo == null) {
        try {
          final res = await http.get(Uri.parse(_fallbackUrl)).timeout(
                const Duration(seconds: 5),
              );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            remoteInfo = AppUpdateInfo.fromJson(data);
          }
        } catch (e) {
          debugPrint('[AppUpdateService] Fallback check failed: $e');
        }
      }

      if (remoteInfo == null) {
        return AppUpdateCheckResult(
          isAvailable: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
        );
      }

      final isAvailable = _isUpdateAvailable(
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        remoteVersion: remoteInfo.version,
        remoteBuildNumber: remoteInfo.buildNumber,
      );

      return AppUpdateCheckResult(
        isAvailable: isAvailable,
        info: remoteInfo,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Update check error: $e');
      return const AppUpdateCheckResult(
        isAvailable: false,
        currentVersion: '1.0.0',
        currentBuildNumber: 0,
      );
    }
  }

  static bool _isUpdateAvailable({
    required String currentVersion,
    required int currentBuildNumber,
    required String remoteVersion,
    required int remoteBuildNumber,
  }) {
    if (remoteBuildNumber > currentBuildNumber && remoteBuildNumber > 0) {
      return true;
    }
    return _isSemanticNewer(remoteVersion, currentVersion);
  }

  static bool _isSemanticNewer(String remote, String current) {
    try {
      final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (rParts.length < 3) {
        rParts.add(0);
      }
      while (cParts.length < 3) {
        cParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Check whether we should prompt the user right now (respects 24h snooze).
  static Future<bool> shouldPrompt(AppUpdateInfo info) async {
    if (info.forceUpdate) return true;
    final prefs = await SharedPreferences.getInstance();
    final dismissedBuild = prefs.getInt(_prefDismissedBuild);
    final lastPromptMillis = prefs.getInt(_prefLastPromptTime) ?? 0;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    // If already dismissed this exact build and within 24h, skip
    if (dismissedBuild == info.buildNumber) {
      final hoursPassed = (nowMillis - lastPromptMillis) / (1000 * 60 * 60);
      if (hoursPassed < 24) return false;
    }
    return true;
  }

  /// Mark the update as dismissed for later reminder.
  static Future<void> markDismissed(int buildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefDismissedBuild, buildNumber);
    await prefs.setInt(_prefLastPromptTime, DateTime.now().millisecondsSinceEpoch);
  }

  /// Downloads the APK with progress streaming.
  static Future<File?> downloadApk(
    String url, {
    required void Function(double progress, int received, int total) onProgress,
    required void Function(String message) onStatus,
  }) async {
    final client = http.Client();
    try {
      onStatus('Connecting to download server...');
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/buildtrack-update.apk');

      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      onStatus('Downloading update...');
      final sink = targetFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        onProgress(progress, receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      onStatus('Download complete.');
      return targetFile;
    } finally {
      client.close();
    }
  }

  /// Initiates APK package installation.
  static Future<bool> installApk(File apkFile) async {
    if (!await apkFile.exists()) return false;

    if (Platform.isAndroid) {
      try {
        final status = await Permission.requestInstallPackages.status;
        if (status.isDenied) {
          final res = await Permission.requestInstallPackages.request();
          if (!res.isGranted) {
            debugPrint('[AppUpdateService] REQUEST_INSTALL_PACKAGES not granted yet.');
          }
        }
      } catch (e) {
        debugPrint('[AppUpdateService] Permission check error: $e');
      }
    }

    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );
    debugPrint('[AppUpdateService] Install open result: ${result.type} - ${result.message}');
    return result.type == ResultType.done;
  }

  /// High-level method to check and display update prompt if available.
  static Future<void> checkAndPrompt(
    BuildContext context, {
    bool forceCheck = false,
  }) async {
    if (!context.mounted) return;

    final check = await checkForUpdate();
    if (!context.mounted) return;

    if (check.isAvailable && check.info != null) {
      final ok = forceCheck ? true : await shouldPrompt(check.info!);
      if (ok && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: !check.info!.forceUpdate,
          builder: (ctx) => AppUpdateDialog(
            info: check.info!,
            currentVersion: check.currentVersion,
            currentBuildNumber: check.currentBuildNumber,
          ),
        );
      }
    } else if (forceCheck && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'BuildTrack is up to date (v${check.currentVersion})',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
