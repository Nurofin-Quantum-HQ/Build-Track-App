import 'dart:convert';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openDocumentPlatform({
  required String doc,
  required String name,
}) async {
  if (doc.startsWith('data:')) {
    final parts = doc.split(';base64,');
    if (parts.length == 2) {
      final bytes = base64Decode(parts.last);
      final tempDir = await getTemporaryDirectory();
      final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final fileName = cleanName.contains('.') ? cleanName : '$cleanName.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
      return;
    }
  }

  if (doc.startsWith('http')) {
    final uri = Uri.parse(doc);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
